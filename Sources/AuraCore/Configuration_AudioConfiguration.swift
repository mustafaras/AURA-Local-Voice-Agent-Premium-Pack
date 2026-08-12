import Foundation

/// Configuration for the real-time audio capture pipeline.
///
/// Defaults are chosen for a 16 kHz mono wake-word/STT input stream on macOS.
public struct AudioConfiguration: Codable, Sendable, Equatable {
  public var sampleRate: Double
  public var channelCount: UInt32
  public var frameLength: UInt32
  public var ringBufferSeconds: Double
  public var captureBufferSize: UInt32
  public var enableEchoCancellation: Bool
  public var enableAutomaticGainControl: Bool

  public init(
    sampleRate: Double = 16_000,
    channelCount: UInt32 = 1,
    frameLength: UInt32 = 512,
    ringBufferSeconds: Double = 5.0,
    captureBufferSize: UInt32 = 1024,
    enableEchoCancellation: Bool = true,
    enableAutomaticGainControl: Bool = true
  ) {
    self.sampleRate = sampleRate
    self.channelCount = channelCount
    self.frameLength = frameLength
    self.ringBufferSeconds = ringBufferSeconds
    self.captureBufferSize = captureBufferSize
    self.enableEchoCancellation = enableEchoCancellation
    self.enableAutomaticGainControl = enableAutomaticGainControl
  }

  public func validate() throws(AuraError) {
    guard sampleRate > 0 else {
      throw AuraError.invalidConfiguration("sampleRate must be positive")
    }
    guard channelCount > 0 else {
      throw AuraError.invalidConfiguration("channelCount must be positive")
    }
    guard frameLength > 0 else {
      throw AuraError.invalidConfiguration("frameLength must be positive")
    }
    guard ringBufferSeconds > 0 else {
      throw AuraError.invalidConfiguration("ringBufferSeconds must be positive")
    }
    guard captureBufferSize > 0 else {
      throw AuraError.invalidConfiguration("captureBufferSize must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sampleRate = try container.decodeIfPresent(Double.self, forKey: .sampleRate) ?? 16_000
    channelCount = try container.decodeIfPresent(UInt32.self, forKey: .channelCount) ?? 1
    frameLength = try container.decodeIfPresent(UInt32.self, forKey: .frameLength) ?? 512
    ringBufferSeconds =
      try container.decodeIfPresent(Double.self, forKey: .ringBufferSeconds) ?? 5.0
    captureBufferSize =
      try container.decodeIfPresent(UInt32.self, forKey: .captureBufferSize) ?? 1024
    enableEchoCancellation =
      try container.decodeIfPresent(Bool.self, forKey: .enableEchoCancellation) ?? true
    enableAutomaticGainControl =
      try container.decodeIfPresent(Bool.self, forKey: .enableAutomaticGainControl) ?? true
  }
}
