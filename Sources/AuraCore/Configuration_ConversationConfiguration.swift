import Foundation

/// Configuration for the conversation state machine and timeout policy.
public struct ConversationConfiguration: Codable, Sendable, Equatable {
  /// Seconds of silence or inactivity before aborting a listening turn.
  public var listenTimeoutSeconds: Double

  /// Seconds allowed for the intent engine to produce a response plan.
  public var thinkTimeoutSeconds: Double

  /// Seconds allowed for the TTS engine to complete a spoken response.
  public var speechTimeoutSeconds: Double

  /// Grace period after barge-in before another interruption is accepted.
  public var bargeInGraceMilliseconds: UInt32

  /// Number of consecutive silent frames required to end a listening turn.
  public var silenceEndFrames: UInt32

  /// Short grace window used when a stable segment looks syntactically
  /// incomplete. A later segment may complete the turn sooner.
  public var continuationWindowSeconds: Double

  /// Deterministic voice commands that always stop the assistant mid-speech.
  public var deterministicStopCommands: Set<String>

  /// Deterministic voice commands that toggle pause/resume.
  public var deterministicPauseResumeCommands: Set<String>

  public init(
    listenTimeoutSeconds: Double = 10.0,
    thinkTimeoutSeconds: Double = 30.0,
    speechTimeoutSeconds: Double = 60.0,
    bargeInGraceMilliseconds: UInt32 = 500,
    silenceEndFrames: UInt32 = 30,
    continuationWindowSeconds: Double = 1.25,
    deterministicStopCommands: Set<String> = [
      "stop", "cancel", "abort", "quit", "dur", "iptal", "vazgeç",
    ],
    deterministicPauseResumeCommands: Set<String> = [
      "pause", "resume", "continue", "duraklat", "sürdür", "devam et",
    ]
  ) {
    self.listenTimeoutSeconds = listenTimeoutSeconds
    self.thinkTimeoutSeconds = thinkTimeoutSeconds
    self.speechTimeoutSeconds = speechTimeoutSeconds
    self.bargeInGraceMilliseconds = bargeInGraceMilliseconds
    self.silenceEndFrames = silenceEndFrames
    self.continuationWindowSeconds = continuationWindowSeconds
    self.deterministicStopCommands = deterministicStopCommands
    self.deterministicPauseResumeCommands = deterministicPauseResumeCommands
  }

  public func validate() throws(AuraError) {
    guard listenTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("listenTimeoutSeconds must be positive")
    }
    guard thinkTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("thinkTimeoutSeconds must be positive")
    }
    guard speechTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("speechTimeoutSeconds must be positive")
    }
    guard bargeInGraceMilliseconds > 0 else {
      throw AuraError.invalidConfiguration("bargeInGraceMilliseconds must be positive")
    }
    guard silenceEndFrames > 0 else {
      throw AuraError.invalidConfiguration("silenceEndFrames must be positive")
    }
    guard continuationWindowSeconds > 0 else {
      throw AuraError.invalidConfiguration("continuationWindowSeconds must be positive")
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    listenTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .listenTimeoutSeconds) ?? 10.0
    thinkTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .thinkTimeoutSeconds) ?? 30.0
    speechTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .speechTimeoutSeconds) ?? 60.0
    bargeInGraceMilliseconds =
      try container.decodeIfPresent(UInt32.self, forKey: .bargeInGraceMilliseconds) ?? 500
    silenceEndFrames = try container.decodeIfPresent(UInt32.self, forKey: .silenceEndFrames) ?? 30
    continuationWindowSeconds =
      try container.decodeIfPresent(Double.self, forKey: .continuationWindowSeconds) ?? 1.25
    deterministicStopCommands =
      try container.decodeIfPresent(Set<String>.self, forKey: .deterministicStopCommands) ?? [
        "stop", "cancel", "abort", "quit", "dur", "iptal", "vazgeç",
      ]
    deterministicPauseResumeCommands =
      try container.decodeIfPresent(Set<String>.self, forKey: .deterministicPauseResumeCommands)
      ?? ["pause", "resume", "continue", "duraklat", "sürdür", "devam et"]
  }
}
