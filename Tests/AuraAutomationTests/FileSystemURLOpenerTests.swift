import AuraCore
import Foundation
import Testing

@testable import AuraAutomation

/// Records what was handed to LaunchServices and returns a scripted result, so
/// every assertion below is about *our* contract rather than about whether the
/// machine running the tests happened to open something.
private final class LaunchServicesSpy: LaunchServicesOpening, @unchecked Sendable {
  private let lock = NSLock()
  private let result: Bool
  private var openedURLs: [URL] = []
  private var revealedPaths: [String] = []

  init(result: Bool = true) {
    self.result = result
  }

  func open(_ url: URL) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    openedURLs.append(url)
    return result
  }

  func selectFile(_ path: String, inFileViewerRootedAtPath root: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    revealedPaths.append(path)
    return result
  }

  var opened: [URL] {
    lock.lock()
    defer { lock.unlock() }
    return openedURLs
  }

  var revealed: [String] {
    lock.lock()
    defer { lock.unlock() }
    return revealedPaths
  }

  var totalCalls: Int { opened.count + revealed.count }
}

/// A disposable directory tree. Each test gets its own, so nothing leaks
/// between tests and nothing outside the temporary directory is touched.
private final class Sandbox {
  let root: URL

  init() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-sp004-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  @discardableResult
  func file(_ name: String, executable: Bool = false) throws -> URL {
    let url = root.appendingPathComponent(name)
    try Data("contents".utf8).write(to: url)
    if executable {
      try FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: url.path)
    }
    return url
  }

  @discardableResult
  func directory(_ name: String) throws -> URL {
    let url = root.appendingPathComponent(name, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  func symlink(_ name: String, to destination: URL) throws -> URL {
    let url = root.appendingPathComponent(name)
    try FileManager.default.createSymbolicLink(at: url, withDestinationURL: destination)
    return url
  }

  deinit {
    try? FileManager.default.removeItem(at: root)
  }
}

/// Returns the refusal a validator produced, or `nil` if it accepted.
///
/// Takes an untyped `throws` closure deliberately: Swift 6 does not infer a
/// closure literal's thrown type as a specific error, so a
/// `throws(OpenTargetRejection)` parameter cannot accept `{ try validator... }`
/// at the call site. The downcast below re-establishes the type, and a
/// non-`OpenTargetRejection` error fails the assertion by returning `nil`
/// rather than being silently treated as the expected refusal.
private func rejection(_ body: () throws -> URL) -> OpenTargetRejection? {
  do {
    _ = try body()
    return nil
  } catch let error as OpenTargetRejection {
    return error
  } catch {
    return nil
  }
}

@Suite("SP-004 filesystem and URL open-target validation")
struct OpenTargetValidatorTests {
  private let validator = OpenTargetValidator()

  // MARK: - Accepting the intended targets

  @Test("accepts a plain regular file and returns its canonical path")
  func acceptsRegularFile() throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let resolved = try validator.validateFile(path: file.path)
    #expect(FileManager.default.fileExists(atPath: resolved.path))
    #expect(resolved.lastPathComponent == "notes.txt")
  }

  @Test("accepts a directory for open_folder and rejects it for open_file")
  func directoryIsFolderOnly() throws {
    let sandbox = try Sandbox()
    let dir = try sandbox.directory("Reports")
    #expect(throws: Never.self) { try validator.validateFolder(path: dir.path) }
    #expect(rejection { try validator.validateFile(path: dir.path) } == .notARegularFile)
  }

  @Test("accepts a file for open_file and rejects it for open_folder")
  func fileIsFileOnly() throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    #expect(throws: Never.self) { try validator.validateFile(path: file.path) }
    #expect(rejection { try validator.validateFolder(path: file.path) } == .notADirectory)
  }

  @Test("reveal accepts both a file and a directory, since revealing never runs anything")
  func revealAcceptsEither() throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let dir = try sandbox.directory("Reports")
    #expect(throws: Never.self) { try validator.validateRevealTarget(path: file.path) }
    #expect(throws: Never.self) { try validator.validateRevealTarget(path: dir.path) }
  }

  @Test("resolves a symlink to its canonical destination rather than opening the link")
  func resolvesSymlink() throws {
    let sandbox = try Sandbox()
    let real = try sandbox.file("real.txt")
    let link = try sandbox.symlink("link.txt", to: real)
    let resolved = try validator.validateFile(path: link.path)
    #expect(resolved.lastPathComponent == "real.txt")
  }

  // MARK: - Malformed input

  @Test("rejects an empty, whitespace-only, or missing target")
  func rejectsEmptyAndMissing() {
    #expect(rejection { try validator.validateFile(path: "") } == .emptyTarget)
    #expect(rejection { try validator.validateFile(path: "   ") } == .emptyTarget)
    #expect(
      rejection { try validator.validateFile(path: "/nonexistent-\(UUID().uuidString)") }
        == .doesNotExist)
  }

  @Test("rejects control characters and null bytes in a path")
  func rejectsControlCharacters() {
    #expect(rejection { try validator.validateFile(path: "/tmp/a\u{0}b") } == .containsNullByte)
    #expect(
      rejection { try validator.validateFile(path: "/tmp/a\u{1b}[2Jb") }
        == .controlCharactersInTarget)
    #expect(
      rejection { try validator.validateFile(path: "/tmp/a\nb") } == .controlCharactersInTarget)
  }

  @Test("rejects a target longer than the configured limit")
  func rejectsOverlongTarget() {
    let tiny = OpenTargetValidator(maximumTargetLength: 16)
    #expect(
      rejection { try tiny.validateFile(path: "/" + String(repeating: "a", count: 64)) }
        == .targetTooLong(limit: 16))
  }

  // MARK: - Adversarial: execution disguised as "opening"

  @Test(
    "rejects executable and location-forwarding extensions that LaunchServices would run",
    arguments: [
      "payload.command", "payload.scpt", "payload.workflow", "payload.webloc",
      "payload.inetloc", "payload.url", "payload.terminal", "payload.jar",
    ])
  func rejectsExecutableExtensions(name: String) throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file(name)
    guard case .executableTarget = rejection({ try validator.validateFile(path: file.path) })
    else {
      Issue.record("\(name) was not refused as an executable target")
      return
    }
  }

  @Test("rejects a file carrying the executable bit even with a harmless extension")
  func rejectsExecutableBit() throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("harmless.txt", executable: true)
    #expect(
      rejection { try validator.validateFile(path: file.path) }
        == .executableTarget(detail: "the file is marked executable"))
  }

  @Test("rejects an application bundle for both open_file and open_folder")
  func rejectsApplicationBundle() throws {
    let sandbox = try Sandbox()
    let bundle = try sandbox.directory("Evil.app")
    // Either classification is a correct refusal: a real bundle reports
    // isApplication, while a synthetic one is caught by the extension rule.
    let fileRejection = rejection { try validator.validateFile(path: bundle.path) }
    let folderRejection = rejection { try validator.validateFolder(path: bundle.path) }
    #expect(fileRejection != nil)
    #expect(folderRejection != nil)
    if case .notADirectory = folderRejection {
      Issue.record("an .app bundle must not be refused merely as 'not a directory'")
    }
  }

  @Test("rejects a symlink whose destination is an executable target")
  func rejectsSymlinkToExecutable() throws {
    let sandbox = try Sandbox()
    let payload = try sandbox.file("payload.command")
    let link = try sandbox.symlink("innocent.txt", to: payload)
    guard case .executableTarget = rejection({ try validator.validateFile(path: link.path) })
    else {
      Issue.record("a symlink to a .command file must be refused after resolution")
      return
    }
  }

  // MARK: - Adversarial: containment

  @Test("rejects a target that escapes the approved roots via ..")
  func rejectsTraversalEscape() throws {
    let sandbox = try Sandbox()
    let approved = try sandbox.directory("approved")
    let outside = try sandbox.file("outside.txt")
    let confined = OpenTargetValidator(approvedRoots: [approved.path])
    let traversal = approved.path + "/../outside.txt"
    #expect(rejection { try confined.validateFile(path: traversal) } == .outsideApprovedRoots)
    #expect(rejection { try confined.validateFile(path: outside.path) } == .outsideApprovedRoots)
  }

  @Test("rejects a symlink inside an approved root that points outside it")
  func rejectsSymlinkEscape() throws {
    let sandbox = try Sandbox()
    let approved = try sandbox.directory("approved")
    let secret = try sandbox.file("secret.txt")
    let link = approved.appendingPathComponent("innocent.txt")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: secret)
    let confined = OpenTargetValidator(approvedRoots: [approved.path])
    #expect(rejection { try confined.validateFile(path: link.path) } == .outsideApprovedRoots)
  }

  @Test("does not treat a sibling root with a shared prefix as contained")
  func rejectsSiblingPrefixRoot() throws {
    let sandbox = try Sandbox()
    _ = try sandbox.directory("approved")
    let sibling = try sandbox.directory("approved-evil")
    let file = sibling.appendingPathComponent("payload.txt")
    try Data("x".utf8).write(to: file)
    let confined = OpenTargetValidator(
      approvedRoots: [sandbox.root.appendingPathComponent("approved").path])
    #expect(rejection { try confined.validateFile(path: file.path) } == .outsideApprovedRoots)
  }

  @Test("accepts a target inside an approved root")
  func acceptsInsideApprovedRoot() throws {
    let sandbox = try Sandbox()
    let approved = try sandbox.directory("approved")
    let file = approved.appendingPathComponent("notes.txt")
    try Data("x".utf8).write(to: file)
    let confined = OpenTargetValidator(approvedRoots: [approved.path])
    #expect(throws: Never.self) { try confined.validateFile(path: file.path) }
  }

  // MARK: - Adversarial: URL schemes

  @Test(
    "refuses every scheme outside the allowlist",
    arguments: [
      "file:///etc/passwd", "javascript:alert(1)", "data:text/html,<script>",
      "ftp://example.com/x", "smb://example.com/share", "vbscript:msgbox",
      "customapp://do-something",
    ])
  func rejectsDisallowedSchemes(raw: String) {
    guard case .disallowedScheme = rejection({ try validator.validateURL(raw) }) else {
      Issue.record("\(raw) was not refused by scheme")
      return
    }
  }

  @Test("accepts http, https and mailto")
  func acceptsAllowedSchemes() throws {
    #expect(throws: Never.self) { try validator.validateURL("https://example.com/docs") }
    #expect(throws: Never.self) { try validator.validateURL("http://example.com") }
    #expect(throws: Never.self) { try validator.validateURL("mailto:someone@example.com") }
  }

  @Test("refuses a URL embedding a username or password")
  func rejectsEmbeddedCredentials() {
    // REPO_HYGIENE_SECRET_FIXTURE: basic_auth_url — intentional test fixture, not a real credential
    #expect(
      rejection { try validator.validateURL("https://user:secret@example.com") }
        == .embeddedCredentials)
    #expect(
      rejection { try validator.validateURL("https://user@example.com") } == .embeddedCredentials)
  }

  @Test("refuses an http URL with no host")
  func rejectsHostlessURL() {
    #expect(rejection { try validator.validateURL("https:///just-a-path") } == .missingHost)
  }

  @Test("refuses a mailto whose recipient decodes to a mail-header injection")
  func rejectsMailtoHeaderInjection() {
    // %0A decodes to a newline inside `path`, which would inject a new header.
    #expect(
      rejection { try validator.validateURL("mailto:a@b.com%0ABcc:victim@c.com") }
        == .controlCharactersInTarget)
    #expect(rejection { try validator.validateURL("mailto:") } == .malformedURL)
  }

  @Test("refuses a malformed or scheme-less URL")
  func rejectsMalformedURL() {
    #expect(rejection { try validator.validateURL("example.com") } == .malformedURL)
    #expect(rejection { try validator.validateURL("   ") } == .emptyTarget)
  }

  // MARK: - Sensitive locations

  @Test("refuses credential and privacy-state locations")
  func rejectsSensitiveLocations() throws {
    let sandbox = try Sandbox()
    let ssh = try sandbox.directory(".ssh")
    let key = ssh.appendingPathComponent("id_rsa")
    try Data("KEY".utf8).write(to: key)
    guard case .sensitiveLocation = rejection({ try validator.validateFile(path: key.path) })
    else {
      Issue.record("a file under .ssh/ must be refused as a protected location")
      return
    }
    guard
      case .sensitiveLocation = rejection({ try validator.validateRevealTarget(path: key.path) })
    else {
      Issue.record("revealing a file under .ssh/ must also be refused")
      return
    }
  }

  @Test("refuses a sensitive location spelled with different case (APFS is case-insensitive)")
  func rejectsCaseVariantSensitiveLocation() throws {
    // RISK-SP-004-CASE-SENSITIVITY closure: APFS is case-insensitive by
    // default, so `/Users/alice/.SSH/id_rsa` resolves to the same file as
    // `/.ssh/id_rsa`. The validator must refuse the case variant identically.
    let sandbox = try Sandbox()
    let ssh = try sandbox.directory(".SSH")
    let key = ssh.appendingPathComponent("id_rsa")
    try Data("KEY".utf8).write(to: key)
    guard case .sensitiveLocation = rejection({ try validator.validateFile(path: key.path) })
    else {
      Issue.record("a file under .SSH/ (case variant) must be refused as a protected location")
      return
    }
    guard
      case .sensitiveLocation = rejection({ try validator.validateRevealTarget(path: key.path) })
    else {
      Issue.record("revealing a file under .SSH/ (case variant) must also be refused")
      return
    }
  }
}

