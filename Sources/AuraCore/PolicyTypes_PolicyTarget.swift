import CryptoKit
import Foundation

// MARK: - Evaluation request and target

/// The target of a policy evaluation request.
public struct PolicyTarget: Codable, Sendable, Equatable {
  public let appID: String?
  public let filePath: String?
  public let directoryPath: String?
  public let command: String?
  public let arguments: [String]
  public let environmentKeys: [String]
  public let networkHost: String?
  public let networkPort: Int?
  /// Scheme of the URL this request targets, when the request is a URL open.
  /// Read by `ResourcePattern.urlScheme(allowed:)`. `nil` for every non-URL
  /// target, which is why that pattern fails closed on `nil`.
  public let urlScheme: String?

  public init(
    appID: String? = nil,
    filePath: String? = nil,
    directoryPath: String? = nil,
    command: String? = nil,
    arguments: [String] = [],
    environmentKeys: [String] = [],
    networkHost: String? = nil,
    networkPort: Int? = nil,
    urlScheme: String? = nil
  ) {
    self.appID = appID
    self.filePath = filePath
    self.directoryPath = directoryPath
    self.command = command
    self.arguments = arguments
    self.environmentKeys = environmentKeys
    self.networkHost = networkHost
    self.networkPort = networkPort
    self.urlScheme = urlScheme
  }

  /// Empty target used for capability-wide grants.
  public static let empty = PolicyTarget()
}
