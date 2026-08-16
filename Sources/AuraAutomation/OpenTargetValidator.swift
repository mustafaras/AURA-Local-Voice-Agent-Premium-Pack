import AuraCore
import Foundation

/// Pure, deterministic validation for the `filesystem.open_file`,
/// `filesystem.open_folder`, `filesystem.reveal`, and `url.open` capabilities.
///
/// Kept free of `NSWorkspace` so every rule is unit- and adversarially
/// testable without performing a side effect. `FileSystemURLOpener` runs this
/// first and only touches LaunchServices once a target is accepted.
///
/// The central hazard these rules address: all four capabilities sit at the
/// `.reversible` risk tier, but `NSWorkspace.open(_:)` runs a target's default
/// handler. For an application bundle, a `.command`/`.scpt`/`.workflow` file,
/// or any file carrying the owner-executable bit, "opening" *is* execution —
/// silently escalating a reversible capability into arbitrary code execution.
/// Location-forwarding files (`.webloc`, `.inetloc`, `.url`) are the same
/// problem one level removed: opening one navigates to an embedded URL that
/// never passed `validateURL(_:)`'s scheme allowlist.
///
/// Path canonicalization and root containment are delegated to
/// `AuraCore.PathConfinement`, the hardened primitive introduced for exactly
/// this purpose: it resolves `..` and symlinks before comparing and matches
/// component-wise, so neither `/approved/../etc` nor a sibling root named
/// `/approved-evil` is ever treated as contained.
public struct OpenTargetValidator: Sendable {
  /// Roots a target must resolve inside. Empty means no root restriction —
  /// every other rule still applies. Callers wanting a narrower blast radius
  /// supply roots explicitly.
  public let approvedRoots: [String]
  public let maximumTargetLength: Int
  public let allowedURLSchemes: Set<String>

  /// Extensions LaunchServices executes, or that forward to another location.
  /// Matched case-insensitively against the canonical path extension.
  public static let executableExtensions: Set<String> = [
    "app", "command", "terminal", "tool", "scpt", "scptd", "applescript",
    "workflow", "action", "shortcut", "pkg", "mpkg", "dmg", "prefpane",
    "qlgenerator", "saver", "service", "wdgt", "kext", "osax", "bundle",
    "plugin", "appex", "jar", "exe", "bat", "vbs",
    // Location-forwarding types: opening one navigates to an embedded URL
    // that never passed the scheme allowlist.
    "webloc", "inetloc", "url", "fileloc",
  ]

  /// Path fragments whose contents are credentials or privacy state. Matched
  /// against the canonical path so a symlink cannot smuggle one in.
  public static let sensitivePathFragments: [(fragment: String, detail: String)] = [
    ("/Library/Keychains/", "keychain"),
    ("/.ssh/", "SSH key material"),
    ("/.gnupg/", "GnuPG key material"),
    ("/.aws/", "cloud credentials"),
    ("/private/var/db/TCC/", "privacy database"),
    ("/Library/Application Support/com.apple.TCC/", "privacy database"),
  ]

  /// The posture every production construction site uses: a target must
  /// resolve inside `DeclaredFileRoots.all`. The bare `init()` default leaves
  /// `approvedRoots` empty ("no root restriction") for focused tests that
  /// supply their own sandbox, so production confinement has to be stated
  /// explicitly rather than inherited by accident — SP-006's closeout found
  /// production silently running with the empty default.
  public static let production = OpenTargetValidator(approvedRoots: DeclaredFileRoots.all)

  public init(
    approvedRoots: [String] = [],
    maximumTargetLength: Int = 4096,
    allowedURLSchemes: Set<String> = ["http", "https", "mailto"]
  ) {
    self.approvedRoots = approvedRoots
    self.maximumTargetLength = maximumTargetLength
    self.allowedURLSchemes = Set(allowedURLSchemes.map { $0.lowercased() })
  }

  // MARK: - Filesystem

  /// Accepts a regular, non-executable file. Rejects directories, bundles,
  /// and anything LaunchServices would run instead of display.
  public func validateFile(path: String) throws(OpenTargetRejection) -> URL {
    let url = try canonicalExistingURL(path: path)
    let values = try typeValues(for: url)
    if values.isApplication == true { throw .applicationBundle }
    guard values.isDirectory != true else { throw .notARegularFile }
    guard values.isRegularFile == true else { throw .notARegularFile }
    try rejectExecutableExtension(url: url)
    if FileManager.default.isExecutableFile(atPath: url.path) {
      throw .executableTarget(detail: "the file is marked executable")
    }
    return url
  }

  /// Accepts a directory that is not an application bundle — opening a `.app`
  /// "folder" launches it rather than revealing its contents.
  public func validateFolder(path: String) throws(OpenTargetRejection) -> URL {
    let url = try canonicalExistingURL(path: path)
    let values = try typeValues(for: url)
    if values.isApplication == true { throw .applicationBundle }
    guard values.isDirectory == true else { throw .notADirectory }
    try rejectExecutableExtension(url: url)
    return url
  }

