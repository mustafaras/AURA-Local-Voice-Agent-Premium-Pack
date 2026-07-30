import Foundation

// MARK: - Residual risk registry

/// Domain of adversarial residual risks tracked by AURA. Each case names an
/// attacker goal or failure mode documented in `docs/security/30_THREAT_MODEL.md`
/// and referenced by ADR-033; this type keeps the registry in code so that
/// red-team categories cannot silently disappear from the operational documents.
public enum ResidualRiskCategory: String, Codable, Sendable, Equatable, CaseIterable {
  case promptInjection
  case toolSpoofing
  case policyBypass
  case memoryPoisoning
  case pluginSupplyChain
  case configurationTampering
  case structuredOutputViolation
  case liveCallerManipulation
  case unknownFailureMode
}

/// Fail-closed default action recorded for a residual risk. This is documentation
/// only; real authority still flows through `PolicyEngine` and `ToolRouter`.
public enum ResidualRiskDefaultAction: String, Codable, Sendable, Equatable {
  case deny
  case confirm
  case escalate
}

/// One entry in the residual-risk registry: owner, mitigation, default action,
/// and a playbook reference for incident response.
public struct ResidualRiskEntry: Sendable, Equatable, Identifiable {
  public let id: UUID
  public let category: ResidualRiskCategory
  public let owner: String
  public let mitigation: String
  public let defaultAction: ResidualRiskDefaultAction
  public let requiresEscalation: Bool
  public let playbookID: String

  public init(
    category: ResidualRiskCategory,
    owner: String,
    mitigation: String,
    defaultAction: ResidualRiskDefaultAction,
    requiresEscalation: Bool,
    playbookID: String
  ) {
    self.id = UUID()
    self.category = category
    self.owner = owner
    self.mitigation = mitigation
    self.defaultAction = defaultAction
    self.requiresEscalation = requiresEscalation
    self.playbookID = playbookID
  }
}

/// Lightweight, deterministic registry of residual adversarial risks. This is
/// not a runtime authority; it documents the current threat-model categories,
/// owners, and playbook links so that tests can verify they remain present and
/// consistent with `docs/security/30_THREAT_MODEL.md`,
/// `docs/decisions/ADR-033-adversarial-safety-red-team-harness.md`,
/// `docs/operations/SECURITY_REVIEW_SCHEDULE.md`, and
/// `docs/operations/ADVERSARIAL_INCIDENT_RESPONSE.md`.
public struct ResidualRiskRegistry: Sendable, Equatable {
  private let entriesByCategory: [ResidualRiskCategory: ResidualRiskEntry]

  public init(entries: [ResidualRiskEntry]) {
    self.entriesByCategory = Dictionary(uniqueKeysWithValues: entries.map { ($0.category, $0) })
  }

  public subscript(category: ResidualRiskCategory) -> ResidualRiskEntry? {
    entriesByCategory[category]
  }

  public var allEntries: [ResidualRiskEntry] {
    Array(entriesByCategory.values)
  }

  /// The canonical Phase 25 residual-risk registry. Keep this in sync with
  /// `docs/security/30_THREAT_MODEL.md` and update the tests when the threat
  /// model changes.
  public static let current = ResidualRiskRegistry(entries: [
    ResidualRiskEntry(
      category: .promptInjection,
      owner: "Security + Intent",
      mitigation: "PromptInjectionClassifier on every untrusted text path; ContentProvenance carriesAuthority false for non-user/system sources.",
      defaultAction: .deny,
      requiresEscalation: false,
      playbookID: "ADVR-001"),
    ResidualRiskEntry(
      category: .toolSpoofing,
      owner: "Intent + ToolRouter",
      mitigation: "Closed IntentKind vocabulary, ToolRouter contract lookup, typed slots only.",
      defaultAction: .deny,
      requiresEscalation: false,
      playbookID: "ADVR-002"),
    ResidualRiskEntry(
      category: .policyBypass,
      owner: "PolicyEngine",
      mitigation: "Deny rules before grants, confirmation hash binding, mandatory-confirmation guard, no actor except user can confirm.",
      defaultAction: .deny,
      requiresEscalation: true,
      playbookID: "ADVR-002"),
    ResidualRiskEntry(
      category: .memoryPoisoning,
      owner: "Memory + Context",
      mitigation: "MemoryProvenance authority tiers, contradiction detection for userPreference, ReferenceResolver evidence thresholds.",
      defaultAction: .deny,
      requiresEscalation: false,
      playbookID: "ADVR-002"),
    ResidualRiskEntry(
      category: .pluginSupplyChain,
      owner: "Plugins + Marketplace",
      mitigation: "PluginVerifier with SHA-256 hash and Ed25519 vendor signature; manifest structural validation forbids wildcard permissions.",
      defaultAction: .deny,
      requiresEscalation: true,
      playbookID: "ADVR-003"),
    ResidualRiskEntry(
      category: .configurationTampering,
      owner: "Config + Security",
      mitigation: "ConfigurationEngine SecurityConstraints, project layer cannot weaken security-relevant keys, immutable privacy flags.",
      defaultAction: .deny,
      requiresEscalation: true,
      playbookID: "ADVR-002"),
    ResidualRiskEntry(
      category: .structuredOutputViolation,
      owner: "Intent + ToolRouter",
      mitigation: "TypedIntent semantic category pins risk tier; ToolRouter rejects unknown kinds and missing required slots.",
      defaultAction: .deny,
      requiresEscalation: false,
      playbookID: "ADVR-002"),
    ResidualRiskEntry(
      category: .liveCallerManipulation,
      owner: "Audio + Policy + Human loop",
      mitigation: "Speaker verification is identity hint only; destructive actions always require confirmation; real-time escalation path to human operator with human loop approval before any privileged action.",
      defaultAction: .escalate,
      requiresEscalation: true,
      playbookID: "ADVR-004"),
    ResidualRiskEntry(
      category: .unknownFailureMode,
      owner: "On-call + Security",
      mitigation: "Fail closed: any unrecognized adversarial condition defaults to deny and is logged without private content.",
      defaultAction: .deny,
      requiresEscalation: true,
      playbookID: "ADVR-005"),
  ])
}
