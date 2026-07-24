import Foundation
import os.log

/// Privacy-aware structured logging interface.
///
/// Logs never include secret payloads or unredacted screenshots by default.
/// Structured metadata (correlation ID, actor, level) is attached to every entry.
public struct AuraLogEntry: Sendable, Equatable {
    public let timestamp: Date
    public let level: LogLevel
    public let subsystem: String
    public let category: String
    public let message: String
    public let correlationID: UUID?
    public let actor: ActorID?

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        subsystem: String,
        category: String,
        message: String,
        correlationID: UUID? = nil,
        actor: ActorID? = nil
    ) {
        self.timestamp = timestamp
        self.level = level
        self.subsystem = subsystem
        self.category = category
        self.message = message
        self.correlationID = correlationID
        self.actor = actor
    }
}

public enum LogLevel: String, Sendable, Codable, Equatable, CaseIterable {
    case trace
    case debug
    case info
    case warning
    case error
    case critical
}

/// A logger that respects a minimum level and routes to os.Logger.
public actor AuraLogger {
    public let subsystem: String
    public let category: String
    public let minimumLevel: LogLevel
    private let osLog: Logger

    public init(subsystem: String, category: String, minimumLevel: LogLevel = .info) {
        self.subsystem = subsystem
        self.category = category
        self.minimumLevel = minimumLevel
        self.osLog = Logger(subsystem: subsystem, category: category)
    }

    public func log(
        level: LogLevel,
        _ message: String,
        correlationID: UUID? = nil,
        actor: ActorID? = nil
    ) {
        guard level.rawValuePriority >= minimumLevel.rawValuePriority else { return }

        let entry = AuraLogEntry(
            level: level,
            subsystem: subsystem,
            category: category,
            message: message,
            correlationID: correlationID,
            actor: actor
        )

        let prefix = [correlationID?.uuidString, actor?.rawValue]
            .compactMap { $0 }
            .joined(separator: " ")

        let fullMessage = prefix.isEmpty ? message : "[\(prefix)] \(message)"

        switch level {
        case .trace, .debug:
            osLog.debug("\(fullMessage, privacy: .public)")
        case .info:
            osLog.info("\(fullMessage, privacy: .public)")
        case .warning:
            osLog.warning("\(fullMessage, privacy: .public)")
        case .error:
            osLog.error("\(fullMessage, privacy: .public)")
        case .critical:
            osLog.critical("\(fullMessage, privacy: .public)")
        }

        // In bootstrap we simply emit to os.Logger; future phases may add file/ledger routing.
        _ = entry
    }

    public func trace(_ message: String, correlationID: UUID? = nil, actor: ActorID? = nil) async {
        log(level: .trace, message, correlationID: correlationID, actor: actor)
    }
    public func debug(_ message: String, correlationID: UUID? = nil, actor: ActorID? = nil) async {
        log(level: .debug, message, correlationID: correlationID, actor: actor)
    }
    public func info(_ message: String, correlationID: UUID? = nil, actor: ActorID? = nil) async {
        log(level: .info, message, correlationID: correlationID, actor: actor)
    }
    public func warning(_ message: String, correlationID: UUID? = nil, actor: ActorID? = nil) async {
        log(level: .warning, message, correlationID: correlationID, actor: actor)
    }
    public func error(_ message: String, correlationID: UUID? = nil, actor: ActorID? = nil) async {
        log(level: .error, message, correlationID: correlationID, actor: actor)
    }
    public func critical(_ message: String, correlationID: UUID? = nil, actor: ActorID? = nil) async {
        log(level: .critical, message, correlationID: correlationID, actor: actor)
    }
}

extension LogLevel {
    fileprivate var rawValuePriority: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info: return 2
        case .warning: return 3
        case .error: return 4
        case .critical: return 5
        }
    }
}
