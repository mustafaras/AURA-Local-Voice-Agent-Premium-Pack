import AuraCore
import Foundation

/// A normalized Claude Code event.
///
/// Some cases are produced by parsing a `claude -p --output-format
/// stream-json` line (`ClaudeEventNormalizer.normalize`); others
/// (`runStarted`, `approvalRequested`, `approvalDecision`, `budgetExceeded`)
/// have no Claude-native wire representation and are synthesized directly by
/// `ClaudeAdapter` — "approval need" is the upfront per-run policy confirm
/// cycle, not a mid-run prompt, since `claude -p` always runs with
/// `--permission-mode dontAsk` (deny rather than prompt; verified `claude
/// exec --help` has no interactive-capable mode usable without a TTY).
public enum ClaudeNormalizedEvent: Sendable, Equatable {
  case runStarted(permissionMode: String, workingDirectory: String, ephemeral: Bool, model: String?)
  case approvalRequested(
    requestID: UUID, riskTier: PermissionRiskTier, targetSummary: String, expiresAt: Date)
  case approvalDecision(requestID: UUID, allowed: Bool, reason: String?)
  /// `system`/`hook_started` or `hook_response`. Only ever reflects hooks
  /// from the loaded `settingSources` (default: the operating user's own
  /// `~/.claude/settings.json` only).
  case hookEvent(hookName: String, hookEvent: String, outcome: String?, sequence: Int)
  /// `system`/`init`, the first event of every run.
  case sessionInit(
    claudeSessionID: String, model: String, permissionMode: String, toolCount: Int,
    mcpServerCount: Int, claudeCodeVersion: String, apiKeySource: String)
  /// A `text`-type content block from an `assistant`/`user` message.
  case message(role: String, text: String, sequence: Int)
  case rateLimitEvent(status: String, rateLimitType: String, sequence: Int)
  /// A non-text content block (`tool_use`, `tool_result`, `thinking`, …) or
  /// any other item not covered above. The authorized smoke test used
  /// `--tools ""` (no tools available), so these shapes were never observed;
  /// carried opaquely rather than with fabricated structured fields.
  case unclassifiedContent(rawContentType: String?, sequence: Int, rawLine: String)
  /// A recognized top-level `type` whose fields were not deeply decoded
  /// (`system/api_retry`, `system/plugin_install`, `stream_event`, …) —
  /// documented by Claude Code but not exercised by the smoke test.
  case unrecognizedTopLevel(rawType: String, sequence: Int, rawLine: String)
  case turnCompleted(
    resultText: String, totalCostUSD: Double, numTurns: Int, durationMs: Int, stopReason: String?,
    permissionDenialCount: Int)
  case turnFailed(message: String?, apiErrorStatus: Int?)
  case claudeError(message: String)
  case budgetExceeded(kind: String, limit: Double, observed: Double)
  /// A JSONL line whose top-level `type` was missing or that failed to
  /// decode at all.
  case unrecognized(rawLine: String)
}

/// Parses `claude -p --output-format stream-json` JSONL lines into
/// `ClaudeNormalizedEvent`.
///
/// Field names and casing below were confirmed by an authorized, real
/// `claude -p` invocation captured in
/// `Tests/AuraAgentTests/Fixtures/claude_smoke_success.jsonl`, cross-checked
/// against official headless-mode documentation. Field casing is
/// inconsistent across event types in the real wire format (e.g.
/// `session_id`/`total_cost_usd` are snake_case while
/// `permissionMode`/`apiKeySource`/`modelUsage` are camelCase within the
/// *same* payload) — this decoder maps each field explicitly rather than
/// assuming a single global casing convention.
public enum ClaudeEventNormalizer {
  private struct TopLevel: Decodable {
    let type: String
  }

  private struct HookPayload: Decodable {
    let hookName: String
    let hookEvent: String
    let outcome: String?
    enum CodingKeys: String, CodingKey {
      case hookName = "hook_name"
      case hookEvent = "hook_event"
      case outcome
    }
  }

  private struct InitPayload: Decodable {
    let sessionID: String
    let model: String
    let permissionMode: String
    let claudeCodeVersion: String
    let apiKeySource: String
    enum CodingKeys: String, CodingKey {
      case sessionID = "session_id"
      case model
      case permissionMode
      case claudeCodeVersion = "claude_code_version"
      case apiKeySource
    }
  }

  private struct ContentBlock: Decodable {
    let type: String
    let text: String?
  }

  private struct MessagePayload: Decodable {
    let role: String
    let content: [ContentBlock]
  }

  private struct MessageEnvelope: Decodable {
    let message: MessagePayload
  }

  private struct RateLimitInfo: Decodable {
    let status: String
    let rateLimitType: String
    enum CodingKeys: String, CodingKey {
      case status
      case rateLimitType
    }
  }

