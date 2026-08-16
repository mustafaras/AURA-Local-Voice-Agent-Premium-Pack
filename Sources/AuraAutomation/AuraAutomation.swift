import AuraCore
import Foundation

/// Native macOS automation coordinator.
///
/// `AuraAutomation` does not enforce policy itself. Tool adapters later route intents
/// through `PolicyEngine` before invoking capabilities here. It emits events so that
/// downstream observers can audit every action and permission change.
public actor AuraAutomation {
  private let config: AutomationConfiguration
  private let applicationController: ApplicationControlling
  private let accessibilityHealth: any AccessibilityHealthChecking
  private let accessibilityObserver: AccessibilityObserving
  private let bus: AuraEventBus?
  private let logger: AuraLogger
  private let fileSystemURLOpener: FileSystemURLOpener

  /// Production initializer using real AppKit and ApplicationServices integrations.
  public init(
    config: AutomationConfiguration = AutomationConfiguration(),
    eventBus: AuraEventBus? = nil,
    logger: AuraLogger = AuraLogger(
      subsystem: "AuraAutomation",
      category: "coordinator"
    )
  ) {
    self.config = config
    self.bus = eventBus
    self.logger = logger
    self.applicationController = ApplicationController(logger: logger)
    self.accessibilityHealth =
      AccessibilityHealth(logger: logger) as any AccessibilityHealthChecking
    self.accessibilityObserver = AccessibilityObserver(logger: logger)
    self.fileSystemURLOpener = FileSystemURLOpener(validator: .production, logger: logger)
  }

  /// Testable initializer that accepts injected controllers and observers.
  public init(
    config: AutomationConfiguration,
    applicationController: ApplicationControlling,
    accessibilityHealth: any AccessibilityHealthChecking,
    accessibilityObserver: AccessibilityObserving,
    eventBus: AuraEventBus? = nil,
    logger: AuraLogger = AuraLogger(
      subsystem: "AuraAutomation",
      category: "coordinator"
    )
  ) {
    self.config = config
    self.applicationController = applicationController
    self.accessibilityHealth = accessibilityHealth
    self.accessibilityObserver = accessibilityObserver
    self.bus = eventBus
    self.logger = logger
    self.fileSystemURLOpener = FileSystemURLOpener(validator: .production, logger: logger)
  }

  /// Discover running applications and emit an event for each.
  public func discoverApplications() async {
    let apps = applicationController.runningApplications()
    for app in apps {
      let payload = ApplicationDiscoveredEvent(
        bundleIdentifier: app.bundleIdentifier,
        name: app.name,
        processID: app.processID,
        isActive: app.isActive,
        isHidden: app.isHidden
      )
      await emit(payload)
    }
  }

  /// Launch an application and emit an action event.
  public func launchApplication(bundleIdentifier: String) async throws(AuraError) {
    let descriptor = try await applicationController.launchApplication(
      bundleIdentifier: bundleIdentifier,
      timeout: config.actionTimeoutSeconds
    )
    await emitAction(.launch, descriptor: descriptor)
  }

  /// Activate a running application and emit an action event.
  public func activateApplication(bundleIdentifier: String) async throws(AuraError) {
    let descriptor = try await applicationController.activateApplication(
      bundleIdentifier: bundleIdentifier,
      timeout: config.actionTimeoutSeconds
    )
    await emitAction(.activate, descriptor: descriptor)
  }

  /// Hide a running application and emit an action event.
  public func hideApplication(bundleIdentifier: String) async throws(AuraError) {
    let descriptor = try await applicationController.hideApplication(
      bundleIdentifier: bundleIdentifier,
      timeout: config.actionTimeoutSeconds
    )
    await emitAction(.hide, descriptor: descriptor)
  }

  /// Quit an application and emit an action event.
  public func quitApplication(bundleIdentifier: String) async throws(AuraError) {
    let descriptor = try await applicationController.quitApplication(
      bundleIdentifier: bundleIdentifier,
      timeout: config.actionTimeoutSeconds
    )
    await emitAction(.quit, descriptor: descriptor)
  }

  // MARK: - SP-005: Filesystem and URL open pass-throughs

  /// Open a file with its default application via `FileSystemURLOpener`.
  /// Policy is evaluated by the caller (`ToolRouter`); the adapter's own
  /// validator provides defense-in-depth.
  public func openFile(path: String) async throws(AuraError) -> OpenOutcome {
    try await fileSystemURLOpener.openFile(path: path)
  }

  /// Open a folder in Finder via `FileSystemURLOpener`.
  public func openFolder(path: String) async throws(AuraError) -> OpenOutcome {
    try await fileSystemURLOpener.openFolder(path: path)
  }

  /// Reveal a file or folder in Finder via `FileSystemURLOpener`.
  public func revealInFinder(path: String) async throws(AuraError) -> OpenOutcome {
    try await fileSystemURLOpener.reveal(path: path)
  }

  /// Open a URL in the default browser via `FileSystemURLOpener`.
  public func openURL(_ raw: String) async throws(AuraError) -> OpenOutcome {
    try await fileSystemURLOpener.openURL(raw)
  }

  /// Check Accessibility trust and emit a permission event.
  public func checkAccessibilityPermission() async -> AccessibilityTrustState {
    let state = await accessibilityHealth.checkTrust()
    await accessibilityHealth.emitPermissionEvent(into: bus)
    return state
  }

  /// Wait for Accessibility to become trusted.
  public func waitForAccessibilityTrust(pollInterval: TimeInterval = 1.0) async throws(AuraError) {
    try await accessibilityHealth.waitForTrust(pollInterval: pollInterval)
  }

  /// Observe an accessible element in the target application.
  public func observeElement(
    bundleIdentifier: String,
    role: String? = nil,
    title: String? = nil
  ) async throws(AuraError) -> AccessibleElementObservation {
    try await accessibilityObserver.observeFirstElement(
      bundleIdentifier: bundleIdentifier,
      role: role,
      title: title,
      timeout: config.observationTimeoutSeconds
    )
  }

  private func emitAction(
    _ action: ApplicationActionEvent.Action,
    descriptor: NativeApplicationDescriptor
  ) async {
    let payload = ApplicationActionEvent(
      bundleIdentifier: descriptor.bundleIdentifier,
      action: action,
      outcome: .succeeded,
      elapsedSeconds: config.actionTimeoutSeconds
    )
    await emit(payload)
  }

  private func emit(_ payload: some EventPayload) async {
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: UUID(),
      actor: ActorID.automation,
      sensitivity: .internalLevel,
      payload: payload
    )
    if let bus {
      await bus.emit(envelope)
    }
  }
}
