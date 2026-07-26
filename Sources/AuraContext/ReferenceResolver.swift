import AuraCore
import Foundation

/// Resolves an implicit reference ("it", "that", "the file", "the last one")
/// against a set of candidate targets.
///
/// Pure and stateless — like `ReviewVerdictParser`, it takes plain data in
/// and returns a typed result, with no I/O or actor isolation of its own.
/// `ContextEngine.resolveReference` is the audited, event-emitting wrapper
/// around this type.
///
/// Two independent guardrails apply, in order:
/// 1. **Ambiguity**: if the top-ranked candidate is not clearly separated
///    from the runner-up (or there is more than one candidate and no clear
///    winner), resolution stops at `.ambiguous` regardless of risk tier —
///    "ask ... when multiple targets remain plausible."
/// 2. **Weak evidence on a guarded tier**: even with a single, unambiguous
///    top candidate, if its capability's risk tier is at or above
///    `configuration.referenceGuardedTierThreshold`, it only resolves when
///    backed by direct evidence, non-inferred authority, in-scope, and
///    confidence at or above `configuration.referenceGuardedMinimumConfidence`.
///    Otherwise resolution stops at `.blockedWeakEvidence` — "'it' never
///    resolves to a destructive target on weak evidence."
public struct ReferenceResolver: Sendable, Equatable {
  public let configuration: ContextConfiguration

  public init(configuration: ContextConfiguration = ContextConfiguration()) {
    self.configuration = configuration
  }

  public func resolve(
    reference: String,
    candidates: [ReferenceCandidate],
    referenceDate: Date = Date()
  ) -> ReferenceResolution {
    guard !candidates.isEmpty else { return .none }

    // Keep each candidate paired with its score throughout — no separate
    // by-ID lookup table, so nothing depends on candidate IDs being unique.
    let scored = candidates
      .map { ($0, ContextRanking.score($0, referenceDate: referenceDate, configuration: configuration)) }
      .sorted { $0.1 > $1.1 }
    let ranked = scored.map(\.0)

    let unambiguous: Bool
    if scored.count == 1 {
      unambiguous = true
    } else {
      unambiguous = (scored[0].1 - scored[1].1) >= configuration.referenceSeparationMargin
    }

    guard unambiguous else {
      return .ambiguous(ranked)
    }

    let top = ranked[0]
    guard isGuarded(top) else {
      return .resolved(top)
    }

    let strongEvidence =
      top.hasDirectEvidence
      && top.authority != .inferred
      && top.scopeMatch
      && top.confidence >= configuration.referenceGuardedMinimumConfidence

    return strongEvidence ? .resolved(top) : .blockedWeakEvidence(top)
  }

  private func isGuarded(_ candidate: ReferenceCandidate) -> Bool {
    guard let riskTier = candidate.capability?.riskTier else { return false }
    return riskTier.rawValue >= configuration.referenceGuardedTierThreshold.rawValue
  }
}
