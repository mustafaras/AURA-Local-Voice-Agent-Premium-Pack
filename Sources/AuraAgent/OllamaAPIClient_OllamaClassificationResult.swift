import AuraCore
import AuraSecurity
import Foundation

/// Decoded, schema-validated result of a classification request.
public struct OllamaClassificationResult: Codable, Sendable, Equatable {
  public let classification: String
}
