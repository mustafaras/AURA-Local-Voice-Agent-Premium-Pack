import Foundation

/// Honest runtime states exposed to the UI and orchestration layer.
public enum RuntimeHealthStatus: String, Codable, Sendable, Equatable, CaseIterable {
  case ready
  case degraded
  case disabledByConfiguration
  case permissionBlocked
  case dependencyMissing
  case configurationInvalid
  case loading
  case circuitOpen
  case unsupported
  case failed
  case recovering
  case requiresUserAction
  case safeMode
}

/// A bounded, inspectable health record for one constructed subsystem.
public struct RuntimeHealth: Codable, Sendable, Equatable, Identifiable {
  public let componentID: String
  public let status: RuntimeHealthStatus
  public let detail: String
  public let observedAt: Date

  public var id: String { componentID }

  public init(
    componentID: String,
    status: RuntimeHealthStatus,
    detail: String,
    observedAt: Date = Date()
  ) {
    self.componentID = componentID
    self.status = status
    self.detail = detail
    self.observedAt = observedAt
  }
}

/// Emitted whenever a registered subsystem changes health state.
public struct RuntimeHealthChangedEvent: EventPayload {
  public static let eventType = "runtime.health.changed"

  public let health: RuntimeHealth

  public init(health: RuntimeHealth) {
    self.health = health
  }
}

/// Actor-isolated registry for truthful subsystem health.
public actor RuntimeHealthRegistry {
  private var entries: [String: RuntimeHealth] = [:]
  private let now: @Sendable () -> Date
  private let eventBus: AuraEventBus?

  public init(
    now: @escaping @Sendable () -> Date = Date.init,
    eventBus: AuraEventBus? = nil
  ) {
    self.now = now
    self.eventBus = eventBus
  }

  public func record(
    componentID: String,
    status: RuntimeHealthStatus,
    detail: String
  ) async {
    let health = RuntimeHealth(
      componentID: componentID,
      status: status,
      detail: detail,
      observedAt: now())
    entries[componentID] = health
    if let eventBus {
      await eventBus.emit(
        EventEnvelope(
          correlationID: UUID(),
          causationID: UUID(),
          actor: .system,
          sensitivity: .internalLevel,
          payload: RuntimeHealthChangedEvent(health: health)))
    }
  }

  public func recordReady(_ componentID: String, detail: String = "ready") async {
    await record(componentID: componentID, status: .ready, detail: detail)
  }

  public func recordFailure(_ componentID: String, detail: String) async {
    await record(componentID: componentID, status: .failed, detail: detail)
  }

  public func health(for componentID: String) -> RuntimeHealth? {
    entries[componentID]
  }

  public func snapshot() -> [RuntimeHealth] {
    entries.values.sorted { $0.componentID < $1.componentID }
  }
}
