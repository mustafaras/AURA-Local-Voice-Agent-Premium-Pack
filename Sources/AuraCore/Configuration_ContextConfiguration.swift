import Foundation

/// Configuration for `ContextEngine` (Phase 16) — ranking weights, bundle
/// size budgets, semantic-match threshold, and reference-resolution
/// guardrails for the destructive-target-on-weak-evidence gate.
public struct ContextConfiguration: Codable, Sendable, Equatable {
  private enum CodingKeys: String, CodingKey {
    case rankingWeightScope, rankingWeightRecency, rankingWeightAuthority
    case rankingWeightConfidence, rankingWeightEvidence, recencyHalfLifeSeconds
    case maxLedgerEntries, maxDecisions, maxPreferences, maxSemanticMatches, maxBundleItems
    case semanticMatchMinimumOverlap, referenceSeparationMargin
    case referenceGuardedMinimumConfidence, referenceGuardedTierThreshold
    case referenceSalienceWeight, maxTokenBudget, maxGraphDepth, maxGraphItems
    case lookupLatencyBudgetSeconds
  }

  /// Ranking weight for scope match (project/task/session). All five
  /// `rankingWeight*` fields must be non-negative and sum to `1.0`.
  public var rankingWeightScope: Double
  /// Ranking weight for recency (exponential decay, see `recencyHalfLifeSeconds`).
  public var rankingWeightRecency: Double
  /// Ranking weight for provenance authority (`ContextAuthority`).
  public var rankingWeightAuthority: Double
  /// Ranking weight for the candidate's own confidence value.
  public var rankingWeightConfidence: Double
  /// Ranking weight for presence of direct evidence references.
  public var rankingWeightEvidence: Double

  /// Half-life, in seconds, of the recency score's exponential decay.
  public var recencyHalfLifeSeconds: Double

  /// Maximum number of project-ledger entries considered for a bundle.
  public var maxLedgerEntries: Int
  /// Maximum number of individual decisions (drawn from those ledger
  /// entries) considered for a bundle.
  public var maxDecisions: Int
  /// Maximum number of user-preference memory records considered.
  public var maxPreferences: Int
  /// Maximum number of semantic-retrieval matches considered.
  public var maxSemanticMatches: Int
  /// Maximum number of optional (non-mandatory) items kept in a bundle after
  /// ranking — the "minimal and sufficient" budget.
  public var maxBundleItems: Int

  /// Minimum keyword-containment score (see `ContextRanking.containmentScore`)
  /// for a memory record to count as a semantic-retrieval match.
  public var semanticMatchMinimumOverlap: Double

  /// Minimum score gap between the top two reference candidates required to
  /// treat resolution as unambiguous.
  public var referenceSeparationMargin: Double
  /// Minimum confidence a guarded-tier reference candidate must have before
  /// it can auto-resolve.
  public var referenceGuardedMinimumConfidence: Double
  /// The lowest `PermissionRiskTier` at which a reference candidate is
  /// "guarded" — auto-resolution requires an unambiguous top candidate,
  /// direct evidence, non-inferred authority, in-scope, and confidence at or
  /// above `referenceGuardedMinimumConfidence`. Below this tier, an
  /// unambiguous top candidate resolves without the extra evidence checks.
  public var referenceGuardedTierThreshold: PermissionRiskTier
  /// Additional Phase 22 reference-graph weight for turn-local
  /// conversational salience. It supplements (and never bypasses) the five
  /// evidence-ranking dimensions.
  public var referenceSalienceWeight: Double
  /// Hard estimated-token ceiling for a final deep-context bundle.
  public var maxTokenBudget: Int
  /// Maximum provenance hops followed from any included memory record.
  public var maxGraphDepth: Int
  /// Maximum graph-derived context nodes admitted across the whole bundle.
  public var maxGraphItems: Int
  /// Measured local lookup budget. Exceeding it is reported in the result
  /// and audit event; no claim of meeting the budget is made unless tested.
  public var lookupLatencyBudgetSeconds: Double

