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
  /// What `userPreferenceEnabled()` answers while the user has not decided.
  /// PA-2 / ADR-066: the composition passes `OwnerTrustPosture.isEnabled`
  /// here so the owner build starts at login by default; `AuraLifecycle`
  /// never imports `AuraPolicy`.
  private let defaultEnabled: Bool

  public init(
    service: any LaunchAtLoginService,
    configurationEngine: ConfigurationEngine? = nil,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil,
    healthRegistry: RuntimeHealthRegistry? = nil,
    logger: AuraLogger? = nil,
    now: @escaping @Sendable () -> Date = Date.init,
    defaultEnabled: Bool = false
  ) {
    self.service = service
    self.configurationEngine = configurationEngine
    self.store = store
    self.eventBus = eventBus
    self.healthRegistry = healthRegistry
    self.logger = logger
    self.now = now
    self.defaultEnabled = defaultEnabled
  }

  /// Current ServiceManagement registration status.
  public func serviceStatus() -> LaunchAtLoginStatus {
    LaunchAtLoginStatus(rawValue: service.statusRawValue) ?? .unknown
  }

  /// User preference as stored in configuration. While no layer above the
  /// schema default carries the key, the answer is `defaultEnabled` — the
  /// schema's `false` is a placeholder, not a decision the user made.
  public func userPreferenceEnabled() async -> Bool {
    guard let engine = configurationEngine else { return defaultEnabled }
    guard
      let entry = await engine.inspect().entries.first(where: { $0.key == Self.userPreferenceKey }),
      entry.sourceLayer != .secureDefaults,
      case .boolean(let value) = entry.value
    else { return defaultEnabled }
    return value
  }

  /// Post-start registration (PA-2 / ADR-066). Registers the running bundle
  /// as a login item when the preference is on and macOS does not already
  /// list it. Idempotent: a second launch answers `changed: false`. It never
  /// writes a preference layer (the default already supplies `true`, and a
  /// session override would outrank the user's later `false`), never throws
  /// (a launch must not fail on ServiceManagement), and never works around
  /// `.requiresApproval` — that state is recorded for the Settings row and
  /// left to the owner's switch in System Settings › Login Items.
  @discardableResult
  public func ensureRegisteredAtLaunch() async -> LaunchAtLoginResult {
    let preference = await userPreferenceEnabled()
    let status = serviceStatus()

    guard preference else {
      let detail = "preference off; not registered at launch"
      await recordHealth(enabled: false, status: status, detail: detail)
      return LaunchAtLoginResult(
        enabled: false, serviceStatus: status, changed: false, detail: detail)
    }

    switch status {
    case .enabled:
      let detail = "already registered"
      await recordHealth(enabled: true, status: status, detail: detail)
      return LaunchAtLoginResult(
        enabled: true, serviceStatus: status, changed: false, detail: detail)
    case .requiresApproval:
      let detail = "registered; awaiting approval in System Settings > Login Items"
      await recordHealth(enabled: true, status: status, detail: detail)
      return LaunchAtLoginResult(
        enabled: true, serviceStatus: status, changed: false, detail: detail)
    case .notRegistered, .notFound, .unknown:
      break
    }

    await emit(
      LaunchAtLoginRequestedEvent(enabled: true, actor: .system),
      sensitivity: .internalLevel)
    do {
      try service.register()
    } catch {
      let detail = "launch registration failed: \(error.localizedDescription)"
      await logger?.error(detail, actor: .lifecycle)
      await healthRegistry?.record(
        componentID: "launch-at-login", status: .failed,
        detail: "enabled=true, status=\(status.rawValue), \(detail)")
      return LaunchAtLoginResult(
        enabled: true, serviceStatus: status, changed: false, detail: detail)
    }

    let newStatus = serviceStatus()
    let changed = newStatus == .enabled
    let detail: String
    switch newStatus {
    case .enabled:
      detail = "registered at launch"
    case .requiresApproval:
      detail = "registered; awaiting approval in System Settings > Login Items"
    case .notRegistered, .notFound, .unknown:
      detail = "register returned but service status is \(newStatus.rawValue)"
    }
    await emit(
      LaunchAtLoginChangedEvent(
        enabled: true, statusRawValue: newStatus.rawValue, actor: .system),
      sensitivity: .internalLevel)
    await recordHealth(enabled: true, status: newStatus, detail: detail)
    return LaunchAtLoginResult(
      enabled: true, serviceStatus: newStatus, changed: changed, detail: detail)
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
    case .notRegistered, .notFound, .requiresApproval:
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

/// Mirrors `SMAppService.Status` raw values exactly (ServiceManagement,
/// `SMAppService.h` NS_ENUM order) so `LaunchAtLoginStatus(rawValue:
/// service.statusRawValue)` is a faithful read. Before PA-2 the raw values
/// were shuffled: macOS's `notRegistered` (0) read as `.unknown` and
/// `requiresApproval` (2) read as `.notFound`, so the health surface called
/// an unregistered login item "unsupported" and the approval state was
/// invisible. `.unknown` is reserved for values outside the SDK enum.
public enum LaunchAtLoginStatus: Int, Codable, Sendable, Equatable {
  case notRegistered = 0
  case enabled = 1
  case requiresApproval = 2
  case notFound = 3
  case unknown = -1
}
