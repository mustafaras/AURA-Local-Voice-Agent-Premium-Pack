import AuraConfig
import AuraCore
import AuraLifecycle
import AuraSecurity
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

struct LaunchAtLoginTests {
  @Test
  func inMemoryServiceReportsStatus() {
    let enabled = InMemoryLaunchAtLoginService(registered: true)
    #expect(enabled.statusRawValue == 1)
    let disabled = InMemoryLaunchAtLoginService(registered: false)
    #expect(disabled.statusRawValue == 3)
  }

  @Test
  func setEnabledPersistsPreferenceAndMutatesService() async throws {
    let config = try await makeConfig()
    let service = InMemoryLaunchAtLoginService(registered: false)
    let controller = LaunchAtLoginController(
      service: service,
      configurationEngine: config)

    let result = try await controller.setEnabled(true)
    #expect(result.enabled == true)
    #expect(result.serviceStatus == LaunchAtLoginStatus.enabled)
    #expect(result.changed == true)
    #expect(service.registered == true)
    #expect(await config.effectiveValue(for: LaunchAtLoginController.userPreferenceKey) == .boolean(true))
  }

  @Test
  func setDisabledUnregistersService() async throws {
    let config = try await makeConfig()
    let service = InMemoryLaunchAtLoginService(registered: true)
    let controller = LaunchAtLoginController(
      service: service,
      configurationEngine: config)

    let result = try await controller.setEnabled(false)
    #expect(result.enabled == false)
    #expect(result.serviceStatus == LaunchAtLoginStatus.notRegistered)
    #expect(result.changed == true)
    #expect(service.registered == false)
  }

  @Test
  func noOpWhenAlreadyInRequestedState() async throws {
    let config = try await makeConfig()
    let service = InMemoryLaunchAtLoginService(registered: true)
    let controller = LaunchAtLoginController(
      service: service,
      configurationEngine: config)

    _ = try await controller.setEnabled(true)
    let result = try await controller.setEnabled(true)
    #expect(result.changed == false)
  }

  @Test
  func registrationErrorPropagatesAsAuraError() async throws {
    let config = try await makeConfig()
    let service = InMemoryLaunchAtLoginService(registered: false)
    service.setSimulateRegisterError(AuraError.lifecycleError("simulated failure"))
    let controller = LaunchAtLoginController(
      service: service,
      configurationEngine: config)

    await #expect(throws: AuraError.self) {
      try await controller.setEnabled(true)
    }
  }
}
