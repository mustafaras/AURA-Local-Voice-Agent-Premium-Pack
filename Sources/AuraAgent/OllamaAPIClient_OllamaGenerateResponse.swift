import AuraCore
import AuraSecurity
import Foundation

/// `POST /api/generate` (`stream: false`) response.
public struct OllamaGenerateResponse: Codable, Sendable, Equatable {
  public let model: String
  public let response: String
  public let done: Bool
  public let doneReason: String?
  public let totalDuration: Int?
  public let evalCount: Int?

  public init(
    model: String, response: String, done: Bool, doneReason: String? = nil,
    totalDuration: Int? = nil, evalCount: Int? = nil
  ) {
    self.model = model
    self.response = response
    self.done = done
    self.doneReason = doneReason
    self.totalDuration = totalDuration
    self.evalCount = evalCount
  }
}
