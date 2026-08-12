import Foundation

/// Emitted when the TTS subsystem stops a prompt early (interruption) or
/// finishes normally.
public struct TTSStoppedEvent: EventPayload {
  public static let eventType = "tts.stopped"

  public let promptID: String
  public let reason: TTSStopReason

  public init(promptID: String, reason: TTSStopReason) {
    self.promptID = promptID
    self.reason = reason
  }
}
