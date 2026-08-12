import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

public enum OAuthProviderID: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  case gmail
  case microsoftGraph
  case custom
}
