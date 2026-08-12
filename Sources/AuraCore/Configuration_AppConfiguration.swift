import Foundation

public struct AppConfiguration: Codable, Sendable, Equatable {
  public var bundleIdentifier: String
  public var serviceName: String

  public init(
    bundleIdentifier: String = "ai.aura.local",
    serviceName: String = "AuraCore"
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.serviceName = serviceName
  }

  public func validate() throws(AuraError) {
    guard !bundleIdentifier.isEmpty else {
      throw AuraError.invalidConfiguration("bundleIdentifier must not be empty")
    }
    guard !serviceName.isEmpty else {
      throw AuraError.invalidConfiguration("serviceName must not be empty")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    bundleIdentifier =
      try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? "ai.aura.local"
    serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? "AuraCore"
  }
}
