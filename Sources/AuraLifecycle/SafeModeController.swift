import AuraConfig
import AuraCore
import AuraStore
import Foundation

/// User-controlled safe-mode controller. Safe mode disables non-essential
/// subsystems and records the fact for the next launch. It is a local recovery
/// tool, not an automatic crash response (crash recovery is handled by
/// `LifecycleObserver`).
public actor SafeModeController {
  public static let safeModeRequestedKey = "lifecycle.safeModeRequested"

  private let configurationEngine: ConfigurationEngine?
  private let store: AuraStore?
  private let eventBus: AuraEventBus?
  private let healthRegistry: RuntimeHealthRegistry?

  public init(
    configurationEngine: ConfigurationEngine? = nil,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    healthRegistry: RuntimeHealthRegistry? = nil
  ) {
    self.configurationEngine = configurationEngine
    self.store = store
    self.eventBus = eventBus
    self.healthRegistry = healthRegistry
  }

  /// Whether safe mode has been requested for the next launch.
  public func isSafeModeRequested() async -> Bool {
    guard let engine = configurationEngine else { return false }
    guard case .boolean(let value) = await engine.effectiveValue(for: Self.safeModeRequestedKey)
    else { return false }
    return value
  }

  /// Request or clear safe mode. Returns the new state.
  @discardableResult
  public func setSafeModeRequested(
    _ requested: Bool,
    reason: String,
    actor: ActorID = .user
  ) async throws(AuraError) -> Bool {
    guard let engine = configurationEngine else {
      throw AuraError.lifecycleError("configuration engine not available")
    }
    let result = try await engine.apply(
      ConfigurationPatch(
        layer: actor == .user ? .userSettings : .sessionOverrides,
        values: [Self.safeModeRequestedKey: .boolean(requested)],
        source: "SafeModeController"),
      actor: actor)
    guard result.accepted else {
      throw AuraError.lifecycleError("safe mode preference rejected: \(result.warnings.joined(separator: "; "))")
    }

    if requested {
      await emit(SafeModeEnteredEvent(reason: reason, actor: actor), .internalLevel)
    }
    await healthRegistry?.record(
      componentID: "safe-mode",
      status: requested ? .safeMode : .disabledByConfiguration,
      detail: requested ? "requested: \(reason)" : "cleared")
    return requested
  }



  private func emit<P: EventPayload>(_ payload: P, _ sensitivity: SensitivityLevel) async {
    guard let eventBus = eventBus else { return }
    await eventBus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .lifecycle,
        sensitivity: sensitivity,
        payload: payload))
  }
}
