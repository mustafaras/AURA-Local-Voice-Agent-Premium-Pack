import AuraCore
import AuraProductivity
import AuraSecurity
import CryptoKit
import Darwin
import Foundation
import Security
import Synchronization

// AURA Chrome native messaging host.
//
// Chrome launches this executable for every native message the extension
// sends, passes the message on stdin (4-byte little-endian length prefix +
// JSON), and reads the reply on stdout in the same framing. This host is the
// Chrome analogue of the Safari app-extension entry point: it decodes the
// untrusted message and delegates to the exact same
// `SafariBridgeNativeMessageHandler` + `SafariBridgeEnvelopeWriter` the Safari
// path uses, so the whole extension-to-app trust path stays covered by the
// regression suite and the two browsers cannot drift apart.
//
// The host writes the signed envelope to the same shared Application Support
// container the AURA app reads, so `browser.read` becomes ready through the
// identical `AuthenticatedSafariWebExtensionTransport` — no new consumer code.

// Chrome native messaging framing: 4-byte little-endian message length, then
// the JSON payload. Replies use the same framing.
enum ChromeNativeMessaging {
  static func readMessage() -> Data? {
    guard let header = readExactly(4) else { return nil }
    let lengthBytes = [UInt8](header)
    let length = Int(
      UInt32(lengthBytes[0])
        | (UInt32(lengthBytes[1]) << 8)
        | (UInt32(lengthBytes[2]) << 16)
        | (UInt32(lengthBytes[3]) << 24))
    guard length > 0, length <= SafariBridgeNativeMessageHandler.maxMessageBytes else {
      return nil
    }
    return readExactly(length)
  }

  private static func readExactly(_ count: Int) -> Data? {
    var result = Data()
    while result.count < count {
      guard let chunk = try? FileHandle.standardInput.read(
        upToCount: count - result.count), !chunk.isEmpty
      else { return nil }
      result.append(chunk)
    }
    return result
  }

  static func writeReply(_ data: Data) {
    let length = UInt32(data.count)
    var header = Data()
    header.append(UInt8(length & 0xFF))
    header.append(UInt8((length >> 8) & 0xFF))
    header.append(UInt8((length >> 16) & 0xFF))
    header.append(UInt8((length >> 24) & 0xFF))
    var out = Data()
    out.append(header)
    out.append(data)
    FileHandle.standardOutput.write(out)
  }
}

// The host's own view of the bridge contract, read from its Info.plist the
// same way the Safari appex does. The build script fills these from the same
// defaults the app uses.
struct ChromeHostConfiguration {
  static let nativeHostName = "ai.aura.local.agent"
  static let chromeExtensionID = "ggccnafnholmbpghgljfbofapcbhkdjh"
  static let chromeSigningServiceName = "com.aura.chrome-bridge"

  let extensionID: String
  let profileID: String
  let secretServiceName: String
  let sharedContainerURL: URL
  let extensionPath: String

  init(homeDirectory: URL) {
    let configurationURL = homeDirectory.appending(
      path: "Library/Application Support/AURA/ChromeNativeHost/host-config.json")
    let stored = (try? Data(contentsOf: configurationURL))
      .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
      ?? [:]
    extensionID = stored["extensionID"] ?? "com.aura.safari-extension"
    profileID = stored["profileID"] ?? "personal"
    // Chrome uses a distinct Keychain namespace. Reusing Safari's service and
    // account names made this non-sandboxed host query a private key created
    // in Safari's data-protection Keychain; securityd waited for UI the native
    // host cannot present. A separate login-Keychain item remains private and
    // returns without that cross-sandbox ACL conflict.
    secretServiceName = Self.chromeSigningServiceName
    let rawPath = stored["sharedContainerPath"]
      ?? "Library/Application Support/AURA/SafariBridge/observation.json"
    sharedContainerURL =
      rawPath.hasPrefix("/")
      ? URL(fileURLWithPath: rawPath)
      : homeDirectory.appending(path: rawPath)
    extensionPath = stored["extensionPath"] ?? ""
  }
}

