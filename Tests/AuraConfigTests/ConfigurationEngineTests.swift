import AuraConfig
import AuraCore
import AuraStore
import Foundation
import Testing

private actor MemoryConfigurationStore: ConfigurationStateStoring {
  var state: ConfigurationGovernanceState?
  var failWrites = false

  init(state: ConfigurationGovernanceState? = nil) {
    self.state = state
  }

  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? {
    state
  }

  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) {
    if failWrites {
      throw AuraError.storeError("injected atomic persistence failure")
    }
    self.state = state
  }

  func setFailWrites(_ value: Bool) {
    failWrites = value
  }
}

private final class TestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date

  init(_ value: Date) {
    self.value = value
  }

  func now() -> Date {
    lock.withLock { value }
  }

  func advance(_ seconds: TimeInterval) {
    lock.withLock { value = value.addingTimeInterval(seconds) }
  }
}

private func engine(
  store: MemoryConfigurationStore = MemoryConfigurationStore(),
  clock: TestClock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
) async throws -> ConfigurationEngine {
  try await ConfigurationEngine.load(store: store, now: clock.now)
}

@Test
func layersResolveInNormativeOrderAndCanBeRevoked() async throws {
  let subject = try await engine()
  for (layer, value) in [
    (ConfigurationLayer.machinePolicy, 18),
    (.userSettings, 16),
    (.projectSettings, 14),
    (.sessionOverrides, 12),
  ] {
    let result = try await subject.apply(
      ConfigurationPatch(
        layer: layer,
        values: ["audio.vad.silenceEndFrames": .integer(value)],
        source: "test"))
    #expect(result.accepted)
  }
  #expect(await subject.effectiveValue(for: "audio.vad.silenceEndFrames") == .integer(12))
  try await subject.revokeOverrides(layer: .sessionOverrides)
  #expect(await subject.effectiveValue(for: "audio.vad.silenceEndFrames") == .integer(14))
}

@Test
func projectConfigurationCannotWeakenHigherRiskPolicy() async throws {
  let subject = try await engine()
  let result = try await subject.apply(
    ConfigurationPatch(
      layer: .projectSettings,
      values: ["policy.maximumAllowByDefaultRisk": .integer(3)],
      source: "untrusted repository"))
  #expect(!result.accepted)
  #expect(result.warnings.first?.contains("would weaken") == true)
  #expect(await subject.effectiveValue(for: "policy.maximumAllowByDefaultRisk") == .integer(0))
}

@Test
func projectConfigurationMayStrengthenConfirmationBoundary() async throws {
  let subject = try await engine()
  let result = try await subject.apply(
    ConfigurationPatch(
      layer: .projectSettings,
      values: ["policy.minimumConfirmationRisk": .integer(3)],
      source: "repository hardening"))
  #expect(result.accepted)
  #expect(await subject.effectiveValue(for: "policy.minimumConfirmationRisk") == .integer(3))
}

@Test
func machinePolicySecurityBoundCannotBeRelaxedByUserOrSession() async throws {
  let subject = try await engine()
  #expect(
    try await subject.apply(
      ConfigurationPatch(
        layer: .machinePolicy,
        values: ["models.maxConcurrentLocalModels": .integer(1)],
        source: "managed policy")
    ).accepted)
  let user = try await subject.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: ["models.maxConcurrentLocalModels": .integer(2)],
      source: "user"))
  let session = try await subject.apply(
    ConfigurationPatch(
      layer: .sessionOverrides,
      values: ["models.maxConcurrentLocalModels": .integer(3)],
      source: "session"))
  #expect(!user.accepted)
  #expect(!session.accepted)
}

@Test
func unknownKeysAreRejectedWarnedAndAudited() async throws {
  let subject = try await engine()
  let result = try await subject.apply(
    ConfigurationPatch(
      layer: .projectSettings, values: ["unknown.secret.switch": .boolean(true)],
      source: "repository"))
  #expect(!result.accepted)
  #expect(result.warnings == ["unknown configuration key ignored: unknown.secret.switch"])
  #expect(await subject.inspect().unknownKeyWarnings == result.warnings)
  #expect(await subject.auditRecords().last?.accepted == false)
}

@Test
func persistenceFailureNeverMakesCandidateEffective() async throws {
  let store = MemoryConfigurationStore()
  let subject = try await engine(store: store)
  await store.setFailWrites(true)
  await #expect(throws: AuraError.self) {
    try await subject.apply(
      ConfigurationPatch(
        layer: .userSettings,
        values: ["audio.vad.silenceEndFrames": .integer(10)],
        source: "test"))
  }
  #expect(await subject.effectiveValue(for: "audio.vad.silenceEndFrames") == .integer(20))
}

