import AuraCore
import Contacts
import EventKit
import Foundation

/// The user's current authorization for a native data source.
///
/// Kept separate from `ProductivityError` because these are *states*, not
/// failures: "not determined" is the normal state of a fresh install and must
/// be presented as "you can grant this", never as an error.
public enum ProductivityAuthorizationState: String, Sendable, Equatable, CaseIterable {
  case authorized
  case notDetermined
  case denied
  case restricted
  /// The framework reported a value this build does not recognize. Treated as
  /// unusable, never as authorized.
  case unavailable
}

/// Read-only authorization probes for the native calendar and contacts
/// sources.
///
/// `EventKitCalendarReadAdapter` and `ContactsFrameworkLookupAdapter` keep
/// their equivalent checks private and surface them only by throwing during a
/// read. That is right for the read path and useless for the health path: the
/// capability registry has to state whether `calendar.read` is usable
/// *before* anyone asks for an agenda, and it must not trigger a permission
/// prompt to find out. These probes read the current status only — they never
/// request access, which stays an explicit onboarding action.
public enum ProductivityAuthorizationProbe {
  public static func calendarState() -> ProductivityAuthorizationState {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .fullAccess, .authorized:
      return .authorized
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    // Write-only calendar access cannot satisfy a read capability. Reporting
    // it as `denied` keeps `calendar.read` honestly unusable rather than
    // "authorized" for an authority that cannot read an event.
    case .writeOnly:
      return .denied
    case .restricted:
      return .restricted
    @unknown default:
      return .unavailable
    }
  }

  public static func contactsState() -> ProductivityAuthorizationState {
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .authorized, .limited:
      return .authorized
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .restricted:
      return .restricted
    @unknown default:
      return .unavailable
    }
  }
}
