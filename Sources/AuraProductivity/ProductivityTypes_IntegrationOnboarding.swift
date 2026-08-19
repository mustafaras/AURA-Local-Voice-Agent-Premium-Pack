import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// Where an enrollment's authority came from. Authority is a typed value the
/// caller must supply, never something the service infers, so "the user
/// approved this account" is something a test can assert rather than assume.
///
/// `ADR-040` makes provider onboarding explicit and least-privilege. A list
/// of addresses sitting in a configuration file is *approval to consider an
/// account*, not consent to store a credential for it, so `.inferred` is
/// always refused.
public enum IntegrationAuthorizationSource: String, Codable, Sendable, Equatable, CaseIterable {
  /// The user completed the in-app integrations onboarding step for this
  /// exact account or profile.
  case userOnboardingConsent
  /// An explicitly authorized test account or profile, used for acceptance
  /// runs. Accepted only when the onboarding service was constructed with
  /// `allowsTestAuthorization: true`.
  case explicitTestAuthorization
  /// The caller concluded approval from configuration, from prior state, or
  /// from a model/tool result. Never sufficient; enrollment fails closed.
  case inferred
}

/// One explicitly authorized account enrollment. Token material is carried
/// only for the duration of the call that stores it in the Keychain; the
/// resulting `IntegrationAccountRecord` keeps a reference instead.
public struct IntegrationAccountAuthorization: Sendable {
  public let provider: OAuthProviderID
  public let accountID: String
  public let tier: OAuthScopeTier
  public let grantedScopes: Set<String>
  public let source: IntegrationAuthorizationSource
  public let material: OAuthTokenMaterial

  public init(
    provider: OAuthProviderID,
    accountID: String,
    tier: OAuthScopeTier,
    grantedScopes: Set<String>,
    source: IntegrationAuthorizationSource,
    material: OAuthTokenMaterial
  ) {
    self.provider = provider
    self.accountID = accountID
    self.tier = tier
    self.grantedScopes = grantedScopes
    self.source = source
    self.material = material
  }
}

/// One explicitly authorized browser-profile enrollment. The Safari bridge's
/// shared secret is generated inside `SafariBridgeSecretStore`, so this
/// request carries no secret at all.
public struct BrowserProfileAuthorization: Sendable, Equatable {
  public let profileID: String
  public let source: IntegrationAuthorizationSource

  public init(profileID: String, source: IntegrationAuthorizationSource) {
    self.profileID = profileID
    self.source = source
  }
}

/// A completed enrollment, safe to hold in memory and to project into the UI.
///
/// The type deliberately has no field that can carry token material: the
/// credential is reachable only through `tokenReference`, itself a non-secret
/// Keychain pointer. `fingerprint` is what non-UI surfaces quote;
/// `displayLabel` is masked and belongs on the user's own screen only.
public struct IntegrationAccountRecord: Sendable, Equatable, Identifiable {
  public let provider: OAuthProviderID
  public let accountID: String
  public let tier: OAuthScopeTier
  public let grantedScopes: Set<String>
  public let tokenReference: OAuthTokenReference
  public let enrolledAt: Date

  public var id: String { tokenReference.keychainKey }
  public var fingerprint: String { ProductivityRedaction.fingerprint(accountID) }
  public var displayLabel: String { ProductivityRedaction.displayLabel(accountID) }

  /// Read-only is a property of the granted scopes, not of an intention.
  public var isReadOnly: Bool { tier == .read }

  public init(
    provider: OAuthProviderID,
    accountID: String,
    tier: OAuthScopeTier,
    grantedScopes: Set<String>,
    tokenReference: OAuthTokenReference,
    enrolledAt: Date
  ) {
    self.provider = provider
    self.accountID = accountID
    self.tier = tier
    self.grantedScopes = grantedScopes
    self.tokenReference = tokenReference
    self.enrolledAt = enrolledAt
  }
}

/// Whether an approved account currently has a usable stored credential.
/// Distinct from "approved": an account can be approved in configuration and
/// still be disconnected because its credential was revoked or expired, and
/// the UI has to be able to say which of the two it is.
public enum IntegrationConnectionState: Sendable, Equatable {
  case connected(fingerprint: String)
  case notProvisioned
  case credentialExpiredOrRevoked
  case unavailable(reason: String)
}
