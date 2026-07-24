import Foundation

// MARK: - Risk tiers

/// Risk classification for a capability or action request.
///
/// Tiers are ordered from least to most sensitive and are used by the policy
/// engine to apply default confirmation and deny rules.
public enum PermissionRiskTier: Int, Codable, Sendable, Equatable, CaseIterable {
  /// Observation of non-sensitive metadata.
  case observation = 0
  /// Reversible local action.
  case reversible = 1
  /// File or environment mutation.
  case mutation = 2
  /// External communication, push, deployment, purchase, deletion,
  /// privilege change, or sensitive-data access.
  case destructive = 3
}

// MARK: - Capabilities

/// A namespaced, typed action descriptor used across tool boundaries.
///
/// Tool adapters translate model intents into concrete `Capability` requests;
/// raw model output must never be executed directly.
public struct Capability: Codable, Sendable, Equatable, Hashable {
  public let domain: String
  public let action: String
  public let riskTier: PermissionRiskTier

  public init(domain: String, action: String, riskTier: PermissionRiskTier) {
    self.domain = domain
    self.action = action
    self.riskTier = riskTier
  }
}

extension Capability {
  public static let fileRead = Capability(domain: "file", action: "read", riskTier: .observation)
  public static let fileWrite = Capability(domain: "file", action: "write", riskTier: .mutation)
  public static let fileDelete = Capability(
    domain: "file", action: "delete", riskTier: .destructive)
  public static let shellExec = Capability(domain: "shell", action: "exec", riskTier: .mutation)
  public static let appActivate = Capability(
    domain: "app", action: "activate", riskTier: .reversible)
  public static let appTerminate = Capability(
    domain: "app", action: "terminate", riskTier: .mutation)
  public static let screenCapture = Capability(
    domain: "screen", action: "capture", riskTier: .observation)
  public static let screenReadText = Capability(
    domain: "screen", action: "readText", riskTier: .observation)
  public static let agentRun = Capability(domain: "agent", action: "run", riskTier: .destructive)
  public static let networkRequest = Capability(
    domain: "network", action: "request", riskTier: .destructive)
  public static let systemChangePrivilege = Capability(
    domain: "system", action: "changePrivilege", riskTier: .destructive)

  public static let vscodeOpen = Capability(domain: "vscode", action: "open", riskTier: .reversible)
  public static let vscodeInjectTerminal = Capability(
    domain: "vscode", action: "injectTerminal", riskTier: .mutation)
  public static let vscodeManageExtension = Capability(
    domain: "vscode", action: "manageExtension", riskTier: .mutation)
  public static let vscodeObserveState = Capability(
    domain: "vscode", action: "observeState", riskTier: .observation)

  /// Convenience identifier used for pattern matching and event logging.
  public var identifier: String { "\(domain).\(action)" }
}

// MARK: - Resource patterns

/// Scope primitive for grants and deny rules.
///
/// Patterns are evaluated in order; a request matches a grant if at least one
/// pattern matches every constrained dimension of the request.
public enum ResourcePattern: Codable, Sendable, Equatable, Hashable {
  /// Matches any target. Use sparingly and only for low-risk capabilities.
  case any

  /// Matches a specific application bundle identifier.
  case appID(String)

  /// Matches a file path using a shell-style glob.
  case filePath(glob: String)

  /// Matches files under a directory path.
  case directory(String, recursive: Bool)

  /// Matches a shell command by regular expression.
  case command(regex: String)

  /// Requires the command arguments to be a subset of the allowed list.
  case argument(allowed: [String])

  /// Requires environment keys to be a subset of the allowed list.
  case environment(keys: [String])

  /// Matches a network host and optional port range.
  case network(host: String, port: ClosedRange<Int>)
}

// MARK: - Confirmation requirement

/// Describes when and how a grant requires explicit user confirmation.
public enum ConfirmationRequirement: Codable, Sendable, Equatable {
  /// No confirmation required.
  case none

  /// Confirm once per session, then allow for the remainder of the session.
  case oncePerSession

  /// Confirm every request.
  case always

  /// Confirm when the capability risk tier is at least the given tier.
  case forRiskTier(PermissionRiskTier)

  /// Confirm when the target matches the given pattern (e.g. outside home).
  case when(pattern: ResourcePattern)
}

// MARK: - Grants and deny rules

