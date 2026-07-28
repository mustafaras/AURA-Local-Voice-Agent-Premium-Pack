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

  var title: String {
    switch self {
    case .granted: "Granted"
    case .denied: "Denied"
    case .notDetermined: "Not requested"
    case .restricted: "Restricted"
    case .unavailable: "Unavailable"
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
