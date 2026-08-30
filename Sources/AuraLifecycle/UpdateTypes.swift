import AuraCore
import CryptoKit
import Foundation

// MARK: - Manifest / package models

public struct UpdateManifest: Codable, Sendable, Equatable {
  public let version: String
  public let bundleIdentifier: String
  public let minimumOSVersion: String
  public let channel: String
  public let publishedAt: Date
  public let downloadURL: String
  public let packageHash: String
  public let packageHashAlgorithm: String
  public let packageSizeBytes: Int
  public let signatureBase64: String
  public let publicKeyBase64: String
  public let previousVersion: String?
  public let killSwitch: Bool
  public let minimumPreviousVersion: String?

  public init(
    version: String,
    bundleIdentifier: String,
    minimumOSVersion: String,
    channel: String,
    publishedAt: Date,
    downloadURL: String,
    packageHash: String,
    packageHashAlgorithm: String,
    packageSizeBytes: Int,
    signatureBase64: String,
    publicKeyBase64: String,
    previousVersion: String? = nil,
    killSwitch: Bool = false,
    minimumPreviousVersion: String? = nil
  ) {
    self.version = version
    self.bundleIdentifier = bundleIdentifier
    self.minimumOSVersion = minimumOSVersion
    self.channel = channel
    self.publishedAt = publishedAt
    self.downloadURL = downloadURL
    self.packageHash = packageHash
    self.packageHashAlgorithm = packageHashAlgorithm
    self.packageSizeBytes = packageSizeBytes
    self.signatureBase64 = signatureBase64
    self.publicKeyBase64 = publicKeyBase64
    self.previousVersion = previousVersion
    self.killSwitch = killSwitch
    self.minimumPreviousVersion = minimumPreviousVersion
  }
}

public struct UpdatePackage: Codable, Sendable, Equatable {
  public let url: URL
  public let sizeBytes: Int
  public let data: Data

  public init(url: URL, data: Data) {
    self.url = url
    self.sizeBytes = data.count
    self.data = data
  }
}

public struct UpdatePackageReceipt: Codable, Sendable, Equatable {
  public let manifest: UpdateManifest
  public let package: UpdatePackage

  public init(manifest: UpdateManifest, package: UpdatePackage) {
    self.manifest = manifest
    self.package = package
  }
}

// MARK: - Validation result

public enum UpdateValidationResult: Codable, Sendable, Equatable {
  case valid
  case invalid(UpdateValidationFailure)
}

public enum UpdateValidationFailure: Codable, Sendable, Equatable {
  case bundleIdentifierMismatch(expected: String, got: String)
  case versionNotNewer(current: String, offered: String)
  case versionMalformed(String)
  case publishedAtTooOld(Date, maximumAge: TimeInterval)
  case publishedAtTooNew(Date, now: Date)
  case hashAlgorithmUnsupported(String)
  case hashMismatch(expected: String, computed: String)
  case sizeMismatch(expected: Int, got: Int)
  case signatureVerificationFailed
  case killSwitchEngaged(version: String)
  case minimumPreviousVersionNotMet(current: String, required: String)
  case channelMismatch(expected: String, got: String)
  case osVersionUnsupported(required: String, current: String)
}

// MARK: - Update status

public enum UpdateCheckResult: Codable, Sendable, Equatable {
  case noUpdateAvailable
  case updateAvailable(UpdateManifest)
  case error(String)
}

public enum UpdateStageResult: Codable, Sendable, Equatable {
  case staged(UUID)
  case blocked(String)
  case error(String)
}

// MARK: - Version comparison

public struct Version {
  public let components: [Int]

  public init?(_ string: String) {
    let trimmed = string.trimmingCharacters(in: .whitespaces)
    let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
    var values: [Int] = []
    for part in parts {
      guard let value = Int(part), value >= 0 else { return nil }
      values.append(value)
    }
    guard !values.isEmpty else { return nil }
    self.components = values
  }

  public func isNewer(than other: Version) -> Bool {
    let maxCount = max(components.count, other.components.count)
    for index in 0..<maxCount {
      let left = index < components.count ? components[index] : 0
      let right = index < other.components.count ? other.components[index] : 0
      if left > right { return true }
      if left < right { return false }
    }
    return false
  }

  public func isAtLeast(_ other: Version) -> Bool {
    !other.isNewer(than: self)
  }
}

// MARK: - Local verification helpers

public enum UpdateHashAlgorithm: String, Codable, Sendable, Equatable {
  case sha256 = "SHA-256"
  case sha512 = "SHA-512"

  public var supported: Bool {
    switch self {
    case .sha256, .sha512: return true
    }
  }

  public func hash(of data: Data) -> String {
    switch self {
    case .sha256:
      return Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    case .sha512:
      return Data(SHA512.hash(data: data)).map { String(format: "%02x", $0) }.joined()
    }
  }
}
