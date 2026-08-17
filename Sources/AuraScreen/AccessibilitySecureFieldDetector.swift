import AppKit
@preconcurrency import ApplicationServices
import AuraCore
import Foundation

/// Classifies an `AXError` returned by an attribute read into "there is
/// genuinely nothing there" versus "the query did not complete".
///
/// The distinction is the whole point of `SecureFieldProbe.indeterminate`: a
/// safety detector that collapses both cases into "nothing found" is a guard
/// that disables itself exactly when the system is least healthy, and no test
/// over its happy path can see that happen.
public enum AccessibilityProbeClassification {
  /// `true` when the error is a definitive statement that the attribute has no
  /// value — nothing is focused, the element is gone, or the element does not
  /// carry the attribute at all. Every other error means the answer is
  /// unknown, and unknown must never be reported as "no".
  public static func isDeterminedAbsence(_ error: AXError) -> Bool {
    switch error {
    case .noValue, .attributeUnsupported, .invalidUIElement:
      return true
    default:
      return false
    }
  }

  /// A stable, non-localized description for evidence and refusal messages.
  /// Carries no window contents, element values, or user data.
  public static func describe(_ error: AXError) -> String {
    switch error {
    case .success: return "success"
    case .apiDisabled: return "apiDisabled"
    case .cannotComplete: return "cannotComplete"
    case .notImplemented: return "notImplemented"
    case .invalidUIElement: return "invalidUIElement"
    case .invalidUIElementObserver: return "invalidUIElementObserver"
    case .attributeUnsupported: return "attributeUnsupported"
    case .actionUnsupported: return "actionUnsupported"
    case .notificationUnsupported: return "notificationUnsupported"
    case .noValue: return "noValue"
    case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
    case .notEnoughPrecision: return "notEnoughPrecision"
    case .failure: return "failure"
    case .illegalArgument: return "illegalArgument"
    case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
    case .notificationNotRegistered: return "notificationNotRegistered"
    @unknown default: return "unknownAXError(\(error.rawValue))"
    }
  }
}

/// Production `SecureFieldDetecting` using the real Accessibility API,
/// mirroring `AuraAutomation.AccessibilityObserver`'s verified attribute
/// access pattern: `kAXFocusedUIElementAttribute` to find the focused
/// element, then `kAXSubroleAttribute` compared against
/// `kAXSecureTextFieldSubrole` ("AXSecureTextField").
///
/// Every path that cannot answer the question returns
/// `SecureFieldProbe.indeterminate` rather than "no secure field". Callers
/// refuse on it: refusing to type when the credential state is unreadable is
/// the only safe default, and it is reported as what it is instead of being
/// dressed up as a secure-field detection.
public actor AccessibilitySecureFieldDetector: SecureFieldDetecting {
  public init() {}

  /// Fail-closed collapse of `probeSecureField` onto the boolean contract:
  /// an unreadable state answers "yes, refuse", because the alternative
  /// silently disables every guard built on top of this call.
  public func isSecureFieldFocused(applicationBundleIdentifier: String) async -> Bool {
    await probeSecureField(applicationBundleIdentifier: applicationBundleIdentifier).refusesInput
  }

  public func probeSecureField(applicationBundleIdentifier: String) async -> SecureFieldProbe {
    let trusted = await MainActor.run {
      AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
    }
    // Without Accessibility trust nothing about the focused element is
    // observable — that is unknown, not "no secure field".
    guard trusted else { return .indeterminate("accessibility not trusted") }

    let apps = await MainActor.run { NSWorkspace.shared.runningApplications }
    // A target that is not running has no focused element at all. This is a
    // determined absence, not a failed query.
    guard let app = apps.first(where: { $0.bundleIdentifier == applicationBundleIdentifier })
    else { return .notFocused }

    let axApp = AXUIElementCreateApplication(app.processIdentifier)
    var elementRef: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(
      axApp, (kAXFocusedUIElementAttribute as NSString) as CFString, &elementRef)
    if error != .success {
      return AccessibilityProbeClassification.isDeterminedAbsence(error)
        ? .notFocused
        : .indeterminate(
          "focused-element read failed: \(AccessibilityProbeClassification.describe(error))")
    }
    guard let elementRef else { return .notFocused }
    guard CFGetTypeID(elementRef) == AXUIElementGetTypeID() else {
      return .indeterminate("focused element was not an AXUIElement")
    }
    // ApplicationServices imports AXUIElement as an opaque CF type; the exact
    // type-ID proof bounds this bridge after rejecting every other CF object.
    let element = unsafeDowncast(elementRef, to: AXUIElement.self)

    var subroleRef: CFTypeRef?
    let subroleError = AXUIElementCopyAttributeValue(
      element, (kAXSubroleAttribute as NSString) as CFString, &subroleRef)
    if subroleError != .success {
      // A focused element with no subrole attribute is a determined "not a
      // secure field"; a failed read is not.
      return AccessibilityProbeClassification.isDeterminedAbsence(subroleError)
        ? .notFocused
        : .indeterminate(
          "subrole read failed: \(AccessibilityProbeClassification.describe(subroleError))")
    }
    guard let subrole = subroleRef as? String else {
      return .indeterminate("subrole was not a string")
    }

    return subrole == (kAXSecureTextFieldSubrole as NSString) as String ? .focused : .notFocused
  }
}
