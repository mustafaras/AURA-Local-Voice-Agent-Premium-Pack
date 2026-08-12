import AuraCore
import AuraSecurity
import Foundation

public struct OllamaNLUResult: Codable, Sendable, Equatable {
  public let dialogueAct: String
  public let language: String
  public let capabilityID: String
  public let confidence: String
  public let ambiguityReason: String

  public enum CodingKeys: String, CodingKey {
    case dialogueAct = "dialogue_act"
    case language
    case capabilityID = "capability_id"
    case confidence
    case ambiguityReason = "ambiguity_reason"
  }
}
