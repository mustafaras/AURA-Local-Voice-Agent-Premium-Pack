import AuraConfig
import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

private actor MemoryConfigurationStore: ConfigurationStateStoring {
  var state: ConfigurationGovernanceState?
  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? { state }
  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) { self.state = state }
}

private func makeConfig() async throws -> ConfigurationEngine {
  try await ConfigurationEngine.load(store: MemoryConfigurationStore(), now: Date.init)
}

struct SafeModeTests {
  @Test
  func safeModeFlagDefaultsToFalse() async throws {
    let config = try await makeConfig()
    let controller = SafeModeController(configurationEngine: config)
    #expect(await controller.isSafeModeRequested() == false)
  }

  @Test
  func requestingSafeModePersists() async throws {
    let config = try await makeConfig()
    let controller = SafeModeController(configurationEngine: config)
    let requested = try await controller.setSafeModeRequested(true, reason: "test recovery")
    #expect(requested == true)
    #expect(await controller.isSafeModeRequested() == true)
    #expect(await config.effectiveValue(for: SafeModeController.safeModeRequestedKey) == .boolean(true))
  }

  @Test
  func clearingSafeModePersists() async throws {
    let config = try await makeConfig()
    let controller = SafeModeController(configurationEngine: config)
    _ = try await controller.setSafeModeRequested(true, reason: "test")
    let cleared = try await controller.setSafeModeRequested(false, reason: "test clear")
    #expect(cleared == false)
    #expect(await controller.isSafeModeRequested() == false)
  }

  @Test
  func safeModeRecordsHealthStatus() async throws {
    let config = try await makeConfig()
    let health = RuntimeHealthRegistry()
    let controller = SafeModeController(
      configurationEngine: config,
      healthRegistry: health)
    _ = try await controller.setSafeModeRequested(true, reason: "recovery")
    let snapshot = await health.snapshot()
    #expect(snapshot.contains { $0.componentID == "safe-mode" })
  }
}
