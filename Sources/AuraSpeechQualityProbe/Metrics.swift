import Foundation

enum Metrics {
  /// Tokenize for scoring: case-folded, punctuation-stripped, whitespace-split.
  ///
  /// Turkish case folding is locale-sensitive (`I` → `ı`, not `i`), so the
  /// Turkish locale is used explicitly. Folding with the default locale would
  /// turn `İSTANBUL` into `i̇stanbul` and invent a mismatch that the recognizer
  /// never made.
  static func tokens(_ text: String) -> [String] {
    text.lowercased(with: Locale(identifier: "tr-TR"))
      .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
      .map(String.init)
      .filter { !$0.isEmpty }
  }

  /// Word Error Rate: Levenshtein edit distance over token sequences divided
  /// by the reference length. Substitutions, insertions, and deletions all
  /// count, which is why this is reported instead of the softer token-overlap
  /// score the earlier harness used.
  ///
  /// Returns 1.0 for an empty transcript against a non-empty reference — a
  /// recognizer that produces nothing has failed completely, not perfectly.
  static func wordErrorRate(reference: String, hypothesis: String) -> Double {
    let referenceTokens = tokens(reference)
    let hypothesisTokens = tokens(hypothesis)
    guard !referenceTokens.isEmpty else { return hypothesisTokens.isEmpty ? 0 : 1 }

    var previous = Array(0...hypothesisTokens.count)
    var current = [Int](repeating: 0, count: hypothesisTokens.count + 1)

    for referenceIndex in 1...referenceTokens.count {
      current[0] = referenceIndex
      for hypothesisIndex in 1...hypothesisTokens.count {
        let substitutionCost =
          referenceTokens[referenceIndex - 1] == hypothesisTokens[hypothesisIndex - 1] ? 0 : 1
        current[hypothesisIndex] = min(
          previous[hypothesisIndex] + 1,  // deletion
          current[hypothesisIndex - 1] + 1,  // insertion
          previous[hypothesisIndex - 1] + substitutionCost  // substitution
        )
      }
      swap(&previous, &current)
    }

    return Double(previous[hypothesisTokens.count]) / Double(referenceTokens.count)
  }

  /// Fraction of declared entities that survive into the transcript.
  ///
  /// An entity counts as recovered when *any* of its declared surface forms
  /// appears. Forms are matched as normalized token subsequences, not raw
  /// substrings, so `"three thirty"` matches inside a longer sentence
  /// regardless of punctuation but never spuriously matches `"threethirty"`.
  ///
  /// The accepted forms come from the corpus definition, so this stays a
  /// ground-truth comparison. It never inspects the hypothesis to decide what
  /// counts as correct — that would be rewriting a bad transcript into a
  /// successful command, which SP-016 explicitly forbids.
  static func entityRecall(entities: [CorpusEntity], hypothesis: String) -> Double {
    guard !entities.isEmpty else { return 1.0 }
    let hypothesisTokens = tokens(hypothesis)
    let hits = entities.filter { entity in
      entity.allForms.contains { form in
        containsSubsequence(hypothesisTokens, tokens(form))
      }
    }
    return Double(hits.count) / Double(entities.count)
  }

  /// Entities that did not survive, for per-utterance diagnosis.
  static func missingEntities(entities: [CorpusEntity], hypothesis: String) -> [String] {
    let hypothesisTokens = tokens(hypothesis)
    return entities.filter { entity in
      !entity.allForms.contains { form in
        containsSubsequence(hypothesisTokens, tokens(form))
      }
    }.map(\.canonical)
  }

  static func containsSubsequence(_ haystack: [String], _ needle: [String]) -> Bool {
    guard !needle.isEmpty else { return true }
    guard haystack.count >= needle.count else { return false }
    for start in 0...(haystack.count - needle.count) {
      if Array(haystack[start..<(start + needle.count)]) == needle { return true }
    }
    return false
  }
}
