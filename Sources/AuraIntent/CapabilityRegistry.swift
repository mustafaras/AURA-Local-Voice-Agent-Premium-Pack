import AuraCore
import Foundation

/// The minimum evidence class a capability must have before it is exposed
/// to users in a given deployment stage, mirroring `EVIDENCE_INDEX.md`'s
/// evidence quality classes (unit/static, contract, integration simulated,
/// system, live hardware, release).
public enum CapabilityEvidenceClass: String, Codable, Sendable, Equatable, Comparable {
  case unitStatic
  case contract
  case integrationSimulated
  case system
  case liveHardware
  case release

  private var ordinal: Int {
    switch self {
    case .unitStatic: return 0
    case .contract: return 1
    case .integrationSimulated: return 2
    case .system: return 3
    case .liveHardware: return 4
    case .release: return 5
    }
  }

  public static func < (lhs: CapabilityEvidenceClass, rhs: CapabilityEvidenceClass) -> Bool {
    lhs.ordinal < rhs.ordinal
  }
}

/// Whether a capability's execution stays entirely on-device or may leave it.
public enum CapabilityLocality: String, Codable, Sendable, Equatable {
  case local
  case cloud
}

/// A capability's current reachability. Unlike `RuntimeHealth` (a live
/// runtime signal for an already-registered, wired backend), this also
/// covers capabilities that are registered but deliberately not yet
/// connected to a real adapter — `04_R3_CAPABILITY_REGISTRY_AND_PLANNER
/// .prompt.md`'s "disconnected future capabilities are visibly disabled
/// rather than falsely ready."
public enum CapabilityAvailability: Sendable, Equatable {
  case ready
  case degraded(reason: String)
  /// Registered (schema, risk, permissions are real and reviewed) but no
  /// production adapter is wired yet. `reason` must be truthful and
  /// user-presentable, never a placeholder string.
  case disabled(reason: String)
}

/// A capability's declared retry/cancellation/resource contract.
public struct CapabilityExecutionBudget: Sendable, Equatable {
  public let timeoutSeconds: Double
  public let supportsCancellation: Bool
  public let isRetryable: Bool
  public let maxConcurrentInvocations: Int

  public init(
    timeoutSeconds: Double,
    supportsCancellation: Bool,
    isRetryable: Bool,
    maxConcurrentInvocations: Int = 1
  ) {
    self.timeoutSeconds = timeoutSeconds
    self.supportsCancellation = supportsCancellation
    self.isRetryable = isRetryable
    self.maxConcurrentInvocations = maxConcurrentInvocations
  }
}

/// Localized, user-presentable identity for a capability — never internal
/// implementation naming leaked to the user (per `ADR-036`'s addendum on
/// prompt/response terminology leakage).
public struct CapabilityPresentation: Sendable, Equatable {
  public let titleByLocale: [DialogueLanguage: String]
  public let descriptionByLocale: [DialogueLanguage: String]
  public let examplesByLocale: [DialogueLanguage: [String]]

  public init(
    titleByLocale: [DialogueLanguage: String],
    descriptionByLocale: [DialogueLanguage: String],
    examplesByLocale: [DialogueLanguage: [String]] = [:]
  ) {
    self.titleByLocale = titleByLocale
    self.descriptionByLocale = descriptionByLocale
    self.examplesByLocale = examplesByLocale
  }

  public func title(for language: DialogueLanguage) -> String {
    titleByLocale[language] ?? titleByLocale[.english] ?? titleByLocale.values.first ?? ""
  }
}

/// A single registered capability's full contract —
/// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s "Capability
/// manifest" section, field for field. Superset of the prior phase's
/// `ToolContract`; unlike `ToolContract`, a manifest is looked up by a
/// stable, versioned, namespaced ID rather than a closed `IntentKind`, so
/// new capabilities can be registered without widening a switch statement.
public struct CapabilityManifest: Sendable, Equatable {
  public let id: String
  public let version: String
  public let presentation: CapabilityPresentation
  public let inputSchemaDescription: String
  public let outputSchemaDescription: String
  public let owningAdapter: String
  public let requiredCapability: Capability
  public let sideEffects: [String]
  public let requiredGrantCapabilities: [Capability]
  public let requiredNetworkDomains: [String]
  public let requiredExternalDependencies: [String]
  public let locality: CapabilityLocality
  public let isIdempotent: Bool
  public let executionBudget: CapabilityExecutionBudget
  public let confirmationRule: String
  public let verificationMethod: String
  public let rollbackStrategy: String
  public let sensitivity: SensitivityLevel
  public let retentionBehavior: String
  public let minimumEvidenceClass: [String: CapabilityEvidenceClass]
  /// `true` when the owning adapter evaluates policy itself before running
  /// (e.g. the coding-agent CLI adapters, which call `PolicyEngine.evaluate`
  /// internally) — mirrors `ToolContract.enforcesPolicyInternally` exactly;
  /// the router must not double-evaluate in that case.
  public let enforcesPolicyInternally: Bool

