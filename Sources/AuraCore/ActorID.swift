import Foundation

/// Uniquely identifies the origin of an event or command.
public enum ActorID: String, Codable, Sendable, Equatable, CaseIterable {
  case user
  case system
  case audio
  case policy
  case automation
  case agentCodex
  case agentClaude
  case agentCopilot
  case agentOllama
  case orchestrator
  case task
  case memory
  case context
  case screen
  case computerUse
  case unknown
}

/// Sensitivity classification for an event or piece of data.
public enum SensitivityLevel: String, Codable, Sendable, Equatable, CaseIterable {
  case publicLevel = "public"
  case internalLevel = "internal"
  case sensitive
  case secret
}

/// A typed error domain used across AURA subsystems.
public enum AuraError: Error, Sendable, Equatable {
  case invalidConfiguration(String)
  case serializationError(String)
  case storeError(String)
  case migrationError(String)
  case eventValidationError(String)
  case notImplemented(String)
  case sttEngineError(String)
  case ttsAdapterFailed(String)
  case automationError(String)
  case shellError(String)
  case vscodeError(String)
  case taskNotFound(UUID)
  case taskInvalidState(String)
  case taskQueueFull
  case taskCancelled(UUID)
  case taskExpired(UUID)
  case taskError(String)
  case codexError(String)
  case claudeError(String)
  case copilotError(String)
  case ollamaError(String)
  case orchestrationError(String)
  case memoryError(String)
  case contextError(String)
  case screenCaptureError(String)
  case computerUseError(String)
}

extension AuraError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidConfiguration(let detail):
      return "Invalid configuration: \(detail)"
    case .serializationError(let detail):
      return "Serialization error: \(detail)"
    case .storeError(let detail):
      return "Store error: \(detail)"
    case .migrationError(let detail):
      return "Migration error: \(detail)"
    case .eventValidationError(let detail):
      return "Event validation error: \(detail)"
    case .notImplemented(let detail):
      return "Not implemented: \(detail)"
    case .sttEngineError(let detail):
      return "STT engine error: \(detail)"
    case .ttsAdapterFailed(let detail):
      return "TTS adapter failed: \(detail)"
    case .automationError(let detail):
      return "Automation error: \(detail)"
    case .shellError(let detail):
      return "Shell error: \(detail)"
    case .vscodeError(let detail):
      return "VS Code error: \(detail)"
    case .taskNotFound(let id):
      return "Task not found: \(id.uuidString)"
    case .taskInvalidState(let detail):
      return "Task invalid state: \(detail)"
    case .taskQueueFull:
      return "Task queue is full"
    case .taskCancelled(let id):
      return "Task cancelled: \(id.uuidString)"
    case .taskExpired(let id):
      return "Task expired: \(id.uuidString)"
    case .taskError(let detail):
      return "Task error: \(detail)"
    case .codexError(let detail):
      return "Codex error: \(detail)"
    case .claudeError(let detail):
      return "Claude error: \(detail)"
    case .copilotError(let detail):
      return "Copilot error: \(detail)"
    case .ollamaError(let detail):
      return "Ollama error: \(detail)"
    case .orchestrationError(let detail):
      return "Orchestration error: \(detail)"
    case .memoryError(let detail):
      return "Memory error: \(detail)"
    case .contextError(let detail):
      return "Context error: \(detail)"
    case .screenCaptureError(let detail):
      return "Screen capture error: \(detail)"
    case .computerUseError(let detail):
      return "Computer-use error: \(detail)"
    }
  }
}
