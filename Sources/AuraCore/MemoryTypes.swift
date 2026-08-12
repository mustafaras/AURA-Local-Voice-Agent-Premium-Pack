import Foundation

// MARK: - Memory class

/// The eight memory classes from `docs/subsystems/21_MEMORY_ENGINE.md`.
public enum MemoryClass: String, Codable, Sendable, Equatable, CaseIterable {
  case ephemeralAudio
  case workingConversation
  case sessionSummary
  case taskState
  case projectFact
  case userPreference
  case proceduralKnowledge
  case auditSecurity
}
