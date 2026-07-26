import Foundation

// MARK: - Computer-use control loop event payloads
//
// Every payload here is redaction-safe by construction: none carries raw
// screen pixels, raw model text, typed text content, or accessibility
// element values — only structured identifiers, counts, hashes, and closed
// enum cases, matching the precedent set by `ScreenContextEventPayloads`.

/// Emitted once when a control loop session begins.
public struct ComputerUseLoopStartedEvent: EventPayload {
  public static let eventType = "computerUse.loop.started"

  public let runID: UUID
  public let windowID: Int
  public let appBundleIdentifier: String
  /// Free-text objective, carried for audit only — never re-parsed or
  /// executed by the loop itself.
  public let objective: String

  public init(runID: UUID, windowID: Int, appBundleIdentifier: String, objective: String) {
    self.runID = runID
    self.windowID = windowID
    self.appBundleIdentifier = appBundleIdentifier
    self.objective = objective
  }
}

/// Emitted after each Observe phase.
public struct ComputerUseObservationEvent: EventPayload {
  public static let eventType = "computerUse.loop.observation"

  public let runID: UUID
  public let iteration: Int
  public let observationID: UUID
  public let contentHash: String

  public init(runID: UUID, iteration: Int, observationID: UUID, contentHash: String) {
    self.runID = runID
    self.iteration = iteration
    self.observationID = observationID
    self.contentHash = contentHash
  }
}

/// Emitted after each Plan phase. Carries only counts and closed enum
/// cases — never step rationale or anchor text.
public struct ComputerUsePlanGeneratedEvent: EventPayload {
  public static let eventType = "computerUse.loop.planGenerated"

  public let runID: UUID
  public let iteration: Int
  public let stepCount: Int
  public let intents: [ComputerUseSemanticIntent]

  public init(runID: UUID, iteration: Int, stepCount: Int, intents: [ComputerUseSemanticIntent]) {
    self.runID = runID
    self.iteration = iteration
    self.stepCount = stepCount
    self.intents = intents
  }
}

/// Emitted when a proposed plan is rejected outright (too many steps, an
/// invalid anchor) rather than silently truncated or coerced.
public struct ComputerUseInvalidPlanEvent: EventPayload {
  public static let eventType = "computerUse.loop.invalidPlan"

  public let runID: UUID
  public let iteration: Int
  public let reason: String

  public init(runID: UUID, iteration: Int, reason: String) {
    self.runID = runID
    self.iteration = iteration
    self.reason = reason
  }
}

/// Emitted for every step execution attempt, successful or not.
public struct ComputerUseStepEvent: EventPayload {
  public static let eventType = "computerUse.loop.step"

  public let runID: UUID
  public let iteration: Int
  public let stepID: UUID
  public let semanticIntent: ComputerUseSemanticIntent
  public let usedAccessibilityAnchor: Bool
  public let executed: Bool
  public let blockReason: ComputerUseStepBlockReason?

  public init(
    runID: UUID,
    iteration: Int,
    stepID: UUID,
    semanticIntent: ComputerUseSemanticIntent,
    usedAccessibilityAnchor: Bool,
    executed: Bool,
    blockReason: ComputerUseStepBlockReason?
  ) {
    self.runID = runID
    self.iteration = iteration
    self.stepID = stepID
    self.semanticIntent = semanticIntent
    self.usedAccessibilityAnchor = usedAccessibilityAnchor
    self.executed = executed
    self.blockReason = blockReason
  }
}

/// Emitted when a mandatory-confirmation intent reached a bare `.allow`
/// decision and was blocked unconditionally regardless of grant
/// configuration.
public struct ComputerUseMandatoryConfirmationBlockedEvent: EventPayload {
  public static let eventType = "computerUse.loop.mandatoryConfirmationBlocked"

  public let runID: UUID
  public let iteration: Int
  public let stepID: UUID
  public let semanticIntent: ComputerUseSemanticIntent

  public init(runID: UUID, iteration: Int, stepID: UUID, semanticIntent: ComputerUseSemanticIntent)
  {
    self.runID = runID
    self.iteration = iteration
    self.stepID = stepID
    self.semanticIntent = semanticIntent
  }
}

/// Emitted after each Verify phase.
public struct ComputerUseVerifyEvent: EventPayload {
  public static let eventType = "computerUse.loop.verify"

  public let runID: UUID
  public let iteration: Int
  public let progressed: Bool
  public let consecutiveNoProgressCount: Int

  public init(runID: UUID, iteration: Int, progressed: Bool, consecutiveNoProgressCount: Int) {
    self.runID = runID
    self.iteration = iteration
    self.progressed = progressed
    self.consecutiveNoProgressCount = consecutiveNoProgressCount
  }
}

/// Emitted when an unexpected modal or security dialog halts the loop.
public struct ComputerUseModalDialogDetectedEvent: EventPayload {
  public static let eventType = "computerUse.loop.modalDialogDetected"

  public let runID: UUID
  public let iteration: Int
  public let dialogBundleIdentifier: String?

  public init(runID: UUID, iteration: Int, dialogBundleIdentifier: String?) {
    self.runID = runID
    self.iteration = iteration
    self.dialogBundleIdentifier = dialogBundleIdentifier
  }
}

/// Emitted when the observed application/window identity no longer matches
/// the session's approved target.
public struct ComputerUseIdentityChangedEvent: EventPayload {
  public static let eventType = "computerUse.loop.identityChanged"

  public let runID: UUID
  public let iteration: Int
  public let expectedBundleIdentifier: String
  public let observedBundleIdentifier: String?

  public init(
    runID: UUID, iteration: Int, expectedBundleIdentifier: String,
    observedBundleIdentifier: String?
  ) {
    self.runID = runID
    self.iteration = iteration
    self.expectedBundleIdentifier = expectedBundleIdentifier
    self.observedBundleIdentifier = observedBundleIdentifier
  }
}

/// Emitted once when a control loop session ends, for any reason.
public struct ComputerUseLoopCompletedEvent: EventPayload {
  public static let eventType = "computerUse.loop.completed"

  public let runID: UUID
  public let outcomeDescription: String
  public let iterations: Int

  public init(runID: UUID, outcomeDescription: String, iterations: Int) {
    self.runID = runID
    self.outcomeDescription = outcomeDescription
    self.iterations = iterations
  }
}

// MARK: - Emergency stop events

/// Emitted whenever emergency stop is triggered, from any of the three
/// equally authoritative channels.
public struct EmergencyStopTriggeredEvent: EventPayload {
  public static let eventType = "computerUse.emergencyStop.triggered"

  public let source: EmergencyStopSource
  public let reason: String

  public init(source: EmergencyStopSource, reason: String) {
    self.source = source
    self.reason = reason
  }
}

/// Emitted when emergency stop is explicitly reset, re-arming generated
/// input. Never happens automatically.
public struct EmergencyStopResetEvent: EventPayload {
  public static let eventType = "computerUse.emergencyStop.reset"

  public let actor: ActorID

  public init(actor: ActorID) {
    self.actor = actor
  }
}
