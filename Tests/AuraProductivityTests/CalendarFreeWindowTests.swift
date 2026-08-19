import AuraCore
import Foundation
import Testing

@testable import AuraProductivity

/// SP-011's live matrix names `agenda/free-window`. The agenda half was live
/// before this suite existed; the free-window half had no implementation at
/// all — `CalendarReadAdapter` exposed only `agenda(from:to:calendarIDs:)`.
///
/// These cases cover the derivation itself, which is pure, so the behaviour is
/// pinned without EventKit, a real calendar, or a granted TCC prompt.
struct CalendarFreeWindowTests {
  private let day = Date(timeIntervalSince1970: 1_760_000_000)

  private func at(_ hours: Double) -> Date {
    day.addingTimeInterval(hours * 3600)
  }

  private func busy(_ from: Double, _ to: Double) throws -> CalendarTimeRange {
    try CalendarTimeRange(start: at(from), end: at(to))
  }

  @Test("an empty calendar is one free window covering the range")
  func emptyCalendarIsWideOpen() {
    let windows = CalendarFreeWindows.windows(
      between: at(9), and: at(17), busy: [], minimumDuration: 0)
    #expect(windows.count == 1)
    #expect(windows.first?.start == at(9))
    #expect(windows.first?.end == at(17))
  }

  @Test("gaps between meetings are reported in chronological order")
  func gapsBetweenMeetings() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(10, 11), try busy(13, 14)],
      minimumDuration: 0)
    #expect(windows.map(\.start) == [at(9), at(11), at(14)])
    #expect(windows.map(\.end) == [at(10), at(13), at(17)])
  }

  /// Unsorted input is what an adapter actually returns once more than one
  /// calendar is involved; sorting inside the derivation is what keeps the
  /// caller from having to know that.
  @Test("unsorted busy ranges still produce correct gaps")
  func unsortedInput() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(13, 14), try busy(10, 11)],
      minimumDuration: 0)
    #expect(windows.map(\.start) == [at(9), at(11), at(14)])
  }

  @Test("overlapping meetings collapse into one busy block")
  func overlappingMeetings() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(10, 12), try busy(11, 13)],
      minimumDuration: 0)
    #expect(windows.map(\.start) == [at(9), at(13)])
  }

  /// The failure this guards against is specific: a short meeting nested
  /// inside a long one moves the cursor backwards, and the derivation invents
  /// a free window that sits inside the longer meeting.
  @Test("a meeting nested inside another never invents free time")
  func nestedMeetingDoesNotInventFreeTime() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(10, 15), try busy(11, 12)],
      minimumDuration: 0)
    #expect(windows.map(\.start) == [at(9), at(15)])
    #expect(windows.allSatisfy { $0.end <= at(10) || $0.start >= at(15) })
  }

  @Test("an all-day event clamped to the range leaves nothing free")
  func allDayEventFillsTheRange() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(-12, 36)],
      minimumDuration: 0)
    #expect(windows.isEmpty)
  }

  @Test("events entirely outside the range are ignored")
  func eventsOutsideRangeAreIgnored() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(2, 4), try busy(20, 22)],
      minimumDuration: 0)
    #expect(windows.count == 1)
    #expect(windows.first?.start == at(9))
    #expect(windows.first?.end == at(17))
  }

  @Test("gaps shorter than the minimum are not offered")
  func minimumDurationFiltersShortGaps() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(9),
      and: at(17),
      busy: [try busy(9, 11), try busy(11.25, 17)],
      minimumDuration: 30 * 60)
    #expect(windows.isEmpty)
  }

  @Test("an inverted or empty range yields no windows")
  func invertedRangeYieldsNothing() {
    #expect(
      CalendarFreeWindows.windows(
        between: at(17), and: at(9), busy: [], minimumDuration: 0
      ).isEmpty)
    #expect(
      CalendarFreeWindows.windows(
        between: at(9), and: at(9), busy: [], minimumDuration: 0
      ).isEmpty)
  }

  @Test("windows never overlap each other")
  func windowsAreDisjoint() throws {
    let windows = CalendarFreeWindows.windows(
      between: at(0),
      and: at(24),
      busy: [try busy(1, 3), try busy(2, 5), try busy(9, 9.5), try busy(20, 26)],
      minimumDuration: 0)
    for (earlier, later) in zip(windows, windows.dropFirst()) {
      #expect(earlier.end <= later.start)
    }
  }
}
