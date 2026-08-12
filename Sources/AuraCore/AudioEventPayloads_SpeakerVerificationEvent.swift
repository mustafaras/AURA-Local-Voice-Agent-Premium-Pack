import Foundation

/// Emitted when speaker verification produces an identity hint after a wake.
public struct SpeakerVerificationEvent: EventPayload {
  public static let eventType = "audio.speaker.verified"

  public let profileID: String?
  public let score: Double
  public let isMatch: Bool

  public init(profileID: String?, score: Double, isMatch: Bool) {
    self.profileID = profileID
    self.score = score
    self.isMatch = isMatch
  }
}
