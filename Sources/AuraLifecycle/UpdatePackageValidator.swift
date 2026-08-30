import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// Fail-closed deterministic validator for update manifests and packages.
/// All checks are local and synchronous. Signature verification is
/// deterministic: it compares a caller-supplied expected signature against a
/// caller-supplied public key using EdDSA/Curve25519 where available; on
/// platforms without CryptoKit signing it falls back to a structural check
/// that is documented as `localOnly`.
public struct UpdatePackageValidator: Sendable {
  public let currentVersion: String
  public let bundleIdentifier: String
  public let updateChannel: String
  public let osVersionProvider: @Sendable () -> String
  public let clock: @Sendable () -> Date
  public let maximumManifestAge: TimeInterval
  public let signatureVerifier: UpdateSignatureVerifier

  public init(
    currentVersion: String,
    bundleIdentifier: String,
    updateChannel: String,
    osVersionProvider: @escaping @Sendable () -> String = UpdatePackageValidator.currentOSVersion,
    clock: @escaping @Sendable () -> Date = Date.init,
    maximumManifestAge: TimeInterval = 14 * 24 * 60 * 60,
    signatureVerifier: UpdateSignatureVerifier = .production
  ) {
    self.currentVersion = currentVersion
    self.bundleIdentifier = bundleIdentifier
    self.updateChannel = updateChannel
    self.osVersionProvider = osVersionProvider
    self.clock = clock
    self.maximumManifestAge = maximumManifestAge
    self.signatureVerifier = signatureVerifier
  }

  /// Validate a manifest without a package. Used for "check" paths.
  public func validate(manifest: UpdateManifest) -> UpdateValidationResult {
    validateManifestStructure(manifest)
  }

  /// Validate a manifest plus downloaded package.
  public func validate(manifest: UpdateManifest, package: UpdatePackage) -> UpdateValidationResult {
    let structure = validateManifestStructure(manifest)
    if case .invalid = structure { return structure }

    guard package.sizeBytes == manifest.packageSizeBytes else {
      return .invalid(.sizeMismatch(expected: manifest.packageSizeBytes, got: package.sizeBytes))
    }

    guard let algorithm = UpdateHashAlgorithm(rawValue: manifest.packageHashAlgorithm),
      algorithm.supported
    else {
      return .invalid(.hashAlgorithmUnsupported(manifest.packageHashAlgorithm))
    }

    let computedHash = algorithm.hash(of: package.data)
    guard computedHash.lowercased() == manifest.packageHash.lowercased() else {
      return .invalid(.hashMismatch(expected: manifest.packageHash, computed: computedHash))
    }

    guard signatureVerifier.verify(
      manifest: manifest,
      publicKeyBase64: manifest.publicKeyBase64,
      signatureBase64: manifest.signatureBase64)
    else {
      return .invalid(.signatureVerificationFailed)
    }

    return .valid
  }

  private func validateManifestStructure(_ manifest: UpdateManifest) -> UpdateValidationResult {
    guard manifest.bundleIdentifier == bundleIdentifier else {
      return .invalid(
        .bundleIdentifierMismatch(expected: bundleIdentifier, got: manifest.bundleIdentifier))
    }

    guard manifest.channel == updateChannel else {
      return .invalid(.channelMismatch(expected: updateChannel, got: manifest.channel))
    }

    guard let offered = Version(manifest.version) else {
      return .invalid(.versionMalformed(manifest.version))
    }
    guard let current = Version(currentVersion) else {
      return .invalid(.versionMalformed(currentVersion))
    }
    guard offered.isNewer(than: current) else {
      return .invalid(.versionNotNewer(current: currentVersion, offered: manifest.version))
    }

    if let minimumPrevious = manifest.minimumPreviousVersion,
      let required = Version(minimumPrevious)
    {
      guard current.isAtLeast(required) else {
        return .invalid(
          .minimumPreviousVersionNotMet(current: currentVersion, required: minimumPrevious))
      }
    }

    let now = clock()
    let age = now.timeIntervalSince(manifest.publishedAt)
    if age > maximumManifestAge {
      return .invalid(.publishedAtTooOld(manifest.publishedAt, maximumAge: maximumManifestAge))
    }
    if manifest.publishedAt > now.addingTimeInterval(60) {
      return .invalid(.publishedAtTooNew(manifest.publishedAt, now: now))
    }

    let currentOS = osVersionProvider()
    if let requiredOS = Version(manifest.minimumOSVersion),
      let installed = Version(currentOS)
    {
      guard installed.isAtLeast(requiredOS) else {
        return .invalid(.osVersionUnsupported(required: manifest.minimumOSVersion, current: currentOS))
      }
    }

    if manifest.killSwitch {
      return .invalid(.killSwitchEngaged(version: manifest.version))
    }

    return .valid
  }

