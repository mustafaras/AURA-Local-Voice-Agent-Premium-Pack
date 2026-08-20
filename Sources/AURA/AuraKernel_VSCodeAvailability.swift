import AuraCore
import AuraIntent
import AuraVSCode
import Foundation

extension AuraKernel {
  /// Recompute every VS Code capability's registry availability from the live
  /// bridge health snapshot.
  ///
  /// `submitText` and `probeExternalAvailability` both call this, because any
  /// turn may be the first one after the user finishes provisioning the
  /// companion extension.
  func refreshVSCodeAvailability() async {
    guard let adapter = vscodeAdapter else {
      await runtimeHealthRegistry?.record(
        componentID: "vscode",
        status: .disabledByConfiguration,
        detail: "VS Code adapter not constructed")
      return
    }
    let health = await adapter.bridgeHealth()
    await applyVSCodeAvailability(health)
  }

  private func applyVSCodeAvailability(_ health: VSCodeBridgeHealth) async {
    guard let registry = capabilityRegistry else { return }
    let availability: CapabilityAvailability
    let runtimeStatus: RuntimeHealthStatus
    switch health.state {
    case .ready:
      availability = .ready
      runtimeStatus = .ready
    case .degraded:
      availability = .degraded(reason: "VS Code bridge degraded: \(health.detail)")
      runtimeStatus = .degraded
    case .disconnected:
      availability = .disabled(reason: "VS Code bridge disconnected: \(health.detail)")
      runtimeStatus = .dependencyMissing
    case .unauthorized:
      availability = .disabled(reason: "VS Code bridge not authenticated: \(health.detail)")
      runtimeStatus = .permissionBlocked
    case .versionMismatch:
      availability = .disabled(reason: "VS Code bridge version mismatch: \(health.detail)")
      runtimeStatus = .unsupported
    }

    for manifest in InitialCapabilitySet.vscodeCapabilityManifests() {
      await registry.setAvailability(availability, for: manifest.qualifiedID)
    }
    await runtimeHealthRegistry?.record(
      componentID: "vscode", status: runtimeStatus, detail: health.detail)
  }

  /// Convenience used by `probeExternalAvailability` to refresh VS Code state
  /// alongside productivity and Safari. This is the launch-safe post-launch
  /// probe: it only reads the Keychain if an extension ID is configured.
  func refreshVSCodeBridgeHealth() async {
    await refreshVSCodeAvailability()
  }
}

extension InitialCapabilitySet {
  fileprivate static func vscodeCapabilityManifests() -> [CapabilityManifest] {
    [
      vscodeEditorState,
      vscodeWorkspaceStatus,
      vscodeDiagnostics,
      vscodeRunTask,
      vscodeCancelTask,
      vscodeRunTests,
      vscodeCancelTests,
      vscodeTerminalSessions,
      vscodeBridgeHealth,
    ]
  }
}

extension CapabilityManifest {
  fileprivate var qualifiedID: String { "\(id)@\(version)" }
}
