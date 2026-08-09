import CryptoKit
import Foundation

// MARK: - Shared helper IPC infrastructure

/// Protocol version shared by all AURA sandbox helpers. Bumped whenever a
/// breaking change is made to any helper request/response envelope.
public enum HelperIPCProtocol {
  public static let version = 2
}

/// Common header carried by every helper request envelope. Concrete request
/// types extend this via a nested `payload` field.
public struct HelperIPCRequestHeader: Codable, Sendable, Equatable {
  public let protocolVersion: Int
  public let requestID: UUID
  public let nonce: UUID
  public let helperKind: HelperKind
  public let capability: Capability
  public let actor: ActorID
  public let target: PolicyTarget
  public let planHash: String
  public let issuedAt: Date
  public let expiresAt: Date
  public let payloadSHA256Hex: String

  public init(
    protocolVersion: Int,
    requestID: UUID,
    nonce: UUID,
    helperKind: HelperKind,
    capability: Capability,
    actor: ActorID,
    target: PolicyTarget,
    planHash: String,
    issuedAt: Date,
    expiresAt: Date,
    payloadSHA256Hex: String
  ) {
    self.protocolVersion = protocolVersion
    self.requestID = requestID
    self.nonce = nonce
    self.helperKind = helperKind
    self.capability = capability
    self.actor = actor
    self.target = target
    self.planHash = planHash
    self.issuedAt = issuedAt
    self.expiresAt = expiresAt
    self.payloadSHA256Hex = payloadSHA256Hex
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
  public let requestID: UUID
  public let nonce: UUID
  public let sandboxAttested: Bool
  public let payloadSHA256Hex: String

  public init(
    protocolVersion: Int,
    requestID: UUID,
    nonce: UUID,
    sandboxAttested: Bool,
    payloadSHA256Hex: String
  ) {
    self.protocolVersion = protocolVersion
    self.requestID = requestID
    self.nonce = nonce
    self.sandboxAttested = sandboxAttested
    self.payloadSHA256Hex = payloadSHA256Hex
  }
}

/// Typed request envelope shared by the AURA process and sandbox helpers.
/// The process-launch pipe is the current transport boundary; this envelope
/// adds the application-level bindings that the pipe alone does not provide:
/// capability, actor, target, immutable plan hash, payload hash, freshness,
/// and a one-time nonce.
public struct HelperIPCRequestEnvelope: Codable, Sendable, Equatable {
  public let header: HelperIPCRequestHeader
  public let payload: Data

  public init(header: HelperIPCRequestHeader, payload: Data) {
    self.header = header
    self.payload = payload
  }

  public init(
    helperKind: HelperKind,
    capability: Capability,
    actor: ActorID,
    target: PolicyTarget,
    payload: Data,
    requestID: UUID = UUID(),
    nonce: UUID = UUID(),
    issuedAt: Date = Date(),
    expiresAt: Date? = nil
  ) {
    let expiry = expiresAt ?? issuedAt.addingTimeInterval(30)
    self.payload = payload
    self.header = HelperIPCRequestHeader(
      protocolVersion: HelperIPCProtocol.version,
      requestID: requestID,
      nonce: nonce,
      helperKind: helperKind,
      capability: capability,
      actor: actor,
      target: target,
      planHash: PolicyPlanHasher.hash(capability: capability, actor: actor, target: target),
      issuedAt: issuedAt,
      expiresAt: expiry,
      payloadSHA256Hex: sha256Hex(payload))
  }
}

/// Typed response envelope. A response is accepted only when it binds back to
/// the exact request ID and nonce and its payload digest matches its bytes.
public struct HelperIPCResponseEnvelope: Codable, Sendable, Equatable {
  public let header: HelperIPCResponseHeader
  public let payload: Data

  public init(request: HelperIPCRequestEnvelope, sandboxAttested: Bool, payload: Data) {
    self.payload = payload
    self.header = HelperIPCResponseHeader(
      protocolVersion: HelperIPCProtocol.version,
      requestID: request.header.requestID,
      nonce: request.header.nonce,
      sandboxAttested: sandboxAttested,
      payloadSHA256Hex: sha256Hex(payload))
  }
}

/// Closed capability map for the two currently planned helper boundaries.
/// A helper never receives network, secret, plugin, OAuth, or privilege-change
/// authority merely because a caller supplied that capability in JSON.
public enum HelperIPCAuthorization {
  public static func allows(_ capability: Capability, for helper: HelperKind) -> Bool {
    switch helper {
    case .automation:
      return capability.domain == "app"
        || capability.domain == "screen"
        || capability.domain == "computerUse"
    case .shell:
      return capability.domain == "shell"
        || (capability.domain == "agent" && capability.action != "ollamaCloudInference")
    }
  }
}

public enum HelperIPCValidator {
  public static func validate(
    _ request: HelperIPCRequestEnvelope,
    expectedHelper: HelperKind,
    now: Date = Date(),
    maximumLifetimeSeconds: TimeInterval = 30,
    maximumFutureSkewSeconds: TimeInterval = 5
  ) throws(AuraError) {
    let header = request.header
    guard header.protocolVersion == HelperIPCProtocol.version,
      header.helperKind == expectedHelper
    else {
      throw .securityError("helper IPC protocol or helper-kind mismatch")
    }
    guard HelperIPCAuthorization.allows(header.capability, for: expectedHelper) else {
      throw .securityError("helper IPC capability is outside the helper allowlist")
    }
    guard header.expiresAt > header.issuedAt,
      header.expiresAt.timeIntervalSince(header.issuedAt) <= maximumLifetimeSeconds,
      header.issuedAt <= now.addingTimeInterval(maximumFutureSkewSeconds),
      now < header.expiresAt
    else {
      throw .securityError("helper IPC request is expired or has an invalid freshness window")
    }
    guard header.payloadSHA256Hex == sha256Hex(request.payload) else {
      throw .securityError("helper IPC payload hash mismatch")
    }
    let expectedPlanHash = PolicyPlanHasher.hash(
      capability: header.capability, actor: header.actor, target: header.target)
    guard header.planHash == expectedPlanHash else {
      throw .securityError("helper IPC plan hash mismatch")
    }
  }

  public static func validate(
    _ response: HelperIPCResponseEnvelope,
    for request: HelperIPCRequestEnvelope,
    expectedHelper: HelperKind,
    now: Date = Date()
  ) throws(AuraError) {
    try validate(request, expectedHelper: expectedHelper, now: now)
    guard response.header.protocolVersion == HelperIPCProtocol.version,
      response.header.requestID == request.header.requestID,
      response.header.nonce == request.header.nonce,
      response.header.sandboxAttested,
      response.header.payloadSHA256Hex == sha256Hex(response.payload)
    else {
      throw .securityError("helper IPC response failed request binding or attestation")
    }
  }
}

/// Replay protection must live in the caller because helpers are intentionally
/// short-lived. Expired nonces are purged, while a consumed nonce remains
/// rejected for the lifetime of its freshness window.
public actor HelperIPCReplayGuard {
  private var consumed: [UUID: Date] = [:]

  public init() {}

  public func consume(
    _ request: HelperIPCRequestEnvelope,
    expectedHelper: HelperKind,
    now: Date = Date()
  ) throws(AuraError) {
    try HelperIPCValidator.validate(request, expectedHelper: expectedHelper, now: now)
    consumed = consumed.filter { $0.value > now }
    guard consumed[request.header.nonce] == nil else {
      throw .securityError("helper IPC nonce replay detected")
    }
    consumed[request.header.nonce] = request.header.expiresAt
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
