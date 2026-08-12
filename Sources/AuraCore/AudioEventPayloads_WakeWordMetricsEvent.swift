import Foundation

/// Emitted to report wake-word pipeline metrics (false accept/false reject
/// counters, etc.). May be emitted from a background actor and is purely
/// diagnostic.
public struct WakeWordMetricsEvent: EventPayload {
  public static let eventType = "audio.wake.metrics"

  public let falseAccepts: UInt64
  public let falseRejects: UInt64
  public let antiTriggerSuppressions: UInt64
  public let totalHypotheses: UInt64

  public init(
    falseAccepts: UInt64,
    falseRejects: UInt64,
    antiTriggerSuppressions: UInt64,
    totalHypotheses: UInt64
  ) {
    self.falseAccepts = falseAccepts
    self.falseRejects = falseRejects
    self.antiTriggerSuppressions = antiTriggerSuppressions
    self.totalHypotheses = totalHypotheses
  }
}
