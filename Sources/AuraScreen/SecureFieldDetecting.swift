import AuraCore
import Foundation

/// Detects whether the currently focused UI element in an application is a
/// secure (password-style) text field, via the Accessibility API's
/// `kAXSecureTextFieldSubrole`.
///
/// A separate, minimal protocol rather than a dependency on the whole
/// `AuraAutomation` module — `AuraScreen` only ever needs this one yes/no
/// check, not general element observation/control.
public protocol SecureFieldDetecting: Sendable {
  func isSecureFieldFocused(applicationBundleIdentifier: String) async -> Bool

  /// The same question, but able to say "I could not tell".
  ///
  /// `isSecureFieldFocused` has to answer yes or no, and a detector that
  /// cannot read the Accessibility state has no truthful way to say so — it
  /// must pick one, and picking "no" makes every guard above it inert while
  /// all tests still pass. This variant separates a determined absence from an
  /// unreadable state so callers can refuse on the latter *and* report why.
  ///
  /// The default implementation preserves the existing contract for detectors
  /// that genuinely cannot be indeterminate (scripted/test conformers).
  func probeSecureField(applicationBundleIdentifier: String) async -> SecureFieldProbe
}

extension SecureFieldDetecting {
  public func probeSecureField(applicationBundleIdentifier: String) async -> SecureFieldProbe {
    await isSecureFieldFocused(applicationBundleIdentifier: applicationBundleIdentifier)
      ? .focused : .notFocused
  }
}

/// The outcome of a secure-field check, including the case a boolean cannot
/// express: the check itself did not complete.
public enum SecureFieldProbe: Sendable, Equatable {
  /// A secure field holds focus in the target application. Refuse input.
  case focused
  /// The check completed and no secure field holds focus.
  case notFocused
  /// The check did not complete — the Accessibility query failed, so nothing
  /// is known about the focused element. Callers must refuse input and report
  /// *this* reason rather than claiming a secure field was found.
  case indeterminate(String)

  /// Fail-closed collapse to the boolean contract: anything other than a
  /// completed "no" refuses.
  public var refusesInput: Bool { self != .notFocused }
}
