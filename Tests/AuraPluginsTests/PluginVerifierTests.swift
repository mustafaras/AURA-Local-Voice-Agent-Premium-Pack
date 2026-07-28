import AuraCore
import AuraPlugins
import CryptoKit
import Foundation
import Testing

@Test
func verifierAcceptsAWellFormedTrustedSignedPlugin() {
  let fixture = PluginFixtures.makeSignedManifest(vendorName: "TrustedVendor")
  let registry = PluginTrustRegistry(
    keysByVendor: ["TrustedVendor": fixture.privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .verified)
  #expect(result.isVerified)
}

@Test
func verifierRejectsUntrustedVendor() {
  let fixture = PluginFixtures.makeSignedManifest(vendorName: "UnknownVendor")
  // Trust registry only knows a *different* vendor.
  let registry = PluginTrustRegistry(
    keysByVendor: ["SomeOtherVendor": Curve25519.Signing.PrivateKey().publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .untrustedVendor)
}

@Test
func verifierRejectsTamperedBundleContent() {
  let fixture = PluginFixtures.makeSignedManifest(vendorName: "TrustedVendor")
  let registry = PluginTrustRegistry(
    keysByVendor: ["TrustedVendor": fixture.privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  // Adversary swaps the bundle payload for something else entirely while
  // keeping the original manifest (hash-collision-style spoofing attempt).
  let tamperedBundle = Data("malicious payload, different from what was signed".utf8)
  let result = verifier.verify(manifest: fixture.manifest, bundleData: tamperedBundle)
  #expect(result == .hashMismatch)
}

@Test
func verifierRejectsForgedSignatureFromWrongKey() {
  let fixture = PluginFixtures.makeSignedManifest(vendorName: "TrustedVendor")
  // Trust registry has the vendor name but a *different* real key than the
  // one that actually signed this manifest — simulates a vendor-name-spoof
  // attempt where the attacker doesn't have the real vendor's private key.
  let attackerKey = Curve25519.Signing.PrivateKey()
  let registry = PluginTrustRegistry(keysByVendor: ["TrustedVendor": attackerKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  let result = verifier.verify(manifest: fixture.manifest, bundleData: fixture.bundleData)
  #expect(result == .signatureInvalid)
}

@Test
func verifierRejectsManifestMutatedAfterSigning() {
  let fixture = PluginFixtures.makeSignedManifest(vendorName: "TrustedVendor")
  let registry = PluginTrustRegistry(
    keysByVendor: ["TrustedVendor": fixture.privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  // Adversary tries to escalate declared capabilities after the vendor
  // signed the original, narrower manifest.
  let escalated = PluginManifest(
    id: fixture.manifest.id, version: fixture.manifest.version,
    vendorName: fixture.manifest.vendorName,
    capabilities: [.fileRead, .shellExec, .agentRun],
    requiredPermissions: fixture.manifest.requiredPermissions,
    contentHashSHA256Hex: fixture.manifest.contentHashSHA256Hex,
    signatureBase64: fixture.manifest.signatureBase64)

  let result = verifier.verify(manifest: escalated, bundleData: fixture.bundleData)
  #expect(result == .signatureInvalid)
}

@Test
func verifierRejectsManifestWithTamperedRequiredPermissions() {
  // Regression test for a real gap caught during independent security
  // review: `signedPayload` must cover `requiredPermissions`, since that
  // field directly becomes `Grant.patterns` in `PluginRegistry.install`.
  // Widening it to `.any` after signing must invalidate the signature.
  let fixture = PluginFixtures.makeSignedManifest(
    vendorName: "TrustedVendor", requiredPermissions: [.directory("/tmp/scoped", recursive: false)])
  let registry = PluginTrustRegistry(
    keysByVendor: ["TrustedVendor": fixture.privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  let widened = PluginManifest(
    id: fixture.manifest.id, version: fixture.manifest.version,
    vendorName: fixture.manifest.vendorName, capabilities: fixture.manifest.capabilities,
    requiredPermissions: [.any],
    contentHashSHA256Hex: fixture.manifest.contentHashSHA256Hex,
    signatureBase64: fixture.manifest.signatureBase64)

  let result = verifier.verify(manifest: widened, bundleData: fixture.bundleData)
  guard case .manifestInvalid = result else {
    Issue.record("expected fail-closed manifest rejection, got \(result)")
    return
  }
}

@Test
func verifierRejectsManifestWithMutatedCapabilityRiskTier() {
  // Regression test: signing must cover each capability's full identity,
  // including `riskTier`, not just its "domain.action" identifier string —
  // otherwise the *same-named* capability could be re-declared at a
  // different (e.g. lower) risk tier without invalidating the signature,
  // silently changing the confirmation/deny-by-default behavior a grant
  // for it receives from `PolicyEngine`.
  let originalCapability = Capability(domain: "custom", action: "doThing", riskTier: .destructive)
  let fixture = PluginFixtures.makeSignedManifest(
    vendorName: "TrustedVendor", capabilities: [originalCapability])
  let registry = PluginTrustRegistry(
    keysByVendor: ["TrustedVendor": fixture.privateKey.publicKey])
  let verifier = PluginVerifier(trustRegistry: registry)

  // Same domain/action, different riskTier — `identifier` alone would not
  // have detected this tamper before the fix.
  let mutatedTierCapability = Capability(
    domain: "custom", action: "doThing", riskTier: .observation)
  let mutated = PluginManifest(
    id: fixture.manifest.id, version: fixture.manifest.version,
    vendorName: fixture.manifest.vendorName,
    capabilities: [mutatedTierCapability],
    requiredPermissions: fixture.manifest.requiredPermissions,
    contentHashSHA256Hex: fixture.manifest.contentHashSHA256Hex,
    signatureBase64: fixture.manifest.signatureBase64)

  let result = verifier.verify(manifest: mutated, bundleData: fixture.bundleData)
  #expect(result == .signatureInvalid)
}

@Test
func verifierRejectsStructurallyInvalidManifestBeforeCryptography() {
  let manifest = PluginManifest(
    id: "not-reverse-dns", version: "1.0.0", vendorName: "Vendor",
    contentHashSHA256Hex: String(repeating: "a", count: 64),
    signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
  let registry = PluginTrustRegistry(keysByVendor: [:])
  let verifier = PluginVerifier(trustRegistry: registry)

  let result = verifier.verify(manifest: manifest, bundleData: Data())
  guard case .manifestInvalid = result else {
    Issue.record("expected manifestInvalid, got \(result)")
    return
  }
}
