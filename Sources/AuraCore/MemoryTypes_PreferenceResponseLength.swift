import Foundation

public enum PreferenceResponseLength: String, Codable, Sendable, Equatable, CaseIterable {
  case concise
  case balanced
  case detailed
}
