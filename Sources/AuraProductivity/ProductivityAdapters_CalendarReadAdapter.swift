import AuraCore
import AuraSecurity
import Foundation

public protocol CalendarReadAdapter: Sendable {
  func agenda(
    from start: Date,
    to end: Date,
    calendarIDs: Set<String>?
  ) async throws(ProductivityError) -> [CalendarEventSnapshot]
}
