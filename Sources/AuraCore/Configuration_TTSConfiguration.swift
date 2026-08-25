import Foundation

/// Configuration for text-to-speech adapters and turn-taking policy.
public struct TTSConfiguration: Codable, Sendable, Equatable {
  /// Priority-ordered list of TTS adapter identifiers.
  public var adapterChain: TTSAdapterChain

  /// Default BCP-47 locale for synthesized speech.
  public var defaultLocale: String

  /// Default speech rate. Must be positive.
  public var defaultRate: Double

  /// Explicit local system voice used when the neural adapter is unavailable.
  /// Empty means the system fallback auto-selects the best installed voice for
  /// the locale by platform quality; no specific system voice is favored.
  public var preferredSystemVoiceIdentifier: String

  /// Whether user speech detected during assistant speech stops the assistant.
  public var enableBargeIn: Bool

  /// Whether assistant output should suppress wake-word detection.
  public var enableAntiTrigger: Bool

  public init(
    adapterChain: TTSAdapterChain = TTSAdapterChain(),
    defaultLocale: String = "tr-TR",
    defaultRate: Double = 0.92,
    preferredSystemVoiceIdentifier: String = "",
    enableBargeIn: Bool = true,
    enableAntiTrigger: Bool = true
  ) {
    self.adapterChain = adapterChain
    self.defaultLocale = defaultLocale
    self.defaultRate = defaultRate
    self.preferredSystemVoiceIdentifier = preferredSystemVoiceIdentifier
    self.enableBargeIn = enableBargeIn
    self.enableAntiTrigger = enableAntiTrigger
  }

  public func validate() throws(AuraError) {
    try adapterChain.validate()
    guard !defaultLocale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("tts defaultLocale must not be empty")
    }
    guard defaultRate > 0 else {
      throw AuraError.invalidConfiguration("tts defaultRate must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    adapterChain =
      try container.decodeIfPresent(TTSAdapterChain.self, forKey: .adapterChain)
      ?? TTSAdapterChain()
    defaultLocale = try container.decodeIfPresent(String.self, forKey: .defaultLocale) ?? "tr-TR"
    defaultRate = try container.decodeIfPresent(Double.self, forKey: .defaultRate) ?? 0.92
    preferredSystemVoiceIdentifier =
      try container.decodeIfPresent(String.self, forKey: .preferredSystemVoiceIdentifier)
      ?? ""
    enableBargeIn = try container.decodeIfPresent(Bool.self, forKey: .enableBargeIn) ?? true
    enableAntiTrigger = try container.decodeIfPresent(Bool.self, forKey: .enableAntiTrigger) ?? true
  }
}
