import AuraCore
import Foundation

/// A normalized Copilot event.
///
/// Some cases are produced by parsing a `copilot -p --output-format json`
/// line (`CopilotEventNormalizer.normalize`); others (`runStarted`,
/// `approvalRequested`, `approvalDecision`, `repositoryInstructionsScanned`,
/// `budgetExceeded`) have no Copilot-native wire representation and are
/// synthesized directly by `CopilotAdapter` — "approval need" is the upfront
/// per-run policy confirm cycle, since unattended `copilot -p` requires tool
/// approval to be granted before spawning (`--allow-all-tools` or exhaustive
/// `--allow-tool` grants), not mid-run.
public enum CopilotNormalizedEvent: Sendable, Equatable {
  case runStarted(
    toolProfile: String, workingDirectory: String, model: String?, customInstructionsLoaded: Bool)
  case approvalRequested(
    requestID: UUID, riskTier: PermissionRiskTier, targetSummary: String, expiresAt: Date)
  case approvalDecision(requestID: UUID, allowed: Bool, reason: String?)
  case repositoryInstructionsScanned(
    filesScanned: [String], secretsDetected: Bool, blockedFiles: [String])
  /// A confirmed but not deeply-typed `session.*` informational event
  /// (`mcp_servers_loaded`, `skills_loaded`, `tools_updated`).
  case session(rawType: String, sequence: Int)
  case sessionError(
    errorType: String, errorCode: String?, message: String, statusCode: Int?, sequence: Int)
  /// A confirmed `user.message` event. (`assistant.message` was never
  /// observed — both authorized smoke test invocations hit an account-level
  /// quota error before the model produced any text — so it is not decoded
  /// here; see ADR-013.)
  case message(role: String, content: String, sequence: Int)
  case turnStart(turnID: String?, model: String?, sequence: Int)
  case turnEnd(turnID: String?, sequence: Int)
  case assistantIdle(sequence: Int)
  case modelCallStart(model: String, sequence: Int)
  case modelCallFailure(model: String, statusCode: Int?, errorMessage: String, sequence: Int)
  /// The confirmed final `result` event with `exitCode == 0`.
  case turnCompleted(
    exitCode: Int, sessionDurationMs: Int, premiumRequests: Int, filesModifiedCount: Int,
    linesAdded: Int, linesRemoved: Int)
  /// The confirmed final `result` event with a non-zero `exitCode`. `result`
  /// itself carries no error message field — error detail comes from the
  /// `session.error`/`model.call_failure` events that precede it.
  case turnFailed(message: String?)
  case copilotError(message: String)
  case budgetExceeded(kind: String, limit: Double, observed: Double)
  /// A recognized top-level `type` not covered above.
  case unrecognizedTopLevel(rawType: String, sequence: Int, rawLine: String)
  /// A JSONL line whose top-level `type` was missing or that failed to
  /// decode at all.
  case unrecognized(rawLine: String)
}

/// Parses `copilot -p --output-format json` JSONL lines into
/// `CopilotNormalizedEvent`.
///
/// Shapes below were confirmed by two authorized, real `copilot -p`
/// invocations captured in `Tests/AuraAgentTests/Fixtures/
/// copilot_smoke_quota_error.jsonl` / `copilot_smoke_quota_error2.jsonl` —
/// both hit the account's exhausted monthly Copilot quota before the model
/// produced any text, so a successful `assistant` text-content event was
/// never observed and is not fabricated here (see ADR-013). Every non-`result`
/// event shares `{type, data, id, timestamp, parentId, ephemeral?}`; `result`
/// is flat (`type` plus fields directly, no `data` wrapper, no `id`/`parentId`).
/// Some `data` fields are optional in this decoder even where always present
/// in one fixture, because they were absent in the other (e.g. `model` on
/// `assistant.turn_start`/`turn_end`, and `model.call_start` itself only
/// appeared in one of the two captures) — never assumed universally required.
public enum CopilotEventNormalizer {
  private struct TopLevel: Decodable {
    let type: String
  }

