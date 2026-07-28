import AuraCore
import AuraPlugins
import AuraPolicy
import AuraStore
import CryptoKit
import Foundation
import Testing

private actor RecordingRuntimeHost: PluginRuntimeHosting {
  private(set) var calls = 0

  func execute(
    manifest: PluginManifest,
    artifactURL: URL,
    request: PluginRuntimeRequest
  ) async throws(AuraError) -> PluginRuntimeResponse {
    calls += 1
    return PluginRuntimeResponse(
      nonce: request.nonce, sandboxAttested: true, output: Data("runtime-ok".utf8))
  }
}

private func makePhase23Registry(
  fixture: SignedPluginFixture,
  engine: PolicyEngine,
  store: AuraStore? = nil,
  artifactStore: PluginArtifactStore? = nil,
  runtimeHost: (any PluginRuntimeHosting)? = nil
) async throws -> PluginRegistry {
  let trust = PluginTrustRegistry(
    keysByVendor: [fixture.manifest.vendorName: fixture.privateKey.publicKey])
  return try await PluginRegistry(
    verifier: PluginVerifier(trustRegistry: trust),
    policyEngine: engine,
    store: store,
    artifactStore: artifactStore,
    runtimeHost: runtimeHost)
}

private func makeArtifactStore() throws -> PluginArtifactStore {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  return try PluginArtifactStore(rootDirectory: root)
}

@Test
func manifestRejectsImplicitOrAnyCapabilityScope() {
  let hash = String(repeating: "a", count: 64)
  let signature = Data(repeating: 0, count: 64).base64EncodedString()
  let empty = PluginManifest(
    id: "com.example.empty", version: "1.0.0", vendorName: "Vendor",
    capabilities: [.fileRead], requiredPermissions: [],
    contentHashSHA256Hex: hash, signatureBase64: signature)
  let any = PluginManifest(
    id: "com.example.any", version: "1.0.0", vendorName: "Vendor",
    capabilities: [.fileRead], requiredPermissions: [.any],
    contentHashSHA256Hex: hash, signatureBase64: signature)

  #expect(throws: AuraError.self) { try empty.validate() }
  #expect(throws: AuraError.self) { try any.validate() }
}

@Test
func manifestMigrationNotesAndKeyIDAreSignatureBound() {
  let fixture = PluginFixtures.makeSignedManifest(vendorName: "TrustedVendor")
  let trust = PluginTrustRegistry(
    keysByVendor: [fixture.manifest.vendorName: fixture.privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: trust)
  let keySpoof = PluginManifest(
    id: fixture.manifest.id,
    version: fixture.manifest.version,
    vendorName: fixture.manifest.vendorName,
    vendorKeyID: "rotated",
    capabilities: fixture.manifest.capabilities,
    requiredPermissions: fixture.manifest.requiredPermissions,
    migrationNotes: fixture.manifest.migrationNotes,
    contentHashSHA256Hex: fixture.manifest.contentHashSHA256Hex,
    signatureBase64: fixture.manifest.signatureBase64)

  #expect(
    verifier.verify(manifest: keySpoof, bundleData: fixture.bundleData) == .untrustedVendor)
  let migrationTamper = PluginManifest(
    id: fixture.manifest.id,
    version: fixture.manifest.version,
    vendorName: fixture.manifest.vendorName,
    capabilities: fixture.manifest.capabilities,
    requiredPermissions: fixture.manifest.requiredPermissions,
    migrationNotes: "run attacker migration",
    contentHashSHA256Hex: fixture.manifest.contentHashSHA256Hex,
    signatureBase64: fixture.manifest.signatureBase64)
  #expect(
    verifier.verify(manifest: migrationTamper, bundleData: fixture.bundleData)
      == .signatureInvalid)
}

