import Foundation

// `AVAudioFrameCount` is provided by AVFoundation; do not redefine it.

/// Configuration for native macOS automation and application control.
public struct AutomationConfiguration: Codable, Sendable, Equatable {
  /// Seconds allowed for a launch/activate/hide/quit action before timeout.
  public var actionTimeoutSeconds: Double

  /// Seconds allowed for an Accessibility observation before timeout.
  public var observationTimeoutSeconds: Double

  /// Bundle identifiers that must never be observed or controlled.
  public var sensitiveBundleIdentifiers: Set<String>

  /// Capability identifiers (domain.action) that automation may perform.
  public var allowedAutomationCapabilities: Set<String>

  public init(
    actionTimeoutSeconds: Double = 10.0,
    observationTimeoutSeconds: Double = 5.0,
    sensitiveBundleIdentifiers: Set<String> = [
      "com.apple.securityagent",
      "com.apple.keychainaccess",
    ],
    allowedAutomationCapabilities: Set<String> = [
      "app.activate",
      "app.terminate",
    ]
  ) {
    self.actionTimeoutSeconds = actionTimeoutSeconds
    self.observationTimeoutSeconds = observationTimeoutSeconds
    self.sensitiveBundleIdentifiers = sensitiveBundleIdentifiers
    self.allowedAutomationCapabilities = allowedAutomationCapabilities
  }

  public func validate() throws(AuraError) {
    guard actionTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("automation actionTimeoutSeconds must be positive")
    }
    guard observationTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration(
        "automation observationTimeoutSeconds must be positive")
    }
    guard !allowedAutomationCapabilities.isEmpty else {
      throw AuraError.invalidConfiguration(
        "automation allowedAutomationCapabilities must not be empty")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    actionTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .actionTimeoutSeconds) ?? 10.0
    observationTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .observationTimeoutSeconds) ?? 5.0
    sensitiveBundleIdentifiers =
      try container.decodeIfPresent(Set<String>.self, forKey: .sensitiveBundleIdentifiers)
      ?? [
        "com.apple.securityagent",
        "com.apple.keychainaccess",
      ]
    allowedAutomationCapabilities =
      try container.decodeIfPresent(Set<String>.self, forKey: .allowedAutomationCapabilities)
      ?? [
        "app.activate",
        "app.terminate",
      ]
  }
}
