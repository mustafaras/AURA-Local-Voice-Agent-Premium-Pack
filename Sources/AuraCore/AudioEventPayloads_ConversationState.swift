import Foundation

/// Discrete conversation states.
public enum ConversationState: String, Codable, Sendable, Equatable {
  case idle
  case listening
  case thinking
  case speaking
  case interrupted
  case timeout
  case error
}
