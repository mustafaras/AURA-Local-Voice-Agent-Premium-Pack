import Foundation

/// Configuration for the R5 productivity integrations. This slice covers the
/// Safari read bridge; provider/account onboarding is SP-010's objective.
public struct ProductivityConfiguration: Codable, Sendable, Equatable {
  /// The approved Safari profile the read bridge is bound to.
  public var safariProfileID: String

  /// The Safari Web Extension bundle identifier the bridge authenticates.
  public var safariExtensionID: String

  /// Absolute path to the shared app-group container where the extension
  /// writes its signed observation envelope.
  public var safariSharedContainerPath: String

  /// Keychain service name for the Safari bridge shared secret.
  public var safariSecretServiceName: String

  /// Hosts the Safari bridge may read (the approved page domains).
  public var safariAllowedHosts: [String]

  public init(
    safariProfileID: String = "personal",
    safariExtensionID: String = "com.aura.safari-extension",
    safariSharedContainerPath: String = "",
    safariSecretServiceName: String = "com.aura.safari-bridge",
    safariAllowedHosts: [String] = []
  ) {
    self.safariProfileID = safariProfileID
    self.safariExtensionID = safariExtensionID
    self.safariSharedContainerPath = safariSharedContainerPath
    self.safariSecretServiceName = safariSecretServiceName
    self.safariAllowedHosts = safariAllowedHosts
  }

  public func validate() throws(AuraError) {
    guard !safariProfileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("productivity safariProfileID must not be empty")
    }
    guard !safariExtensionID.isEmpty else {
      throw AuraError.invalidConfiguration("productivity safariExtensionID must not be empty")
    }
    guard !safariSecretServiceName.isEmpty else {
      throw AuraError.invalidConfiguration(
        "productivity safariSecretServiceName must not be empty")
    }
  }
}
