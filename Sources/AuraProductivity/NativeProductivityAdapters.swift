import AuraCore
import AuraSecurity
import Contacts
import EventKit
import Foundation

/// Structured local calendar adapter. It never requests permission as a side
/// effect of a read; onboarding calls `requestReadAccess()` explicitly.
public actor EventKitCalendarReadAdapter: CalendarReadAdapter {
  private let eventStore: EKEventStore
  private let classifier: PromptInjectionClassifier

  public init(
    eventStore: EKEventStore = EKEventStore(),
    classifier: PromptInjectionClassifier = PromptInjectionClassifier()
  ) {
    self.eventStore = eventStore
    self.classifier = classifier
  }

  public func requestReadAccess() async throws(ProductivityError) -> Bool {
    do {
      return try await eventStore.requestFullAccessToEvents()
    } catch {
      throw .permissionDenied
    }
  }

  public func agenda(
    from start: Date,
    to end: Date,
    calendarIDs: Set<String>? = nil
  ) async throws(ProductivityError) -> [CalendarEventSnapshot] {
    guard end > start else {
      throw .invalidInput("calendar range end must be after start")
    }
    try requireReadAuthorization()
    let calendars = eventStore.calendars(for: .event).filter { calendar in
      calendarIDs?.contains(calendar.calendarIdentifier) ?? true
    }
    let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
    return eventStore.events(matching: predicate).compactMap { event in
      guard let eventID = event.eventIdentifier, let eventStart = event.startDate,
        let eventEnd = event.endDate
      else { return nil }
      let title = ExternalContent(
        sourceID: "calendar:\(eventID):title",
        text: event.title ?? "",
        provenance: .eventContent,
        classifier: classifier)
      let location = event.location.map {
        ExternalContent(
          sourceID: "calendar:\(eventID):location",
          text: $0,
          provenance: .eventContent,
          classifier: classifier)
      }
      let recurrence = event.recurrenceRules?.first.map {
        ExternalContent(
          sourceID: "calendar:\(eventID):recurrence",
          text: $0.description,
          provenance: .eventContent,
          classifier: classifier)
      }
      guard !title.isBlocked, !(location?.isBlocked ?? false), !(recurrence?.isBlocked ?? false)
      else {
        return nil
      }
      guard let range = try? CalendarTimeRange(start: eventStart, end: eventEnd) else {
        return nil
      }
      return CalendarEventSnapshot(
        id: eventID,
        calendarID: event.calendar.calendarIdentifier,
        title: title,
        range: range,
        timeZoneIdentifier: event.timeZone?.identifier,
        location: location,
        recurrenceDescription: recurrence)
    }
  }

  private func requireReadAuthorization() throws(ProductivityError) {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .fullAccess, .authorized:
      return
    case .notDetermined:
      throw .permissionRequired
    case .writeOnly, .denied, .restricted:
      throw .permissionDenied
    @unknown default:
      throw .permissionDenied
    }
  }
}

/// Structured, candidate-only Contacts adapter. It asks for no permission
/// during lookup and returns only the fields needed to resolve the request.
public actor ContactsFrameworkLookupAdapter: ContactsLookupAdapter {
  private let contactStore: CNContactStore
  private let classifier: PromptInjectionClassifier

  public init(
    contactStore: CNContactStore = CNContactStore(),
    classifier: PromptInjectionClassifier = PromptInjectionClassifier()
  ) {
    self.contactStore = contactStore
    self.classifier = classifier
  }

  public func requestReadAccess() async throws(ProductivityError) -> Bool {
    do {
      return try await contactStore.requestAccess(for: .contacts)
    } catch {
      throw .permissionDenied
    }
  }

  public func lookup(
    query: String,
    limit: Int = 5
  ) async throws(ProductivityError) -> ScopedContactResolution {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedQuery.isEmpty else {
      throw .invalidInput("contact lookup query must not be empty")
    }
    let boundedLimit = min(max(limit, 1), 10)
    try requireReadAuthorization()

    let keys: [CNKeyDescriptor] = [
      CNContactIdentifierKey as CNKeyDescriptor,
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
    ]
    let request = CNContactFetchRequest(keysToFetch: keys)
    request.predicate = CNContact.predicateForContacts(matchingName: normalizedQuery)
    var candidates: [ContactCandidate] = []
    do {
      try contactStore.enumerateContacts(with: request) { [classifier] contact, stop in
        guard candidates.count < boundedLimit else {
          stop.pointee = true
          return
        }
        let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        let content = ExternalContent(
          sourceID: "contact:\(contact.identifier):name",
          text: displayName,
          provenance: .contactRecord,
          classifier: classifier)
        guard !content.isBlocked else { return }
        candidates.append(
          ContactCandidate(
            id: contact.identifier,
            displayName: content,
            emailAddresses: contact.emailAddresses.map { String($0.value) },
            phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue }))
      }
    } catch {
      throw .providerUnavailable
    }
    return ScopedContactResolution(query: normalizedQuery, candidates: candidates)
  }

  private func requireReadAuthorization() throws(ProductivityError) {
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .authorized, .limited:
      return
    case .notDetermined:
      throw .permissionRequired
    case .denied, .restricted:
      throw .permissionDenied
    @unknown default:
      throw .permissionDenied
    }
  }
}
