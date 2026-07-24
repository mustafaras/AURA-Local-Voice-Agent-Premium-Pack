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
        }
    }
}
