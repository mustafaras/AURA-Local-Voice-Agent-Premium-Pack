import AuraCore
import AuraLifecycle
import Foundation
import Testing

struct UpdatePackageValidatorTests {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)
  private let base = UpdateManifest(
    version: "2.0.0",
    bundleIdentifier: "com.aura.agent",
    minimumOSVersion: "14.0.0",
    channel: "stable",
    publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
    downloadURL: "https://example.com/update.zip",
    packageHash: "",
    packageHashAlgorithm: "SHA-256",
    packageSizeBytes: 0,
    signatureBase64: "sig",
    publicKeyBase64: "key",
    previousVersion: "1.0.0",
    minimumPreviousVersion: "1.0.0")

  private func makeValidator(
    currentVersion: String = "1.0.0",
    channel: String = "stable",
    clock: Date = Date(timeIntervalSince1970: 1_700_000_000),
    os: String = "27.0.0",
    signatureVerifier: UpdateSignatureVerifier = .alwaysAccept
  ) -> UpdatePackageValidator {
    UpdatePackageValidator(
      currentVersion: currentVersion,
      bundleIdentifier: "com.aura.agent",
      updateChannel: channel,
      osVersionProvider: { os },
      clock: { clock },
      maximumManifestAge: 14 * 24 * 60 * 60,
      signatureVerifier: signatureVerifier)
  }

  private func package(data: Data = Data("update".utf8), size: Int? = nil) -> UpdatePackage {
    let bytes = data
    return UpdatePackage(url: URL(fileURLWithPath: "/tmp/update.zip"), data: bytes)
  }

  @Test
  func validManifestAndPackagePasses() {
    let data = Data("update".utf8)
    let hash = UpdateHashAlgorithm.sha256.hash(of: data)
    var manifest = base
    manifest = UpdateManifest(
      version: base.version,
      bundleIdentifier: base.bundleIdentifier,
      minimumOSVersion: base.minimumOSVersion,
      channel: base.channel,
      publishedAt: base.publishedAt,
      downloadURL: base.downloadURL,
      packageHash: hash,
      packageHashAlgorithm: base.packageHashAlgorithm,
      packageSizeBytes: data.count,
      signatureBase64: base.signatureBase64,
      publicKeyBase64: base.publicKeyBase64,
      previousVersion: base.previousVersion,
      minimumPreviousVersion: base.minimumPreviousVersion)
    let validator = makeValidator()
    let result = validator.validate(manifest: manifest, package: package(data: data, size: data.count))
    #expect(result == .valid)
  }

  @Test
  func staleManifestRejected() {
    let manifest = base
    let validator = makeValidator(clock: base.publishedAt.addingTimeInterval(30 * 24 * 60 * 60))
    let result = validator.validate(manifest: manifest)
    #expect(result == .invalid(.publishedAtTooOld(base.publishedAt, maximumAge: 14 * 24 * 60 * 60)))
  }

  @Test
  func killSwitchEngagedRejected() {
    let manifest = UpdateManifest(
      version: "2.0.0",
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: base.publishedAt,
      downloadURL: base.downloadURL,
      packageHash: "",
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: 0,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      killSwitch: true,
      minimumPreviousVersion: nil)
    let validator = makeValidator()
    let result = validator.validate(manifest: manifest)
    #expect(result == .invalid(.killSwitchEngaged(version: "2.0.0")))
  }

  @Test
  func downgradeAndReplayRejected() {
    let manifest = base
    let validator = makeValidator(currentVersion: "3.0.0")
    let result = validator.validate(manifest: manifest)
    #expect(result == .invalid(.versionNotNewer(current: "3.0.0", offered: "2.0.0")))
  }

  @Test
  func hashMismatchRejected() {
    let data = Data("update".utf8)
    let manifest = UpdateManifest(
      version: "2.0.0",
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: base.publishedAt,
      downloadURL: base.downloadURL,
      packageHash: "0000000000000000000000000000000000000000000000000000000000000000",
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: data.count,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      minimumPreviousVersion: nil)
    let validator = makeValidator()
    let result = validator.validate(manifest: manifest, package: package(data: data, size: data.count))
    guard case .invalid(.hashMismatch) = result else {
      Issue.record("expected hash mismatch, got \(result)")
      return
    }
  }

  @Test
  func signatureRejectionBlocked() {
    let data = Data("update".utf8)
    let hash = UpdateHashAlgorithm.sha256.hash(of: data)
    let manifest = UpdateManifest(
      version: "2.0.0",
      bundleIdentifier: "com.aura.agent",
      minimumOSVersion: "14.0.0",
      channel: "stable",
      publishedAt: base.publishedAt,
      downloadURL: base.downloadURL,
      packageHash: hash,
      packageHashAlgorithm: "SHA-256",
      packageSizeBytes: data.count,
      signatureBase64: "sig",
      publicKeyBase64: "key",
      previousVersion: "1.0.0",
      minimumPreviousVersion: nil)
    let validator = makeValidator(signatureVerifier: .alwaysReject)
    let result = validator.validate(manifest: manifest, package: package(data: data, size: data.count))
    #expect(result == .invalid(.signatureVerificationFailed))
  }

  @Test
  func channelMismatchRejected() {
    let manifest = base
    let validator = makeValidator(channel: "beta")
    let result = validator.validate(manifest: manifest)
    #expect(result == .invalid(.channelMismatch(expected: "beta", got: "stable")))
  }
}
