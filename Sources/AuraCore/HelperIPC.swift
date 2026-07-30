import CryptoKit
import Foundation

// MARK: - Shared helper IPC infrastructure

/// Protocol version shared by all AURA sandbox helpers. Bumped whenever a
/// breaking change is made to any helper request/response envelope.
public enum HelperIPCProtocol {
  public static let version = 1
}

/// Common header carried by every helper request envelope. Concrete request
/// types extend this via a nested `payload` field.
public struct HelperIPCRequestHeader: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let nonce: UUID
  public let helperKind: HelperKind

  public init(protocolVersion: Int, nonce: UUID, helperKind: HelperKind) {
    self.protocolVersion = protocolVersion
    self.nonce = nonce
    self.helperKind = helperKind
  }
}

/// Discriminator for helper executable selection and request routing.
public enum HelperKind: String, Codable, Sendable, Equatable, CaseIterable {
  case automation
  case shell
}

/// Common attestation carried by every helper response envelope.
public struct HelperIPCResponseHeader: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let nonce: UUID
  public let sandboxAttested: Bool

  public init(protocolVersion: Int, nonce: UUID, sandboxAttested: Bool) {
    self.protocolVersion = protocolVersion
    self.nonce = nonce
    self.sandboxAttested = sandboxAttested
  }
}

/// Failure modes helpers can report. Kept intentionally coarse to avoid leaking
/// internal state across the process boundary.
public enum HelperIPCError: String, Codable, Sendable, Equatable {
  case invalidRequest
  case sandboxNotEnabled
  case launchFailed
  case executionTimeout
  case outputLimitExceeded
  case internalFailure
}

// MARK: - Sandbox attestation

/// Returns `true` iff the current process has the App Sandbox entitlement.
/// Used by helper executables to fail closed when sandboxing is missing.
public func sandboxIsEnabled() -> Bool {
  guard let task = SecTaskCreateFromSelf(nil) else { return false }
  let value = SecTaskCopyValueForEntitlement(
    task, "com.apple.security.app-sandbox" as CFString, nil)
  return (value as? Bool) == true
}

// MARK: - SHA-256 convenience

public func sha256Hex(_ data: Data) -> String {
  SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Process launch verification

/// Verifies that a helper executable exists, is readable, and matches the
/// expected SHA-256 digest. Throws `AuraError.invalidConfiguration` on failure.
public func verifyHelperIntegrity(
  url: URL,
  expectedSHA256Hex: String
) throws(AuraError) {
  guard expectedSHA256Hex.count == 64,
    expectedSHA256Hex == expectedSHA256Hex.lowercased(),
    expectedSHA256Hex.allSatisfy(\.isHexDigit)
  else {
    throw AuraError.invalidConfiguration("invalid helper SHA-256 digest")
  }
  guard let data = try? Data(contentsOf: url) else {
    throw AuraError.invalidConfiguration("helper executable is unreadable: \(url.path)")
  }
  guard sha256Hex(data) == expectedSHA256Hex else {
    throw AuraError.invalidConfiguration("helper executable failed SHA-256 verification")
  }
}

// MARK: - Bounded output collector

/// Thread-safe output collector with a byte limit. Used by both helpers and
/// the main app when reading helper stdout.
public final class HelperOutputCollector: @unchecked Sendable {
  private let lock = NSLock()
  private let limit: Int
  private var data = Data()
  private var exceeded = false

  public init(limit: Int = 1_048_576) {
    self.limit = limit
  }

  public func append(_ chunk: Data) {
    guard !chunk.isEmpty else { return }
    lock.lock()
    if data.count + chunk.count > limit {
      exceeded = true
    } else if !exceeded {
      data.append(chunk)
    }
    lock.unlock()
  }

  public func result() -> (data: Data, exceeded: Bool) {
    lock.lock()
    let result = (data, exceeded)
    lock.unlock()
    return result
  }
}

// MARK: - Configuration helpers

/// Configuration for one sandbox helper executable.
public struct HelperExecutableConfiguration: Codable, Sendable, Equatable {
  public let helperExecutablePath: String
  public let helperSHA256Hex: String

  public init(helperExecutablePath: String = "", helperSHA256Hex: String = "") {
    self.helperExecutablePath = helperExecutablePath
    self.helperSHA256Hex = helperSHA256Hex
  }

  public var isConfigured: Bool {
    !helperExecutablePath.isEmpty && !helperSHA256Hex.isEmpty
  }

  public func validate() throws(AuraError) {
    guard isConfigured else {
      throw AuraError.invalidConfiguration("helper executable is not configured")
    }
    guard helperSHA256Hex.count == 64,
      helperSHA256Hex == helperSHA256Hex.lowercased(),
      helperSHA256Hex.allSatisfy(\.isHexDigit)
    else {
      throw AuraError.invalidConfiguration("helper SHA-256 must be 64 lowercase hex digits")
    }
  }
}
