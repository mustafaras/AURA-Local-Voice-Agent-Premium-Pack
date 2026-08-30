import AuraCore
import Foundation

// MARK: - Content-free aggregate telemetry events (SP-029)

/// Session-outcome bucket: count of `completed`, `degraded`, `blocked`, or
/// `user_stopped` sessions. No transcript, prompt, model output, or content is
/// carried — only the bucket identifier and a unit count.
public enum TelemetrySessionOutcomeBucket: String, Codable, Sendable, Equatable, CaseIterable {
  case completed
  case degraded
  case blocked
  case userStopped = "user_stopped"
}

/// Confirmation-outcome bucket: count of `allowed`, `denied`, `expired`, or
/// `dismissed` policy confirmations. No target, plan, or action is carried.
public enum TelemetryConfirmationOutcomeBucket: String, Codable, Sendable, Equatable, CaseIterable {
  case allowed
  case denied
  case expired
  case dismissed
}

/// Recovery-outcome bucket: count of `clean_shutdown`, `crash_detected`,
/// `recovered`, or `safe_mode_entered` lifecycle events. No diagnostics are
/// carried.
public enum TelemetryRecoveryOutcomeBucket: String, Codable, Sendable, Equatable, CaseIterable {
  case cleanShutdown = "clean_shutdown"
  case crashDetected = "crash_detected"
  case recovered
  case safeModeEntered = "safe_mode_entered"
}

/// Resource-pressure class bucket. Derived from an already-bounded health
/// classification; no raw thermal or memory numbers are carried.
public enum TelemetryResourcePressureClass: String, Codable, Sendable, Equatable, CaseIterable {
  case nominal
  case light
  case heavy
  case critical
}

/// A single content-free, monotonic latency sample input (in milliseconds).
/// The aggregator buckets these by percentile band and never stores an exact
/// timestamp that could identify a user activity.
public struct TelemetryLatencySample: Codable, Sendable, Equatable {
  /// One of the latency fields in `beta-readiness.json`'s `aggregate_fields`:
  /// `ptt_ack`, `stt_partial`, `dialogue_first_token`.
  public let field: String
  public let milliseconds: Double
  public let correlationID: UUID

  public init(field: String, milliseconds: Double, correlationID: UUID = UUID()) {
    self.field = field
    self.milliseconds = milliseconds
    self.correlationID = correlationID
  }
}

/// A content-free aggregate event emitted by `TelemetryAggregator` only when
/// opt-in aggregate telemetry is enabled. The payload carries only a field
/// name, a bucket, and a count.
public struct TelemetryAggregateEvent: EventPayload {
  public static let eventType = "lifecycle.telemetry.aggregate.bumped"

  public let field: String
  public let bucket: String
  public let count: Int
  public let day: String

  public init(field: String, bucket: String, count: Int, day: String) {
    self.field = field
    self.bucket = bucket
    self.count = count
    self.day = day
  }
}
