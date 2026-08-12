import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

extension AuraAppModel {
  func openMicrophoneSettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "Microphone")
  }

  func openSpeechSettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "SpeechRecognition")
  }

  func openAccessibilitySettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "Accessibility")
  }

  func openScreenRecordingSettings() {
    PermissionCoordinator.openPrivacySettings(anchor: "ScreenCapture")
  }

  func refreshConfigurationInspection() {
    Task {
      guard let kernel else { return }
      if let inspection = await kernel.configurationInspection() {
        effectiveConfiguration = inspection.entries
        localRecommendationsEnabled =
          inspection.entries.first(where: {
            $0.key == "privacy.localRecommendationsEnabled"
          })?.value == .boolean(true)
      }
      configurationAuditCount = await kernel.configurationAuditRecords().count
    }
  }

  func setLocalRecommendationsEnabled(_ enabled: Bool) {
    Task {
      do {
        try await kernel?.setLocalRecommendationsEnabled(enabled)
        refreshConfigurationInspection()
      } catch {
        setError("Configuration change failed: \(error.localizedDescription)")
      }
    }
  }

  func quit() {
    resolveConfirmation(accepted: false)
    emergencyShortcutMonitor.stop()
    Task {
      await kernel?.stop()
      NSApplication.shared.terminate(nil)
    }
  }

  func configureConfirmationPresenter() async {
    await confirmationPresenter.setHandler { [weak self] challenge in
      guard let self else { return false }
      return await self.awaitConfirmation(challenge)
    }
  }
}
