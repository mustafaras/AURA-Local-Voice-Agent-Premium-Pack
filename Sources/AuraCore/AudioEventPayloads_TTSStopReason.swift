import Foundation

/// Reason a TTS prompt stopped.
public enum TTSStopReason: String, Codable, Sendable, Equatable {
  case completed
  case interrupted
  case error
  case timeout
}