@Test
func pluginGrantsAreScopedToPluginActorAndHaveExpiry() async throws {
  let fixture = PluginFixtures.makeSignedManifest(capabilities: [.appActivate])
  let store = try await makeTestStore()
  let engine = try await makeTestPolicyEngine(
    store: store, allowByDefaultTiers: [.observation])
  let registry = try await makePhase23Registry(fixture: fixture, engine: engine, store: store)
  _ = try await registry.install(manifest: fixture.manifest, bundleData: fixture.bundleData)

  let pluginDecision = await engine.evaluate(
    PolicyEvaluationRequest(
      capability: .appActivate,
      actor: .plugin,
      target: PolicyTarget(directoryPath: "/tmp/aura-plugin-tests"),
      sessionID: UUID(),
      correlationID: UUID(),
      causationID: UUID()))
  guard case .allow = pluginDecision else {
    Issue.record("expected actor-scoped plugin grant to allow the plugin")
    return
  }
  let userDecision = await engine.evaluate(
    PolicyEvaluationRequest(
      capability: .appActivate,
      actor: .user,
      target: PolicyTarget(directoryPath: "/tmp/aura-plugin-tests"),
      sessionID: UUID(),
      correlationID: UUID(),
      causationID: UUID()))
  guard case .deny = userDecision else {
    Issue.record("plugin grant must not authorize the user actor")
    return
  }

  let json = try #require(await store.value(forKey: "aura.policy.grants"))
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let grants = try decoder.decode([Grant].self, from: Data(json.utf8))
  let pluginGrant = try #require(grants.first { $0.purpose.hasPrefix("plugin:") })
  #expect(pluginGrant.subjectActor == .plugin)
  #expect(pluginGrant.expiresAt != nil)
  #expect(!pluginGrant.patterns.contains(.any))
}

@Test
func expiredPluginGrantCannotFallThroughToPermissiveDefaults() async throws {
  let engine = try await makeTestPolicyEngine(
    allowByDefaultTiers: Set(PermissionRiskTier.allCases))
  try await engine.issueGrant(
    Grant(
      capability: .appActivate,
      patterns: [.appID("com.example.target")],
      confirmationRequirement: .none,
      expiresAt: Date(timeIntervalSinceNow: -1),
      subjectActor: .plugin,
      purpose: "expired-adversarial-fixture"))

  let decision = await engine.evaluate(
    PolicyEvaluationRequest(
      capability: .appActivate,
      actor: .plugin,
      target: PolicyTarget(appID: "com.example.target"),
      sessionID: UUID(),
      correlationID: UUID(),
      causationID: UUID()))
  guard case .deny = decision else {
    Issue.record("expired plugin grant must deny even when app defaults are permissive")
    return
  }
}

@Test
func disabledAndQuarantinedPluginsNeverReachRuntime() async throws {
  let fixture = PluginFixtures.makeSignedManifest(capabilities: [.appActivate])
  let engine = try await makeTestPolicyEngine(allowByDefaultTiers: [.observation])
  let artifacts = try makeArtifactStore()
  let runtime = RecordingRuntimeHost()
  let registry = try await makePhase23Registry(
    fixture: fixture, engine: engine, artifactStore: artifacts, runtimeHost: runtime)
  _ = try await registry.install(manifest: fixture.manifest, bundleData: fixture.bundleData)
  let target = PolicyTarget(directoryPath: "/tmp/aura-plugin-tests")

  await #expect(throws: AuraError.self) {
    try await registry.execute(
      pluginID: fixture.manifest.id, capability: .appActivate, target: target, payload: Data())
  }
  #expect(await runtime.calls == 0)

  try await registry.enable(pluginID: fixture.manifest.id)
  let output = try await registry.execute(
    pluginID: fixture.manifest.id, capability: .appActivate, target: target, payload: Data())
  #expect(String(data: output, encoding: .utf8) == "runtime-ok")
  #expect(await runtime.calls == 1)
  await #expect(throws: AuraError.self) {
    try await registry.execute(
      pluginID: fixture.manifest.id, capability: .fileWrite, target: target, payload: Data())
  }
  await #expect(throws: AuraError.self) {
    try await registry.execute(
      pluginID: fixture.manifest.id, capability: .appActivate,
      target: PolicyTarget(directoryPath: "/tmp/outside-scope"), payload: Data())
  }
  #expect(await runtime.calls == 1)

  try await registry.quarantine(pluginID: fixture.manifest.id, reason: "adversarial test")
  await #expect(throws: AuraError.self) {
    try await registry.execute(
      pluginID: fixture.manifest.id, capability: .appActivate, target: target, payload: Data())
  }
  #expect(await runtime.calls == 1)
}

