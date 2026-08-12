import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

public struct OAuthScopeManifest: Codable, Sendable, Equatable {
  public let provider: OAuthProviderID
  public let readScopes: Set<String>
  public let composeScopes: Set<String>
  public let sendScopes: Set<String>

  public init(
    provider: OAuthProviderID,
    readScopes: Set<String>,
    composeScopes: Set<String> = [],
    sendScopes: Set<String> = []
  ) {
    self.provider = provider
    self.readScopes = readScopes
    self.composeScopes = composeScopes
    self.sendScopes = sendScopes
  }

  /// The currently selected Gmail scopes are based on Google's published
  /// scope taxonomy. No send scope is present in the read tier.
  public static let gmailReadFirst = OAuthScopeManifest(
    provider: .gmail,
    readScopes: ["https://www.googleapis.com/auth/gmail.readonly"],
    composeScopes: ["https://www.googleapis.com/auth/gmail.compose"],
    sendScopes: ["https://www.googleapis.com/auth/gmail.send"])

  public func scopes(for tier: OAuthScopeTier) -> Set<String> {
    switch tier {
    case .read:
      return readScopes
    case .compose:
      return readScopes.union(composeScopes)
    case .send:
      return readScopes.union(composeScopes).union(sendScopes)
    }
  }

  /// Validate provider-returned or caller-requested scopes against the
  /// reviewed manifest. Unknown scopes and tier escalation fail closed.
  public func validate(
    requestedScopes: Set<String>,
    for tier: OAuthScopeTier
  ) throws(ProductivityError) {
    let allowed = scopes(for: tier)
    guard requestedScopes.isSubset(of: allowed) else {
      let unknown = requestedScopes.subtracting(allowed).sorted().joined(separator: ", ")
      throw .insufficientScope(required: "unreviewed OAuth scope(s): \(unknown)")
    }
    guard requestedScopes.isSuperset(of: readScopes) else {
      throw .insufficientScope(required: readScopes.sorted().joined(separator: ", "))
    }
    if tier == .read && !requestedScopes.isDisjoint(with: composeScopes.union(sendScopes)) {
      throw .insufficientScope(required: "read-only installation cannot request compose/send")
    }
  }

  public func isReadOnly(_ scopes: Set<String>) -> Bool {
    scopes.isSubset(of: readScopes)
  }
}
