import CryptoKit
import Foundation

/// Request sent into the policy engine for authorization.
public struct PolicyEvaluationRequest: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let capability: Capability
  public let actor: ActorID
  public let target: PolicyTarget
  public let arguments: [String]
  public let environment: [String: String]
  public let sessionID: UUID
  public let correlationID: UUID
  public let causationID: UUID
  public let turnContext: TurnContext?

  public init(
    id: UUID = UUID(),
    capability: Capability,
    actor: ActorID,
    target: PolicyTarget = .empty,
    arguments: [String] = [],
    environment: [String: String] = [:],
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID,
    turnContext: TurnContext? = nil
  ) {
    self.id = id
    self.capability = capability
    self.actor = actor
    self.target = target
    self.arguments = arguments
    self.environment = environment
    self.sessionID = sessionID
    self.correlationID = correlationID
    self.causationID = causationID
    self.turnContext = turnContext
  }
}
