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
    let hypTokens = hypothesis.lowercased().components(separatedBy: .whitespacesAndNewlines).filter
    { !$0.isEmpty }
    guard !refTokens.isEmpty else { return hypTokens.isEmpty ? 0 : 1 }
    let distance = levenshtein(refTokens, hypTokens)
    return Double(distance) / Double(refTokens.count)
  }

  /// Entity error rate over a set of expected entity strings. Returns the
  /// fraction of expected entities missing from the hypothesis.
  public static func entityErrorRate(reference: String, hypothesis: String, entities: Set<String>)
    -> Double
  {
    let normalizedHyp = hypothesis.lowercased()
    let missing = entities.filter { entity in
      !normalizedHyp.contains(entity.lowercased())
    }
    guard !entities.isEmpty else { return 0 }
    return Double(missing.count) / Double(entities.count)
  }

  /// Levenshtein distance on arrays of tokens.
  public static func levenshtein<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
    let n = a.count
    let m = b.count
    guard n > 0 else { return m }
    guard m > 0 else { return n }

    var previous = Array(0...m)
    var current = Array(repeating: 0, count: m + 1)

    for i in 1...n {
      current[0] = i
      for j in 1...m {
        let cost = a[i - 1] == b[j - 1] ? 0 : 1
        current[j] = min(
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost
        )
      }
      swap(&previous, &current)
    }
    return previous[m]
  }
}
