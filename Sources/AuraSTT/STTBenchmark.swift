import Foundation

/// Deterministic benchmarking utilities for STT accuracy and latency.
///
/// WER is computed using simple whitespace tokenization. Entity error rate
/// counts user-vocabulary terms that differ between reference and hypothesis.
public enum STTBenchmark {
  /// Word Error Rate: (S + D + I) / N. Lower is better.
  public static func wordErrorRate(reference: String, hypothesis: String) -> Double {
    let refTokens = reference.lowercased().components(separatedBy: .whitespacesAndNewlines).filter {
      !$0.isEmpty
    }
    let hypTokens = hypothesis.lowercased()
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
    guard !refTokens.isEmpty else { return hypTokens.isEmpty ? 0 : 1 }
    let distance = levenshtein(refTokens, hypTokens)
    return Double(distance) / Double(refTokens.count)
  }

  /// Entity error rate over a set of expected entity strings. Returns the
  /// fraction of expected entities missing from the hypothesis.
  public static func entityErrorRate(
    reference: String, hypothesis: String, entities: Set<String>
  ) -> Double {
    let normalizedHyp = hypothesis.lowercased()
    let missing = entities.filter { entity in
      !normalizedHyp.contains(entity.lowercased())
    }
    guard !entities.isEmpty else { return 0 }
    return Double(missing.count) / Double(entities.count)
  }

  /// Levenshtein distance on arrays of tokens.
  public static func levenshtein<T: Equatable>(
    _ referenceTokens: [T], _ hypothesisTokens: [T]
  ) -> Int {
    let referenceCount = referenceTokens.count
    let hypothesisCount = hypothesisTokens.count
    guard referenceCount > 0 else { return hypothesisCount }
    guard hypothesisCount > 0 else { return referenceCount }

    var previous = Array(0...hypothesisCount)
    var current = Array(repeating: 0, count: hypothesisCount + 1)

    for referenceIndex in 1...referenceCount {
      current[0] = referenceIndex
      for hypothesisIndex in 1...hypothesisCount {
        let cost =
          referenceTokens[referenceIndex - 1] == hypothesisTokens[hypothesisIndex - 1] ? 0 : 1
        current[hypothesisIndex] = min(
          previous[hypothesisIndex] + 1,
          current[hypothesisIndex - 1] + 1,
          previous[hypothesisIndex - 1] + cost
        )
      }
      swap(&previous, &current)
    }
    return previous[hypothesisCount]
  }
}
