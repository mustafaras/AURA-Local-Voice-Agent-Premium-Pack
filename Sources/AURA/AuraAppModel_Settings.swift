import AppKit
import AuraAgent
import AuraConfig
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation

extension AuraAppModel {
  var isVSCodeBridgeAcceptanceEnabled: Bool {
    ProcessInfo.processInfo.environment["AURA_SP012_LIVE_ACCEPTANCE"] == "1"
  }

  var vscodeBridgeExtensionID: String {
    ProcessInfo.processInfo.environment["AURA_SP012_EXTENSION_ID"]
      ?? "ai.aura.vscode-bridge"
  }

  func refreshVSCodeBridgeProvisioning() {
    Task { @MainActor in
      guard let kernel else {
        isVSCodeBridgeProvisioned = false
        return
      }
      do {
        isVSCodeBridgeProvisioned = try await kernel.vscodeBridgeProvisioned()
      } catch {
        isVSCodeBridgeProvisioned = false
      }
    }
  }

  /// Stores only the user-entered secret in AURA's Keychain. The transient
  /// field is cleared before the asynchronous call and is never persisted or
  /// included in a status message.
  func provisionVSCodeBridge() {
    let secret = vscodeBridgeSecret
    vscodeBridgeSecret = ""
    guard secret.utf8.count >= 16 else {
      lastOperationMessage = "VS Code bridge secret must be at least 16 characters."
      return
    }
    Task { @MainActor in
      do {
        guard let kernel else { throw AuraError.invalidConfiguration("AURA runtime is not started") }
        try await kernel.provisionVSCodeBridge(
          sharedSecret: secret, extensionID: vscodeBridgeExtensionID)
        isVSCodeBridgeProvisioned = try await kernel.vscodeBridgeProvisioned()
        lastOperationMessage = "VS Code bridge secret stored in AURA Keychain."
      } catch {
        isVSCodeBridgeProvisioned = false
        lastOperationMessage = "VS Code bridge provisioning failed: \(error.localizedDescription)"
      }
    }
  }

  /// Runs the narrow, read-only live acceptance probe without surfacing any
  /// editor path, document text, or signed payload detail in the UI.
  func readVSCodeEditorState() {
    vscodeBridgeRoundTripStatus = "Reading VS Code editor state..."
    Task { @MainActor in
      guard let kernel else {
        vscodeBridgeRoundTripStatus = "AURA runtime is not started."
        return
      }
      let result = await kernel.readVSCodeEditorState()
      switch result {
      case .success(let response):
        vscodeBridgeRoundTripStatus = response.editor == nil
          ? "Authenticated bridge responded; no active editor state was reported."
          : "Authenticated VS Code editor-state round trip completed."
      case .failure(let error):
        vscodeBridgeRoundTripStatus =
          "VS Code editor-state round trip failed: \(error.localizedDescription)"
      }
    }
  }

  func revokeVSCodeBridge() {
    Task { @MainActor in
      do {
        guard let kernel else { throw AuraError.invalidConfiguration("AURA runtime is not started") }
        try await kernel.revokeVSCodeBridge(extensionID: vscodeBridgeExtensionID)
        isVSCodeBridgeProvisioned = false
        lastOperationMessage = "VS Code bridge secret revoked from AURA Keychain."
    } catch {
      lastOperationMessage = "VS Code bridge revocation failed: \(error.localizedDescription)"
    }
  }
  }

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
    resolveConfirmation(accepted: false, outcome: .dismissed)
    emergencyShortcutMonitor.stop()
    Task {
      await kernel?.stop()
      NSApplication.shared.terminate(nil)
    }
  }

  /// WindowGroup close is a SwiftUI scene-lifecycle event and does not call
  /// the application menu's explicit quit action. Preserve the same
  /// fail-closed, redacted dismissal outcome on that user-visible path.
  func dismissPendingConfirmationForWindowClose() {
    guard pendingConfirmation != nil else { return }
    resolveConfirmation(accepted: false, outcome: .dismissed)
  }

  func configureConfirmationPresenter() async {
    await confirmationPresenter.setHandler { [weak self] challenge in
      guard let self else { return false }
      return await self.awaitConfirmation(challenge)
    }
  }
}
