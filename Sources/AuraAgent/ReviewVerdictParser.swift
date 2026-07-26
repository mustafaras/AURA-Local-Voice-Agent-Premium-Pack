import AuraCore
import Foundation

/// Parses a reviewer agent's accumulated text output for a fixed,
/// orchestrator-defined verdict marker.
///
/// `MultiAgentOrchestrator` instructs the reviewer role, as part of its own
/// prompt, to end its answer with exactly one of:
///
/// ```
/// VERDICT: APPROVE
/// VERDICT: REQUEST_CHANGES: <reason>
/// ```
///
/// This is a convention the orchestrator itself defines and controls — not
/// an invented backend API — and it is deliberately narrow: free-form model
/// prose is never itself treated as an approval. If no marker is found, the
/// verdict is `.unparseable`, which `MultiAgentOrchestrator` treats as a
/// disagreement (never a silent approval), satisfying "no raw model output
/// may become an executable action."
public enum ReviewVerdictParser {
  private static let approvePattern = try! NSRegularExpression(
    pattern: #"VERDICT:\s*APPROVE\s*$"#, options: [.caseInsensitive])
  private static let requestChangesPattern = try! NSRegularExpression(
    pattern: #"VERDICT:\s*REQUEST_CHANGES:\s*(.*)$"#,
    options: [.caseInsensitive, .dotMatchesLineSeparators])

  public static func parse(_ text: String) -> ReviewVerdict {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .unparseable }

    let fullRange = NSRange(trimmed.startIndex..., in: trimmed)

    if let match = requestChangesPattern.firstMatch(in: trimmed, options: [], range: fullRange),
      match.numberOfRanges > 1,
      let reasonRange = Range(match.range(at: 1), in: trimmed)
    {
      let reason = trimmed[reasonRange].trimmingCharacters(in: .whitespacesAndNewlines)
      return .requestChanges(reason: reason.isEmpty ? "no reason given" : reason)
    }

    if approvePattern.firstMatch(in: trimmed, options: [], range: fullRange) != nil {
      return .approve
    }

    return .unparseable
  }
}
