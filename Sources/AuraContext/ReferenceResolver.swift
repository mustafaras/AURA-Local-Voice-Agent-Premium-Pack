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
    referenceDate: Date = Date(),
    explicitlyConfirmedTargetID: UUID? = nil
  ) -> ReferenceResolution {
    let resolutionGraph = graph(
      reference: reference, candidates: candidates, referenceDate: referenceDate,
      explicitlyConfirmedTargetID: explicitlyConfirmedTargetID)
    guard !resolutionGraph.nodes.isEmpty else { return .none }
    if let confirmed = resolutionGraph.nodes.first(where: \.explicitlyConfirmed) {
      return .resolved(confirmed.candidate)
    }

    let lexicalMatches = resolutionGraph.nodes.filter(\.lexicalMatch)
    let scored = lexicalMatches.isEmpty ? resolutionGraph.nodes : lexicalMatches
    let ranked = scored.map(\.candidate)

    let unambiguous: Bool
    if scored.count == 1 {
      unambiguous = true
    } else {
      unambiguous =
        (scored[0].score - scored[1].score) >= configuration.referenceSeparationMargin
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

  /// Build the inspectable Phase 22 reference graph. Candidate rank combines
  /// the Phase 16 evidence score with conversational salience and a
  /// deterministic lexical-kind boost. Neither boost can bypass the guarded
  /// evidence/confirmation check in `resolve`.
  public func graph(
    reference: String,
    candidates: [ReferenceCandidate],
    referenceDate: Date = Date(),
    explicitlyConfirmedTargetID: UUID? = nil
  ) -> ReferenceResolutionGraph {
    let requestedKind = entityKind(for: reference)
    let nodes = candidates.filter { candidate in
      let age = referenceDate.timeIntervalSince(candidate.observedAt)
      return age >= 0 && age <= configuration.referenceCandidateMaxAgeSeconds
    }.map { candidate -> ReferenceGraphNode in
      let lexicalMatch = requestedKind == nil || candidate.entityKind == requestedKind
      let evidenceScore = ContextRanking.score(
        candidate, referenceDate: referenceDate, configuration: configuration)
      let lexicalBoost = lexicalMatch ? 0.05 : 0
      let salienceBoost =
        configuration.referenceSalienceWeight * candidate.conversationalSalience
      return ReferenceGraphNode(
        candidate: candidate,
        score: evidenceScore + lexicalBoost + salienceBoost,
        lexicalMatch: lexicalMatch,
        explicitlyConfirmed: explicitlyConfirmedTargetID == candidate.id)
    }.sorted {
      if $0.score != $1.score { return $0.score > $1.score }
      if $0.candidate.observedAt != $1.candidate.observedAt {
        return $0.candidate.observedAt > $1.candidate.observedAt
      }
      return $0.candidate.id.uuidString < $1.candidate.id.uuidString
    }
    return ReferenceResolutionGraph(reference: reference, nodes: nodes)
  }

  private func entityKind(for reference: String) -> ReferenceEntityKind? {
    let normalized = reference.lowercased()
    if normalized.contains("file") || normalized.contains("document") { return .file }
    if normalized.contains("repo") || normalized.contains("repository")
      || normalized.contains("workspace")
    {
      return .repository
    }
    if normalized.contains("app") || normalized.contains("application") { return .application }
    if normalized.contains("task") || normalized.contains("job") { return .task }
    if normalized.contains("test") { return .test }
    if normalized.contains("draft") { return .draft }
    if normalized.contains("claude") || normalized.contains("codex")
      || normalized.contains("copilot")
    {
      return .backend
    }
    if normalized.contains("decision") { return .decision }
    if normalized.contains("preference") || normalized.contains("setting") { return .preference }
    return nil
  }

  private func isGuarded(_ candidate: ReferenceCandidate) -> Bool {
    guard let riskTier = candidate.capability?.riskTier else { return false }
    return riskTier.rawValue >= configuration.referenceGuardedTierThreshold.rawValue
  }
}
