import AuraCore
import Foundation

/// A normalized Codex event.
///
/// Some cases are produced by parsing a `codex exec --json` line
/// (`CodexEventNormalizer.normalize`); others (`runStarted`,
/// `approvalRequested`, `approvalDecision`, `budgetExceeded`) have no
/// Codex-native wire representation and are synthesized directly by
/// `CodexAdapter` — "approval need" is the upfront per-run policy confirm
/// cycle, not a Codex-native mid-run prompt, since `codex exec` has no
/// `-a/--ask-for-approval` flag at all (verified via `codex exec --help`;
/// that flag exists only on the top-level interactive `codex` command).
public enum CodexNormalizedEvent: Sendable, Equatable {
  case runStarted(sandbox: String, workingDirectory: String, ephemeral: Bool, model: String?)
  case approvalRequested(
    requestID: UUID, riskTier: PermissionRiskTier, targetSummary: String, expiresAt: Date)
  case approvalDecision(requestID: UUID, allowed: Bool, reason: String?)
  case threadStarted(threadID: String?)
  case turnStarted
  /// A `reasoning` or `agent_message` item — the model's internal reasoning
  /// text or its visible answer. Confirmed shape: `item.text`.
  case agentText(role: String, text: String, sequence: Int)
  /// An `error`-typed item nested inside `item.completed` (distinct from a
  /// top-level `error` event or a `turn.failed`). Confirmed shape:
  /// `item.message`.
  case itemError(message: String, sequence: Int)
  /// An item whose type is named in Codex's public documentation
  /// (`command_execution`, `file_change`, `plan_update`, `mcp_tool_call`,
  /// `web_search`) but was not observed in the authorized smoke test, or any
  /// other item type not covered above. Carried opaquely rather than with
  /// fabricated structured fields — see ADR-011.
  case unclassifiedItem(rawItemType: String?, sequence: Int, rawLine: String)
  case turnCompleted(observedTokenUsage: [String: Int])
  /// Confirmed shape: `error.message` (nested, not a top-level field).
  case turnFailed(message: String?)
  /// A top-level `error` event. Confirmed shape: `message` (flat).
  case codexError(message: String)
  case budgetExceeded(kind: String, limit: Double, observed: Double)
  /// A JSONL line whose top-level `type` was missing, unrecognized, or that
  /// failed to decode. Forwarded rather than dropped so callers can decide
  /// whether it is safe to ignore.
  case unrecognized(rawLine: String)
}

/// Parses `codex exec --json` JSONL lines into `CodexNormalizedEvent`.
///
/// The top-level discriminator (`thread.started`, `turn.started`,
/// `turn.completed`, `turn.failed`, `item.started`, `item.completed`,
/// `error`) and the shapes below were confirmed either from official
/// documentation or from an authorized, real `codex exec --json` invocation
/// captured in `Tests/AuraAgentTests/Fixtures/`:
/// - `thread.started`: `{type, thread_id}`
/// - `turn.started` / `turn.completed`: `{type}` / `{type, usage: {...}}`
/// - `turn.failed`: `{type, error: {message}}` (nested, not flat)
/// - top-level `error`: `{type, message}` (flat)
/// - `item.completed`: `{type, item: {id, type, ...}}`, where the nested
///   `item.type` is confirmed for `error` (`{id, type, message}`) and
///   `reasoning`/`agent_message` (`{id, type, text}`). Other item types named
///   in Codex's documentation (`command_execution`, `file_change`,
///   `plan_update`, `mcp_tool_call`, `web_search`) were not observed and are
///   carried opaquely. `item.started` was not observed in the smoke test
///   either; it is parsed with the same tolerant logic as `item.completed`.
/// `usage` key names (`input_tokens`, `cached_input_tokens`, `output_tokens`,
/// `reasoning_output_tokens`) are confirmed but extracted leniently — this
/// decoder never assumes a fixed set of usage keys, only integers.
public enum CodexEventNormalizer {
  private struct TopLevel: Decodable {
    let type: String
  }

  private struct ThreadStartedPayload: Decodable {
    let threadID: String?
    enum CodingKeys: String, CodingKey {
      case threadID = "thread_id"
    }
  }

  private struct ErrorPayload: Decodable {
    let message: String?
  }

  private struct TurnFailedPayload: Decodable {
    let error: ErrorPayload?
  }

  private struct ItemEnvelope: Decodable {
    let item: ItemPayload?
  }

  private struct ItemPayload: Decodable {
    let type: String?
    let message: String?
    let text: String?
  }

  public static func normalize(line: String, sequence: Int) -> CodexNormalizedEvent {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
      return .unrecognized(rawLine: trimmed)
    }
    guard let topLevel = try? JSONDecoder().decode(TopLevel.self, from: data) else {
      return .unrecognized(rawLine: trimmed)
    }

    switch topLevel.type {
    case "thread.started":
      let threadID = (try? JSONDecoder().decode(ThreadStartedPayload.self, from: data))?.threadID
      return .threadStarted(threadID: threadID)

    case "turn.started":
      return .turnStarted

    case "turn.completed":
      return .turnCompleted(observedTokenUsage: extractUsage(from: data))

    case "turn.failed":
      let message = (try? JSONDecoder().decode(TurnFailedPayload.self, from: data))?.error?.message
      return .turnFailed(message: message)

    case "item.started", "item.completed":
      return normalizeItem(data: data, rawLine: trimmed, sequence: sequence)

    case "error":
      let message = (try? JSONDecoder().decode(ErrorPayload.self, from: data))?.message ?? trimmed
      return .codexError(message: message)

    default:
      return .unrecognized(rawLine: trimmed)
    }
  }

  private static func normalizeItem(
    data: Data, rawLine: String, sequence: Int
  ) -> CodexNormalizedEvent {
    guard let item = (try? JSONDecoder().decode(ItemEnvelope.self, from: data))?.item else {
      return .unclassifiedItem(rawItemType: nil, sequence: sequence, rawLine: rawLine)
    }
    switch item.type {
    case "error":
      return .itemError(message: item.message ?? rawLine, sequence: sequence)
    case "reasoning", "agent_message":
      return .agentText(role: item.type ?? "unknown", text: item.text ?? "", sequence: sequence)
    default:
      return .unclassifiedItem(rawItemType: item.type, sequence: sequence, rawLine: rawLine)
    }
  }

  /// Best-effort extraction of a `usage` object's integer fields.
  private static func extractUsage(from data: Data) -> [String: Int] {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let usage = object["usage"] as? [String: Any]
    else {
      return [:]
    }
    var result: [String: Int] = [:]
    for (key, value) in usage {
      if let intValue = value as? Int {
        result[key] = intValue
      } else if let numberValue = value as? NSNumber {
        result[key] = numberValue.intValue
      }
    }
    return result
  }
}
