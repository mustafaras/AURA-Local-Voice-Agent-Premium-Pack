import AVFAudio
import AppKit
@preconcurrency import ApplicationServices
import Contacts
import EventKit
import Foundation
import Speech

enum PermissionState: String, Sendable {
  case granted
  case denied
  case notDetermined
  case restricted
  case unavailable

  /// Localized, following the `AuraAppStatus.title(for:)` precedent. There is
  /// deliberately no unlocalized `title` left behind: this value is read out to
  /// VoiceOver on the surface that tells a user whether AURA can hear them, and
  /// an English-only overload is exactly how that regressed before.
  func title(for language: AuraUILanguage) -> String {
    switch self {
    case .granted: AuraCopy.text("perm.granted", language: language)
    case .denied: AuraCopy.text("perm.denied", language: language)
    case .notDetermined: AuraCopy.text("perm.notRequested", language: language)
    case .restricted: AuraCopy.text("perm.restricted", language: language)
    case .unavailable: AuraCopy.text("perm.unavailable", language: language)
    }
  }
}

/// The six macOS permissions the product needs, in the order the single
/// consent pass requests them (ADR-065 §3). All six belong to the main app
/// process — see `personal-assistant-plan/evidence/PA-1/permission-map.md`.
enum PermissionKind: String, CaseIterable, Sendable {
  case microphone
  case speechRecognition
  case accessibility
  case screenRecording
  case calendar
  case contacts

  var copyKey: String {
    switch self {
    case .microphone: "perm.microphone"
    case .speechRecognition: "perm.speechRecognition"
    case .accessibility: "perm.accessibility"
    case .screenRecording: "perm.screenRecording"
    case .calendar: "perm.calendar"
    case .contacts: "perm.contacts"
    }
  }

  /// The `x-apple.systempreferences` Privacy anchor for the fallback button.
  var settingsAnchor: String {
    switch self {
    case .microphone: "Microphone"
    case .speechRecognition: "SpeechRecognition"
    case .accessibility: "Accessibility"
    case .screenRecording: "ScreenCapture"
    case .calendar: "Calendars"
    case .contacts: "Contacts"
    }
  }
}

struct PermissionSnapshot: Sendable, Equatable {
  var microphone: PermissionState
  var speechRecognition: PermissionState
  var accessibility: PermissionState
  var screenRecording: PermissionState
  /// ADR-065 §3: Calendars and Contacts join the snapshot so the consent pass
  /// and the indicators cover every permission the product uses.
  var calendar: PermissionState = .notDetermined
  var contacts: PermissionState = .notDetermined

  var speechReady: Bool {
    microphone == .granted && speechRecognition == .granted
  }

  func state(for kind: PermissionKind) -> PermissionState {
    switch kind {
    case .microphone: microphone
    case .speechRecognition: speechRecognition
    case .accessibility: accessibility
    case .screenRecording: screenRecording
    case .calendar: calendar
    case .contacts: contacts
    }
  }

  /// Every permission granted — the state the single consent pass aims for.
  var allGranted: Bool {
    PermissionKind.allCases.allSatisfy { state(for: $0) == .granted }
  }

  /// Permissions macOS will still prompt for (never asked yet).
  var undetermined: [PermissionKind] {
    PermissionKind.allCases.filter { state(for: $0) == .notDetermined }
  }
}

enum PermissionCoordinator {
  static func snapshot() -> PermissionSnapshot {
    PermissionSnapshot(
      microphone: microphoneState(),
      speechRecognition: speechState(),
      accessibility: AXIsProcessTrusted() ? .granted : .denied,
      screenRecording: CGPreflightScreenCaptureAccess() ? .granted : .denied,
      calendar: calendarState(),
      contacts: contactsState())
  }

  /// ADR-065 §3 — the single consent pass. Requests, in order, every
  /// permission macOS has not yet decided: Microphone, Speech Recognition,
  /// Accessibility, Screen Recording, Calendars, Contacts. Already-decided
  /// permissions are never re-requested (macOS would not prompt anyway; the
  /// UI hands the user the System Settings pane instead). Each request is
  /// awaited before the next so the prompts arrive one at a time.
  static func requestAllPermissions() async -> PermissionSnapshot {
    _ = await requestVoicePermissions()
    if !AXIsProcessTrusted() {
      _ = requestAccessibilityPermission()
    }
    if !CGPreflightScreenCaptureAccess() {
      _ = CGRequestScreenCaptureAccess()
    }
    _ = await requestCalendarPermission()
    _ = await requestContactsPermission()
    return snapshot()
  }

  static func requestCalendarPermission() async -> PermissionSnapshot {
    if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
      _ = try? await EKEventStore().requestFullAccessToEvents()
    }
    return snapshot()
  }

  static func requestContactsPermission() async -> PermissionSnapshot {
    if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
      _ = try? await CNContactStore().requestAccess(for: .contacts)
    }
    return snapshot()
  }

  static func requestVoicePermissions() async -> PermissionSnapshot {
    if AVAudioApplication.shared.recordPermission == .undetermined {
      _ = await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
          continuation.resume(returning: granted)
        }
      }
    }
    if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
      _ = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status)
        }
      }
    }
    return snapshot()
  }

  static func requestAccessibilityPermission() -> PermissionSnapshot {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    return snapshot()
  }

  static func requestScreenRecordingPermission() -> PermissionSnapshot {
    if !CGPreflightScreenCaptureAccess() {
      _ = CGRequestScreenCaptureAccess()
    }
    return snapshot()
  }

  /// Re-read the screen-recording state after the user has (possibly) flipped
  /// the toggle in System Settings.
  ///
  /// Two macOS behaviors make a plain re-read insufficient:
  /// 1. The TCC toggle takes effect for a running process only after it
  ///    restarts — the preflight keeps answering "denied" for the current
  ///    process even when the pane shows the switch on.
  /// 2. The request API returns immediately, so a snapshot taken in the same
  ///    run-loop turn races the system's own bookkeeping.
  /// A short bounded settle, then a fresh preflight, keeps the indicator from
  /// showing a state one toggle older than the pane. If the preflight still
  /// says denied after a grant, the remediation is a restart — which the UI
  /// states, instead of silently showing a stale row.
  static func refreshScreenRecordingPermission() async -> PermissionSnapshot {
    if !CGPreflightScreenCaptureAccess() {
      _ = CGRequestScreenCaptureAccess()
      try? await Task.sleep(nanoseconds: 500_000_000)
    }
    return snapshot()
  }

  @MainActor
  static func openPrivacySettings(anchor: String) {
    guard
      let url = URL(
        string:
          "x-apple.systempreferences:com.apple.preference.security?Privacy_\(anchor)")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private static func microphoneState() -> PermissionState {
    switch AVAudioApplication.shared.recordPermission {
    case .granted: .granted
    case .denied: .denied
    case .undetermined: .notDetermined
    @unknown default: .unavailable
    }
  }

  private static func calendarState() -> PermissionState {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .fullAccess, .authorized: .granted
    case .writeOnly: .restricted
    case .denied: .denied
    case .notDetermined: .notDetermined
    case .restricted: .restricted
    @unknown default: .unavailable
    }
  }

  private static func contactsState() -> PermissionState {
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .authorized, .limited: .granted
    case .denied: .denied
    case .notDetermined: .notDetermined
    case .restricted: .restricted
    @unknown default: .unavailable
    }
  }

  private static func speechState() -> PermissionState {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized: .granted
    case .denied: .denied
    case .notDetermined: .notDetermined
    case .restricted: .restricted
    @unknown default: .unavailable
    }
  }
}