@Test
func updateRollbackUninstallPreserveAuditAndRemoveArtifacts() async throws {
  let first = PluginFixtures.makeSignedManifest(
    version: "1.0.0", capabilities: [.appActivate], bundleContent: "#!/bin/sh\nprintf one")
  let secondData = Data("#!/bin/sh\nprintf two".utf8)
  let secondHash = PluginArtifactStore.sha256Hex(secondData)
  let unsignedSecond = PluginManifest(
    id: first.manifest.id,
    version: "2.0.0",
    vendorName: first.manifest.vendorName,
    capabilities: first.manifest.capabilities,
    requiredPermissions: first.manifest.requiredPermissions,
    migrationNotes: "No data migration required.",
    contentHashSHA256Hex: secondHash,
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let secondSignature = try first.privateKey.signature(for: unsignedSecond.signedPayload)
  let second = PluginManifest(
    id: unsignedSecond.id,
    version: unsignedSecond.version,
    vendorName: unsignedSecond.vendorName,
    capabilities: unsignedSecond.capabilities,
    requiredPermissions: unsignedSecond.requiredPermissions,
    migrationNotes: unsignedSecond.migrationNotes,
    contentHashSHA256Hex: unsignedSecond.contentHashSHA256Hex,
    signatureBase64: secondSignature.base64EncodedString())

  let store = try await makeTestStore()
  let engine = try await makeTestPolicyEngine(store: store)
  let artifacts = try makeArtifactStore()
  let registry = try await makePhase23Registry(
    fixture: first, engine: engine, store: store, artifactStore: artifacts)
  _ = try await registry.install(manifest: first.manifest, bundleData: first.bundleData)
  try await registry.update(
    pluginID: first.manifest.id, manifest: second, bundleData: secondData)
  #expect(await registry.record(forPluginID: first.manifest.id)?.manifest.version == "2.0.0")

  try await registry.rollback(pluginID: first.manifest.id, toVersion: "1.0.0")
  #expect(await registry.record(forPluginID: first.manifest.id)?.manifest.version == "1.0.0")
  let paths =
    await registry.record(forPluginID: first.manifest.id)?.retainedVersions
    .compactMap(\.artifactRelativePath) ?? []
  for path in paths {
    #expect(await artifacts.artifactExists(relativePath: path))
  }

  try await registry.uninstall(pluginID: first.manifest.id)
  for path in paths {
    #expect(await artifacts.artifactExists(relativePath: path) == false)
  }
  let audit = try await store.pluginAuditRecords(pluginID: first.manifest.id)
  #expect(audit.map(\.action).contains("install"))
  #expect(audit.map(\.action).contains("update"))
  #expect(audit.map(\.action).contains("rollback"))
  #expect(audit.map(\.action).contains("uninstall"))
}

@Test
func artifactTamperBlocksEnableBeforeRuntime() async throws {
  let fixture = PluginFixtures.makeSignedManifest()
  let engine = try await makeTestPolicyEngine()
  let artifacts = try makeArtifactStore()
  let registry = try await makePhase23Registry(
    fixture: fixture, engine: engine, artifactStore: artifacts)
  _ = try await registry.install(manifest: fixture.manifest, bundleData: fixture.bundleData)
  let path = try #require(
    await registry.record(forPluginID: fixture.manifest.id)?.artifactRelativePath)
  let url = artifacts.rootDirectory.appendingPathComponent(path)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
  try Data("tampered after installation".utf8).write(to: url)

  await #expect(throws: AuraError.self) {
    try await registry.enable(pluginID: fixture.manifest.id)
  }
  #expect(await registry.isActionable(pluginID: fixture.manifest.id) == false)
}

@Test
func marketplaceRequiresExplicitSourceApproval() async throws {
  let fixture = PluginFixtures.makeSignedManifest()
  let engine = try await makeTestPolicyEngine()
  let registry = try await makePhase23Registry(fixture: fixture, engine: engine)
  let marketplace = PluginMarketplace(registry: registry)
  let package = PluginMarketplacePackage(
    sourceID: "local.vendor.catalog", manifest: fixture.manifest, payload: fixture.bundleData)

  await #expect(throws: AuraError.self) { try await marketplace.register(package) }
  try await marketplace.approveSource("local.vendor.catalog")
  try await marketplace.register(package)
  #expect(await marketplace.catalog().count == 1)
  #expect(try await marketplace.install(packageID: package.id) == .installed)
}
