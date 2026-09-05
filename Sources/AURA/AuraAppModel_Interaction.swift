import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

extension AuraAppModel {
  func requestVoicePermissions() {
    Task {
      statusDetail = "Waiting for voice permissions"
      permissions = await PermissionCoordinator.requestVoicePermissions()
      if permissions.speechReady {
        do {
          guard let kernel else {
            setError("AURA runtime is not started; voice permission setup cannot continue")
            return
          }
          try await kernel.startSpeechRecognition()
          status = .idle
          statusDetail = "Ready — use Push to Talk"
        } catch {
          setError("Speech recognition could not start: \(error.localizedDescription)")
        }
      } else {
        status = .restricted
        statusDetail = "Voice permissions are required for speech input"
      }
    }
  }

  func refreshPermissions() {
    permissions = PermissionCoordinator.snapshot()
  }

  func requestAccessibilityPermission() {
    permissions = PermissionCoordinator.requestAccessibilityPermission()
  }

  /// `preservingDetail` exists because this method is also the re-read on
  /// `setLaunchAtLogin`'s failure path. Clearing the detail unconditionally
  /// erased the message that path had just written, so a toggle that failed
  /// snapped back with **no explanation at all** — the silent failure the
  /// `catch` below is explicitly written to avoid. Found live on 2026-08-31
  /// (`EV-SP-030-20260831-R11-LIVE-GATE-01`): the UI showed an unchanged
  /// toggle and an empty detail while the underlying call had thrown.
  func refreshLaunchAtLogin(preservingDetail: String? = nil) {
    Task {
      do {
        launchAtLoginEnabled = try await kernel?.isLaunchAtLoginEnabled() ?? false
        launchAtLoginDetail = preservingDetail ?? ""
      } catch {
        // Reported, never swallowed: a silent false here would read as
        // "disabled" when the truth is "could not be determined".
        launchAtLoginDetail = error.localizedDescription
      }
    }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    // Re-entrancy guard, not just a nice-to-have: found live 2026-09-01. The
    // Settings Toggle's inline Binding(get:set:) re-invokes `set` a second
    // time before `launchAtLoginEnabled` catches up — it only updates after
    // this whole async round trip completes — and the second call's
    // awaitConfirmation immediately superseded (denied) the first call's
    // still-pending confirmation before its card ever had a chance to render.
    // The result was "was not confirmed" appearing instantly, with no card
    // visible at all. One in-flight request at a time closes that race.
    guard !isSettingLaunchAtLogin else { return }
    isSettingLaunchAtLogin = true
    Task {
      defer { isSettingLaunchAtLogin = false }
      do {
        guard let result = try await kernel?.setLaunchAtLoginEnabled(enabled) else { return }
        launchAtLoginEnabled = result.enabled
        launchAtLoginDetail = result.detail
      } catch {
        let message = error.localizedDescription
        launchAtLoginDetail = message
        // Re-read rather than assume the toggle took effect — but carry the
        // reason through, or the re-read reports success and wipes it.
        refreshLaunchAtLogin(preservingDetail: message)
      }
    }
  }

  func refreshLatencySummaries() {
    Task { latencySummaries = await kernel?.latencyPercentileSummaries() ?? [] }
  }

  func requestScreenRecordingPermission() {
    Task {
      permissions = await PermissionCoordinator.refreshScreenRecordingPermission()
      // The user's System Settings pane can show AURA's switch ON while this
      // still-running process keeps answering "denied": the toggle binds at
      // next launch. Say so instead of leaving a row that contradicts the
      // pane the user just set.
      if permissions.screenRecording != .granted {
        lastOperationMessage =
          "If the toggle is on in System Settings, quit and reopen AURA once "
          + "to pick up screen observation."
      }
    }
  }

  /// `ptt_ack` sample eligibility and elapsed time, or `nil` when the turn is
  /// not a sample at all.
  ///
  /// A turn that had to raise the OS permission prompt is **excluded**. Its
  /// window contains the user's reaction time to a modal dialog plus one-time
  /// speech-engine startup — neither is the machine latency this SLO reports,
  /// and one such sample would dominate an early percentile set. Denial
  /// already returns before the acknowledgement; *granting* did not, which is
  /// the case this guards.
  /// `nonisolated`: pure arithmetic over its arguments, touching no model
  /// state, so it carries no main-actor requirement of its own.
  nonisolated static func pushToTalkAckSample(
    pressedAt: DispatchTime,
    acknowledgedAt: DispatchTime,
    promptedForPermissions: Bool
  ) -> Double? {
    guard !promptedForPermissions else { return nil }
    return Double(
      acknowledgedAt.uptimeNanoseconds - pressedAt.uptimeNanoseconds) / 1_000_000_000
  }

  func pushToTalk() {
    // `ptt_ack` starts here, at the button press. Any later origin — the wake
    // activation, the first response plan — measures a different thing and
    // would understate what the user actually waits for.
    let pressedAt = DispatchTime.now()
    Task {
      var promptedForPermissions = false
      if !permissions.speechReady {
        promptedForPermissions = true
        // Proactively trigger the real OS permission prompt here instead of
        // only setting a passive status label — a user pressing Push to Talk
        // expects that action itself to request access, the same way it
        // would on iOS/Android, rather than needing to discover a separate
        // menu control first.
        statusDetail = "Waiting for voice permissions"
        permissions = await PermissionCoordinator.requestVoicePermissions()
        guard permissions.speechReady else {
          status = .restricted
          statusDetail = "Grant microphone and Speech Recognition access first"
          return
        }
        do {
          guard let kernel else {
            setError("AURA runtime is not started; Push to Talk cannot start")
            return
          }
          try await kernel.startSpeechRecognition()
        } catch {
          setError("Speech recognition could not start: \(error.localizedDescription)")
          return
        }
      }
      do {
        try await kernel?.activatePushToTalk()
        status = .listening
        statusDetail = "Listening on device"
        // Recorded only on the path that actually reached the listening
        // acknowledgement, and only when no permission prompt intervened.
        // A failure returns before this point; a *granted* prompt did not,
        // so the exclusion is enforced by `pushToTalkAckSample` rather than
        // by control flow.
        if let elapsed = Self.pushToTalkAckSample(
          pressedAt: pressedAt,
          acknowledgedAt: .now(),
          promptedForPermissions: promptedForPermissions)
        {
          await kernel?.recordPushToTalkAcknowledgement(seconds: elapsed)
        }
      } catch {
        setError(error.localizedDescription)
      }
    }
  }