/// A user-authorized permission rule with scoped, time-bounded applicability.
public struct Grant: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capability: Capability
  public let patterns: [ResourcePattern]
  public let confirmationRequirement: ConfirmationRequirement
  public let createdAt: Date
  public let expiresAt: Date?
  public let issuer: ActorID
  public let purpose: String

  public init(
    id: UUID = UUID(),
    capability: Capability,
    patterns: [ResourcePattern] = [.any],
    confirmationRequirement: ConfirmationRequirement = .forRiskTier(.mutation),
    createdAt: Date = Date(),
    expiresAt: Date? = nil,
    issuer: ActorID = .user,
    purpose: String = ""
  ) {
    self.id = id
    self.capability = capability
    self.patterns = patterns
    self.confirmationRequirement = confirmationRequirement
    self.createdAt = createdAt
    self.expiresAt = expiresAt
    self.issuer = issuer
    self.purpose = purpose
  }
}

/// Authoritative deny rule evaluated before grants.
public struct DenyRule: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capability: Capability?
  public let patterns: [ResourcePattern]
  public let actor: ActorID?
  public let reason: String

  public init(
    id: UUID = UUID(),
    capability: Capability? = nil,
    patterns: [ResourcePattern] = [.any],
    actor: ActorID? = nil,
    reason: String
  ) {
    self.id = id
    self.capability = capability
    self.patterns = patterns
    self.actor = actor
    self.reason = reason
  }
}

// MARK: - Evaluation request and target

/// The target of a policy evaluation request.
public struct PolicyTarget: Codable, Sendable, Equatable {
  public let appID: String?
  public let filePath: String?
  public let directoryPath: String?
  public let command: String?
  public let arguments: [String]
  public let environmentKeys: [String]
  public let networkHost: String?
  public let networkPort: Int?

  public init(
    appID: String? = nil,
    filePath: String? = nil,
    directoryPath: String? = nil,
    command: String? = nil,
    arguments: [String] = [],
    environmentKeys: [String] = [],
    networkHost: String? = nil,
    networkPort: Int? = nil
  ) {
    self.appID = appID
    self.filePath = filePath
    self.directoryPath = directoryPath
    self.command = command
    self.arguments = arguments
    self.environmentKeys = environmentKeys
    self.networkHost = networkHost
    self.networkPort = networkPort
  }

  /// Empty target used for capability-wide grants.
  public static let empty = PolicyTarget()
}

/// Request sent into the policy engine for authorization.
public struct PolicyEvaluationRequest: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capability: Capability
  public let actor: ActorID
  public let target: PolicyTarget
  public let arguments: [String]
  public let environment: [String: String]
  public let sessionID: UUID
  public let correlationID: UUID
  public let causationID: UUID

  public init(
    id: UUID = UUID(),
    capability: Capability,
    actor: ActorID,
    target: PolicyTarget = .empty,
    arguments: [String] = [],
    environment: [String: String] = [:],
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) {
    self.id = id
    self.capability = capability
    self.actor = actor
    self.target = target
    self.arguments = arguments
    self.environment = environment
    self.sessionID = sessionID
    self.correlationID = correlationID
    self.causationID = causationID
  }
}

// MARK: - Decision and confirmation types

/// Result of a policy evaluation.
public enum PolicyDecision: Codable, Sendable, Equatable {
  case allow(auditID: UUID, grantID: UUID?)
  case deny(reason: String, auditID: UUID)
  case confirm(challenge: PolicyConfirmationChallenge, auditID: UUID)
}

/// Tamper-evident challenge issued when a request requires confirmation.
public struct PolicyConfirmationChallenge: Codable, Sendable, Equatable {
  /// ID of the originating `PolicyEvaluationRequest`.
  public let requestID: UUID
  /// Session-scoped identifier for per-session confirmation tracking.
  public let sessionID: UUID
  public let nonce: String
  public let issuedAt: Date
  public let requestedAction: Capability
  public let targetSummary: String
  public let riskTier: PermissionRiskTier
  public let expiresAt: Date
  public let expectedHash: String

  public init(
    requestID: UUID,
    sessionID: UUID,
    nonce: String,
    issuedAt: Date,
    requestedAction: Capability,
    targetSummary: String,
    riskTier: PermissionRiskTier,
    expiresAt: Date,
    expectedHash: String
  ) {
    self.requestID = requestID
    self.sessionID = sessionID
    self.nonce = nonce
    self.issuedAt = issuedAt
    self.requestedAction = requestedAction
    self.targetSummary = targetSummary
    self.riskTier = riskTier
    self.expiresAt = expiresAt
    self.expectedHash = expectedHash
  }
}

/// Response to a confirmation challenge returned by the UI or caller.
public struct PolicyConfirmationResponse: Codable, Sendable, Equatable {
  public let requestID: UUID
  public let nonce: String
  public let responseHash: String
  public let accepted: Bool

  public init(
    requestID: UUID,
    nonce: String,
    responseHash: String,
    accepted: Bool
  ) {
    self.requestID = requestID
    self.nonce = nonce
    self.responseHash = responseHash
    self.accepted = accepted
  }
}