  /// Accepts a file or a directory. Revealing selects an item in Finder and
  /// never runs it, so the executable rules do not apply — but the target
  /// must still exist, resolve inside the approved roots, and not be a
  /// protected location, since revealing discloses that it exists.
  public func validateRevealTarget(path: String) throws(OpenTargetRejection) -> URL {
    try canonicalExistingURL(path: path)
  }

  // MARK: - URL

  /// Accepts only the allow-listed schemes with a well-formed authority.
  /// Everything else — `file:`, `javascript:`, `data:`, and every custom
  /// application scheme — is refused by omission rather than by denylist, so
  /// a newly registered handler cannot become reachable by default.
  public func validateURL(_ raw: String) throws(OpenTargetRejection) -> URL {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    try rejectMalformedText(trimmed)
    guard let components = URLComponents(string: trimmed) else { throw .malformedURL }
    guard let scheme = components.scheme?.lowercased(), !scheme.isEmpty else {
      throw .malformedURL
    }
    guard allowedURLSchemes.contains(scheme) else { throw .disallowedScheme(scheme: scheme) }
    guard components.user == nil, components.password == nil else { throw .embeddedCredentials }
    if scheme == "mailto" {
      // `mailto:` carries its recipient in the path. An empty one has no
      // recipient; a decoded newline would inject extra mail headers, and
      // `URLComponents` percent-decodes `%0A` into `path`, so re-check it.
      let recipient = components.path
      guard !recipient.isEmpty else { throw .malformedURL }
      guard !recipient.unicodeScalars.contains(where: Self.isForbiddenControlScalar) else {
        throw .controlCharactersInTarget
      }
    } else {
      guard let host = components.host, !host.isEmpty else { throw .missingHost }
    }
    guard let url = components.url else { throw .malformedURL }
    return url
  }

  // MARK: - Shared rules

  /// Canonicalizes through `PathConfinement` (expanding `~`/`$VAR`, resolving
  /// `..` and symlinks), then applies existence and containment rules to the
  /// *canonical* path. Canonicalizing first is what stops a symlink inside an
  /// approved root from redirecting to a target outside it, or to a bundle.
  private func canonicalExistingURL(path: String) throws(OpenTargetRejection) -> URL {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    try rejectMalformedText(trimmed)
    let canonical = PathConfinement.canonicalize(trimmed)
    guard canonical.hasPrefix("/") else { throw .notAnAbsolutePath }
    guard FileManager.default.fileExists(atPath: canonical) else { throw .doesNotExist }
    try rejectSensitiveLocation(canonicalPath: canonical)
    if !approvedRoots.isEmpty,
      !PathConfinement.isContained(canonical, within: approvedRoots)
    {
      throw .outsideApprovedRoots
    }
    return URL(fileURLWithPath: canonical)
  }

  private func rejectMalformedText(_ trimmed: String) throws(OpenTargetRejection) {
    guard !trimmed.isEmpty else { throw .emptyTarget }
    guard trimmed.count <= maximumTargetLength else {
      throw .targetTooLong(limit: maximumTargetLength)
    }
    guard !trimmed.utf8.contains(0) else { throw .containsNullByte }
    guard !trimmed.unicodeScalars.contains(where: Self.isForbiddenControlScalar) else {
      throw .controlCharactersInTarget
    }
  }

  private func typeValues(for url: URL) throws(OpenTargetRejection) -> URLResourceValues {
    do {
      return try url.resourceValues(forKeys: [
        .isRegularFileKey, .isDirectoryKey, .isApplicationKey,
      ])
    } catch {
      // The path existed a moment ago; if its attributes cannot be read now,
      // fail closed rather than opening something unclassified.
      throw .doesNotExist
    }
  }

  private func rejectExecutableExtension(url: URL) throws(OpenTargetRejection) {
    let ext = url.pathExtension.lowercased()
    guard !ext.isEmpty, Self.executableExtensions.contains(ext) else { return }
    throw .executableTarget(detail: "\".\(ext)\" targets are executed or forward elsewhere")
  }

  private func rejectSensitiveLocation(canonicalPath: String) throws(OpenTargetRejection) {
    // Compare against a trailing-slash form so a fragment like "/.ssh/" also
    // matches the directory itself, not only files beneath it. APFS is
    // case-insensitive by default on macOS, so the comparison uses a
    // case-normalized probe — a user-named `/Users/alice/.SSH/` on a
    // case-insensitive volume resolves to the same file as `/.ssh/` and must
    // be refused identically. (RISK-SP-004-CASE-SENSITIVITY.)
    let probe = canonicalPath.hasSuffix("/") ? canonicalPath : canonicalPath + "/"
    let normalizedProbe = probe.lowercased()
    for entry in Self.sensitivePathFragments where normalizedProbe.contains(entry.fragment) {
      throw .sensitiveLocation(detail: entry.detail)
    }
  }

  /// Control characters are rejected outright. They have no legitimate place
  /// in a path or URL and are the vehicle for terminal-escape and mail-header
  /// injection when the target is later rendered.
  private static func isForbiddenControlScalar(_ scalar: Unicode.Scalar) -> Bool {
    scalar.value < 0x20 || scalar.value == 0x7F
  }
}
