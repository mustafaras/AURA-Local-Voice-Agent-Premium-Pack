import Foundation

/// Emitted when `IntentEngine` (`AuraIntent`) finishes classifying a
/// `TurnCompletedEvent` into a `TypedIntent`.
public struct IntentClassifiedEvent: EventPayload {
  public static let eventType = "intent.classified"

  public let intentID: UUID
  public let turnCorrelationID: UUID
  public let kind: String
  public let semanticCategory: IntentSemanticCategory
  public let confidence: Double
  public let isAmbiguous: Bool
  public let riskTier: PermissionRiskTier

  public init(
    intentID: UUID, turnCorrelationID: UUID, kind: String,
    semanticCategory: IntentSemanticCategory, confidence: Double, isAmbiguous: Bool,
    riskTier: PermissionRiskTier
  ) {
    self.intentID = intentID
    self.turnCorrelationID = turnCorrelationID
    self.kind = kind
    self.semanticCategory = semanticCategory
    self.confidence = confidence
    self.isAmbiguous = isAmbiguous
    self.riskTier = riskTier
  }
}

/// Emitted when `IntentEngine` fails to persist a classified intent to
/// `MemoryEngine`. This is diagnostic only; it does not block routing.
public struct IntentMemoryFailedEvent: EventPayload {
  public static let eventType = "intent.memory.failed"

  public let intentID: UUID
  public let turnCorrelationID: UUID
  public let reason: String

  public init(intentID: UUID, turnCorrelationID: UUID, reason: String) {
    self.intentID = intentID
    self.turnCorrelationID = turnCorrelationID
    self.reason = reason
  }
}

/// Emitted when `ToolRouter` (`AuraIntent`) selects a tool contract for a
/// classified intent, before evaluating policy.
public struct IntentPlanGeneratedEvent: EventPayload {
  public static let eventType = "intent.plan.generated"

  public let intentID: UUID
  public let toolID: String
  public let capabilityIdentifier: String

  public init(intentID: UUID, toolID: String, capabilityIdentifier: String) {
    self.intentID = intentID
    self.toolID = toolID
    self.capabilityIdentifier = capabilityIdentifier
  }
}

/// Emitted whenever `ToolRouter` refuses to execute a classified intent —
/// policy denial, mandatory-confirmation block, declined confirmation, or
/// unresolved ambiguity.
public struct IntentBlockedEvent: EventPayload {
  public static let eventType = "intent.blocked"

  public let intentID: UUID
  public let reason: String

  public init(intentID: UUID, reason: String) {
    self.intentID = intentID
    self.reason = reason
  }
}

/// Emitted immediately before `ToolRouter` invokes a backend subsystem for
/// an authorized intent.
public struct ToolInvokedEvent: EventPayload {
  public static let eventType = "tool.invoked"

  public let intentID: UUID
  public let toolID: String

  public init(intentID: UUID, toolID: String) {
    self.intentID = intentID
    self.toolID = toolID
  }
}

/// Emitted when a tool invocation started by `ToolInvokedEvent` completes,
/// successfully or not. Never carries raw tool output — only a bounded
/// summary, matching the project's "typed events, not raw text" convention.
public struct ToolResultEvent: EventPayload {
  public static let eventType = "tool.result"

  public let intentID: UUID
  public let toolID: String
  public let succeeded: Bool
  public let summary: String

  public init(intentID: UUID, toolID: String, succeeded: Bool, summary: String) {
    self.intentID = intentID
    self.toolID = toolID
    self.succeeded = succeeded
    self.summary = summary
  }
}
