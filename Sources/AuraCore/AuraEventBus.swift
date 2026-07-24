import Foundation

/// A typed, async event bus with explicit causality and correlation.
///
/// The bus is intentionally minimal in bootstrap. Future phases will add
/// persistence, backpressure, and XPC bridging.
public actor AuraEventBus {
    private var handlers: [String: [@Sendable (Any) async -> Void]] = [:]
    private let logger: AuraLogger

    public init(logger: AuraLogger) {
        self.logger = logger
    }

    /// Subscribe to events of a given payload type.
    public func subscribe<P: EventPayload>(
        _ type: P.Type,
        handler: @escaping @Sendable (EventEnvelope<P>) async -> Void
    ) async {
        let key = P.eventType
        handlers[key, default: []].append { value in
            if let envelope = value as? EventEnvelope<P> {
                await handler(envelope)
            }
        }
        await logger.debug("Subscribed to \(key)")
    }

    /// Emit an envelope to all subscribers.
    public func emit<P: EventPayload>(_ envelope: EventEnvelope<P>) async {
        let key = P.eventType
        try? envelope.validateSchema()
        let subscribers = handlers[key] ?? []
        await logger.debug("Emitting \(key) to \(subscribers.count) subscriber(s)")
        for subscriber in subscribers {
            await subscriber(envelope)
        }
    }
}
