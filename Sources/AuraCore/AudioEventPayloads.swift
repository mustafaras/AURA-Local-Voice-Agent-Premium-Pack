import Foundation

// MARK: - STT shared result type

/// A single alternative transcript with its confidence.
/// Lives in AuraCore so that cross-target events can carry alternatives
/// without creating an import cycle with AuraSTT.
public struct STTAlternative: Codable, Sendable, Equatable {
  public let text: String
  public let confidence: Double

  public init(text: String, confidence: Double) {
    self.text = text
    self.confidence = confidence
  }
}
