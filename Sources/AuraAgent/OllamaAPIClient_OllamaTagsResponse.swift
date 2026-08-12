import AuraCore
import AuraSecurity
import Foundation

/// `GET /api/tags`'s top-level envelope.
public struct OllamaTagsResponse: Codable, Sendable, Equatable {
  public let models: [OllamaTagsModel]

  public init(models: [OllamaTagsModel]) {
    self.models = models
  }
}
