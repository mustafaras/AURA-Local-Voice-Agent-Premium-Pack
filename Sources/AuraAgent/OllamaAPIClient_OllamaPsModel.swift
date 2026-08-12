import AuraCore
import AuraSecurity
import Foundation

/// One entry of `GET /api/ps`'s `models` array — currently resident models.
public struct OllamaPsModel: Codable, Sendable, Equatable {
  public let name: String
  public let size: UInt64
  public let sizeVram: UInt64
  public let expiresAt: String
  public let contextLength: Int?

  public init(
    name: String, size: UInt64, sizeVram: UInt64, expiresAt: String, contextLength: Int? = nil
  ) {
    self.name = name
    self.size = size
    self.sizeVram = sizeVram
    self.expiresAt = expiresAt
    self.contextLength = contextLength
  }
}
