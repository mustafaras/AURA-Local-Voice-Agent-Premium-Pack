import AuraCore
import AuraPlugins
import AuraPolicy
import AuraStore
import CryptoKit
import Foundation
import Testing

// MARK: - Helpers

private func signedManifest(
  capabilities: [Capability] = [.fileRead],
  requiredPermissions: [ResourcePattern]? = nil,
  vendorName: String = "ExampleVendor"
) -> (manifest: PluginManifest, bundleData: Data, privateKey: Curve25519.Signing.PrivateKey) {
  let privateKey = Curve25519.Signing.PrivateKey()
  let bundleData = Data("plugin bundle payload".utf8)
  let hashHex = SHA256.hash(data: bundleData).compactMap { String(format: "%02x", $0) }.joined()
  let permissions =
    requiredPermissions
    ?? (capabilities.isEmpty ? [] : [.directory("/tmp/aura-plugin-tests", recursive: true)])
  let unsigned = PluginManifest(
    id: "com.example.testplugin", version: "1.0.0", vendorName: vendorName,
    capabilities: capabilities, requiredPermissions: permissions,
    contentHashSHA256Hex: hashHex,
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let signature = try! privateKey.signature(for: unsigned.signedPayload)
  let signed = PluginManifest(
    id: unsigned.id, version: unsigned.version, vendorName: unsigned.vendorName,
    vendorKeyID: unsigned.vendorKeyID, signingAlgorithm: unsigned.signingAlgorithm,
    capabilities: unsigned.capabilities, inputSchemas: unsigned.inputSchemas,
    outputSchemas: unsigned.outputSchemas, requiredPermissions: unsigned.requiredPermissions,
    supportedApplicationBundleIDs: unsigned.supportedApplicationBundleIDs,
    networkDomains: unsigned.networkDomains,
    executableDependencies: unsigned.executableDependencies,
    entrypoint: unsigned.entrypoint, grantLifetimeSeconds: unsigned.grantLifetimeSeconds,
    migrationNotes: unsigned.migrationNotes, auditLevel: unsigned.auditLevel,
    contentHashSHA256Hex: unsigned.contentHashSHA256Hex,
    signatureBase64: signature.base64EncodedString())
  return (manifest: signed, bundleData: bundleData, privateKey: privateKey)
}

private func registry(
  trusting fixture: (
    manifest: PluginManifest, bundleData: Data, privateKey: Curve25519.Signing.PrivateKey
  )
) -> PluginTrustRegistry {
  PluginTrustRegistry(keysByVendor: [
    fixture.manifest.vendorName: fixture.privateKey.publicKey
  ])
}

// MARK: - Attack taxonomy: plugin manifest/package tampering and vendor spoofing

@Test
func pluginVerifierRejectsTamperedBundleHash() async throws {
  let fixture = signedManifest()
  let verifier = PluginVerifier(trustRegistry: registry(trusting: fixture))
  let tamperedBundle = Data("tampered payload".utf8)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: tamperedBundle)
  #expect(result == .hashMismatch)
}

@Test
func pluginVerifierRejectsUntrustedVendor() async throws {
  let fixture = signedManifest()
  let emptyRegistry = PluginTrustRegistry(keysByVendor: [:])
  let verifier = PluginVerifier(trustRegistry: emptyRegistry)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .untrustedVendor)
}

@Test
func pluginVerifierRejectsForgedSignature() async throws {
  let fixture = signedManifest()
  let attackerKey = Curve25519.Signing.PrivateKey()
  let evilRegistry = PluginTrustRegistry(keysByVendor: [
    fixture.manifest.vendorName: attackerKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: evilRegistry)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .signatureInvalid)
}

@Test
func pluginVerifierAcceptsTrustedSignedManifest() async throws {
  let fixture = signedManifest()
  let verifier = PluginVerifier(trustRegistry: registry(trusting: fixture))
  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .verified)
}

@Test
func pluginManifestRejectsCapabilityEscalationWithAnyPermission() async throws {
  let fixture = signedManifest(
    capabilities: [.fileRead, .shellExec],
    requiredPermissions: [.any])
  let verifier = PluginVerifier(trustRegistry: registry(trusting: fixture))
  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  if case .manifestInvalid = result {
    #expect(Bool(true))
  } else {
    Issue.record("expected .manifestInvalid for .any permission escalation, got \(result)")
  }
}

@Test
func pluginPolicyDeniesInstallWithoutExplicitGrant() async throws {
  let (engine, _) = try await makeAdversarialPolicyEngine(
    allowByDefaultTiers: [.observation, .reversible, .mutation, .destructive])
  let decision = await engine.evaluate(
    policyRequest(capability: .pluginInstall, target: PolicyTarget.empty))
  // .pluginInstall is .destructive; the default confirmation tier is .mutation,
  // so it always routes to confirm unless an explicit confirmationRequirement:.none
  // grant exists.
  guard case .confirm = decision else {
    Issue.record("expected confirm for plugin install without grant, got \(decision)")
    return
  }
}