  private struct SessionErrorData: Decodable {
    let errorType: String
    let errorCode: String?
    let message: String
    let statusCode: Int?
  }
  private struct SessionErrorEnvelope: Decodable {
    let data: SessionErrorData
  }

  private struct UserMessageData: Decodable {
    let content: String
  }
  private struct UserMessageEnvelope: Decodable {
    let data: UserMessageData
  }

  private struct TurnData: Decodable {
    let turnId: String?
    let model: String?
  }
  private struct TurnEnvelope: Decodable {
    let data: TurnData
  }

  private struct ModelCallStartData: Decodable {
    let model: String
  }
  private struct ModelCallStartEnvelope: Decodable {
    let data: ModelCallStartData
  }

  private struct ModelCallFailureData: Decodable {
    let model: String
    let statusCode: Int?
    let errorMessage: String
  }
  private struct ModelCallFailureEnvelope: Decodable {
    let data: ModelCallFailureData
  }

  private struct CodeChanges: Decodable {
    let linesAdded: Int
    let linesRemoved: Int
    let filesModified: [String]
  }
  private struct ResultUsage: Decodable {
    let premiumRequests: Int
    let sessionDurationMs: Int
    let codeChanges: CodeChanges
  }
  private struct ResultPayload: Decodable {
    let exitCode: Int
    let usage: ResultUsage
  }

  public static func normalize(line: String, sequence: Int) -> CopilotNormalizedEvent {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
      return .unrecognized(rawLine: trimmed)
    }
    guard let topLevel = try? JSONDecoder().decode(TopLevel.self, from: data) else {
      return .unrecognized(rawLine: trimmed)
    }

    switch topLevel.type {
    case "session.mcp_servers_loaded", "session.skills_loaded", "session.tools_updated":
      return .session(rawType: topLevel.type, sequence: sequence)

    case "session.error":
      guard let envelope = try? JSONDecoder().decode(SessionErrorEnvelope.self, from: data) else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      return .sessionError(
        errorType: envelope.data.errorType, errorCode: envelope.data.errorCode,
        message: envelope.data.message, statusCode: envelope.data.statusCode, sequence: sequence)

    case "user.message":
      guard let envelope = try? JSONDecoder().decode(UserMessageEnvelope.self, from: data) else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      return .message(role: "user", content: envelope.data.content, sequence: sequence)

    case "assistant.turn_start":
      let envelope = try? JSONDecoder().decode(TurnEnvelope.self, from: data)
      return .turnStart(
        turnID: envelope?.data.turnId, model: envelope?.data.model, sequence: sequence)

    case "assistant.turn_end":
      let envelope = try? JSONDecoder().decode(TurnEnvelope.self, from: data)
      return .turnEnd(turnID: envelope?.data.turnId, sequence: sequence)

    case "assistant.idle":
      return .assistantIdle(sequence: sequence)

    case "model.call_start":
      guard let envelope = try? JSONDecoder().decode(ModelCallStartEnvelope.self, from: data)
      else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      return .modelCallStart(model: envelope.data.model, sequence: sequence)

    case "model.call_failure":
      guard let envelope = try? JSONDecoder().decode(ModelCallFailureEnvelope.self, from: data)
      else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      return .modelCallFailure(
        model: envelope.data.model, statusCode: envelope.data.statusCode,
        errorMessage: envelope.data.errorMessage, sequence: sequence)

    case "result":
      guard let result = try? JSONDecoder().decode(ResultPayload.self, from: data) else {
        return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
      }
      if result.exitCode == 0 {
        return .turnCompleted(
          exitCode: result.exitCode, sessionDurationMs: result.usage.sessionDurationMs,
          premiumRequests: result.usage.premiumRequests,
          filesModifiedCount: result.usage.codeChanges.filesModified.count,
          linesAdded: result.usage.codeChanges.linesAdded,
          linesRemoved: result.usage.codeChanges.linesRemoved)
      }
      return .turnFailed(message: nil)

    default:
      return .unrecognizedTopLevel(rawType: topLevel.type, sequence: sequence, rawLine: trimmed)
    }
  }
}
