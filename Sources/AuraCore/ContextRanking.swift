import Foundation

/// Pure scoring for context reconstruction and reference resolution.
///
/// Both `ContextEngine` (ranking optional bundle candidates) and
/// `ReferenceResolver` (ranking reference targets) score their candidates
/// with the same five dimensions named in
/// `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md`: "scope match, recency,
/// authority, confidence, and direct evidence." Keeping the math here, pure
/// and dependency-free, makes both callers trivially unit-testable against
/// the same deterministic function.
public enum ContextRanking {
  /// Exponential recency decay: `1.0` at `observedAt == referenceDate`,
  /// halving every `halfLifeSeconds`. Never negative, never above `1.0`.
  public static func recencyScore(
    observedAt: Date, referenceDate: Date, halfLifeSeconds: Double
  ) -> Double {
    guard halfLifeSeconds > 0 else { return observedAt <= referenceDate ? 1 : 0 }
    let age = max(0, referenceDate.timeIntervalSince(observedAt))
    return pow(0.5, age / halfLifeSeconds)
  }

  /// Normalize a `ContextAuthority` tier onto `[0, 1]`.
  public static func authorityScore(_ authority: ContextAuthority) -> Double {
    Double(authority.rawValue) / Double(ContextAuthority.userStated.rawValue)
  }

  /// Composite rank score for one candidate, combining scope match, recency,
  /// authority, confidence, and direct evidence per `configuration`'s
  /// weights (which are validated elsewhere to sum to `1.0`).
  public static func score(
    _ candidate: some ContextRankable,
    referenceDate: Date,
    configuration: ContextConfiguration
  ) -> Double {
    let recency = recencyScore(
      observedAt: candidate.observedAt, referenceDate: referenceDate,
      halfLifeSeconds: configuration.recencyHalfLifeSeconds)
    let authority = authorityScore(candidate.authority)
    return configuration.rankingWeightScope * (candidate.scopeMatch ? 1 : 0)
      + configuration.rankingWeightRecency * recency
      + configuration.rankingWeightAuthority * authority
      + configuration.rankingWeightConfidence * candidate.confidence
      + configuration.rankingWeightEvidence * (candidate.hasDirectEvidence ? 1 : 0)
  }

  /// Whether a `MemoryRecord`'s scope applies to a request made under
  /// `requestScope`. A record with no scope constraints at all (`.global`)
  /// always applies. A record with at least one constrained field applies
  /// only if that field matches the corresponding field of `requestScope`;
  /// a record scoped to a different project/task/session than the request
  /// is out of scope.
  public static func scopeMatches(recordScope: MemoryScope, requestScope: MemoryScope) -> Bool {
    if recordScope.projectID == nil, recordScope.taskID == nil, recordScope.sessionID == nil {
      return true
    }
    if let projectID = recordScope.projectID, projectID == requestScope.projectID { return true }
    if let taskID = recordScope.taskID, taskID == requestScope.taskID { return true }
    if let sessionID = recordScope.sessionID, sessionID == requestScope.sessionID { return true }
    return false
  }

  /// Deterministic keyword tokenizer used by semantic retrieval: lowercases,
  /// splits on non-alphanumeric boundaries, and drops short/stopword tokens.
  public static func tokenize(_ text: String) -> Set<String> {
    let stopwords: Set<String> = [
      "the", "a", "an", "of", "to", "and", "or", "is", "are", "was", "were", "for", "on", "in",
      "at", "it", "this", "that", "with", "as", "be", "by", "from",
    ]
    let lowered = text.lowercased()
    let pieces =
      lowered
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { $0.count >= 3 && !stopwords.contains($0) }
    return Set(pieces)
  }

  /// Fraction of `query`'s tokens that also appear in `document` — a
  /// recall-oriented containment score, not full Jaccard, so a short
  /// document that fully covers a short query still scores `1.0`.
  public static func containmentScore(query: Set<String>, document: Set<String>) -> Double {
    guard !query.isEmpty else { return 0 }
    return Double(query.intersection(document).count) / Double(query.count)
  }
}
