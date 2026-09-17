import AuraConfig
import AuraCore
import AuraLifecycle
import AuraStore
import Foundation
import Testing

// PA-2 / ADR-066 — launch at login by default under the owner posture.
//
// The posture reaches `AuraLifecycle` as a configuration value
// (`defaultEnabled`), never as an `AuraPolicy` import, so these tests pass
// `true`/`false` explicitly instead of reading `OwnerTrustPosture`.

private actor MemoryConfigurationStore: ConfigurationStateStoring {
  var state: ConfigurationGovernanceState?
  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? { state }
  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) { self.state = state }
}

private func makeConfig() async throws -> ConfigurationEngine {
  try await ConfigurationEngine.load(store: MemoryConfigurationStore(), now: Date.init)
}

private func makeController(
  service: InMemoryLaunchAtLoginService,
  defaultEnabled: Bool,
  health: RuntimeHealthRegistry? = nil
) async throws -> LaunchAtLoginController {
  LaunchAtLoginController(
    service: service,
    configurationEngine: try await makeConfig(),
    healthRegistry: health,
    defaultEnabled: defaultEnabled)
}

struct PA2LaunchAtLoginDefaultTests {
  // MARK: - Status raw values are the ServiceManagement contract

  @Test
  func statusRawValuesMatchSMAppServiceStatus() {
    // SMAppService.Status (ServiceManagement/SMAppService.h, NS_ENUM order):
    // notRegistered = 0, enabled = 1, requiresApproval = 2, notFound = 3.
    #expect(LaunchAtLoginStatus(rawValue: 0) == .notRegistered)
    #expect(LaunchAtLoginStatus(rawValue: 1) == .enabled)
    #expect(LaunchAtLoginStatus(rawValue: 2) == .requiresApproval)
    #expect(LaunchAtLoginStatus(rawValue: 3) == .notFound)
    #expect(LaunchAtLoginStatus(rawValue: 99) == nil)
  }

  @Test
  func inMemoryServiceUsesTheSameRawValues() {
    #expect(InMemoryLaunchAtLoginService(registered: true).statusRawValue == 1)
    #expect(InMemoryLaunchAtLoginService(registered: false).statusRawValue == 0)
    let approval = InMemoryLaunchAtLoginService(registered: false)
    approval.setSimulatedStatusRawValue(2)
    #expect(approval.statusRawValue == 2)
  }

  // MARK: - Default-on behind the posture value

  @Test
  func unsetPreferenceFollowsTheInjectedDefault() async throws {
    let on = try await makeController(
      service: InMemoryLaunchAtLoginService(), defaultEnabled: true)
    #expect(await on.userPreferenceEnabled() == true)

    let off = try await makeController(
      service: InMemoryLaunchAtLoginService(), defaultEnabled: false)
    #expect(await off.userPreferenceEnabled() == false)
  }

  @Test
  func explicitUserOffBeatsDefaultOn() async throws {
    let config = try await makeConfig()
    let controller = LaunchAtLoginController(
      service: InMemoryLaunchAtLoginService(),
      configurationEngine: config,
      defaultEnabled: true)
    _ = try await config.apply(
      ConfigurationPatch(
        layer: .userSettings,
        values: [LaunchAtLoginController.userPreferenceKey: .boolean(false)],
        source: "test"),
      actor: .user)
    #expect(await controller.userPreferenceEnabled() == false)
  }

  // MARK: - Idempotent post-start registration

  @Test
  func ensureRegisteredAtLaunchRegistersOnceThenReportsUnchanged() async throws {
    let service = InMemoryLaunchAtLoginService(registered: false)
    let health = RuntimeHealthRegistry()
    let controller = try await makeController(
      service: service, defaultEnabled: true, health: health)

    let first = await controller.ensureRegisteredAtLaunch()
    #expect(first.enabled == true)
    #expect(first.changed == true)
    #expect(first.serviceStatus == .enabled)
    #expect(service.registered == true)
    #expect(service.registerCallCount == 1)

    let second = await controller.ensureRegisteredAtLaunch()
    #expect(second.changed == false)
    #expect(second.serviceStatus == .enabled)
    #expect(service.registerCallCount == 1)
    #expect(await health.health(for: "launch-at-login")?.status == .ready)
  }

