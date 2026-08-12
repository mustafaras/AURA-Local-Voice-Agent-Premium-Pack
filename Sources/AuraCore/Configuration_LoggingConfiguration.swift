import Foundation

public struct LoggingConfiguration: Codable, Sendable, Equatable {
  public var minimumLevel: String
  public var destination: String

  public init(
    minimumLevel: String = "info",
    destination: String = "stderr"
  ) {
    self.minimumLevel = minimumLevel
    self.destination = destination
  }

  public func validate() throws(AuraError) {
    let validLevels = ["trace", "debug", "info", "warning", "error", "critical"]
    guard validLevels.contains(minimumLevel.lowercased()) else {
      throw AuraError.invalidConfiguration("minimumLevel must be one of \(validLevels)")
    }
    guard !destination.isEmpty else {
      throw AuraError.invalidConfiguration("destination must not be empty")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    minimumLevel = try container.decodeIfPresent(String.self, forKey: .minimumLevel) ?? "info"
    destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? "stderr"
  }
}