// MARK: - Configuration

/// Policy-specific configuration embedded in `AuraConfiguration`.
public struct PolicyConfiguration: Codable, Sendable, Equatable {
  /// Capabilities at or above this tier require explicit confirmation by default
  /// when no matching grant says otherwise.
  public var defaultConfirmationTier: PermissionRiskTier

  /// Number of seconds a confirmation challenge remains valid.
  public var confirmationExpirySeconds: Double

  /// Risk tiers that are allowed when no grant exists (dangerous; default empty).
  public var allowByDefaultTiers: Set<PermissionRiskTier>

  /// Risk tiers that are denied when no grant exists (default all except observation).
  public var denyByDefaultTiers: Set<PermissionRiskTier>

  /// Store key under which grants are persisted.
  public var grantStoreKey: String

  /// Store key under which deny rules are persisted.
  public var denyRuleStoreKey: String

  public init(
    defaultConfirmationTier: PermissionRiskTier = .mutation,
    confirmationExpirySeconds: Double = 60.0,
    allowByDefaultTiers: Set<PermissionRiskTier> = [],
    denyByDefaultTiers: Set<PermissionRiskTier> = [.reversible, .mutation, .destructive],
    grantStoreKey: String = "aura.policy.grants",
    denyRuleStoreKey: String = "aura.policy.denyRules"
  ) {
    self.defaultConfirmationTier = defaultConfirmationTier
    self.confirmationExpirySeconds = confirmationExpirySeconds
    self.allowByDefaultTiers = allowByDefaultTiers
    self.denyByDefaultTiers = denyByDefaultTiers
    self.grantStoreKey = grantStoreKey
    self.denyRuleStoreKey = denyRuleStoreKey
  }

  public func validate() throws(AuraError) {
    guard confirmationExpirySeconds > 0 else {
      throw AuraError.invalidConfiguration("policy confirmationExpirySeconds must be positive")
    }
    guard !grantStoreKey.isEmpty else {
      throw AuraError.invalidConfiguration("policy grantStoreKey must not be empty")
    }
    guard !denyRuleStoreKey.isEmpty else {
      throw AuraError.invalidConfiguration("policy denyRuleStoreKey must not be empty")
    }
    let overlap = allowByDefaultTiers.intersection(denyByDefaultTiers)
    guard overlap.isEmpty else {
      throw AuraError.invalidConfiguration(
        "policy allowByDefaultTiers and denyByDefaultTiers overlap: \(overlap.map { String($0.rawValue) }.joined(separator: ", "))"
      )
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultConfirmationTier =
      try container.decodeIfPresent(PermissionRiskTier.self, forKey: .defaultConfirmationTier)
      ?? .mutation
    confirmationExpirySeconds =
      try container.decodeIfPresent(Double.self, forKey: .confirmationExpirySeconds) ?? 60.0
    allowByDefaultTiers =
      try container.decodeIfPresent(Set<PermissionRiskTier>.self, forKey: .allowByDefaultTiers)
      ?? []
    denyByDefaultTiers =
      try container.decodeIfPresent(Set<PermissionRiskTier>.self, forKey: .denyByDefaultTiers) ?? [
        .reversible, .mutation, .destructive,
      ]
    grantStoreKey =
      try container.decodeIfPresent(String.self, forKey: .grantStoreKey) ?? "aura.policy.grants"
    denyRuleStoreKey =
      try container.decodeIfPresent(String.self, forKey: .denyRuleStoreKey)
      ?? "aura.policy.denyRules"
  }

  /// Merge a partial policy configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> PolicyConfiguration {
    PolicyConfiguration(
      defaultConfirmationTier: self.defaultConfirmationTier,
      confirmationExpirySeconds: self.confirmationExpirySeconds <= 0
        ? PolicyConfiguration().confirmationExpirySeconds
        : self.confirmationExpirySeconds,
      allowByDefaultTiers: self.allowByDefaultTiers.isEmpty
        ? PolicyConfiguration().allowByDefaultTiers
        : self.allowByDefaultTiers,
      denyByDefaultTiers: self.denyByDefaultTiers.isEmpty
        ? PolicyConfiguration().denyByDefaultTiers
        : self.denyByDefaultTiers,
      grantStoreKey: self.grantStoreKey.isEmpty
        ? PolicyConfiguration().grantStoreKey
        : self.grantStoreKey,
      denyRuleStoreKey: self.denyRuleStoreKey.isEmpty
        ? PolicyConfiguration().denyRuleStoreKey
        : self.denyRuleStoreKey
    )
  }
}