@Test
func rollbackSurvivesStoreAndEngineRestart() async throws {
  let path = FileManager.default.temporaryDirectory
    .appendingPathComponent("aura-config-\(UUID().uuidString).sqlite").path
  let auraStore = try await AuraStore(path: path)
  let stateStore = AuraStoreConfigurationStateStore(store: auraStore)
  let subject = try await ConfigurationEngine.load(store: stateStore)
  _ = try await subject.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: ["audio.vad.silenceEndFrames": .integer(11)],
      source: "first"))
  let restorePoint = try #require(await subject.snapshots().first)
  _ = try await subject.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: ["audio.vad.silenceEndFrames": .integer(7)],
      source: "second"))
  try await subject.rollback(to: restorePoint.id)

  let reloaded = try await ConfigurationEngine.load(
    store: AuraStoreConfigurationStateStore(store: auraStore))
  #expect(await reloaded.effectiveValue(for: "audio.vad.silenceEndFrames") == .integer(20))
}

@Test
func featureFlagsRequireCompleteFutureDatedGovernanceMetadata() async throws {
  let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
  let subject = try await engine(clock: clock)
  let result = try await subject.registerFeatureFlag(
    FeatureFlagDefinition(
      key: "voice.experimental",
      owner: "",
      purpose: "",
      expiresAt: clock.now().addingTimeInterval(-1),
      defaultEnabled: false,
      rollbackPlan: ""))
  #expect(!result.accepted)
  #expect(result.warnings.count == 4)
}

@Test
func expiredFlagAndKillSwitchOverrideEveryOtherDecision() async throws {
  let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
  let subject = try await engine(clock: clock)
  let flag = FeatureFlagDefinition(
    key: "voice.experimental",
    owner: "Voice",
    purpose: "Bounded experiment",
    expiresAt: clock.now().addingTimeInterval(60),
    defaultEnabled: true,
    rollbackPlan: "Disable and use Kaan")
  #expect(try await subject.registerFeatureFlag(flag).accepted)
  try await subject.setFeatureFlagOverride(
    key: flag.key, enabled: true, userID: "local-user")
  try await subject.setFeatureFlagKillSwitch(key: flag.key, engaged: true)
  #expect(
    await subject.evaluateFeatureFlag(
      flag.key, context: FeatureFlagContext(userID: "local-user")
    ).reason == .killSwitch)
  try await subject.setFeatureFlagKillSwitch(key: flag.key, engaged: false)
  clock.advance(61)
  #expect(await subject.evaluateFeatureFlag(flag.key).reason == .expired)
  #expect(!(await subject.evaluateFeatureFlag(flag.key).enabled))
}

@Test
func projectOverrideCannotEnableGovernedOffFlag() async throws {
  let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
  let subject = try await engine(clock: clock)
  _ = try await subject.registerFeatureFlag(
    FeatureFlagDefinition(
      key: "unsafe.project.experiment",
      owner: "Security",
      purpose: "Disabled experiment",
      expiresAt: clock.now().addingTimeInterval(300),
      defaultEnabled: false,
      rollbackPlan: "Keep disabled"))
  await #expect(throws: AuraError.self) {
    try await subject.setFeatureFlagOverride(
      key: "unsafe.project.experiment", enabled: true, projectID: "untrusted-project")
  }
}

@Test
func registryMayExplicitlyPermitOrdinaryProjectOptIn() async throws {
  let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
  let subject = try await engine(clock: clock)
  _ = try await subject.registerFeatureFlag(
    FeatureFlagDefinition(
      key: "ui.compact.status",
      owner: "UI",
      purpose: "Project-scoped presentation experiment",
      expiresAt: clock.now().addingTimeInterval(300),
      defaultEnabled: false,
      rollbackPlan: "Use standard status view",
      projectMayEnable: true))
  try await subject.setFeatureFlagOverride(
    key: "ui.compact.status", enabled: true, projectID: "project")
  #expect(
    await subject.evaluateFeatureFlag(
      "ui.compact.status", context: FeatureFlagContext(projectID: "project")
    ).enabled)
}

@Test
func rolloutAssignmentIsStableAndBounded() async throws {
  let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
  let subject = try await engine(clock: clock)
  _ = try await subject.registerFeatureFlag(
    FeatureFlagDefinition(
      key: "safe.rollout",
      owner: "Runtime",
      purpose: "A/B-safe local rollout",
      expiresAt: clock.now().addingTimeInterval(300),
      defaultEnabled: true,
      rollbackPlan: "Engage kill switch",
      rolloutPercentage: 50))
  let context = FeatureFlagContext(userID: "stable-local-identity")
  let first = await subject.evaluateFeatureFlag("safe.rollout", context: context)
  let second = await subject.evaluateFeatureFlag("safe.rollout", context: context)
  #expect(first == second)
  #expect(first.reason == .rolloutIncluded || first.reason == .rolloutExcluded)
}

