import Foundation

/// The origin of a user turn. This is metadata, not permission; PolicyEngine
/// remains the only authority for side effects.
public enum TurnActivationSource: String, Codable, Sendable, Equatable {
  case pushToTalk
  case wakeWord
  case text
  case replay
  case system
}

/// Authority provenance carried with a turn. Untrusted content never becomes
/// authority merely because it appears in a local event.
public enum TurnAuthorityProvenance: String, Codable, Sendable, Equatable {
  case userUtterance
  case userConfirmation
  case systemPolicy
  case derived
  case untrustedContent
}

/// Actual backend identities observed while a turn is processed.
public struct TurnBackendIDs: Codable, Sendable, Equatable {
  public let stt: String?
  public let tts: String?
  public let model: String?
  public let tool: String?

  public init(
    stt: String? = nil,
    tts: String? = nil,
    model: String? = nil,
    tool: String? = nil
  ) {
    self.stt = stt
    self.tts = tts
    self.model = model
    self.tool = tool
  }

  public func updating(
    stt: String?? = nil,
    tts: String?? = nil,
    model: String?? = nil,
    tool: String?? = nil
  ) -> TurnBackendIDs {
    TurnBackendIDs(
      stt: stt ?? self.stt,
      tts: tts ?? self.tts,
      model: model ?? self.model,
      tool: tool ?? self.tool
    )
  }

  public var usesMockBackend: Bool {
    [stt, tts, model, tool].compactMap { $0 }.contains { value in
      value.lowercased().contains("mock") || value.lowercased().contains("deterministic")
    }
  }
}

/// Immutable metadata for one complete assistant turn.
///
/// The correlation ID remains stable for the whole turn. Each stage advances
/// the causation ID to the event it just emitted instead of creating a new
/// unrelated trace root.
public struct TurnContext: Codable, Sendable, Equatable, Identifiable {
  public let sessionID: UUID
  public let turnID: UUID
  public let correlationID: UUID
  public let causationID: UUID
  public let activationSource: TurnActivationSource
  public let actor: ActorID
  public let authority: TurnAuthorityProvenance
  public let sensitivity: SensitivityLevel
  public let language: String?
  public let timingOrigin: TimeInterval
  public let backendIDs: TurnBackendIDs
  public let pendingTaskID: UUID?
  public let pendingConfirmationID: UUID?

  public var id: UUID { turnID }

  public init(
    sessionID: UUID,
    turnID: UUID = UUID(),
    correlationID: UUID = UUID(),
    causationID: UUID = UUID(),
    activationSource: TurnActivationSource,
    actor: ActorID,
    authority: TurnAuthorityProvenance,
    sensitivity: SensitivityLevel,
    language: String? = nil,
    timingOrigin: TimeInterval = ProcessInfo.processInfo.systemUptime,
    backendIDs: TurnBackendIDs = TurnBackendIDs(),
    pendingTaskID: UUID? = nil,
    pendingConfirmationID: UUID? = nil
  ) {
    self.sessionID = sessionID
    self.turnID = turnID
    self.correlationID = correlationID
    self.causationID = causationID
    self.activationSource = activationSource
    self.actor = actor
    self.authority = authority
    self.sensitivity = sensitivity
    self.language = language
    self.timingOrigin = timingOrigin
    self.backendIDs = backendIDs
    self.pendingTaskID = pendingTaskID
    self.pendingConfirmationID = pendingConfirmationID
  }

  public func advancing(
    causationID: UUID,
    backendIDs: TurnBackendIDs? = nil,
    pendingTaskID: UUID?? = nil,
    pendingConfirmationID: UUID?? = nil
  ) -> TurnContext {
    TurnContext(
      sessionID: sessionID,
      turnID: turnID,
      correlationID: correlationID,
      causationID: causationID,
      activationSource: activationSource,
      actor: actor,
      authority: authority,
      sensitivity: sensitivity,
      language: language,
      timingOrigin: timingOrigin,
      backendIDs: backendIDs ?? self.backendIDs,
      pendingTaskID: pendingTaskID ?? self.pendingTaskID,
      pendingConfirmationID: pendingConfirmationID ?? self.pendingConfirmationID
    )
  }

  public func withBackendIDs(_ backendIDs: TurnBackendIDs) -> TurnContext {
    advancing(causationID: causationID, backendIDs: backendIDs)
  }

  public func envelope<Payload: EventPayload>(
    actor: ActorID? = nil,
    sensitivity: SensitivityLevel? = nil,
    payload: Payload
  ) -> EventEnvelope<Payload> {
    EventEnvelope(
      correlationID: correlationID,
      causationID: causationID,
      actor: actor ?? self.actor,
      sensitivity: sensitivity ?? self.sensitivity,
      payload: payload
    )
  }
}
