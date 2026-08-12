import Foundation

/// Emitted when a speaker verification profile is enrolled or updated.
public struct SpeakerEnrollmentEvent: EventPayload {
  public static let eventType = "audio.speaker.enrollment"

  public let profileID: String
  public let samplesEnrolled: UInt32

  public init(profileID: String, samplesEnrolled: UInt32) {
    self.profileID = profileID
    self.samplesEnrolled = samplesEnrolled
  }
}
