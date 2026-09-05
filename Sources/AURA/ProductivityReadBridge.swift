import AuraCore
import AuraIntent
import AuraProductivity
import Foundation

/// The only place adapter output crosses into the decision layer.
///
/// Everything private stops here. Addresses become fingerprints, provider
/// text is bounded and secret-scrubbed by `ProductivityRedaction.boundedText`,
/// and a `ProductivityError` becomes a `diagnostic(for:)` string rather than
/// the `errorDescription` a person would read in a dialog — which
/// interpolates every candidate address for `accountAmbiguous`.
///
/// The bridge also refuses to read a capability that is not currently
/// available. The router already checks registry availability, so this is the
/// second of two independent checks: registry state can be stale between
/// refreshes, and a revoked credential has to fail on the read rather than on
/// the last snapshot.
struct ProductivityReadBridge: ProductivityReading {
  let runtime: ProductivityRuntime

  func readActiveBrowserTab(
    profileID: String?
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    let snapshot = await runtime.browserSnapshot()
    if let blocked = Self.blocking(snapshot) { return .failure(blocked) }
    guard let bridge = runtime.safariBridge else {
      return .failure(.notConfigured(reason: "the Chrome bridge is not composed"))
    }
    // A stated profile that is not the approved one is refused rather than
    // silently redirected to whichever profile happens to be approved.
    if let profileID, profileID != bridge.profile.profileID {
      return .failure(
        .ambiguous(question: "Which Chrome profile should I read? Only one is approved."))
    }
    do {
      let tab = try await bridge.adapter.readActiveTab()
      let title = ProductivityRedaction.boundedText(tab.title.text)
      let host = tab.url.host ?? "the current page"
      return .success(
        ProductivityReadResult(
          capabilityID: InitialCapabilitySet.browserRead.id,
          itemCount: 1,
          summary: "The active page on \(host) is titled “\(title)”.",
          sourceFingerprint: ProductivityRedaction.fingerprint(tab.profileID)))
    } catch {
      return .failure(Self.failure(from: error))
    }
  }

  func searchMail(
    accountID: String?,
    query: String,
    limit: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    let snapshot = await runtime.mailSnapshot()
    if let blocked = Self.blocking(snapshot) { return .failure(blocked) }
    guard let mail = runtime.mail else {
      return .failure(.notConfigured(reason: "no mail account is connected"))
    }
    let approved = await runtime.onboarding.approvedAccountIDs()
    let resolved: String
    switch (accountID, approved.count) {
    case (let stated?, _):
      guard approved.contains(stated) else {
        return .failure(.ambiguous(question: "That account is not one you have approved."))
      }
      resolved = stated
    case (nil, 1):
      resolved = approved[0]
    default:
      return .failure(
        .ambiguous(question: "Which of your approved mail accounts should I search?"))
    }
    do {
      let headers = try await mail.search(accountID: resolved, query: query, limit: limit)
      // Only subjects are summarized. Bodies, senders, and recipients stay in
      // the adapter: a match count and a few subjects answer "did anything
      // arrive" without moving message content into a prompt or an event.
      let subjects =
        headers
        .prefix(3)
        .map { "“\(ProductivityRedaction.boundedText($0.subject.text, limit: 80))”" }
        .joined(separator: ", ")
      let summary =
        headers.isEmpty
        ? "No messages matched."
        : "\(headers.count) message(s) matched: \(subjects)."
      return .success(
        ProductivityReadResult(
          capabilityID: InitialCapabilitySet.mailRead.id,
          itemCount: headers.count,
          summary: summary,
          sourceFingerprint: ProductivityRedaction.fingerprint(resolved)))
    } catch {
      return .failure(Self.failure(from: error))
    }
  }

