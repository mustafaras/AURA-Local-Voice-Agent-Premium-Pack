import Foundation

/// Emitted when a latency-sensitive milestone is measured by the conversation
/// state machine. Both `wakeToAck` and `simpleCommandCompletion` are measured
/// from the accepted wake activation time so the numbers remain comparable.
public struct LatencyMeasuredEvent: EventPayload {
  public static let eventType = "performance.latency.measured"

  public enum Kind: String, Codable, Sendable, Equatable {
    /// Wake-word activation to first response-plan emission (acknowledgement).
    case wakeToAck

    /// Wake-word activation to end of spoken response for a deterministic
    /// command that needs no remote model.
    case simpleCommandCompletion
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
