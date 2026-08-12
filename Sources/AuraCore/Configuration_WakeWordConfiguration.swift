import Foundation

public struct WakeWordConfiguration: Codable, Sendable, Equatable {
  /// Phrase to listen for (used by configurable detectors; may be ignored
  /// by model-based detectors that have a fixed trigger).
  public var phrase: String

  /// Voice-activity energy threshold in dBFS (negative). Values closer to
  /// zero are more sensitive; lower values are less sensitive.
  public var vadEnergyThresholdDB: Double

  /// Number of consecutive silent frames before VAD reports speech end.
  public var vadSilenceFrames: UInt32

  /// Minimum wake-word confidence in [0, 1].
  public var wakeConfidenceThreshold: Double

  /// Minimum time between accepted wake detections (seconds).
  public var wakeDebounceSeconds: Double

  /// Suppress assistant-generated wake phrase and other self-trigger sources.
  public var enableAntiTriggerProtection: Bool

  /// Whether to run optional speaker verification after a wake detection.
  public var speakerVerificationEnabled: Bool

  /// Speaker verification similarity threshold in [0, 1].
  public var speakerVerificationThreshold: Double

  /// Keyboard shortcut that enables privacy mode (e.g. "⇧⌘L"). Empty means
  /// no shortcut is configured and the menu-bar toggle is used instead.
  public var privacyModeKeyboardShortcut: String

  /// When true, listening in privacy mode is only armed by the keyboard
  /// shortcut rather than continuous wake-word detection.
  public var privacyModeRequiresKeyboardShortcut: Bool

  public init(
    phrase: String = "hey aura",
    vadEnergyThresholdDB: Double = -40.0,
    vadSilenceFrames: UInt32 = 20,
    wakeConfidenceThreshold: Double = 0.75,
    wakeDebounceSeconds: Double = 2.0,
    enableAntiTriggerProtection: Bool = true,
    speakerVerificationEnabled: Bool = false,
    speakerVerificationThreshold: Double = 0.80,
    privacyModeKeyboardShortcut: String = "⇧⌘L",
    privacyModeRequiresKeyboardShortcut: Bool = true
  ) {
    self.phrase = phrase
    self.vadEnergyThresholdDB = vadEnergyThresholdDB
    self.vadSilenceFrames = vadSilenceFrames
    self.wakeConfidenceThreshold = wakeConfidenceThreshold
    self.wakeDebounceSeconds = wakeDebounceSeconds
    self.enableAntiTriggerProtection = enableAntiTriggerProtection
    self.speakerVerificationEnabled = speakerVerificationEnabled
    self.speakerVerificationThreshold = speakerVerificationThreshold
    self.privacyModeKeyboardShortcut = privacyModeKeyboardShortcut
    self.privacyModeRequiresKeyboardShortcut = privacyModeRequiresKeyboardShortcut
  }

  public func validate() throws(AuraError) {
    guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("wake phrase must not be empty")
    }
    guard vadEnergyThresholdDB <= 0 else {
      throw AuraError.invalidConfiguration("vadEnergyThresholdDB must be negative or zero")
    }
    guard vadSilenceFrames > 0 else {
      throw AuraError.invalidConfiguration("vadSilenceFrames must be positive")
    }
    guard wakeConfidenceThreshold >= 0, wakeConfidenceThreshold <= 1 else {
      throw AuraError.invalidConfiguration("wakeConfidenceThreshold must be in [0, 1]")
    }
    guard wakeDebounceSeconds >= 0 else {
      throw AuraError.invalidConfiguration("wakeDebounceSeconds must be non-negative")
    }
    guard speakerVerificationThreshold >= 0, speakerVerificationThreshold <= 1 else {
      throw AuraError.invalidConfiguration("speakerVerificationThreshold must be in [0, 1]")
    }
  }
}
