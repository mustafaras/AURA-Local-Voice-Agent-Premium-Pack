import AppKit
@preconcurrency import ApplicationServices
import AuraCore
import Foundation

/// Production `SecureFieldDetecting` using the real Accessibility API,
/// mirroring `AuraAutomation.AccessibilityObserver`'s verified attribute
/// access pattern: `kAXFocusedUIElementAttribute` to find the focused
/// element, then `kAXSubroleAttribute` compared against
/// `kAXSecureTextFieldSubrole` ("AXSecureTextField").
public actor AccessibilitySecureFieldDetector: SecureFieldDetecting {
  public init() {}

  public func isSecureFieldFocused(applicationBundleIdentifier: String) async -> Bool {
    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }
    guard trusted else { return false }

    let apps = await MainActor.run { NSWorkspace.shared.runningApplications }
    guard let app = apps.first(where: { $0.bundleIdentifier == applicationBundleIdentifier })
    else { return false }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var elementRef: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(
      axApp, (kAXFocusedUIElementAttribute as NSString) as CFString, &elementRef)
    guard error == .success, let elementRef else { return false }
    guard CFGetTypeID(elementRef) == AXUIElementGetTypeID() else { return false }
    // ApplicationServices imports AXUIElement as an opaque CF type; the exact
    // type-ID proof bounds this bridge after rejecting every other CF object.
    let element = unsafeDowncast(elementRef, to: AXUIElement.self)

    var subroleRef: CFTypeRef?
    let subroleError = AXUIElementCopyAttributeValue(
      element, (kAXSubroleAttribute as NSString) as CFString, &subroleRef)
    guard subroleError == .success, let subrole = subroleRef as? String else { return false }

    return subrole == (kAXSecureTextFieldSubrole as NSString) as String
  }
}
