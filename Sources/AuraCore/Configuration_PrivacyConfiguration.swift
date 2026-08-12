import Foundation

public struct PrivacyConfiguration: Codable, Sendable, Equatable {
  public var ambientAudioRetentionSeconds: Double
  public var screenshotRetentionDays: Int

  public init(
    ambientAudioRetentionSeconds: Double = 0,
    screenshotRetentionDays: Int = 7
  ) {
    self.ambientAudioRetentionSeconds = ambientAudioRetentionSeconds
    self.screenshotRetentionDays = screenshotRetentionDays
  }

  public func validate() throws(AuraError) {
    guard ambientAudioRetentionSeconds >= 0 else {
      throw AuraError.invalidConfiguration("ambientAudioRetentionSeconds must be non-negative")
    }
    guard screenshotRetentionDays >= 0 else {
      throw AuraError.invalidConfiguration("screenshotRetentionDays must be non-negative")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    ambientAudioRetentionSeconds =
      try container.decodeIfPresent(Double.self, forKey: .ambientAudioRetentionSeconds) ?? 0
    screenshotRetentionDays =
      try container.decodeIfPresent(Int.self, forKey: .screenshotRetentionDays) ?? 7
  }
}
