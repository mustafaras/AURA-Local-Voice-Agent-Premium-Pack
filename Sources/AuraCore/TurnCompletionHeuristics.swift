import Foundation

/// Conservative, deterministic continuation hints. This never rewrites text;
/// it only delays dispatch briefly when a stable segment visibly ends with a
/// connector, colon, comma, or open punctuation.
public enum TurnCompletionHeuristics {
  private static let continuationTokens: Set<String> = [
    "and", "or", "but", "because", "if", "to", "with", "for", "then",
    "ve", "veya", "ama", "çünkü", "eğer", "için", "ile", "sonra", "şu",
  ]

  public static func likelyIncomplete(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    if trimmed.hasSuffix(":") || trimmed.hasSuffix(",") || trimmed.hasSuffix("…") {
      return true
    }
    if trimmed.hasSuffix("(") || trimmed.hasSuffix("[") || trimmed.hasSuffix("{") {
      return true
    }
    let last =
      trimmed
      .lowercased()
      .split(whereSeparator: { $0.isWhitespace || ".!?;:,.".contains($0) })
      .last
      .map(String.init)
    return last.map(continuationTokens.contains) ?? false
  }
}
