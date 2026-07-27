import AuraCore
import AuraPlugins
import AuraPolicy
import AuraStore
import CryptoKit
import Foundation

// MARK: - Signed manifest fixtures

struct SignedPluginFixture {
  let manifest: PluginManifest
  let bundleData: Data
  let privateKey: Curve25519.Signing.PrivateKey
}

enum PluginFixtures {
  /// Build a manifest whose `contentHashSHA256Hex` really matches
  /// `bundleData` and whose `signatureBase64` is a real Ed25519 signature
  /// over `signedPayload`, produced by a freshly generated keypair — never
  /// a hand-typed fixture, so `PluginVerifier` exercises real cryptography.
  static func makeSignedManifest(
    id: String = "com.example.testplugin",
    vendorName: String = "ExampleVendor",
    capabilities: [Capability] = [.fileRead],
    requiredPermissions: [ResourcePattern] = [],
    bundleContent: String = "plugin bundle payload"
  ) -> SignedPluginFixture {
    let privateKey = Curve25519.Signing.PrivateKey()
    let bundleData = Data(bundleContent.utf8)
    let hashHex = SHA256.hash(data: bundleData).compactMap { String(format: "%02x", $0) }.joined()

    let unsigned = PluginManifest(
      id: id, version: "1.0.0", vendorName: vendorName, capabilities: capabilities,
      requiredPermissions: requiredPermissions,
      contentHashSHA256Hex: hashHex,
      signatureBase64: Data(repeating: 0, count: 64).base64EncodedString())
    let signature = try! privateKey.signature(for: unsigned.signedPayload)
    let signed = PluginManifest(
      id: unsigned.id, version: unsigned.version, vendorName: unsigned.vendorName,
      capabilities: unsigned.capabilities, requiredPermissions: unsigned.requiredPermissions,
      supportedApplicationBundleIDs: unsigned.supportedApplicationBundleIDs,
      networkDomains: unsigned.networkDomains,
      executableDependencies: unsigned.executableDependencies,
      migrationNotes: unsigned.migrationNotes, auditLevel: unsigned.auditLevel,
      contentHashSHA256Hex: unsigned.contentHashSHA256Hex,
      signatureBase64: signature.base64EncodedString())

    return SignedPluginFixture(manifest: signed, bundleData: bundleData, privateKey: privateKey)
  }
}

// MARK: - PolicyEngine test helper (mirrors Tests/AuraPolicyTests/PolicyEngineTests.swift)

func makeTestStore() async throws -> AuraStore {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  let path = dir.appendingPathComponent("test.sqlite").path
  return try await AuraStore(path: path)
}

/// Widening `allowByDefaultTiers` alone is not sufficient for a
/// `.destructive`-tier capability like `.pluginInstall`: `PolicyEngine`'s
/// default-confirmation check (`riskTier >= defaultConfirmationTier`, and
/// `.destructive` is the highest tier there is) still routes it to
/// `.confirm` rather than `.allow`. Matching the established pattern used by
/// `PolicyEngineTests`/`ComputerUseControlLoopTests` for a similar "just let
/// this happy path through" need, this helper issues an explicit
/// `confirmationRequirement: .none` grant for each plugin-lifecycle
/// capability when `grantPluginLifecycleCapabilities` is true (the default).
/// The one deny-path test in this file passes `false` and a narrow
/// `allowByDefaultTiers` instead, since a matching grant would otherwise
/// short-circuit `PolicyEngine.evaluate`'s deny-by-default fallback it
/// exists to exercise.
func makeTestPolicyEngine(
  store: AuraStore? = nil,
  allowByDefaultTiers: Set<PermissionRiskTier> = [.observation, .reversible, .mutation, .destructive],
  grantPluginLifecycleCapabilities: Bool = true
) async throws(AuraError) -> PolicyEngine {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraPluginsTests", category: "bus"))
  let config = PolicyConfiguration(
    allowByDefaultTiers: allowByDefaultTiers,
    denyByDefaultTiers: Set(PermissionRiskTier.allCases).subtracting(allowByDefaultTiers)
  )
  let engine = try await PolicyEngine(configuration: config, eventBus: bus, store: store)
  if grantPluginLifecycleCapabilities {
    for capability in [
      Capability.pluginInstall, .pluginEnable, .pluginDisable, .pluginQuarantine, .pluginUninstall,
    ] {
      try await engine.issueGrant(
        Grant(capability: capability, patterns: [.any], confirmationRequirement: .none))
    }
  }
  return engine
}