  func summarizeMailThread(
    accountID: String?,
    query: String
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    let snapshot = await runtime.mailSnapshot()
    if let blocked = Self.blocking(snapshot) { return .failure(blocked) }
    guard let mail = runtime.mail else {
      return .failure(.notConfigured(reason: "no mail account is connected"))
    }
    let resolved: String
    switch await resolveMailAccount(accountID) {
    case .success(let account):
      resolved = account
    case .failure(let failure):
      return .failure(failure)
    }
    do {
      let headers = try await mail.search(accountID: resolved, query: query, limit: 10)
      guard let first = headers.first else {
        return .success(
          ProductivityReadResult(
            capabilityID: InitialCapabilitySet.mailRead.id,
            itemCount: 0,
            summary: "No thread matched.",
            sourceFingerprint: ProductivityRedaction.fingerprint(resolved)))
      }
      // `readThread` screens every subject and body as untrusted mail
      // content. A single blocked message rejects the whole thread before
      // anything crosses this bridge.
      let thread = try await mail.readThread(accountID: resolved, threadID: first.threadID)
      var uniqueSubjects: [String] = []
      for message in thread.messages {
        let subject = ProductivityRedaction.boundedText(message.header.subject.text, limit: 80)
        if !uniqueSubjects.contains(subject) { uniqueSubjects.append(subject) }
      }
      let subjectSummary = uniqueSubjects.prefix(3).map { "“\($0)”" }.joined(separator: ", ")
      let summary =
        subjectSummary.isEmpty
        ? "The matched thread contains \(thread.messages.count) message(s)."
        : "The matched thread contains \(thread.messages.count) message(s): \(subjectSummary)."
      return .success(
        ProductivityReadResult(
          capabilityID: InitialCapabilitySet.mailRead.id,
          itemCount: thread.messages.count,
          summary: summary,
          sourceFingerprint: ProductivityRedaction.fingerprint(resolved)))
    } catch {
      return .failure(Self.failure(from: error))
    }
  }

  func readCalendarAgenda(
    dayRange: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    let snapshot = runtime.calendarSnapshot()
    if let blocked = Self.blocking(snapshot) { return .failure(blocked) }
    guard let calendar = runtime.calendar else {
      return .failure(.notConfigured(reason: "calendar reading is not enabled"))
    }
    let boundedDays = min(max(dayRange, 1), 31)
    let start = Calendar.current.startOfDay(for: Date())
    guard let end = Calendar.current.date(byAdding: .day, value: boundedDays, to: start) else {
      return .failure(.failed(reason: "the requested date range could not be computed"))
    }
    do {
      let events = try await calendar.agenda(from: start, to: end, calendarIDs: nil)
      let titles =
        events
        .prefix(3)
        .map { ProductivityRedaction.boundedText($0.title.text, limit: 80) }
        .joined(separator: ", ")
      let summary =
        events.isEmpty
        ? "Nothing is scheduled in that range."
        : "\(events.count) event(s): \(titles)."
      return .success(
        ProductivityReadResult(
          capabilityID: InitialCapabilitySet.calendarRead.id,
          itemCount: events.count,
          summary: summary,
          sourceFingerprint: ProductivityRedaction.fingerprint("local-calendar")))
    } catch {
      return .failure(Self.failure(from: error))
    }
  }

  /// "When am I free?" — the other half of SP-011's `agenda/free-window` leg.
  ///
  /// It runs the same authorization check and the same EventKit read as the
  /// agenda, then reports the gaps instead of the events. Free windows carry
  /// no titles, locations, or attendees, so this answer is strictly less
  /// revealing than the agenda one it is derived from.
  func readCalendarFreeWindows(
    dayRange: Int,
    minimumMinutes: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    let snapshot = runtime.calendarSnapshot()
    if let blocked = Self.blocking(snapshot) { return .failure(blocked) }
    guard let calendar = runtime.calendar else {
      return .failure(.notConfigured(reason: "calendar reading is not enabled"))
    }
    let boundedDays = min(max(dayRange, 1), 31)
    let boundedMinutes = min(max(minimumMinutes, 5), 480)
    // The window opens now, not at midnight: a gap that has already passed is
    // not free time, and reporting it is how a scheduling answer becomes
    // actively misleading.
    let now = Date()
    let dayStart = Calendar.current.startOfDay(for: now)
    guard let end = Calendar.current.date(byAdding: .day, value: boundedDays, to: dayStart),
      end > now
    else {
      return .failure(.failed(reason: "the requested date range could not be computed"))
    }
    do {
      let events = try await calendar.agenda(from: now, to: end, calendarIDs: nil)
      let windows = CalendarFreeWindows.windows(
        between: now,
        and: end,
        busy: events.map(\.range),
        minimumDuration: TimeInterval(boundedMinutes * 60))
      let summary = Self.freeWindowSummary(windows, minimumMinutes: boundedMinutes)
      return .success(
        ProductivityReadResult(
          capabilityID: InitialCapabilitySet.calendarRead.id,
          itemCount: windows.count,
          summary: summary,
          sourceFingerprint: ProductivityRedaction.fingerprint("local-calendar")))
    } catch {
      return .failure(Self.failure(from: error))
    }
  }