  public init(
    id: String,
    version: String,
    presentation: CapabilityPresentation,
    inputSchemaDescription: String,
    outputSchemaDescription: String,
    owningAdapter: String,
    requiredCapability: Capability,
    sideEffects: [String] = [],
    requiredGrantCapabilities: [Capability] = [],
    requiredNetworkDomains: [String] = [],
    requiredExternalDependencies: [String] = [],
    locality: CapabilityLocality = .local,
    isIdempotent: Bool,
    executionBudget: CapabilityExecutionBudget,
    confirmationRule: String,
    verificationMethod: String,
    rollbackStrategy: String,
    sensitivity: SensitivityLevel = .internalLevel,
    retentionBehavior: String = "not persisted beyond the invoking turn's audit event",
    minimumEvidenceClass: [String: CapabilityEvidenceClass] = [
      "development": .contract, "beta": .system, "release": .liveHardware,
    ],
    enforcesPolicyInternally: Bool = false
  ) {
    self.id = id
    self.version = version
    self.presentation = presentation
    self.inputSchemaDescription = inputSchemaDescription
    self.outputSchemaDescription = outputSchemaDescription
    self.owningAdapter = owningAdapter
    self.requiredCapability = requiredCapability
    self.sideEffects = sideEffects
    self.requiredGrantCapabilities = requiredGrantCapabilities
    self.requiredNetworkDomains = requiredNetworkDomains
    self.requiredExternalDependencies = requiredExternalDependencies
    self.locality = locality
    self.isIdempotent = isIdempotent
    self.executionBudget = executionBudget
    self.confirmationRule = confirmationRule
    self.verificationMethod = verificationMethod
    self.rollbackStrategy = rollbackStrategy
    self.sensitivity = sensitivity
    self.retentionBehavior = retentionBehavior
    self.minimumEvidenceClass = minimumEvidenceClass
    self.enforcesPolicyInternally = enforcesPolicyInternally
  }

  /// A stable `id@version` key, used by the registry and by `PlanStep` to
  /// pin a plan to the exact manifest revision it was validated against.
  public var qualifiedID: String { "\(id)@\(version)" }
}

/// The sole production source for user-reachable capabilities —
/// `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`'s completion gate.
/// Unknown IDs or schema versions fail closed: every lookup method returns
/// `nil` rather than guessing or falling back to a default.
public actor CapabilityRegistry {
  private var manifestsByQualifiedID: [String: CapabilityManifest] = [:]
  private var latestVersionByID: [String: String] = [:]
  private var availabilityByQualifiedID: [String: CapabilityAvailability] = [:]

  public init() {}

  /// Register a manifest. Re-registering the same `qualifiedID` replaces it
  /// (used by tests and by future health/version updates); registering a
  /// higher semantic version under the same `id` updates the "latest"
  /// pointer `resolve(id:)` uses.
  public func register(_ manifest: CapabilityManifest, availability: CapabilityAvailability) {
    manifestsByQualifiedID[manifest.qualifiedID] = manifest
    availabilityByQualifiedID[manifest.qualifiedID] = availability
    if let existingLatest = latestVersionByID[manifest.id] {
      if isVersion(manifest.version, newerThan: existingLatest) {
        latestVersionByID[manifest.id] = manifest.version
      }
    } else {
      latestVersionByID[manifest.id] = manifest.version
    }
  }

  public func setAvailability(_ availability: CapabilityAvailability, for qualifiedID: String) {
    guard manifestsByQualifiedID[qualifiedID] != nil else { return }
    availabilityByQualifiedID[qualifiedID] = availability
  }

  /// Look up an exact `id`/`version` pair. `nil` for anything unregistered
  /// — callers must fail closed, never assume a default version.
  public func manifest(id: String, version: String) -> CapabilityManifest? {
    manifestsByQualifiedID["\(id)@\(version)"]
  }

  /// Resolve the latest registered version of `id`. Still `nil`, not a
  /// guess, when `id` was never registered.
  public func resolveLatest(id: String) -> CapabilityManifest? {
    guard let version = latestVersionByID[id] else { return nil }
    return manifest(id: id, version: version)
  }

  public func availability(qualifiedID: String) -> CapabilityAvailability? {
    availabilityByQualifiedID[qualifiedID]
  }

  public func availability(id: String, version: String) -> CapabilityAvailability? {
    availability(qualifiedID: "\(id)@\(version)")
  }

  /// All registered manifests, for health/capability-inspection UI and
  /// tests. Order is not significant.
  public func allManifests() -> [CapabilityManifest] {
    Array(manifestsByQualifiedID.values)
  }

  public func reachableManifests() -> [CapabilityManifest] {
    manifestsByQualifiedID.values.filter {
      if case .ready = availabilityByQualifiedID[$0.qualifiedID] { return true }
      return false
    }
  }

  /// Minimal `major.minor.patch` comparison — manifests only ever use this
  /// shape (mirrors `ToolContract.version`'s existing convention of plain
  /// `"1.0.0"` strings); anything else compares lexicographically as a
  /// safe, deterministic fallback rather than crashing.
  private func isVersion(_ candidate: String, newerThan existing: String) -> Bool {
    let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
    let existingParts = existing.split(separator: ".").compactMap { Int($0) }
    guard candidateParts.count == 3, existingParts.count == 3 else {
      return candidate > existing
    }
    return candidateParts.lexicographicallyPrecedes(existingParts) == false
      && candidateParts != existingParts
  }
}
