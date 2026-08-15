import Foundation

/// A typed, async event bus with explicit causality and correlation.
///
/// The bus keeps delivery in memory and can optionally persist only the
/// privacy-safe trace projection. Event payloads are never persisted here.
public actor AuraEventBus {
  private var handlers: [String: [@Sendable (Any) async -> Void]] = [:]
  private let logger: AuraLogger
  private let tracePersistence: (any AuraTracePersistence)?

  /// Shared event bus used by framework targets. Production code passes a
  /// configured logger; tests can inject an isolated bus via `init()`.
  public static let shared: AuraEventBus = {
    AuraEventBus(logger: AuraLogger(subsystem: "AuraCore", category: "eventBus"))
  }()

  public init(logger: AuraLogger, tracePersistence: (any AuraTracePersistence)? = nil) {
    self.logger = logger
    self.tracePersistence = tracePersistence
  }

  /// Internal initializer for test event capture.
  internal init() {
    self.logger = AuraLogger(subsystem: "AuraCore", category: "testBus")
    self.tracePersistence = nil
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

  /// Persist an explicitly redacted trace projection. Persistence failures
  /// are surfaced through diagnostics but never authorize or replay an action.
  public func recordTrace(_ record: RedactedTraceRecord) async {
    guard let tracePersistence else { return }
    do {
      try await tracePersistence.appendTrace(record)
    } catch {
      await logger.warning(
        "Trace persistence failed [phase=\(record.phase), eventType=\(record.eventType)]",
        correlationID: record.correlationID,
        actor: .system)
    }
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
