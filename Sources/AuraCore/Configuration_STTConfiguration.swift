import Foundation

/// Configuration for wake-word detection, voice activity detection, speaker
/// verification, and privacy-mode activation.
public struct STTConfiguration: Codable, Sendable, Equatable {
  /// Engine adapter to load (e.g. "native-speech", "mock-stt").
  public var engineID: String

  /// Primary locale for transcription, in BCP-47 form.
  public var locale: String

  /// Secondary local locale used only if the primary Speech adapter cannot
  /// start. This is not a claim of simultaneous bilingual recognition.
  public var fallbackLocale: String

  /// Number of frames ingested before a partial result is emitted.
  public var partialBoundaryFrames: UInt32

  /// Additional frames required before a partial is promoted to stable.
  public var stabilizationDelayFrames: UInt32

  /// Whether to enable user vocabulary hints when supported by the engine.
  public var enableCustomVocabulary: Bool

  public init(
    engineID: String = "native-speech",
    locale: String = "tr-TR",
    fallbackLocale: String = "en-US",
    partialBoundaryFrames: UInt32 = 3,
    stabilizationDelayFrames: UInt32 = 2,
    enableCustomVocabulary: Bool = true
  ) {
    self.engineID = engineID
    self.locale = locale
    self.fallbackLocale = fallbackLocale
    self.partialBoundaryFrames = partialBoundaryFrames
    self.stabilizationDelayFrames = stabilizationDelayFrames
    self.enableCustomVocabulary = enableCustomVocabulary
  }

  public func validate() throws(AuraError) {
    guard !engineID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("stt engineID must not be empty")
    }
    guard !locale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("stt locale must not be empty")
    }
    guard !fallbackLocale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("stt fallbackLocale must not be empty")
    }
    guard partialBoundaryFrames > 0 else {
      throw AuraError.invalidConfiguration("stt partialBoundaryFrames must be positive")
    }
    guard stabilizationDelayFrames > 0 else {
      throw AuraError.invalidConfiguration("stt stabilizationDelayFrames must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    engineID = try container.decodeIfPresent(String.self, forKey: .engineID) ?? "native-speech"
    locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "tr-TR"
    fallbackLocale =
      try container.decodeIfPresent(String.self, forKey: .fallbackLocale) ?? "en-US"
    partialBoundaryFrames =
      try container.decodeIfPresent(UInt32.self, forKey: .partialBoundaryFrames) ?? 3
    stabilizationDelayFrames =
      try container.decodeIfPresent(UInt32.self, forKey: .stabilizationDelayFrames) ?? 2
    enableCustomVocabulary =
      try container.decodeIfPresent(Bool.self, forKey: .enableCustomVocabulary) ?? true
  }
}