  public init(
    rankingWeightScope: Double = 0.30,
    rankingWeightRecency: Double = 0.25,
    rankingWeightAuthority: Double = 0.20,
    rankingWeightConfidence: Double = 0.15,
    rankingWeightEvidence: Double = 0.10,
    recencyHalfLifeSeconds: Double = 3600,
    maxLedgerEntries: Int = 5,
    maxDecisions: Int = 5,
    maxPreferences: Int = 5,
    maxSemanticMatches: Int = 3,
    maxBundleItems: Int = 12,
    semanticMatchMinimumOverlap: Double = 0.34,
    referenceSeparationMargin: Double = 0.12,
    referenceGuardedMinimumConfidence: Double = 0.85,
    referenceGuardedTierThreshold: PermissionRiskTier = .mutation,
    referenceSalienceWeight: Double = 0.15,
    maxTokenBudget: Int = 1_024,
    maxGraphDepth: Int = 4,
    maxGraphItems: Int = 12,
    lookupLatencyBudgetSeconds: Double = 0.25
  ) {
    self.rankingWeightScope = rankingWeightScope
    self.rankingWeightRecency = rankingWeightRecency
    self.rankingWeightAuthority = rankingWeightAuthority
    self.rankingWeightConfidence = rankingWeightConfidence
    self.rankingWeightEvidence = rankingWeightEvidence
    self.recencyHalfLifeSeconds = recencyHalfLifeSeconds
    self.maxLedgerEntries = maxLedgerEntries
    self.maxDecisions = maxDecisions
    self.maxPreferences = maxPreferences
    self.maxSemanticMatches = maxSemanticMatches
    self.maxBundleItems = maxBundleItems
    self.semanticMatchMinimumOverlap = semanticMatchMinimumOverlap
    self.referenceSeparationMargin = referenceSeparationMargin
    self.referenceGuardedMinimumConfidence = referenceGuardedMinimumConfidence
    self.referenceGuardedTierThreshold = referenceGuardedTierThreshold
    self.referenceSalienceWeight = referenceSalienceWeight
    self.maxTokenBudget = maxTokenBudget
    self.maxGraphDepth = maxGraphDepth
    self.maxGraphItems = maxGraphItems
    self.lookupLatencyBudgetSeconds = lookupLatencyBudgetSeconds
  }

  private var rankingWeights: [Double] {
    [
      rankingWeightScope, rankingWeightRecency, rankingWeightAuthority, rankingWeightConfidence,
      rankingWeightEvidence,
    ]
  }

  public func validate() throws(AuraError) {
    try validateRankingWeights()
    try validateCoreBounds()
    try validateReferenceBounds()
  }

  private func validateRankingWeights() throws(AuraError) {
    guard rankingWeights.allSatisfy({ $0 >= 0 }) else {
      throw AuraError.invalidConfiguration("context ranking weights must be non-negative")
    }
    let sum = rankingWeights.reduce(0, +)
    guard abs(sum - 1.0) < 0.0001 else {
      throw AuraError.invalidConfiguration("context ranking weights must sum to 1.0, got \(sum)")
    }
  }

  private func validateCoreBounds() throws(AuraError) {
    try validatePrimaryBounds()
    try validateGraphBounds()
  }

  private func validatePrimaryBounds() throws(AuraError) {
    guard recencyHalfLifeSeconds > 0 else {
      throw AuraError.invalidConfiguration("context recencyHalfLifeSeconds must be positive")
    }
    guard maxLedgerEntries > 0 else {
      throw AuraError.invalidConfiguration("context maxLedgerEntries must be positive")
    }
    guard maxDecisions > 0 else {
      throw AuraError.invalidConfiguration("context maxDecisions must be positive")
    }
    guard maxPreferences > 0 else {
      throw AuraError.invalidConfiguration("context maxPreferences must be positive")
    }
    guard maxSemanticMatches > 0 else {
      throw AuraError.invalidConfiguration("context maxSemanticMatches must be positive")
    }
    guard referenceSalienceWeight >= 0 else {
      throw AuraError.invalidConfiguration("context referenceSalienceWeight must be non-negative")
    }
    guard maxTokenBudget > 0 else {
      throw AuraError.invalidConfiguration("context maxTokenBudget must be positive")
    }
    guard maxBundleItems > 0 else {
      throw AuraError.invalidConfiguration("context maxBundleItems must be positive")
    }
  }

