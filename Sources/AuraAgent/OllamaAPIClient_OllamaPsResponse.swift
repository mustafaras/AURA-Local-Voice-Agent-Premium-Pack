import AuraCore
import AuraSecurity
import Foundation

/// `GET /api/ps`'s top-level envelope.
public struct OllamaPsResponse: Codable, Sendable, Equatable {
  public let models: [OllamaPsModel]

  public init(models: [OllamaPsModel]) {
    self.models = models
  }
}
