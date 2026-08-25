import AuraCore
import Foundation

extension ToolRouter {
  /// Largest number of unconsumed observations retained. Observations are
  /// normally taken by the dispatch coordinator on the same turn they are
  /// produced; the cap bounds the map when a caller routes without ever
  /// collecting (plan execution, fixtures, adversarial tests).
  static var maxRetainedToolObservations: Int { 16 }

  /// Record what a tool observed on this turn. Overwrites any earlier
  /// observation for the same intent — one intent yields at most one fact.
  func recordToolObservation(_ observation: ToolObservation, intentID: UUID) {
    recentToolObservations[intentID] = observation
    guard recentToolObservations.count > Self.maxRetainedToolObservations else { return }
    let sorted = recentToolObservations.sorted { $0.value.observedAt < $1.value.observedAt }
    for (key, _) in sorted.prefix(recentToolObservations.count - Self.maxRetainedToolObservations) {
      recentToolObservations.removeValue(forKey: key)
    }
  }

  /// Consume the observation for one intent, if the tool produced one.
  /// Taking removes it: an observation is evidence for exactly one memory
  /// write, never replayed into a later turn.
  public func takeToolObservation(intentID: UUID) -> ToolObservation? {
    recentToolObservations.removeValue(forKey: intentID)
  }
}
