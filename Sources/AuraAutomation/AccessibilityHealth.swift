@preconcurrency import ApplicationServices
import AuraCore
import Foundation

/// Provides synchronous and async checks of Accessibility permission state.
public actor AccessibilityHealth {
  private let logger: AuraLogger
  private var lastState: AccessibilityTrustState
  private var continuation: CheckedContinuation<Void, Never>?

  public init(
    logger: AuraLogger = AuraLogger(
      subsystem: "AuraAutomation",
      category: "accessibility-health"
    )
  ) {
    self.logger = logger
    self.lastState = AccessibilityTrustState.unknown
  }

  /// Current trust state of Accessibility permissions.
  public var trustState: AccessibilityTrustState {
    get async { lastState }
  }

  /// Check whether Accessibility is trusted for this process.
  ///
  /// This intentionally avoids a blocking prompt; the user must grant permission in
  /// System Settings, and the agent reports the state instead of hanging.
  public func checkTrust() async -> AccessibilityTrustState {
    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [
          kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
    }
    let state: AccessibilityTrustState = trusted ? .granted : .denied
    if state != lastState {
      lastState = state
      await logger.info("Accessibility trust state changed to \(String(describing: state))")
    }
    return state
  }

  /// Wait until Accessibility becomes trusted, polling with the provided interval.
  ///
  /// Returns immediately if already trusted. Throws if the task is cancelled.
  public func waitForTrust(pollInterval: TimeInterval = 1.0) async throws(AuraError) {
    while true {
      let state = await checkTrust()
      if state == .granted {
        return
      }
      do {
        try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
      } catch {
        throw AuraError.automationError("Cancelled waiting for Accessibility trust")
      }
    }
  }

  /// Emit a permission event that downstream policy and UI components can observe.
  public func emitPermissionEvent(into bus: AuraEventBus?) async {
    let state = await checkTrust()
    let payload = AccessibilityPermissionEvent(
      source: "AuraAutomation.AccessibilityHealth",
      state: state,
      timestamp: Date()
    )
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
