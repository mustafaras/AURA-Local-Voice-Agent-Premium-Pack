import AVFAudio
import AppKit
@preconcurrency import ApplicationServices
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

struct PermissionSnapshot: Sendable {
  var microphone: PermissionState
  var speechRecognition: PermissionState
  var accessibility: PermissionState
  var screenRecording: PermissionState

  var speechReady: Bool {
    microphone == .granted && speechRecognition == .granted
  }
}

enum PermissionCoordinator {
  static func snapshot() -> PermissionSnapshot {
    PermissionSnapshot(
      microphone: microphoneState(),
      speechRecognition: speechState(),
      accessibility: AXIsProcessTrusted() ? .granted : .denied,
      screenRecording: CGPreflightScreenCaptureAccess() ? .granted : .denied)
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