enum ChromeHostPeerValidator {
  private static let chromeRequirement =
    #"(identifier "com.google.Chrome" or identifier "com.google.Chrome.beta" or identifier "com.google.Chrome.dev" or identifier "com.google.Chrome.canary") and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = EQHXZ8M8AV"#
  private static let approvedHashes = [
    "README.md": "68688f53783a084c625aa72c4b92337da0c239c1063388f884735cf47112fac6",
    "manifest.json": "8d6ef2bd484ba791704b31493e7b5b05493b0d3709e964c503575c0c3e0574be",
    "background.js": "d3606a61d2887dd222c13b6ba9a424cb6c8d7ad3fe77a6046d7e85c642fb2f3d",
    "bootstrap.html": "d91a9bd538cd61a9e1f50bbd38b8136a42e31fab44d4582867154b49fb40479f",
    "bootstrap.js": "2a882249dbe39f8b699a032cece2c2e88fce771d5d4825a35aae49fa242a6d2b",
    "bootstrap.css": "72e6d84ce93d2038f50904662839a824ac874b3eb7a536f179dfe6c1a63b1ecc",
  ]

  static func validate(
    arguments: [String], extensionPath: String, parentPID: pid_t = getppid()
  ) -> Bool {
    guard arguments.count > 1,
      arguments[1] == "chrome-extension://\(ChromeHostConfiguration.chromeExtensionID)/"
    else { return fail("origin") }
    guard !extensionPath.isEmpty else { return fail("extension-path-missing") }
    guard signedContainingAppIsValid(extensionPath: extensionPath)
    else { return fail("containing-app-signature") }
    guard extensionPredatesChrome(extensionPath: extensionPath, processID: parentPID)
    else { return fail("extension-changed-after-launch") }
    guard extensionMatchesApprovedHashes(at: extensionPath)
    else { return fail("extension-hash") }

    guard SecCodeHelperIPCPeerVerifier().verify(
      processID: parentPID, designatedRequirement: chromeRequirement)
    else { return fail("parent-signature") }
    return true
  }

  private static func extensionMatchesApprovedHashes(at path: String) -> Bool {
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    guard let entries = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
      options: []),
      Set(entries.map(\.lastPathComponent)) == Set(approvedHashes.keys)
    else { return false }

    return approvedHashes.allSatisfy { filename, expected in
      let fileURL = directory.appending(path: filename)
      guard let values = try? fileURL.resourceValues(
        forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
        values.isRegularFile == true,
        values.isSymbolicLink != true,
        let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
      else {
        return false
      }
      return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        == expected
    }
  }

