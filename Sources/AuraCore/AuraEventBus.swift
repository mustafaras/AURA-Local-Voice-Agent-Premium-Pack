import Foundation

/// A typed, async event bus with explicit causality and correlation.
///
/// The bus is intentionally minimal in bootstrap. Future phases will add
/// persistence, backpressure, and XPC bridging.
public actor AuraEventBus {
  private var handlers: [String: [@Sendable (Any) async -> Void]] = [:]
  private let logger: AuraLogger

  /// Shared event bus used by framework targets. Production code passes a
  /// configured logger; tests can inject an isolated bus via `init()`.
  public static let shared: AuraEventBus = {
    AuraEventBus(logger: AuraLogger(subsystem: "AuraCore", category: "eventBus"))
  }()

  public init(logger: AuraLogger) {
    self.logger = logger
  }

  /// Internal initializer for test event capture.
  internal init() {
    self.logger = AuraLogger(subsystem: "AuraCore", category: "testBus")
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
    await emitInternal(envelope)
  }

  internal func emitInternal<P: EventPayload>(_ envelope: EventEnvelope<P>) async {
    let key = P.eventType
    try? envelope.validateSchema()
    let subscribers = handlers[key] ?? []
    await logger.debug("Emitting \(key) to \(subscribers.count) subscriber(s)")
    for subscriber in subscribers {
      await subscriber(envelope)
    }
  }
}
