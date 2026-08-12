import AuraCore
import AuraSecurity
import Foundation

// MARK: - Calendar and contacts ports

public struct CalendarEventSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let calendarID: String
  public let title: ExternalContent
  public let range: CalendarTimeRange
  public let timeZoneIdentifier: String?
  public let location: ExternalContent?
  public let recurrenceDescription: ExternalContent?

  public init(
    id: String,
    calendarID: String,
    title: ExternalContent,
    range: CalendarTimeRange,
    timeZoneIdentifier: String?,
    location: ExternalContent? = nil,
    recurrenceDescription: ExternalContent? = nil
  ) {
    self.id = id
    self.calendarID = calendarID
    self.title = title
    self.range = range
    self.timeZoneIdentifier = timeZoneIdentifier
    self.location = location
    self.recurrenceDescription = recurrenceDescription
  }
}
