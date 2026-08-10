import AuraCore
import AuraPlugins
import CryptoKit
import Foundation
import Testing

// MARK: - Attack taxonomy: supply-chain verification

// macOS bundle code-signature and notarization checks are intentionally not
// implemented in this codebase yet (`AuraSecurity` currently handles prompt
// injection, provenance, secrets, and network allowlists). To keep adversarial
// tests grounded in real code rather than invented APIs, this file exercises
// the plugin supply-chain boundary that *does* exist: `PluginVerifier` and
// `PluginManifest`. Hash, signature, vendor trust, and manifest structural
// integrity are verified with real Ed25519 signatures from `CryptoKit`.

private func makeSignedManifest(
  id: String = "com.example.testplugin",
  version: String = "1.0.0",
  vendorName: String = "ExampleVendor",
  capabilities: [Capability] = [.fileRead],
  requiredPermissions: [ResourcePattern]? = nil,
  bundleContent: String = "plugin bundle payload"
) -> (manifest: PluginManifest, bundleData: Data, privateKey: Curve25519.Signing.PrivateKey) {
  let privateKey = Curve25519.Signing.PrivateKey()
  let bundleData = Data(bundleContent.utf8)
  let hashHex = SHA256.hash(data: bundleData).compactMap { String(format: "%02x", $0) }.joined()
  let permissions =
    requiredPermissions
    ?? (capabilities.isEmpty ? [] : [.directory("/tmp/aura-plugin-tests", recursive: true)])
  let unsigned = PluginManifest(
    id: id, version: version, vendorName: vendorName, capabilities: capabilities,
    requiredPermissions: permissions, contentHashSHA256Hex: hashHex,
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

@Test
func pluginVerifierDetectsMissingSignatureWhenManifestIsUnsigned() async throws {
  // An unsigned manifest has a placeholder signature base64 of 64 zero bytes,
  // which fails manifest structural validation (signature length mismatch).
  let privateKey = Curve25519.Signing.PrivateKey()
  let bundleData = Data("plugin bundle payload".utf8)
  let hashHex = SHA256.hash(data: bundleData).compactMap { String(format: "%02x", $0) }.joined()
  let unsignedManifest = PluginManifest(
    id: "com.example.unsigned", version: "1.0.0", vendorName: "UntrustedVendor",
    capabilities: [.fileRead],
    requiredPermissions: [.directory("/tmp/aura-plugin-tests", recursive: true)],
    contentHashSHA256Hex: hashHex,
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let registry = PluginTrustRegistry(keysByVendor: [
    unsignedManifest.vendorName: privateKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: registry)
  let result = verifier.verify(manifest: unsignedManifest, bundleData: bundleData)
  #expect(result == .signatureInvalid)
}

@Test
func pluginVerifierRejectsHashTamperedPackage() async throws {
  let fixture = makeSignedManifest()
  let registry = PluginTrustRegistry(keysByVendor: [
    fixture.manifest.vendorName: fixture.privateKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: registry)
  let tamperedBundle = Data("attacker-controlled payload".utf8)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: tamperedBundle)
  #expect(result == .hashMismatch)
}

@Test
func pluginVerifierRejectsVendorKeyRotationAttack() async throws {
  // Attacker re-signs the *same* bundle bytes with their own key and forges a
  // manifest claiming the original vendor. The registry only trusts the real
  // vendor key, so verification fails at the vendor-trust step before signature.
  let fixture = makeSignedManifest()
  let attackerKey = Curve25519.Signing.PrivateKey()
  let forgedSignature = try attackerKey.signature(for: fixture.manifest.signedPayload)
  let forgedManifest = PluginManifest(
    id: fixture.manifest.id,
    version: fixture.manifest.version,
    vendorName: fixture.manifest.vendorName,
    vendorKeyID: fixture.manifest.vendorKeyID,
    signingAlgorithm: fixture.manifest.signingAlgorithm,
    capabilities: fixture.manifest.capabilities,
    inputSchemas: fixture.manifest.inputSchemas,
    outputSchemas: fixture.manifest.outputSchemas,
    requiredPermissions: fixture.manifest.requiredPermissions,
    supportedApplicationBundleIDs: fixture.manifest.supportedApplicationBundleIDs,
    networkDomains: fixture.manifest.networkDomains,
    executableDependencies: fixture.manifest.executableDependencies,
    entrypoint: fixture.manifest.entrypoint,
    grantLifetimeSeconds: fixture.manifest.grantLifetimeSeconds,
    migrationNotes: fixture.manifest.migrationNotes,
    auditLevel: fixture.manifest.auditLevel,
    contentHashSHA256Hex: fixture.manifest.contentHashSHA256Hex,
    signatureBase64: forgedSignature.base64EncodedString())

  let realRegistry = PluginTrustRegistry(keysByVendor: [
    fixture.manifest.vendorName: fixture.privateKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: realRegistry)
  let result = verifier.verify(manifest: forgedManifest, bundleData: fixture.bundleData)
  #expect(result == .signatureInvalid)
}

@Test
func pluginVerifierAcceptsUnmodifiedTrustedPackage() async throws {
  let fixture = makeSignedManifest()
  let registry = PluginTrustRegistry(keysByVendor: [
    fixture.manifest.vendorName: fixture.privateKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: registry)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .verified)
}

@Test
func pluginManifestRejectsDowngradeToWildcardPermission() async throws {
  // Capability-bearing plugin with `.any` permission is structural invalid,
  // so the verifier returns `.manifestInvalid` before reaching hash/signature.
  let fixture = makeSignedManifest(
    capabilities: [.fileRead, .fileWrite],
    requiredPermissions: [.any])
  let registry = PluginTrustRegistry(keysByVendor: [
    fixture.manifest.vendorName: fixture.privateKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: registry)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  if case .manifestInvalid = result {
    #expect(Bool(true))
  } else {
    Issue.record("expected .manifestInvalid for .any permission escalation, got \(result)")
  }
}

@Test
func pluginManifestRejectsInvalidVersionClaim() async throws {
  let privateKey = Curve25519.Signing.PrivateKey()
  let bundleData = Data("plugin bundle payload".utf8)
  let hashHex = SHA256.hash(data: bundleData).compactMap { String(format: "%02x", $0) }.joined()
  let placeholder = PluginManifest(
    id: "com.example.invalid-version",
    version: "not-a-version",
    vendorName: "BadVendor",
    capabilities: [.fileRead],
    requiredPermissions: [.directory("/tmp/aura-plugin-tests", recursive: true)],
    contentHashSHA256Hex: hashHex,
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let registry = PluginTrustRegistry(keysByVendor: [placeholder.vendorName: privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)
  let result = verifier.verify(manifest: placeholder, bundleData: bundleData)
  if case .manifestInvalid = result {
    #expect(Bool(true))
  } else {
    Issue.record("expected .manifestInvalid for invalid version, got \(result)")
  }
}

@Test
func pluginVerifierDetectsBundleVendorSwapToUntrustedSource() async throws {
  // Even a correctly-signed manifest from a trusted vendor fails when paired
  // with a bundle whose hash was computed over a different vendor's payload,
  // preventing a benign manifest from being reused to vouch for attacker code.
  let trustedFixture = makeSignedManifest(
    vendorName: "TrustedVendor",
    bundleContent: "trusted vendor plugin bundle v1")
  let evilFixture = makeSignedManifest(
    vendorName: "EvilVendor",
    bundleContent: "evil vendor plugin bundle payload")
  let registry = PluginTrustRegistry(keysByVendor: [
    trustedFixture.manifest.vendorName: trustedFixture.privateKey.publicKey
  ])
  let verifier = PluginVerifier(trustRegistry: registry)
  let result = verifier.verify(
    manifest: trustedFixture.manifest,
    bundleData: evilFixture.bundleData)
  #expect(result == .hashMismatch)
}
