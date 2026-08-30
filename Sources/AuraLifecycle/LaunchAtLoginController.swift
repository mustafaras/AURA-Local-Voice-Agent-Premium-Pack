import AuraConfig
import AuraCore
import AuraStore
import Foundation

/// User-controlled launch-at-login with persistence, health reporting, and
/// event emission. All real ServiceManagement work is delegated to an
/// injected `LaunchAtLoginService`; tests inject the in-memory stub.
public actor LaunchAtLoginController {
  public static let userPreferenceKey = "lifecycle.launchAtLoginEnabled"

  private let service: any LaunchAtLoginService
  private let configurationEngine: ConfigurationEngine?
  private let store: AuraStore?
  private let eventBus: AuraEventBus?
  private let healthRegistry: RuntimeHealthRegistry?
  private let logger: AuraLogger?
  private let now: @Sendable () -> Date

  public init(
    service: any LaunchAtLoginService,
    configurationEngine: ConfigurationEngine? = nil,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    healthRegistry: RuntimeHealthRegistry? = nil,
    logger: AuraLogger? = nil,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.service = service
    self.configurationEngine = configurationEngine
    self.store = store
    self.eventBus = eventBus
    self.healthRegistry = healthRegistry
    self.logger = logger
    self.now = now
  }

  /// Current ServiceManagement registration status.
  public func serviceStatus() -> LaunchAtLoginStatus {
    LaunchAtLoginStatus(rawValue: service.statusRawValue) ?? .unknown
  }

  /// User preference as stored in configuration. Defaults to false.
  public func userPreferenceEnabled() async -> Bool {
    guard let engine = configurationEngine else { return false }
    guard case .boolean(let value) = await engine.effectiveValue(for: Self.userPreferenceKey)
    else { return false }
    return value
  }

  /// Persist the user's preference and, if it differs from the service state,
  /// attempt to enable or disable the login item. Returns the resulting state.
  @discardableResult
  public func setEnabled(_ enabled: Bool, actor: ActorID = .user) async throws(AuraError)
    -> LaunchAtLoginResult
  {
    await emit(
      LaunchAtLoginRequestedEvent(enabled: enabled, actor: actor),
      sensitivity: .internalLevel)

    let currentStatus = serviceStatus()
    let stored = await userPreferenceEnabled()

    if enabled == stored && (currentStatus == .enabled) == enabled {
      let unchanged = LaunchAtLoginResult(
        enabled: enabled,
        serviceStatus: currentStatus,
        changed: false,
        detail: "already in requested state")
      await recordHealth(enabled: enabled, status: currentStatus, detail: unchanged.detail)
      return unchanged
    }

    try await persistPreference(enabled, actor: actor)

    do {
      if enabled {
        if currentStatus != .enabled {
          try service.register()
        }
      } else {
        if currentStatus == .enabled {
          try service.unregister()
        }
      }
    } catch {
      await logger?.error(
        "launch-at-login service mutation failed: \(error.localizedDescription)",
        actor: .lifecycle)
      throw AuraError.lifecycleError(
        "launch-at-login service mutation failed: \(error.localizedDescription)")
    }

    let newStatus = serviceStatus()
    let changed = (newStatus == .enabled) == enabled
    let detail = changed
      ? "preference and service updated"
      : "preference updated but service status is \(newStatus.rawValue)"
    let result = LaunchAtLoginResult(
      enabled: enabled,
      serviceStatus: newStatus,
      changed: changed,
      detail: detail)

    await emit(
      LaunchAtLoginChangedEvent(
        enabled: enabled,
        statusRawValue: newStatus.rawValue,
        actor: actor),
      sensitivity: .internalLevel)
    await recordHealth(enabled: enabled, status: newStatus, detail: detail)
    return result
  }

  /// Reconcile preference with service state on launch; useful for crash/sleep
  /// recovery when the system may have changed the underlying registration.
  public func reconcile() async throws(AuraError) {
    let preference = await userPreferenceEnabled()
    let status = serviceStatus()
    switch (preference, status) {
    case (true, .enabled), (false, .notRegistered), (false, .notFound):
      await recordHealth(
        enabled: preference,
        status: status,
        detail: "preference matches service status")
    case (true, _):
      _ = try await setEnabled(true, actor: .system)
    case (false, _):
      _ = try await setEnabled(false, actor: .system)
    }
  }

  private func persistPreference(_ enabled: Bool, actor: ActorID) async throws(AuraError) {
    guard let engine = configurationEngine else {
      throw AuraError.lifecycleError("configuration engine not available")
    }
    let result = try await engine.apply(
      ConfigurationPatch(
        layer: actor == .user ? .userSettings : .sessionOverrides,
        values: [Self.userPreferenceKey: .boolean(enabled)],
        source: "LaunchAtLoginController"),
      actor: actor)
    guard result.accepted else {
      throw AuraError.lifecycleError("preference rejected: \(result.warnings.joined(separator: "; "))")
    }
  }

  private func recordHealth(enabled: Bool, status: LaunchAtLoginStatus, detail: String) async {
    let healthStatus: RuntimeHealthStatus
    switch status {
    case .enabled:
      healthStatus = enabled ? .ready : .disabledByConfiguration
    case .notRegistered, .notFound:
      healthStatus = enabled ? .requiresUserAction : .disabledByConfiguration
    case .unknown:
      healthStatus = .unsupported
    }
    await healthRegistry?.record(
      componentID: "launch-at-login",
      status: healthStatus,
      detail: "enabled=\(enabled), status=\(status.rawValue), \(detail)")
  }

  private func emit<P: EventPayload>(_ payload: P, sensitivity: SensitivityLevel) async {
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

public struct LaunchAtLoginResult: Codable, Sendable, Equatable {
  public let enabled: Bool
  public let serviceStatus: LaunchAtLoginStatus
  public let changed: Bool
  public let detail: String
}

public enum LaunchAtLoginStatus: Int, Codable, Sendable, Equatable {
  case enabled = 1
  case notRegistered = 3
  case notFound = 2
  case unknown = 0
}
