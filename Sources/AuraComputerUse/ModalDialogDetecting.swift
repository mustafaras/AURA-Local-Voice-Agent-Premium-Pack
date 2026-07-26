import AppKit
@preconcurrency import ApplicationServices
import AuraCore
import Foundation

/// Detects an unexpected modal or security dialog so the control loop can
/// stop rather than risk interacting with (or, worse, auto-dismissing) it —
/// per the normative rules "Never approve security dialogs automatically"
/// and "Stop on unexpected modal dialogs."
///
/// A separate, minimal protocol (mirroring `AuraScreen.SecureFieldDetecting`)
/// rather than a dependency on all of `AuraAutomation`'s general-purpose
/// element observation.
public protocol ModalDialogDetecting: Sendable {
  /// Returns the bundle identifier of an unexpected modal dialog currently
  /// frontmost, or `nil` if none is present. A dialog belonging to
  /// `expectedBundleIdentifier` itself (e.g. an in-app alert sheet as part
  /// of the expected flow) is not reported; a system security surface
  /// (Keychain/SecurityAgent) always is, regardless of which app is
  /// nominally frontmost.
  func detectUnexpectedModal(expectedBundleIdentifier: String) async -> String?
}

/// Production detector using the real Accessibility API: `kAXModalAttribute`
/// on the frontmost application's focused window, plus a fixed
/// always-unexpected set of system security surfaces that must never be
/// auto-approved regardless of the modality flag or nominal target app.
public actor AccessibilityModalDialogDetector: ModalDialogDetecting {
  /// Bundle identifiers that are always treated as an unexpected modal, even
  /// if `kAXModalAttribute` is unset or unreadable — matches
  /// `AutomationConfiguration.sensitiveBundleIdentifiers`'s and
  /// `ScreenContextConfiguration.sensitiveApplicationBundleIdentifiers`'s
  /// precedent of a hard, non-content-dependent exclusion list.
  private let alwaysUnexpectedBundleIdentifiers: Set<String>

  public init(
    alwaysUnexpectedBundleIdentifiers: Set<String> = [
      "com.apple.SecurityAgent",
      "com.apple.securityagent",
      "com.apple.keychainaccess",
    ]
  ) {
    self.alwaysUnexpectedBundleIdentifiers = alwaysUnexpectedBundleIdentifiers
  }

  public func detectUnexpectedModal(expectedBundleIdentifier: String) async -> String? {
    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }
    guard trusted else { return nil }

    guard let frontmost = await MainActor.run(body: { NSWorkspace.shared.frontmostApplication })
    else {
      return nil
    }
    guard let frontmostBundleID = frontmost.bundleIdentifier else { return nil }

    if alwaysUnexpectedBundleIdentifiers.contains(frontmostBundleID) {
      return frontmostBundleID
    }

    // A different app becoming frontmost is reported by the control loop's
    // own identity check, not here — this detector only reports an actual
    // modal window (`kAXModalAttribute == true`) within whichever app is
    // frontmost.
    let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
    var windowRef: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(
      axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
    guard err == .success, let windowRef else { return nil }
    let window = windowRef as! AXUIElement

    var modalRef: CFTypeRef?
    let modalErr = AXUIElementCopyAttributeValue(window, kAXModalAttribute as CFString, &modalRef)
    guard modalErr == .success, let isModal = modalRef as? Bool, isModal else { return nil }

    return frontmostBundleID == expectedBundleIdentifier ? nil : frontmostBundleID
  }
}