  private struct RateLimitEnvelope: Decodable {
    let rateLimitInfo: RateLimitInfo
    enum CodingKeys: String, CodingKey {
      case rateLimitInfo = "rate_limit_info"
    }
  }

  private struct ResultPayload: Decodable {
    let isError: Bool
    let result: String?
    let totalCostUSD: Double?
    let numTurns: Int?
    let durationMs: Int?
    let stopReason: String?
    let apiErrorStatus: Int?
    enum CodingKeys: String, CodingKey {
      case isError = "is_error"
      case result
      case totalCostUSD = "total_cost_usd"
      case numTurns = "num_turns"
      case durationMs = "duration_ms"
      case stopReason = "stop_reason"
      case apiErrorStatus = "api_error_status"
    }
  }

  public static func normalize(line: String, sequence: Int) -> ClaudeNormalizedEvent {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
      return .unrecognized(rawLine: trimmed)
    }
    guard let topLevel = try? JSONDecoder().decode(TopLevel.self, from: data) else {
      return .unrecognized(rawLine: trimmed)
    }

    switch topLevel.type {
    case "system":
      return normalizeSystem(data: data, rawLine: trimmed, sequence: sequence)
    case "assistant", "user":
      return normalizeMessage(
        data: data, topLevelType: topLevel.type, rawLine: trimmed, sequence: sequence)
    case "rate_limit_event":
      guard let envelope = try? JSONDecoder().decode(RateLimitEnvelope.self, from: data) else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      return .rateLimitEvent(
        status: envelope.rateLimitInfo.status, rateLimitType: envelope.rateLimitInfo.rateLimitType,
        sequence: sequence)
    case "result":
      guard let result = try? JSONDecoder().decode(ResultPayload.self, from: data) else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      let denialCount = extractArrayCount(from: data, key: "permission_denials")
      if result.isError {
        return .turnFailed(message: result.result, apiErrorStatus: result.apiErrorStatus)
      }
      return .turnCompleted(
        resultText: result.result ?? "", totalCostUSD: result.totalCostUSD ?? 0,
        numTurns: result.numTurns ?? 0, durationMs: result.durationMs ?? 0,
        stopReason: result.stopReason, permissionDenialCount: denialCount)
    default:
      return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
    }
  }

  private static func normalizeSystem(
    data: Data, rawLine: String, sequence: Int
  ) -> ClaudeNormalizedEvent {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let subtype = object["subtype"] as? String
    else {
      return .unrecognizedTopLevel(rawType: "system", sequence: sequence, rawLine: rawLine)
    }

    switch subtype {
    case "hook_started", "hook_response":
      guard let hook = try? JSONDecoder().decode(HookPayload.self, from: data) else {
        return .unrecognizedTopLevel(rawType: "system.\(subtype)", sequence: sequence, rawLine: rawLine)
      }
      return .hookEvent(
        hookName: hook.hookName, hookEvent: hook.hookEvent, outcome: hook.outcome,
        sequence: sequence)
    case "init":
      guard let initPayload = try? JSONDecoder().decode(InitPayload.self, from: data) else {
        return .unrecognizedTopLevel(rawType: "system.init", sequence: sequence, rawLine: rawLine)
      }
      let toolCount = extractArrayCount(from: data, key: "tools")
      let mcpServerCount = extractArrayCount(from: data, key: "mcp_servers")
      return .sessionInit(
        claudeSessionID: initPayload.sessionID, model: initPayload.model,
        permissionMode: initPayload.permissionMode, toolCount: toolCount,
        mcpServerCount: mcpServerCount, claudeCodeVersion: initPayload.claudeCodeVersion,
        apiKeySource: initPayload.apiKeySource)
    default:
      return .unrecognizedTopLevel(rawType: "system.\(subtype)", sequence: sequence, rawLine: rawLine)
    }
  }

  private static func normalizeMessage(
    data: Data, topLevelType: String, rawLine: String, sequence: Int
  ) -> ClaudeNormalizedEvent {
    guard let envelope = try? JSONDecoder().decode(MessageEnvelope.self, from: data) else {
      return .unclassifiedContent(rawContentType: nil, sequence: sequence, rawLine: rawLine)
    }
    // A message may carry multiple content blocks; only the first is
    // reported per line to keep sequencing simple for this phase's scope.
    guard let block = envelope.message.content.first else {
      return .unclassifiedContent(rawContentType: nil, sequence: sequence, rawLine: rawLine)
    }
    if block.type == "text", let text = block.text {
      return .message(role: envelope.message.role, text: text, sequence: sequence)
    }
    return .unclassifiedContent(rawContentType: block.type, sequence: sequence, rawLine: rawLine)
  }

  /// Best-effort count of a top-level array field, tolerant of unknown
  /// element shapes.
  private static func extractArrayCount(from data: Data, key: String) -> Int {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let array = object[key] as? [Any]
    else {
      return 0
    }
    return array.count
  }
}