  public static func currentOSVersion() -> String {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
  }
}

// MARK: - Signature verification

public protocol UpdateSignatureVerifier: Sendable {
  func verify(manifest: UpdateManifest, publicKeyBase64: String, signatureBase64: String) -> Bool
}

public struct ProductionUpdateSignatureVerifier: UpdateSignatureVerifier {
  public init() {}

  public func verify(manifest: UpdateManifest, publicKeyBase64: String, signatureBase64: String)
    -> Bool
  {
    #if canImport(CryptoKit)
      guard let publicKeyData = Data(base64Encoded: publicKeyBase64),
        let signatureData = Data(base64Encoded: signatureBase64)
      else { return false }
      guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
      else { return false }
      guard let canonical = canonicalManifestData(manifest) else { return false }
      return publicKey.isValidSignature(signatureData, for: canonical)
    #else
      // Non-Apple platforms: structural acceptance only when a non-empty key
      // and signature are present. This path must be replaced with a real
      // verifier before release on that platform.
      return !publicKeyBase64.isEmpty && !signatureBase64.isEmpty
    #endif
  }

  private func canonicalManifestData(_ manifest: UpdateManifest) -> Data? {
    var signable = manifest
    signable = UpdateManifest(
      version: signable.version,
      bundleIdentifier: signable.bundleIdentifier,
      minimumOSVersion: signable.minimumOSVersion,
      channel: signable.channel,
      publishedAt: signable.publishedAt,
      downloadURL: signable.downloadURL,
      packageHash: signable.packageHash,
      packageHashAlgorithm: signable.packageHashAlgorithm,
      packageSizeBytes: signable.packageSizeBytes,
      signatureBase64: "",
      publicKeyBase64: "",
      previousVersion: signable.previousVersion,
      killSwitch: signable.killSwitch,
      minimumPreviousVersion: signable.minimumPreviousVersion)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return try? encoder.encode(signable)
  }
}

public struct AlwaysAcceptUpdateSignatureVerifier: UpdateSignatureVerifier {
  public init() {}
  public func verify(manifest: UpdateManifest, publicKeyBase64: String, signatureBase64: String)
    -> Bool
  {
    true
  }
}

public struct AlwaysRejectUpdateSignatureVerifier: UpdateSignatureVerifier {
  public init() {}
  public func verify(manifest: UpdateManifest, publicKeyBase64: String, signatureBase64: String)
    -> Bool
  {
    false
  }
}

extension UpdateSignatureVerifier where Self == ProductionUpdateSignatureVerifier {
  public static var production: ProductionUpdateSignatureVerifier {
    ProductionUpdateSignatureVerifier()
  }
}

extension UpdateSignatureVerifier where Self == AlwaysAcceptUpdateSignatureVerifier {
  public static var alwaysAccept: AlwaysAcceptUpdateSignatureVerifier {
    AlwaysAcceptUpdateSignatureVerifier()
  }
}

extension UpdateSignatureVerifier where Self == AlwaysRejectUpdateSignatureVerifier {
  public static var alwaysReject: AlwaysRejectUpdateSignatureVerifier {
    AlwaysRejectUpdateSignatureVerifier()
  }
}
