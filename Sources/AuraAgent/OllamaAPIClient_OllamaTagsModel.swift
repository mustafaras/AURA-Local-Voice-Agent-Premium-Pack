import AuraCore
import AuraSecurity
import Foundation

/// One entry of `GET /api/tags`'s `models` array.
public struct OllamaTagsModel: Codable, Sendable, Equatable {
  public let name: String
  public let remoteHost: String?
  public let size: UInt64
  public let details: Details
  public let capabilities: [String]

  public init(
    name: String, remoteHost: String? = nil, size: UInt64, details: Details,
    capabilities: [String]
  ) {
    self.name = name
    self.remoteHost = remoteHost
    self.size = size
    self.details = details
    self.capabilities = capabilities
  }

  public struct Details: Codable, Sendable, Equatable {
    public let family: String?
    public let parameterSize: String?
    public let quantizationLevel: String?
    /// Only reliably present for `:cloud` models in real observations; local
    /// GGUF entries (e.g. `gemma4:latest`) omitted it entirely. Treated as
    /// best-effort, never required.
    public let contextLength: Int?

    public init(
      family: String? = nil, parameterSize: String? = nil, quantizationLevel: String? = nil,
      contextLength: Int? = nil
    ) {
      self.family = family
      self.parameterSize = parameterSize
      self.quantizationLevel = quantizationLevel
      self.contextLength = contextLength
    }
  }
}
