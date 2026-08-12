import Foundation

/// Emitted when the TTS subsystem begins speaking a prompt.
public struct TTSStartedEvent: EventPayload {
  public static let eventType = "tts.started"

  public let engineID: String
  public let promptID: String
  public let text: String

  public init(engineID: String, promptID: String, text: String) {
    self.engineID = engineID
    self.promptID = promptID
    self.text = text
  }
}
