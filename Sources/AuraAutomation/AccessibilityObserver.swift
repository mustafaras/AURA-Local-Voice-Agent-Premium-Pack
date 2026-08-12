import AppKit
@preconcurrency import ApplicationServices
import AuraCore
import Foundation

/// Protocol abstracting Accessibility element observation to enable deterministic tests.
public protocol AccessibilityObserving: Sendable {
  func observeFirstElement(
    bundleIdentifier: String,
    role: String?,
    title: String?,
    timeout: TimeInterval
  ) async throws(AuraError) -> AccessibleElementObservation
}

/// Production observer using ApplicationServices.
public actor AccessibilityObserver: AccessibilityObserving {
  private let logger: AuraLogger

  public init(
    logger: AuraLogger = AuraLogger(
      subsystem: "AuraAutomation",
      category: "accessibility-observer"
    )
  ) {
    self.logger = logger
  }

  public func observeFirstElement(
    bundleIdentifier: String,
    role: String?,
    title: String?,
    timeout: TimeInterval
  ) async throws(AuraError) -> AccessibleElementObservation {
    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [
          kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
        ] as CFDictionary)
    }
    guard trusted else {
      throw AuraError.automationError("Accessibility is not trusted")
    }

    guard !bundleIdentifier.isEmpty else {
      throw AuraError.automationError("bundleIdentifier must not be empty")
    }

    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let observation = try? await findElement(
        bundleIdentifier: bundleIdentifier,
        role: role,
        title: title
      ) {
        await logger.info("Observed element in \(bundleIdentifier)")
        return observation
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
      if Task.isCancelled {
        throw AuraError.automationError("Observation cancelled for \(bundleIdentifier)")
      }
    }

    throw AuraError.automationError(
      "Timeout observing element in \(bundleIdentifier) "
        + "(role: \(role ?? "nil"), title: \(title ?? "nil"))"
    )
  }

  private func findElement(
    bundleIdentifier: String,
    role: String?,
    title: String?
  ) async throws(AuraError) -> AccessibleElementObservation? {
    let apps = await MainActor.run { NSWorkspace.shared.runningApplications }
    guard let app = apps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
      return nil
    }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var elementRef: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(
      axApp,
      (kAXFocusedUIElementAttribute as NSString) as CFString,
      &elementRef
    )
    guard error == .success, let elementRef else {
      return nil
    }
    guard CFGetTypeID(elementRef) == AXUIElementGetTypeID() else { return nil }
    // ApplicationServices imports AXUIElement as an opaque CF type; the exact
    // type-ID proof bounds this bridge after rejecting every other CF object.
    let element = unsafeDowncast(elementRef, to: AXUIElement.self)
    let observedRole = copyStringAttribute(
      element: element, attribute: (kAXRoleAttribute as NSString) as String)
    let observedTitle = copyStringAttribute(
      element: element, attribute: (kAXTitleAttribute as NSString) as String)
    let observedValue = copyStringAttribute(
      element: element, attribute: (kAXValueAttribute as NSString) as String)
    let pid = app.processIdentifier

    if let role, observedRole != role {
      return nil
    }
    if let title, observedTitle != title {
      return nil
    }

    return AccessibleElementObservation(
      bundleIdentifier: bundleIdentifier,
      processID: pid,
      elementRole: observedRole,
      elementTitle: observedTitle,
      elementValue: observedValue,
      timestamp: Date()
    )
  }

  private func copyStringAttribute(element: AXUIElement, attribute: String) -> String? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard error == .success, let value else { return nil }
    if CFGetTypeID(value) == AXValueGetTypeID() {
      return nil
    }
    return value as? String
  }
}
