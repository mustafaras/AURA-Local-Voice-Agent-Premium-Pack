import Foundation

#if canImport(ServiceManagement)
  @preconcurrency import ServiceManagement
#endif

/// Abstract the macOS `SMAppService` surface so production and test
/// implementations share a single protocol. This isolates the agent from
/// real ServiceManagement side effects during unit tests and from accidental
/// launch-at-login mutation when authority does not permit it.
public protocol LaunchAtLoginService: Sendable {
  /// Current registration status as a stable raw value.
  nonisolated var statusRawValue: Int { get }
  /// Register this helper/main app service.
  nonisolated func register() throws
  /// Unregister this helper/main app service.
  nonisolated func unregister() throws
}

#if canImport(ServiceManagement)
  /// Production wrapper around `SMAppService`.
  public struct SMAppServiceWrapper: LaunchAtLoginService {
    private let service: SMAppService

    public init(service: SMAppService) {
      self.service = service
    }

    public var statusRawValue: Int {
      service.status.rawValue
    }

    public func register() throws {
      try service.register()
    }

    public func unregister() throws {
      try service.unregister()
    }
  }

  /// Production factory for the main-app launch-at-login service.
  public struct MainAppLaunchAtLoginService: LaunchAtLoginService {
    private let wrapper: SMAppServiceWrapper

    public init() {
      self.wrapper = SMAppServiceWrapper(service: SMAppService.mainApp)
    }

    public var statusRawValue: Int { wrapper.statusRawValue }

    public func register() throws {
      try wrapper.register()
    }

    public func unregister() throws {
      try wrapper.unregister()
    }
  }
#else
  /// Stub when ServiceManagement is unavailable (non-macOS builds).
  public struct MainAppLaunchAtLoginService: LaunchAtLoginService {
    public var statusRawValue: Int { 3 }  // notRegistered
    public func register() throws {}
    public func unregister() throws {}
  }
#endif

/// In-memory service for testing. Simulates enable/disable and status changes.
/// Raw values follow `SMAppService.Status` (0 notRegistered, 1 enabled,
/// 2 requiresApproval, 3 notFound) — the same contract `LaunchAtLoginStatus`
/// decodes.
public final class InMemoryLaunchAtLoginService: LaunchAtLoginService, @unchecked Sendable {
  private let lock = NSLock()
  public private(set) var registered = false
  public private(set) var registerCallCount = 0
  public var simulateRegisterError: Error?
  private var simulatedStatusRawValue: Int?
  private var statusRawValueAfterRegister: Int?

  public init(registered: Bool = false) {
    self.registered = registered
  }

  public var statusRawValue: Int {
    lock.lock(); defer { lock.unlock() }
    if let simulatedStatusRawValue { return simulatedStatusRawValue }
    return registered ? 1 : 0  // enabled / notRegistered
  }

  public func setSimulateRegisterError(_ error: Error?) {
    lock.lock(); defer { lock.unlock() }
    self.simulateRegisterError = error
  }

  /// Force the reported status regardless of `registered` (e.g. 2 to model
  /// macOS holding the item in `.requiresApproval`).
  public func setSimulatedStatusRawValue(_ rawValue: Int?) {
    lock.lock(); defer { lock.unlock() }
    self.simulatedStatusRawValue = rawValue
  }

  /// Status to report once `register()` succeeds (e.g. 2 when macOS accepts
  /// the registration but requires the user's approval).
  public func setStatusRawValueAfterRegister(_ rawValue: Int?) {
    lock.lock(); defer { lock.unlock() }
    self.statusRawValueAfterRegister = rawValue
  }

  public func register() throws {
    lock.lock(); defer { lock.unlock() }
    registerCallCount += 1
    if let error = simulateRegisterError {
      throw error
    }
    registered = true
    if let statusRawValueAfterRegister {
      simulatedStatusRawValue = statusRawValueAfterRegister
    }
  }

  public func unregister() throws {
    lock.lock(); defer { lock.unlock() }
    registered = false
    simulatedStatusRawValue = nil
  }
}