  private static func signedContainingAppIsValid(extensionPath: String) -> Bool {
    let marker = ".app/Contents/Resources/ChromeExtension"
    guard let markerRange = extensionPath.range(of: marker), markerRange.upperBound == extensionPath.endIndex
    else { return false }
    let appPath = String(extensionPath[..<markerRange.lowerBound]) + ".app"
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(
      URL(fileURLWithPath: appPath) as CFURL, [], &staticCode) == errSecSuccess,
      let staticCode
    else { return false }
    let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
    var requirement: SecRequirement?
    guard SecRequirementCreateWithString(
      #"identifier "ai.aura.local.agent""# as CFString, [], &requirement) == errSecSuccess,
      let requirement,
      SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess,
      let appCertificate = signingCertificateData(for: staticCode),
      let hostCertificate = currentHostSigningCertificateData()
    else { return false }
    return appCertificate == hostCertificate
  }

  private static func currentHostSigningCertificateData() -> Data? {
    var dynamicCode: SecCode?
    guard SecCodeCopySelf([], &dynamicCode) == errSecSuccess, let dynamicCode else {
      return nil
    }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(dynamicCode, [], &staticCode) == errSecSuccess,
      let staticCode
    else { return nil }
    return signingCertificateData(for: staticCode)
  }

  private static func signingCertificateData(for code: SecStaticCode) -> Data? {
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(
      code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
      let dictionary = information as? [String: Any],
      let certificates = dictionary[kSecCodeInfoCertificates as String] as? [SecCertificate],
      let certificate = certificates.first
    else { return nil }
    return SecCertificateCopyData(certificate) as Data
  }

  private static func extensionPredatesChrome(
    extensionPath: String, processID: pid_t
  ) -> Bool {
    var processInfo = proc_bsdinfo()
    let size = withUnsafeMutablePointer(to: &processInfo) { pointer in
      proc_pidinfo(
        processID, PROC_PIDTBSDINFO, 0, pointer,
        Int32(MemoryLayout<proc_bsdinfo>.size))
    }
    guard size == MemoryLayout<proc_bsdinfo>.size else { return false }
    let processStartedAt = TimeInterval(processInfo.pbi_start_tvsec)
      + TimeInterval(processInfo.pbi_start_tvusec) / 1_000_000

    return approvedHashes.keys.allSatisfy { filename in
      var fileInfo = stat()
      let path = URL(fileURLWithPath: extensionPath).appending(path: filename).path
      guard lstat(path, &fileInfo) == 0 else { return false }
      let changedAt = TimeInterval(fileInfo.st_ctimespec.tv_sec)
        + TimeInterval(fileInfo.st_ctimespec.tv_nsec) / 1_000_000_000
      return changedAt <= processStartedAt
    }
  }

  private static func fail(_ gate: String) -> Bool {
    let url = FileManager.default.homeDirectoryForCurrentUser.appending(
      path: "Library/Application Support/AURA/ChromeNativeHost/last-validation-error.txt")
    try? Data(gate.utf8).write(to: url, options: .atomic)
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: url.path)
    return false
  }
}

// Resolve the user's real home directory (the host is not sandboxed, so
// NSHomeDirectory() is already correct; this mirrors the appex's helper for
// symmetry and safety).
func realHomeDirectory() -> URL {
  if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
    return URL(fileURLWithPath: String(cString: dir))
  }
  return URL(fileURLWithPath: NSHomeDirectory())
}

let configuration = ChromeHostConfiguration(
  homeDirectory: realHomeDirectory())

guard ChromeHostPeerValidator.validate(
  arguments: ProcessInfo.processInfo.arguments,
  extensionPath: configuration.extensionPath)
else {
  ChromeNativeMessaging.writeReply(Data(#"{"status":"unauthorized"}"#.utf8))
  exit(1)
}

guard let messageData = ChromeNativeMessaging.readMessage() else {
  ChromeNativeMessaging.writeReply(Data(#"{"status":"malformed"}"#.utf8))
  exit(1)
}

// The host is a short-lived process per message; run the async handler to
// completion synchronously. `Task.detached` (not `Task {}`) is required: the
// top-level code runs on the main thread, and a plain `Task {}` inherits the
// main actor — so the semaphore wait below would block the very thread the
// task needs, deadlocking the host. A detached task runs on the global
// concurrent executor, which is free to proceed while the main thread waits.
// `Mutex` (macOS 15+) gives the detached task a thread-safe slot to write the
// reply status into without main-actor isolation.
let replyStatus = Mutex("rejected")
let semaphore = DispatchSemaphore(value: 0)
Task.detached {
  do {
    try FileManager.default.createDirectory(
      at: configuration.sharedContainerURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: configuration.sharedContainerURL.deletingLastPathComponent().path)
    let writer = SafariBridgeEnvelopeWriter(
      extensionID: configuration.extensionID,
      profileID: configuration.profileID,
      sharedContainerURL: configuration.sharedContainerURL,
      secretStore: SafariBridgeSecretStore(
        secretStore: KeychainSecretStore(serviceName: configuration.secretServiceName),
        serviceName: configuration.secretServiceName))
    let handler = SafariBridgeNativeMessageHandler(
      expectedExtensionID: configuration.extensionID,
      expectedProfileID: configuration.profileID,
      writer: writer)
    _ = try await handler.handle(messageData: messageData)
    replyStatus.withLock { $0 = "accepted" }
  } catch {
    replyStatus.withLock { $0 = "rejected" }
  }
  semaphore.signal()
}
_ = semaphore.wait(timeout: .now() + 30)
ChromeNativeMessaging.writeReply(Data(#"{"status":"\#(replyStatus.withLock { $0 })"}"#.utf8))