  private func validateGraphBounds() throws(AuraError) {
    guard maxGraphDepth >= 0 else {
      throw AuraError.invalidConfiguration("context maxGraphDepth must be non-negative")
    }
    guard maxGraphItems >= 0 else {
      throw AuraError.invalidConfiguration("context maxGraphItems must be non-negative")
    }
    guard lookupLatencyBudgetSeconds > 0 else {
      throw AuraError.invalidConfiguration(
        "context lookupLatencyBudgetSeconds must be positive")
    }
  }

  private func validateReferenceBounds() throws(AuraError) {
    guard semanticMatchMinimumOverlap > 0, semanticMatchMinimumOverlap <= 1 else {
      throw AuraError.invalidConfiguration(
        "context semanticMatchMinimumOverlap must be in (0, 1]")
    }
    guard referenceSeparationMargin >= 0 else {
      throw AuraError.invalidConfiguration("context referenceSeparationMargin must be non-negative")
    }
    guard referenceGuardedMinimumConfidence >= 0, referenceGuardedMinimumConfidence <= 1 else {
      throw AuraError.invalidConfiguration(
        "context referenceGuardedMinimumConfidence must be in [0, 1]")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults. The five
  /// ranking weights are merged as one group — a partially-overridden weight
  /// vector cannot preserve the "sums to 1.0" invariant, so any invalid
  /// (negative, or non-summing-to-1.0) group falls back to the full default
  /// set together rather than field by field.
  public func mergedWithDefaults() -> ContextConfiguration {
    let defaults = ContextConfiguration()
    let weightsValid =
      rankingWeights.allSatisfy { $0 >= 0 } && abs(rankingWeights.reduce(0, +) - 1.0) < 0.0001
    return ContextConfiguration(
      rankingWeightScope: weightsValid ? rankingWeightScope : defaults.rankingWeightScope,
      rankingWeightRecency: weightsValid ? rankingWeightRecency : defaults.rankingWeightRecency,
      rankingWeightAuthority: weightsValid
        ? rankingWeightAuthority : defaults.rankingWeightAuthority,
      rankingWeightConfidence: weightsValid
        ? rankingWeightConfidence : defaults.rankingWeightConfidence,
      rankingWeightEvidence: weightsValid ? rankingWeightEvidence : defaults.rankingWeightEvidence,
      recencyHalfLifeSeconds: recencyHalfLifeSeconds <= 0
        ? defaults.recencyHalfLifeSeconds : recencyHalfLifeSeconds,
      maxLedgerEntries: maxLedgerEntries <= 0 ? defaults.maxLedgerEntries : maxLedgerEntries,
      maxDecisions: maxDecisions <= 0 ? defaults.maxDecisions : maxDecisions,
      maxPreferences: maxPreferences <= 0 ? defaults.maxPreferences : maxPreferences,
      maxSemanticMatches: maxSemanticMatches <= 0
        ? defaults.maxSemanticMatches : maxSemanticMatches,
      maxBundleItems: maxBundleItems <= 0 ? defaults.maxBundleItems : maxBundleItems,
      semanticMatchMinimumOverlap: (semanticMatchMinimumOverlap <= 0
        || semanticMatchMinimumOverlap > 1)
        ? defaults.semanticMatchMinimumOverlap : semanticMatchMinimumOverlap,
      referenceSeparationMargin: referenceSeparationMargin < 0
        ? defaults.referenceSeparationMargin : referenceSeparationMargin,
      referenceGuardedMinimumConfidence: (referenceGuardedMinimumConfidence < 0
        || referenceGuardedMinimumConfidence > 1)
        ? defaults.referenceGuardedMinimumConfidence : referenceGuardedMinimumConfidence,
      referenceGuardedTierThreshold: referenceGuardedTierThreshold,
      referenceSalienceWeight: referenceSalienceWeight < 0
        ? defaults.referenceSalienceWeight : referenceSalienceWeight,
      maxTokenBudget: maxTokenBudget <= 0 ? defaults.maxTokenBudget : maxTokenBudget,
      maxGraphDepth: maxGraphDepth < 0 ? defaults.maxGraphDepth : maxGraphDepth,
      maxGraphItems: maxGraphItems < 0 ? defaults.maxGraphItems : maxGraphItems,
      lookupLatencyBudgetSeconds: lookupLatencyBudgetSeconds <= 0
        ? defaults.lookupLatencyBudgetSeconds : lookupLatencyBudgetSeconds
    )
  }

  private static func decoded<T: Decodable>(
    _ container: KeyedDecodingContainer<CodingKeys>,
    _ key: CodingKeys,
    _ fallback: T
  ) throws -> T {
    try container.decodeIfPresent(T.self, forKey: key) ?? fallback
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ContextConfiguration()
    self.init(
      rankingWeightScope: try Self.decoded(
        container, .rankingWeightScope, defaults.rankingWeightScope),
      rankingWeightRecency: try Self.decoded(
        container, .rankingWeightRecency, defaults.rankingWeightRecency),
      rankingWeightAuthority: try Self.decoded(
        container, .rankingWeightAuthority, defaults.rankingWeightAuthority),
      rankingWeightConfidence: try Self.decoded(
        container, .rankingWeightConfidence, defaults.rankingWeightConfidence),
      rankingWeightEvidence: try Self.decoded(
        container, .rankingWeightEvidence, defaults.rankingWeightEvidence),
      recencyHalfLifeSeconds: try Self.decoded(
        container, .recencyHalfLifeSeconds, defaults.recencyHalfLifeSeconds),
      maxLedgerEntries: try Self.decoded(
        container, .maxLedgerEntries, defaults.maxLedgerEntries),
      maxDecisions: try Self.decoded(container, .maxDecisions, defaults.maxDecisions),
      maxPreferences: try Self.decoded(container, .maxPreferences, defaults.maxPreferences),
      maxSemanticMatches: try Self.decoded(
        container, .maxSemanticMatches, defaults.maxSemanticMatches),
      maxBundleItems: try Self.decoded(container, .maxBundleItems, defaults.maxBundleItems),
      semanticMatchMinimumOverlap: try Self.decoded(
        container, .semanticMatchMinimumOverlap, defaults.semanticMatchMinimumOverlap),
      referenceSeparationMargin: try Self.decoded(
        container, .referenceSeparationMargin, defaults.referenceSeparationMargin),
      referenceGuardedMinimumConfidence: try Self.decoded(
        container, .referenceGuardedMinimumConfidence, defaults.referenceGuardedMinimumConfidence),
      referenceGuardedTierThreshold: try Self.decoded(
        container, .referenceGuardedTierThreshold, defaults.referenceGuardedTierThreshold),
      referenceSalienceWeight: try Self.decoded(
        container, .referenceSalienceWeight, defaults.referenceSalienceWeight),
      maxTokenBudget: try Self.decoded(container, .maxTokenBudget, defaults.maxTokenBudget),
      maxGraphDepth: try Self.decoded(container, .maxGraphDepth, defaults.maxGraphDepth),
      maxGraphItems: try Self.decoded(container, .maxGraphItems, defaults.maxGraphItems),
      lookupLatencyBudgetSeconds: try Self.decoded(
        container, .lookupLatencyBudgetSeconds, defaults.lookupLatencyBudgetSeconds))
  }
}