@Test
func telemetryIsAggregateOnlyAndRequiresExplicitOptIn() async throws {
  let subject = try await engine()
  await #expect(throws: AuraError.self) {
    try await subject.recordMetric(.latencySeconds, value: 0.8)
  }
  _ = try await subject.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: ["privacy.localRecommendationsEnabled": .boolean(true)],
      source: "explicit test opt-in"))
  try await subject.recordMetric(.latencySeconds, value: 0.8)
  let audit = await subject.auditRecords()
  #expect(audit.last?.detail.contains("no raw content retained") == true)
}

@Test
func recommendationIsExplainableAndNeverAppliesWithoutAcceptance() async throws {
  let subject = try await engine()
  _ = try await subject.apply(
    ConfigurationPatch(
      layer: .userSettings,
      values: ["privacy.localRecommendationsEnabled": .boolean(true)],
      source: "explicit test opt-in"))
  for value in [0.8, 0.9, 1.0] {
    try await subject.recordMetric(.latencySeconds, value: value)
  }
  let recommendations = try await subject.generateRecommendations()
  let recommendation = try #require(recommendations.first)
  #expect(recommendation.explanation.contains("3 samples"))
  #expect(await subject.effectiveValue(for: recommendation.key) == .integer(20))
  let result = try await subject.acceptRecommendation(id: recommendation.id)
  #expect(result.accepted)
  #expect(await subject.effectiveValue(for: recommendation.key) == .integer(18))
}

@Test
func reversibleMigrationRenamesKeysAndPreservesCompatibilitySnapshot() async throws {
  let oldDefinition = ConfigurationKeyDefinition(
    key: "old.frames", purpose: "old", defaultValue: .integer(20),
    minimumNumber: 1, maximumNumber: 100)
  let oldSchema = ConfigurationSchema(version: "0.9.0", definitions: [oldDefinition])
  var oldState = ConfigurationGovernanceState(schema: oldSchema)
  oldState.layers[.userSettings] = ["old.frames": .integer(9)]
  let store = MemoryConfigurationStore(state: oldState)
  let newDefinition = ConfigurationKeyDefinition(
    key: "new.frames", purpose: "new", defaultValue: .integer(20),
    minimumNumber: 1, maximumNumber: 100)
  let newSchema = ConfigurationSchema(version: "1.0.0", definitions: [newDefinition])
  let migration = ConfigurationMigration(
    fromVersion: "0.9.0", toVersion: "1.0.0", renamedKeys: ["old.frames": "new.frames"])
  let subject = try await ConfigurationEngine.load(
    schema: newSchema, store: store, migrations: [migration])
  #expect(await subject.effectiveValue(for: "new.frames") == .integer(9))
  #expect(await subject.snapshots().first?.schemaVersion == "0.9.0")
  #expect(await store.state?.migrationHistory == ["0.9.0->1.0.0"])
}

@Test
func migrationCanReverseWithinCompatibilityWindow() async throws {
  let newDefinition = ConfigurationKeyDefinition(
    key: "new.frames", purpose: "new", defaultValue: .integer(20),
    minimumNumber: 1, maximumNumber: 100)
  let newSchema = ConfigurationSchema(version: "1.0.0", definitions: [newDefinition])
  var newState = ConfigurationGovernanceState(schema: newSchema)
  newState.layers[.userSettings] = ["new.frames": .integer(8)]
  let store = MemoryConfigurationStore(state: newState)
  let oldDefinition = ConfigurationKeyDefinition(
    key: "old.frames", purpose: "old", defaultValue: .integer(20),
    minimumNumber: 1, maximumNumber: 100)
  let oldSchema = ConfigurationSchema(version: "0.9.0", definitions: [oldDefinition])
  let migration = ConfigurationMigration(
    fromVersion: "0.9.0", toVersion: "1.0.0", renamedKeys: ["old.frames": "new.frames"])
  let subject = try await ConfigurationEngine.load(
    schema: oldSchema, store: store, migrations: [migration])
  #expect(await subject.effectiveValue(for: "old.frames") == .integer(8))
  #expect(await store.state?.migrationHistory == ["1.0.0->0.9.0"])
}

@Test
func sessionOverridesExpireOnRestartButRemainAudited() async throws {
  let store = MemoryConfigurationStore()
  let first = try await engine(store: store)
  _ = try await first.apply(
    ConfigurationPatch(
      layer: .sessionOverrides,
      values: ["audio.vad.silenceEndFrames": .integer(6)],
      source: "ephemeral test"))
  #expect(await first.effectiveValue(for: "audio.vad.silenceEndFrames") == .integer(6))
  let second = try await engine(store: store)
  #expect(await second.effectiveValue(for: "audio.vad.silenceEndFrames") == .integer(20))
  #expect(await second.auditRecords().last?.action == "session.expire")
}