@Suite("SP-004 filesystem and URL adapter execution contract")
struct FileSystemURLOpenerTests {

  // MARK: - Contract

  @Test("opens an accepted file and reports the canonical target")
  func opensAcceptedFile() async throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)

    let outcome = try await opener.openFile(path: file.path)

    #expect(outcome.capabilityID == "filesystem.open_file")
    #expect(spy.opened.count == 1)
    #expect(spy.opened.first?.path == outcome.target)
    #expect(FileManager.default.fileExists(atPath: outcome.target))
  }

  @Test("reveal uses the Finder selection call, not a plain open")
  func revealUsesSelectFile() async throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)

    let outcome = try await opener.reveal(path: file.path)

    #expect(outcome.capabilityID == "filesystem.reveal")
    #expect(spy.revealed.count == 1)
    #expect(spy.opened.isEmpty)
  }

  @Test("opens an accepted URL and reports the normalized target")
  func opensAcceptedURL() async throws {
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)

    let outcome = try await opener.openURL("https://example.com/docs")

    #expect(outcome.capabilityID == "url.open")
    #expect(outcome.target == "https://example.com/docs")
    #expect(spy.opened.first?.absoluteString == "https://example.com/docs")
  }

  @Test("reports the resolved destination of a symlink, never the caller's raw input")
  func reportsResolvedTarget() async throws {
    let sandbox = try Sandbox()
    let real = try sandbox.file("real.txt")
    let link = try sandbox.symlink("link.txt", to: real)
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)

    let outcome = try await opener.openFile(path: link.path)

    #expect(outcome.target.hasSuffix("real.txt"))
    #expect(!outcome.target.hasSuffix("link.txt"))
  }

  // MARK: - Refusal never reaches the side effect

  @Test("a refused target is never handed to LaunchServices")
  func refusalPerformsNoSideEffect() async throws {
    let sandbox = try Sandbox()
    let payload = try sandbox.file("payload.command")
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)

    await #expect(throws: AuraError.self) { try await opener.openFile(path: payload.path) }
    await #expect(throws: AuraError.self) { try await opener.openURL("file:///etc/passwd") }
    await #expect(throws: AuraError.self) {
      try await opener.openFolder(path: "/nonexistent-\(UUID().uuidString)")
    }

    #expect(spy.totalCalls == 0)
  }

  @Test("a refusal is reported as a security error, not an automation failure")
  func refusalIsSecurityError() async throws {
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)
    do {
      _ = try await opener.openURL("javascript:alert(1)")
      Issue.record("a javascript: URL must be refused")
    } catch {
      guard case .securityError = error else {
        Issue.record("expected a securityError, got \(error)")
        return
      }
    }
  }

  // MARK: - Failure verification

  @Test("a false return from the system is a failure, never a silent success")
  func systemRefusalIsReportedAsFailure() async throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let spy = LaunchServicesSpy(result: false)
    let opener = FileSystemURLOpener(launchServices: spy)

    do {
      _ = try await opener.openFile(path: file.path)
      Issue.record("a false result from LaunchServices must not be reported as success")
    } catch {
      guard case .automationError = error else {
        Issue.record("expected an automationError, got \(error)")
        return
      }
    }
    #expect(spy.opened.count == 1)
  }

  @Test("a false return from the Finder selection call is also a failure")
  func revealFailureIsReported() async throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let spy = LaunchServicesSpy(result: false)
    let opener = FileSystemURLOpener(launchServices: spy)

    await #expect(throws: AuraError.self) { try await opener.reveal(path: file.path) }
  }

  // MARK: - Cancellation

  @Test("a task cancelled before the handoff opens nothing")
  func cancelledTaskOpensNothing() async throws {
    let sandbox = try Sandbox()
    let file = try sandbox.file("notes.txt")
    let spy = LaunchServicesSpy()
    let opener = FileSystemURLOpener(launchServices: spy)

    let task = Task {
      // Cancellation is observed at the latest point that still precedes the
      // side effect; these capabilities declare supportsCancellation: false
      // because a handoff already issued to LaunchServices cannot be recalled.
      try await opener.openFile(path: file.path)
    }
    task.cancel()

    let result = await task.result
    #expect(throws: AuraError.self) { try result.get() }
    #expect(spy.totalCalls == 0)
  }
}
