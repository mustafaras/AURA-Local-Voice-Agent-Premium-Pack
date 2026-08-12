import Foundation

/// Emitted as a TTS engine streams audio or progress markers.
public struct TTSChunkEvent: EventPayload {
  public static let eventType = "tts.chunk"

  public let promptID: String
  public let chunk: TTSChunk

  public init(promptID: String, chunk: TTSChunk) {
    self.promptID = promptID
    self.chunk = chunk
  }
}
