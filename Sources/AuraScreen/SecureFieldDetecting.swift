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
}
