import AuraCore
import AuraSecurity
import Foundation

/// The error envelope Ollama returns on non-2xx responses, e.g.
/// `{"error":"model 'x' not found"}` with HTTP 404.
public struct OllamaErrorResponse: Codable, Sendable, Equatable {
  public let error: String

  public init(error: String) {
    self.error = error
  }
}
