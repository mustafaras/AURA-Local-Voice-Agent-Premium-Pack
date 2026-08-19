import AuraCore
import Foundation

/// An unscheduled interval inside a bounded search range.
public struct CalendarFreeWindow: Sendable, Equatable {
  public let start: Date
  public let end: Date

  public init(start: Date, end: Date) {
    self.start = start
    self.end = end
  }

  public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Derives free windows from an agenda that has already been read.
///
/// "When am I free?" is named in SP-011's live matrix, and answering it needs
/// no data beyond the agenda the `calendar.read` capability already returns.
/// Inverting busy time here rather than adding a capability keeps the
/// permission surface unchanged: the same authorization, the same EventKit
/// call, one more shape of answer. It mirrors how `mail.read` serves both a
/// search and a thread summary through one capability.
///
/// The derivation is pure so it is covered without EventKit, a live calendar,
/// or a granted TCC prompt.
public enum CalendarFreeWindows {
  /// Free windows inside `start..<end`, longest-first ordering not applied —
  /// the result is chronological, because "when am I free" is a question about
  /// the order of the day.
  ///
  /// Busy ranges may arrive unsorted, overlapping, nested, or extending past
  /// either bound; all four are normalized rather than trusted. A range that
  /// lies entirely outside the search interval contributes nothing.
  public static func windows(
    between start: Date,
    and end: Date,
    busy: [CalendarTimeRange],
    minimumDuration: TimeInterval
  ) -> [CalendarFreeWindow] {
    guard end > start else { return [] }
    let floor = max(minimumDuration, 0)

    // Clamp to the search interval first, so an all-day or multi-day event
    // cannot push a window boundary outside the range the caller asked about.
    let clamped =
      busy
      .map { (lower: max($0.start, start), upper: min($0.end, end)) }
      .filter { $0.lower < $0.upper }
      .sorted { $0.lower < $1.lower }

    var free: [CalendarFreeWindow] = []
    var cursor = start
    for interval in clamped {
      if interval.lower > cursor {
        append(&free, from: cursor, to: interval.lower, floor: floor)
      }
      // `max` rather than assignment: a nested event ends before one already
      // consumed, and moving the cursor backwards would invent a free window
      // inside a meeting.
      cursor = max(cursor, interval.upper)
    }
    if cursor < end {
      append(&free, from: cursor, to: end, floor: floor)
    }
    return free
  }

  private static func append(
    _ windows: inout [CalendarFreeWindow],
    from start: Date,
    to end: Date,
    floor: TimeInterval
  ) {
    let window = CalendarFreeWindow(start: start, end: end)
    guard window.duration >= floor, window.duration > 0 else { return }
    windows.append(window)
  }
}
