import AuraCore
import AuraSecurity
import Foundation

/// Decoded, schema-validated result of a summarization request.
public struct OllamaSummaryResult: Codable, Sendable, Equatable {
  public let summary: String
}
