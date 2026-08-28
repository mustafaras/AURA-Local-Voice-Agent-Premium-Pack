import AuraCore
import AuraPlugins
import AuraPolicy
import AuraStore
import CryptoKit
import Foundation
import Testing

/// Adversarial supply-chain fixtures for SP-025 (OPEN-11 / R10).
///
/// Closes the "compromised fixtures" leg of the plugin-trust procedure:
/// every lifecycle transition (install, enable, update, rollback, execute)
/// and the helper boundary must fail closed when the artifact, signature,
/// vendor root, retained version, or helper executable is compromised. A
/// passing test asserts the failure path, never a type or a local contract.
@Suite("Plugin supply-chain adversarial fixtures")
struct PluginSupplyChainAdversarialTests {

  private static func makeArtifactStore() throws -> PluginArtifactStore {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return try PluginArtifactStore(rootDirectory: root)
  }

  private static func makeRegistry(
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

  /// A helper executable whose SHA-256 does not match the digest the host
  /// pins. `PluginHelperProcessHost.execute` must fail closed before any
  /// process is launched — a compromised helper can never be used.
  @Test("A compromised plugin helper fails closed before launch")
  func compromisedHelperFailsClosedBeforeLaunch() async throws {
    let helperURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: false)
    try Data("#!/bin/sh\nattacker payload".utf8).write(to: helperURL)
    defer { try? FileManager.default.removeItem(at: helperURL) }

    // Pin a digest that does not match the on-disk helper.
    let pinnedDigest = PluginArtifactStore.sha256Hex(Data("something-else".utf8))
    let host = try PluginHelperProcessHost(
      helperURL: helperURL, expectedHelperSHA256Hex: pinnedDigest)

    let fixture = PluginFixtures.makeSignedManifest(capabilities: [.fileRead])
    let request = PluginRuntimeRequest(
      pluginID: fixture.manifest.id, pluginVersion: fixture.manifest.version,
      capability: .fileRead, target: PolicyTarget(directoryPath: "/tmp/aura-plugin-tests"),
      payload: Data())
    await #expect(throws: AuraError.self) {
      try await host.execute(
        manifest: fixture.manifest, artifactURL: helperURL, request: request)
    }
  }

  /// A plugin installed and enabled, then its on-disk artifact tampered with,
  /// must fail closed on re-verification at enable-time (and at execute-time).
  @Test("A tampered installed artifact blocks enable and execute")
  func tamperedInstalledArtifactBlocksEnableAndExecute() async throws {
    let fixture = PluginFixtures.makeSignedManifest(
      capabilities: [.fileRead], bundleContent: "trusted plugin payload")
    let engine = try await makeTestPolicyEngine()
    let artifacts = try Self.makeArtifactStore()
    let registry = try await Self.makeRegistry(
      fixture: fixture, engine: engine, artifactStore: artifacts)
    _ = try await registry.install(manifest: fixture.manifest, bundleData: fixture.bundleData)

    // Tamper the stored artifact after install.
    let path = try #require(
      await registry.record(forPluginID: fixture.manifest.id)?.artifactRelativePath)
    let url = artifacts.rootDirectory.appendingPathComponent(path)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    try Data("attacker modified the artifact".utf8).write(to: url)

    await #expect(throws: AuraError.self) {
      try await registry.enable(pluginID: fixture.manifest.id)
    }
    await #expect(throws: AuraError.self) {
      _ = try await registry.execute(
        pluginID: fixture.manifest.id, capability: .fileRead,
        target: PolicyTarget(directoryPath: "/tmp/aura-plugin-tests"), payload: Data())
    }
    #expect(await registry.isActionable(pluginID: fixture.manifest.id) == false)
  }

  /// An update whose new bundle's content hash does not match the manifest's
  /// declared hash must be refused before any artifact is stored.
  @Test("A tampered update bundle is refused")
  func tamperedUpdateBundleIsRefused() async throws {
    let first = PluginFixtures.makeSignedManifest(
      version: "1.0.0", capabilities: [.fileRead], bundleContent: "v1 payload")
    let engine = try await makeTestPolicyEngine()
    let artifacts = try Self.makeArtifactStore()
    let registry = try await Self.makeRegistry(
      fixture: first, engine: engine, artifactStore: artifacts)
    _ = try await registry.install(manifest: first.manifest, bundleData: first.bundleData)

    // Attacker crafts a "2.0.0" manifest whose content hash is for v1's data,
    // but supplies different (malicious) bundle bytes.
    let hashHex = PluginArtifactStore.sha256Hex(first.bundleData)
    let unsigned = PluginManifest(
      id: first.manifest.id, version: "2.0.0", vendorName: first.manifest.vendorName,
      capabilities: first.manifest.capabilities,
      requiredPermissions: first.manifest.requiredPermissions,
      contentHashSHA256Hex: hashHex,
      signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
    let signature = try first.privateKey.signature(for: unsigned.signedPayload)
    let forgedManifest = PluginManifest(
      id: unsigned.id, version: unsigned.version, vendorName: unsigned.vendorName,
      capabilities: unsigned.capabilities, requiredPermissions: unsigned.requiredPermissions,
      contentHashSHA256Hex: unsigned.contentHashSHA256Hex,
      signatureBase64: signature.base64EncodedString())

    await #expect(throws: AuraError.self) {
      try await registry.update(
        pluginID: first.manifest.id, manifest: forgedManifest, bundleData: Data("malicious".utf8))
    }
    // The stored version must still be 1.0.0.
    #expect(await registry.record(forPluginID: first.manifest.id)?.manifest.version == "1.0.0")
  }

  /// An update signed by a different vendor key than the one in the trust
  /// registry (vendor-root compromise) must be refused.
  @Test("An update from an untrusted vendor root is refused")
  func updateFromUntrustedVendorRootIsRefused() async throws {
    let first = PluginFixtures.makeSignedManifest(
      version: "1.0.0", capabilities: [.fileRead], bundleContent: "v1 payload")
    let engine = try await makeTestPolicyEngine()
    let artifacts = try Self.makeArtifactStore()
    let registry = try await Self.makeRegistry(
      fixture: first, engine: engine, artifactStore: artifacts)
    _ = try await registry.install(manifest: first.manifest, bundleData: first.bundleData)

    // Attacker with their own key, same vendor display name, signs a 2.0.0.
    let attackerKey = Curve25519.Signing.PrivateKey()
    let attackerBundle = Data("attacker payload".utf8)
    let attackerHash = PluginArtifactStore.sha256Hex(attackerBundle)
    let unsigned = PluginManifest(
      id: first.manifest.id, version: "2.0.0", vendorName: first.manifest.vendorName,
      capabilities: first.manifest.capabilities,
      requiredPermissions: first.manifest.requiredPermissions,
      contentHashSHA256Hex: attackerHash,
      signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
    let signature = try attackerKey.signature(for: unsigned.signedPayload)
    let forgedManifest = PluginManifest(
      id: unsigned.id, version: unsigned.version, vendorName: unsigned.vendorName,
      capabilities: unsigned.capabilities, requiredPermissions: unsigned.requiredPermissions,
      contentHashSHA256Hex: unsigned.contentHashSHA256Hex,
      signatureBase64: signature.base64EncodedString())

    await #expect(throws: AuraError.self) {
      try await registry.update(
        pluginID: first.manifest.id, manifest: forgedManifest, bundleData: attackerBundle)
    }
    #expect(await registry.record(forPluginID: first.manifest.id)?.manifest.version == "1.0.0")
  }

  /// A rollback to a version whose retained artifact has been tampered with
  /// must fail closed (the retained artifact is rehashed and re-verified).
  @Test("A tampered retained artifact blocks rollback")
  func tamperedRetainedArtifactBlocksRollback() async throws {
    let first = PluginFixtures.makeSignedManifest(
      version: "1.0.0", capabilities: [.fileRead], bundleContent: "v1 payload")
    let secondData = Data("v2 payload".utf8)
    let secondHash = PluginArtifactStore.sha256Hex(secondData)
    let unsignedSecond = PluginManifest(
      id: first.manifest.id, version: "2.0.0", vendorName: first.manifest.vendorName,
      capabilities: first.manifest.capabilities,
      requiredPermissions: first.manifest.requiredPermissions,
      contentHashSHA256Hex: secondHash,
      signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
    let secondSignature = try first.privateKey.signature(for: unsignedSecond.signedPayload)
    let second = PluginManifest(
      id: unsignedSecond.id, version: unsignedSecond.version,
      vendorName: unsignedSecond.vendorName, capabilities: unsignedSecond.capabilities,
      requiredPermissions: unsignedSecond.requiredPermissions,
      contentHashSHA256Hex: unsignedSecond.contentHashSHA256Hex,
      signatureBase64: secondSignature.base64EncodedString())

    let engine = try await makeTestPolicyEngine()
    let artifacts = try Self.makeArtifactStore()
    let registry = try await Self.makeRegistry(
      fixture: first, engine: engine, artifactStore: artifacts)
    _ = try await registry.install(manifest: first.manifest, bundleData: first.bundleData)
    try await registry.update(
      pluginID: first.manifest.id, manifest: second, bundleData: secondData)

    // Tamper the retained v1 artifact.
    let record = try #require(await registry.record(forPluginID: first.manifest.id))
    let v1Path = try #require(
      record.retainedVersions.first { $0.manifest.version == "1.0.0" }?.artifactRelativePath)
    let v1URL = artifacts.rootDirectory.appendingPathComponent(v1Path)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: v1URL.path)
    try Data("tampered v1".utf8).write(to: v1URL)

    await #expect(throws: AuraError.self) {
      try await registry.rollback(pluginID: first.manifest.id, toVersion: "1.0.0")
    }
    // Version must still be the current 2.0.0.
    #expect(await registry.record(forPluginID: first.manifest.id)?.manifest.version == "2.0.0")
  }

  /// A quarantined plugin has its grants revoked and can never reach
  /// execution — a one-way safety valve, not a recoverable re-enable.
  @Test("Quarantine revokes grants and blocks all execution")
  func quarantineRevokesGrantsAndBlocksExecution() async throws {
    let fixture = PluginFixtures.makeSignedManifest(capabilities: [.fileRead])
    let engine = try await makeTestPolicyEngine()
    let registry = try await Self.makeRegistry(fixture: fixture, engine: engine)
    _ = try await registry.install(manifest: fixture.manifest, bundleData: fixture.bundleData)
    try await registry.enable(pluginID: fixture.manifest.id)

    try await registry.quarantine(
      pluginID: fixture.manifest.id, reason: "adversarial fixture: suspected compromise")
    let record = await registry.record(forPluginID: fixture.manifest.id)
    #expect(record?.state == PluginLifecycleState.quarantined)
    #expect(record?.grantIDs.isEmpty == true)
    #expect(await registry.isActionable(pluginID: fixture.manifest.id) == false)

    await #expect(throws: AuraError.self) {
      try await registry.enable(pluginID: fixture.manifest.id)
    }
    await #expect(throws: AuraError.self) {
      _ = try await registry.execute(
        pluginID: fixture.manifest.id, capability: .fileRead,
        target: PolicyTarget(directoryPath: "/tmp/aura-plugin-tests"), payload: Data())
    }
  }

  /// A package from an unapproved marketplace source, or a plugin whose
  /// vendor root is unknown, must never install (no authority by presence).
  @Test("Unapproved marketplace source and unknown vendor root never install")
  func unapprovedSourceAndUnknownVendorNeverInstall() async throws {
    let engine = try await makeTestPolicyEngine()
    let registry = try await Self.makeRegistry(
      fixture: PluginFixtures.makeSignedManifest(vendorName: "UnknownVendor"),
      engine: engine)
    let marketplace = PluginMarketplace(registry: registry)
    let fixture = PluginFixtures.makeSignedManifest(vendorName: "SomeVendor")
    let package = PluginMarketplacePackage(
      sourceID: "unapproved.catalog", manifest: fixture.manifest, payload: fixture.bundleData)

    // Unapproved source: register refuses before any install.
    await #expect(throws: AuraError.self) { try await marketplace.register(package) }

    // Approved source, but the registry's trust list does not know the
    // vendor root: install must fail at verification.
    try await marketplace.approveSource("unapproved.catalog")
    try await marketplace.register(package)
    await #expect(throws: AuraError.self) {
      try await marketplace.install(packageID: package.id)
    }
  }
}