  @Test
  func ensureRegisteredAtLaunchDoesNothingWhenPreferenceIsOff() async throws {
    let service = InMemoryLaunchAtLoginService(registered: false)
    let controller = try await makeController(service: service, defaultEnabled: false)

    let result = await controller.ensureRegisteredAtLaunch()
    #expect(result.enabled == false)
    #expect(result.changed == false)
    #expect(service.registered == false)
    #expect(service.registerCallCount == 0)
  }

  @Test
  func ensureRegisteredAtLaunchDoesNotPersistASessionOverride() async throws {
    // The default supplies `true`; writing it as a session override would
    // outrank the user's later `false` in `userSettings` for the rest of the
    // session. The launch hook must therefore leave the preference layers alone.
    let config = try await makeConfig()
    let service = InMemoryLaunchAtLoginService(registered: false)
    let controller = LaunchAtLoginController(
      service: service, configurationEngine: config, defaultEnabled: true)

    _ = await controller.ensureRegisteredAtLaunch()
    let entry = await config.inspect().entries.first {
      $0.key == LaunchAtLoginController.userPreferenceKey
    }
    #expect(entry?.sourceLayer == .secureDefaults)

    // Off switch: the user's `false` wins immediately and unregisters.
    let off = try await controller.setEnabled(false, actor: .user)
    #expect(off.changed == true)
    #expect(service.registered == false)
    #expect(await controller.userPreferenceEnabled() == false)
    let again = await controller.ensureRegisteredAtLaunch()
    #expect(again.changed == false)
    #expect(service.registered == false)
  }

  // MARK: - .requiresApproval is recorded, not worked around

  @Test
  func requiresApprovalIsReportedHonestlyAndNotReRegistered() async throws {
    let service = InMemoryLaunchAtLoginService(registered: false)
    service.setSimulatedStatusRawValue(2)
    let health = RuntimeHealthRegistry()
    let controller = try await makeController(
      service: service, defaultEnabled: true, health: health)

    #expect(await controller.serviceStatus() == .requiresApproval)
    let result = await controller.ensureRegisteredAtLaunch()
    #expect(result.enabled == true)
    #expect(result.changed == false)
    #expect(result.serviceStatus == .requiresApproval)
    #expect(service.registerCallCount == 0)
    #expect(await health.health(for: "launch-at-login")?.status == .requiresUserAction)
  }

  @Test
  func registerThatLandsInRequiresApprovalIsReportedAsUnchanged() async throws {
    let service = InMemoryLaunchAtLoginService(registered: false)
    service.setStatusRawValueAfterRegister(2)
    let health = RuntimeHealthRegistry()
    let controller = try await makeController(
      service: service, defaultEnabled: true, health: health)

    let result = await controller.ensureRegisteredAtLaunch()
    #expect(service.registerCallCount == 1)
    #expect(result.changed == false)
    #expect(result.serviceStatus == .requiresApproval)
    #expect(await health.health(for: "launch-at-login")?.status == .requiresUserAction)
  }

  @Test
  func registrationFailureAtLaunchIsRecordedNotThrown() async throws {
    let service = InMemoryLaunchAtLoginService(registered: false)
    service.setSimulateRegisterError(AuraError.lifecycleError("simulated failure"))
    let health = RuntimeHealthRegistry()
    let controller = try await makeController(
      service: service, defaultEnabled: true, health: health)

    let result = await controller.ensureRegisteredAtLaunch()
    #expect(result.changed == false)
    #expect(result.serviceStatus == .notRegistered)
    #expect(result.detail.contains("simulated failure"))
    #expect(await health.health(for: "launch-at-login")?.status == .failed)
  }
}
