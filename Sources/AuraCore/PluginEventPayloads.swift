import Foundation

/// Emitted whenever `PluginVerifier` (`AuraPlugins`) checks a manifest's
/// content hash and vendor signature, whether the result is acceptance or
/// rejection — verification failures are exactly the adversarial signal a
/// plugin marketplace threat model needs to see.
public struct PluginVerificationEvent: EventPayload {
  public static let eventType = "plugin.verification"

  public let pluginID: String
  public let version: String
  public let result: String
  public let vendorName: String

  public init(pluginID: String, version: String, result: String, vendorName: String) {
    self.pluginID = pluginID
    self.version = version
    self.result = result
    self.vendorName = vendorName
  }
}

/// Emitted on every plugin lifecycle transition: install, enable, disable,
/// quarantine, uninstall.
public struct PluginLifecycleEvent: EventPayload {
  public static let eventType = "plugin.lifecycle"

  public let pluginID: String
  public let transition: String
  public let resultingState: String
  public let reason: String

  public init(pluginID: String, transition: String, resultingState: String, reason: String) {
    self.pluginID = pluginID
    self.transition = transition
    self.resultingState = resultingState
    self.reason = reason
  }
}