  func submitText() {
    let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    textInput = ""
    appendConversation(.init(role: .user, text: text))
    Task {
      do {
        try await kernel?.submitText(text)
        status = .thinking
        statusDetail = "Processing typed request"
      } catch {
        setError(error.localizedDescription)
      }
    }
  }

  func triggerEmergencyStop() {
    Task {
      await kernel?.triggerEmergencyStop()
      resolveConfirmation(accepted: false, outcome: .cancelled)
      emergencyStopActive = true
      status = .stopped
      statusDetail = "Generated input is disabled until explicitly re-armed"
    }
  }

  func resetEmergencyStop() {
    Task {
      await kernel?.resetEmergencyStop()
      emergencyStopActive = false
      status = permissions.speechReady ? .idle : .restricted
      statusDetail =
        permissions.speechReady ? "Ready — use Push to Talk" : "Voice permissions required"
    }
  }

  func resolveConfirmation(
    accepted: Bool, outcome: ConfirmationResolution? = nil
  ) {
    if let challenge = pendingConfirmation {
      recordConfirmationTrace(
        challenge, outcome: outcome ?? (accepted ? .accepted : .denied))
    }
    confirmationContinuation?.resume(returning: accepted)
    confirmationContinuation = nil
    pendingConfirmation = nil
    productUIState.reduce(.hideConfirmation)
  }

  /// Fail closed when a confirmation surface goes away without an explicit
  /// answer — Escape, a drag-dismiss, a window closing.
  ///
  /// Answering through `AuraConfirmationCard` clears `pendingConfirmation`
  /// first, so this is a no-op on that path and cannot turn an *accepted*
  /// authorization into a denial. Anything else leaves the challenge pending,
  /// and an authorization the user never granted must never be treated as
  /// granted. See `EV-SP-030-20260831-R11-LIVE-GATE-03`.
  func denyConfirmationIfStillPending() {
    guard pendingConfirmation != nil else { return }
    resolveConfirmation(accepted: false, outcome: .denied)
  }

  func selectTab(_ tab: AuraProductTab) {
    productUIState.reduce(.selectTab(tab))
    persistProductUIState()
  }

  func setUILanguage(_ language: AuraUILanguage) {
    productUIState.reduce(.setLanguage(language))
    UserDefaults.standard.set(language.rawValue, forKey: "aura.ui.language")
    persistProductUIState()
    refreshProductSnapshots()
  }

  func beginOnboarding() {
    productUIState.reduce(.beginOnboarding)
    persistProductUIState()
  }

  func closeOnboarding() {
    productUIState.reduce(.closeOnboarding)
    persistProductUIState()
  }

  func advanceOnboarding() {
    productUIState.reduce(.advanceOnboarding)
    persistProductUIState()
  }

  func skipOptionalOnboardingStep() {
    productUIState.reduce(.skipOptionalOnboardingStep)
    persistProductUIState()
  }

  private func continueVoicePermissionOnboarding() {
    Task {
      permissions = await PermissionCoordinator.requestVoicePermissions()
      guard permissions.speechReady else {
        status = .restricted
        statusDetail = "Voice permissions are required before continuing"
        return
      }
      do {
        guard let kernel else {
          setError("AURA runtime is not started; voice onboarding cannot continue")
          return
        }
        try await kernel.startSpeechRecognition()
        status = .idle
        statusDetail = "Ready — use Push to Talk"
        advanceOnboarding()
      } catch {
        setError("Speech recognition could not start: \(error.localizedDescription)")
      }
    }
  }

  private func handlePrivilegedAccessOnboarding() {
    requestAccessibilityPermission()
    requestScreenRecordingPermission()
    refreshPermissions()
    guard permissions.accessibility == .granted && permissions.screenRecording == .granted else {
      lastOperationMessage =
        "Accessibility and Screen Recording remain optional; grant them in "
        + "macOS Settings, then continue."
      return
    }
    advanceOnboarding()
  }

  private func handleEmergencyStopOnboarding() {
    if emergencyStopActive {
      resetEmergencyStop()
      advanceOnboarding()
    } else {
      triggerEmergencyStop()
      lastOperationMessage = "Emergency stop is active. Press Continue to re-arm and proceed."
    }
  }

  func onboardingPrimaryAction() {
    switch productUIState.onboarding.stage {
    case .privacy, .health, .voiceTest, .ttsTest, .localModel, .integrations,
      .safeCommand, .launchAtLogin:
      advanceOnboarding()
    case .voicePermissions:
      continueVoicePermissionOnboarding()
    case .wakeWord:
      lastOperationMessage = "Wake word is optional and no acoustic model is installed."
      skipOptionalOnboardingStep()
    case .privilegedAccess:
      handlePrivilegedAccessOnboarding()
    case .emergencyStop:
      handleEmergencyStopOnboarding()
    case .complete:
      closeOnboarding()
    }
  }
}
