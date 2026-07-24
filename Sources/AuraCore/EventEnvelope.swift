import Foundation

/// A versioned, typed envelope used for every command and event in the system.
///
/// Events are immutable facts. Commands are requests. Both travel through the
/// event bus with identical metadata so causality and audit are reconstructible.
/// The current schema version for all AURA envelopes.
public let auraEnvelopeSchemaVersion = "1.0.0"

public struct EventEnvelope<Payload: EventPayload>: Codable, Sendable, Equatable {
    public let id: UUID
    public let schemaVersion: String
    public let timestamp: Date
    public let correlationID: UUID
    public let causationID: UUID
    public let actor: ActorID
    public let sensitivity: SensitivityLevel
    public let payload: Payload

    public init(
        id: UUID = UUID(),
        schemaVersion: String = auraEnvelopeSchemaVersion,
        timestamp: Date = Date(),
        correlationID: UUID,
        causationID: UUID,
        actor: ActorID,
        sensitivity: SensitivityLevel,
        payload: Payload
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.timestamp = timestamp
        self.correlationID = correlationID
        self.causationID = causationID
        self.actor = actor
        self.sensitivity = sensitivity
        self.payload = payload
    }

    /// Create a child envelope that inherits correlation and causation chain.
    public func child(
        actor: ActorID? = nil,
        sensitivity: SensitivityLevel? = nil,
        payload: Payload
    ) -> EventEnvelope<Payload> {
        EventEnvelope(
            correlationID: self.correlationID,
            causationID: self.id,
            actor: actor ?? self.actor,
            sensitivity: sensitivity ?? self.sensitivity,
            payload: payload
        )
    }

    /// Validate schema compatibility. Returns an error if the version is unsupported.
    public func validateSchema() throws(AuraError) {
        guard schemaVersion == auraEnvelopeSchemaVersion else {
            throw AuraError.eventValidationError(
                "Unsupported schema version \(schemaVersion); expected \(auraEnvelopeSchemaVersion)"
            )
        }
    }
}

/// A protocol marker for events that can be wrapped in a type-erased envelope.
public protocol EventPayload: Codable, Sendable, Equatable {
    static var eventType: String { get }
}

/// A concrete payload used for simple lifecycle events.
public struct LifecycleEvent: EventPayload {
    public static let eventType = "lifecycle"

    public let state: String
    public let reason: String?

    public init(state: String, reason: String? = nil) {
        self.state = state
        self.reason = reason
    }
}
