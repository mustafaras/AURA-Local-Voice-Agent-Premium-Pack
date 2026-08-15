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

  func requestScreenRecordingPermission() {
    permissions = PermissionCoordinator.requestScreenRecordingPermission()
  }

  func pushToTalk() {
    Task {
      if !permissions.speechReady {
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
