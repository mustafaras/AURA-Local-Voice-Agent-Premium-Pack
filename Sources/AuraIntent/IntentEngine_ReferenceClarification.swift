import AuraContext
import AuraCore
import Foundation

extension IntentEngine {
  /// The candidate the user picked when answering "which one did you mean?",
  /// or `nil` when there is no live question or the answer does not settle it.
  ///
  /// Resolution is deliberately all-or-nothing: the answer must name exactly
  /// one of the candidates AURA actually offered. An answer matching several
  /// candidates, or none, leaves the reference unresolved and the question
  /// standing — guessing here would invent a confirmation the user never
  /// gave, and `ReferenceResolver` treats an explicit confirmation as
  /// authority to skip its guarded-tier evidence check.
  func confirmedReferenceTargetID(forAnswer utterance: String) -> UUID? {
    guard let pending = pendingReferenceClarification else { return nil }
    guard now() < pending.expiresAt else {
      pendingReferenceClarification = nil
      return nil
    }
    let answerTokens = Self.tokens(in: utterance)
    guard !answerTokens.isEmpty else { return nil }

    let distinctive = Self.distinctiveTokens(among: pending.candidates)
    let matches = pending.candidates.filter { candidate in
      guard let candidateTokens = distinctive[candidate.id] else { return false }
      return !candidateTokens.isDisjoint(with: answerTokens)
    }
    guard matches.count == 1, let confirmed = matches.first else { return nil }
    pendingReferenceClarification = nil
    return confirmed.id
  }

  /// Remember the candidates behind an ambiguous reference so the next turn
  /// can apply the user's answer. Any other resolution clears the question:
  /// once a reference resolves (or has no candidate at all), there is nothing
  /// left to confirm.
  func recordReferenceClarification(from result: DeepContextResult?) {
    guard let result, let reference = result.parsedUtterance.implicitReference else {
      pendingReferenceClarification = nil
      return
    }
    switch result.referenceResolution {
    case .ambiguous(let candidates):
      pendingReferenceClarification = PendingReferenceClarification(
        reference: reference,
        candidates: candidates,
        expiresAt: now().addingTimeInterval(configuration.clarificationExpirySeconds))
    case .resolved, .blockedWeakEvidence, .none:
      pendingReferenceClarification = nil
    }
  }

  /// Words in an utterance, lowercased, split on anything non-alphanumeric.
  /// Tokens shorter than three characters are dropped: "a" and "of" cannot
  /// identify a target, and treating them as identifying would make an
  /// accidental match likely.
  static func tokens(in text: String) -> Set<String> {
    Set(
      text.lowercased()
        .split { !$0.isLetter && !$0.isNumber }
        .map(String.init)
        .filter { $0.count >= 3 })
  }

  /// For each candidate, the tokens that identify *it alone* within this
  /// question.
  ///
  /// Distinctiveness is computed against the offered set rather than in the
  /// abstract, because that is what makes a wrong pick impossible: a token
  /// two candidates share (the `txt` in `alpha.txt`/`beta.txt`, the `com` in
  /// two reverse-DNS bundle identifiers) identifies neither and is dropped,
  /// so an answer containing only shared words matches nothing and the
  /// question stands.
  static func distinctiveTokens(
    among candidates: [ReferenceCandidate]
  ) -> [UUID: Set<String>] {
    let perCandidate = candidates.reduce(into: [UUID: Set<String>]()) { result, candidate in
      result[candidate.id] = identifyingTokens(for: candidate)
    }
    var occurrences: [String: Int] = [:]
    for tokens in perCandidate.values {
      for token in tokens { occurrences[token, default: 0] += 1 }
    }
    return perCandidate.mapValues { tokens in
      tokens.filter { occurrences[$0] == 1 }
    }
  }

  /// Tokens drawn from a candidate's identifying tail.
  ///
  /// A candidate's description is `"<kind>: <value>"`, where the value is a
  /// path, a bundle identifier, or a label. The identifying part is its last
  /// path component — "AURA-Local-Voice-Agent-Premium-Pack", "alpha.txt" —
  /// so the leading directories are dropped. The kind prefix is dropped too:
  /// every repository candidate would otherwise carry the word "repository"
  /// and no answer naming a kind could ever be distinctive.
  static func identifyingTokens(for candidate: ReferenceCandidate) -> Set<String> {
    let value =
      candidate.description
      .split(separator: ":", maxSplits: 1)
      .last
      .map(String.init)?
      .trimmingCharacters(in: .whitespaces) ?? candidate.description
    let tail = value.split(separator: "/").last.map(String.init) ?? value
    return tokens(in: tail)
  }
}