  /// At most three windows, so a wide-open week reports "free all day"-shaped
  /// guidance rather than reciting every gap.
  private static func freeWindowSummary(
    _ windows: [CalendarFreeWindow],
    minimumMinutes: Int
  ) -> String {
    guard !windows.isEmpty else {
      return "No free window of at least \(minimumMinutes) minutes in that range."
    }
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = windows.contains { !Calendar.current.isDateInToday($0.start) }
      ? .short : .none
    let described =
      windows
      .prefix(3)
      .map { "\(formatter.string(from: $0.start))–\(formatter.string(from: $0.end))" }
      .joined(separator: ", ")
    let suffix = windows.count > 3 ? " (and \(windows.count - 3) more)" : ""
    return "\(windows.count) free window(s): \(described)\(suffix)."
  }

  func lookupContacts(
    query: String,
    limit: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    let snapshot = runtime.contactsSnapshot()
    if let blocked = Self.blocking(snapshot) { return .failure(blocked) }
    guard let contacts = runtime.contacts else {
      return .failure(.notConfigured(reason: "contacts lookup is not enabled"))
    }
    do {
      let resolution = try await contacts.lookup(query: query, limit: limit)
      guard !resolution.candidates.isEmpty else {
        return .success(
          ProductivityReadResult(
            capabilityID: InitialCapabilitySet.contactsLookup.id,
            itemCount: 0,
            summary: "No contact matched that name.",
            sourceFingerprint: ProductivityRedaction.fingerprint("local-contacts")))
      }
      // Several matches is a question, not a result: picking one would be a
      // guess, and the details of the others are nobody's business here.
      if resolution.requiresClarification {
        return .failure(
          .ambiguous(
            question:
              "\(resolution.candidates.count) contacts match that name. Which one do you mean?"))
      }
      let candidate = resolution.candidates[0]
      // The name is shown; addresses and phone numbers are counted, never
      // spoken back — the user asked to find a contact, not to broadcast one.
      let name = ProductivityRedaction.boundedText(candidate.displayName.text, limit: 80)
      return .success(
        ProductivityReadResult(
          capabilityID: InitialCapabilitySet.contactsLookup.id,
          itemCount: 1,
          summary:
            "One contact matched: \(name) "
            + "(\(candidate.emailAddresses.count) email, "
            + "\(candidate.phoneNumbers.count) phone on file).",
          sourceFingerprint: ProductivityRedaction.fingerprint(candidate.id)))
    } catch {
      return .failure(Self.failure(from: error))
    }
  }

  // MARK: - Shared mapping

  private func resolveMailAccount(
    _ accountID: String?
  ) async -> Result<String, ProductivityReadFailure> {
    let approved = await runtime.onboarding.approvedAccountIDs()
    switch (accountID, approved.count) {
    case (let stated?, _):
      guard approved.contains(stated) else {
        return .failure(.ambiguous(question: "That account is not one you have approved."))
      }
      return .success(stated)
    case (nil, 1):
      return .success(approved[0])
    default:
      return .failure(
        .ambiguous(question: "Which of your approved mail accounts should I search?"))
    }
  }

  /// Turn an unavailable snapshot into the matching refusal, carrying the
  /// remediation so the conversation can tell the user what to do next.
  private static func blocking(
    _ snapshot: ProductivityIntegrationSnapshot
  ) -> ProductivityReadFailure? {
    switch snapshot.availability {
    case .ready:
      return nil
    case .disabled(let reason):
      return .notConfigured(reason: Self.joined(reason, snapshot.remediation))
    case .degraded(let reason):
      return .unavailable(reason: Self.joined(reason, snapshot.remediation))
    }
  }

  private static func joined(_ reason: String, _ remediation: String) -> String {
    remediation.isEmpty ? reason : "\(reason) \(remediation)"
  }

  private static func failure(from error: any Error) -> ProductivityReadFailure {
    guard let productivityError = error as? ProductivityError else {
      // An unexpected error type must not have its raw description relayed:
      // it could carry a URL, a path, or provider text.
      return .failed(reason: "the integration failed for an unrecognized reason")
    }
    let diagnostic = ProductivityRedaction.diagnostic(for: productivityError)
    switch productivityError {
    case .accountAmbiguous, .profileAmbiguous:
      return .ambiguous(question: "Which approved account or profile should I use?")
    case .notConfigured, .permissionRequired:
      return .notConfigured(reason: diagnostic)
    case .permissionDenied, .oauthTokenExchangeRejected, .tokenExpiredOrRevoked,
      .networkUnavailable, .providerUnavailable, .insufficientScope, .hostNotAllowed,
      .invalidRedirect:
      return .unavailable(reason: diagnostic)
    case .privacyBlocked, .invalidInput, .unsupported, .cancelled:
      return .failed(reason: diagnostic)
    }
  }
}
