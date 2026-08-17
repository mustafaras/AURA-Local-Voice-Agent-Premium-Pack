import AppKit
@preconcurrency import ApplicationServices
import AuraCore
import AuraScreen
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
  ///
  /// `nil` cannot distinguish "no modal" from "could not look", so a caller
  /// that must fail closed uses `probeModal` instead.
  func detectUnexpectedModal(expectedBundleIdentifier: String) async -> String?

  /// The same check, able to report that it did not complete.
  ///
  /// The default implementation preserves the existing contract for detectors
  /// that cannot be indeterminate (scripted/test conformers).
  func probeModal(expectedBundleIdentifier: String) async -> ModalProbe
}

extension ModalDialogDetecting {
  public func probeModal(expectedBundleIdentifier: String) async -> ModalProbe {
    if let bundleID = await detectUnexpectedModal(
      expectedBundleIdentifier: expectedBundleIdentifier)
    {
      return .unexpected(bundleID)
    }
    return .none
  }
}

/// The outcome of a modal check, including the case `String?` cannot express:
/// the check itself did not complete.
public enum ModalProbe: Sendable, Equatable {
  /// The check completed and no unexpected modal is present.
  case none
  /// An unexpected modal belonging to this bundle identifier is frontmost.
  case unexpected(String)
  /// The check did not complete — the Accessibility query failed, so it is
  /// unknown whether a security dialog is on screen. Callers must halt and
  /// report *this* reason rather than claiming a modal was detected.
  case indeterminate(String)
}

/// Production detector using the real Accessibility API: `kAXModalAttribute`
/// on the frontmost application's focused window, plus a fixed
/// always-unexpected set of system security surfaces that must never be
/// auto-approved regardless of the modality flag or nominal target app.
///
/// Failed Accessibility reads surface as `ModalProbe.indeterminate` rather
/// than "no modal": a detector that answers "all clear" when it cannot see is
/// worse than one that refuses, because the security dialog it is meant to
/// catch is exactly the surface most likely to make a read fail.
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

  /// Legacy contract. `nil` here means "no *detected* modal"; it deliberately
  /// does not invent a bundle identifier for an unreadable state, so callers
  /// needing the fail-closed answer must use `probeModal`.
  public func detectUnexpectedModal(expectedBundleIdentifier: String) async -> String? {
    if case .unexpected(let bundleID) = await probeModal(
      expectedBundleIdentifier: expectedBundleIdentifier)
    {
      return bundleID
    }
    return nil
  }

  public func probeModal(expectedBundleIdentifier: String) async -> ModalProbe {
    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }
    guard trusted else { return .indeterminate("accessibility not trusted") }

    guard let frontmost = await MainActor.run(body: { NSWorkspace.shared.frontmostApplication })
    else {
      // No frontmost application at all: nothing is in front of the user, so
      // there is no modal. A determined answer, not a failed one.
      return .none
    }
    guard let frontmostBundleID = frontmost.bundleIdentifier else {
      return .indeterminate("frontmost application has no bundle identifier")
    }

    if alwaysUnexpectedBundleIdentifiers.contains(frontmostBundleID) {
      return .unexpected(frontmostBundleID)
    }

    // A different app becoming frontmost is reported by the control loop's
    // own identity check, not here — this detector only reports an actual
    // modal window (`kAXModalAttribute == true`) within whichever app is
    // frontmost.
    let axApp = AXUIElementCreateApplication(frontmost.processIdentifier)
    var windowRef: CFTypeRef?
    let err = AXUIElementCopyAttributeValue(
      axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
    if err != .success {
      return AccessibilityProbeClassification.isDeterminedAbsence(err)
        ? .none
        : .indeterminate(
          "focused-window read failed: \(AccessibilityProbeClassification.describe(err))")
    }
    guard let windowRef else { return .none }
    guard CFGetTypeID(windowRef) == AXUIElementGetTypeID() else {
      return .indeterminate("focused window was not an AXUIElement")
    }
    // ApplicationServices imports AXUIElement as an opaque CF type; the exact
    // type-ID proof bounds this bridge after rejecting every other CF object.
    let window = unsafeDowncast(windowRef, to: AXUIElement.self)

    var modalRef: CFTypeRef?
    let modalErr = AXUIElementCopyAttributeValue(window, kAXModalAttribute as CFString, &modalRef)
    if modalErr != .success {
      // A window without the modal attribute is not modal; a failed read
      // leaves modality unknown.
      return AccessibilityProbeClassification.isDeterminedAbsence(modalErr)
        ? .none
        : .indeterminate(
          "modal-attribute read failed: \(AccessibilityProbeClassification.describe(modalErr))")
    }
    guard let isModal = modalRef as? Bool else {
      return .indeterminate("modal attribute was not a boolean")
    }
    guard isModal else { return .none }

    return frontmostBundleID == expectedBundleIdentifier ? .none : .unexpected(frontmostBundleID)
  }
}
