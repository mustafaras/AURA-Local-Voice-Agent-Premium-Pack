import Foundation

/// Emitted when a latency-sensitive milestone is measured by the conversation
/// state machine. Both `wakeToAck` and `simpleCommandCompletion` are measured
/// from the accepted wake activation time so the numbers remain comparable.
public struct LatencyMeasuredEvent: EventPayload {
  public static let eventType = "performance.latency.measured"

  public enum Kind: String, Codable, Sendable, Equatable, CaseIterable {
    /// Wake-word activation to first response-plan emission (acknowledgement).
    case wakeToAck

    /// Wake-word activation to end of spoken response for a deterministic
    /// command that needs no remote model.
    case simpleCommandCompletion

    /// Push-to-talk **button press** to the moment the UI acknowledges that it
    /// is listening. This is the R12 `ptt_ack` SLO
    /// (`push_to_talk_acknowledgement_ms`).
    ///
    /// Deliberately distinct from `wakeToAck`, which is measured to the first
    /// *response plan* and therefore includes NLU, policy evaluation and the
    /// model round trip. Reporting `wakeToAck` as `ptt_ack` would overstate the
    /// acknowledgement by whole seconds; they are different metrics.
    case pushToTalkAck

    /// STT activation to the first partial transcript. This is the R12
    /// `stt_partial` SLO (`first_stt_partial_ms`).
    case sttFirstPartial
  }

  public let kind: Kind
  public let latencySeconds: Double
  public let budgetSeconds: Double
  public let isMockEngine: Bool
  public let measuredAt: Date
  public let turnID: UUID?
  public let sessionID: UUID?
  public let backendIDs: TurnBackendIDs?

  public init(
    kind: Kind,
    latencySeconds: Double,
    budgetSeconds: Double,
    isMockEngine: Bool? = nil,
    turnContext: TurnContext? = nil,
    measuredAt: Date = Date()
  ) {
    self.kind = kind
    self.latencySeconds = latencySeconds
    self.budgetSeconds = budgetSeconds
    self.isMockEngine = isMockEngine ?? turnContext?.backendIDs.usesMockBackend ?? false
    self.measuredAt = measuredAt
    self.turnID = turnContext?.turnID
    self.sessionID = turnContext?.sessionID
    self.backendIDs = turnContext?.backendIDs
  }
}
