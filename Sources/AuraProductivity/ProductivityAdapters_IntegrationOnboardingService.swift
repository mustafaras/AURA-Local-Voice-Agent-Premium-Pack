import AuraCore
import AuraSecurity
import Foundation

/// Explicitly authorized onboarding for provider accounts and browser
/// profiles — SP-010's first procedure step.
///
/// Three separate things have to be true before a credential is stored, and
/// each is checked here rather than left to a caller's discipline:
///
/// 1. **Approval.** The account or profile must already be on the approved
///    list the user maintains in configuration. An address the user never
///    approved cannot be enrolled by a caller that merely knows it.
/// 2. **Authority.** The request must carry a real
///    `IntegrationAuthorizationSource`. `.inferred` is refused, and
///    `.explicitTestAuthorization` is refused unless this service was
///    constructed for an acceptance run.
/// 3. **Least privilege.** The granted scopes must validate against the
///    reviewed `OAuthScopeManifest` for the requested tier, and this pass
///    accepts only the `.read` tier — escalation to compose/send is refused
///    here and is gated separately by the destructive `oauth.escalate`
///    capability, which no read path can reach.
///
/// After enrollment the credential exists only in the Keychain. The returned
/// record carries an `OAuthTokenReference`, never token material.
public actor IntegrationOnboardingService {
  private let approvedAccounts: ApprovedIntegrationAccounts
  private let approvedProfiles: ApprovedBrowserProfiles
  private let scopeManifests: [OAuthProviderID: OAuthScopeManifest]
  private let tokenStore: any OAuthTokenStoring
  private let browserSecretStore: SafariBridgeSecretStore?
  private let allowsTestAuthorization: Bool
  private let now: @Sendable () -> Date

  private var enrolledAccounts: [OAuthTokenReference: IntegrationAccountRecord] = [:]
  private var enrolledProfiles: Set<String> = []

  public init(
    approvedAccounts: ApprovedIntegrationAccounts,
    approvedProfiles: ApprovedBrowserProfiles = ApprovedBrowserProfiles(profileIDs: []),
    scopeManifests: [OAuthProviderID: OAuthScopeManifest] = [.gmail: .gmailReadFirst],
    tokenStore: any OAuthTokenStoring,
    browserSecretStore: SafariBridgeSecretStore? = nil,
    allowsTestAuthorization: Bool = false,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.approvedAccounts = approvedAccounts
    self.approvedProfiles = approvedProfiles
    self.scopeManifests = scopeManifests
    self.tokenStore = tokenStore
    self.browserSecretStore = browserSecretStore
    self.allowsTestAuthorization = allowsTestAuthorization
    self.now = now
  }

  // MARK: - Accounts

  /// Enroll one explicitly authorized account. Every check runs before the
  /// credential is written, so a refused enrollment leaves no Keychain item
  /// behind.
  @discardableResult
  public func enroll(
    _ authorization: IntegrationAccountAuthorization
  ) async throws(ProductivityError) -> IntegrationAccountRecord {
    try requireAuthority(authorization.source)
    // Resolution against the approved list is the account-isolation boundary:
    // `resolve` throws rather than returning an unapproved identifier, so an
    // address the user never approved never reaches the token store.
    let accountID = try approvedAccounts.resolve(requestedID: authorization.accountID)
    guard authorization.tier == .read else {
      throw .insufficientScope(
        required: "this pass enrolls read-only accounts; compose/send requires oauth.escalate")
    }
    guard let manifest = scopeManifests[authorization.provider] else {
      throw .unsupported(
        "no reviewed scope manifest for provider \(authorization.provider.rawValue)")
    }
    try manifest.validate(requestedScopes: authorization.grantedScopes, for: authorization.tier)

    let reference = try OAuthTokenReference(provider: authorization.provider, accountID: accountID)
    try await tokenStore.save(authorization.material, for: reference)
    let record = IntegrationAccountRecord(
      provider: authorization.provider,
      accountID: accountID,
      tier: authorization.tier,
      grantedScopes: authorization.grantedScopes,
      tokenReference: reference,
      enrolledAt: now())
    enrolledAccounts[reference] = record
    return record
  }

  /// Revoke one account. The Keychain item is deleted first: if that fails,
  /// the in-memory record stays, so the UI keeps showing the account as
  /// connected rather than claiming a revocation that did not happen.
  public func revokeAccount(
    provider: OAuthProviderID,
    accountID: String
  ) async throws(ProductivityError) {
    let reference = try OAuthTokenReference(provider: provider, accountID: accountID)
    try await tokenStore.revoke(reference)
    enrolledAccounts.removeValue(forKey: reference)
  }

  /// Live connection state for one approved account, derived from the token
  /// store rather than from this actor's memory — a credential revoked out of
  /// band (Keychain deletion, provider-side revocation, expiry) is reported
  /// as disconnected on the next check.
  public func connectionState(
    provider: OAuthProviderID,
    accountID: String
  ) async -> IntegrationConnectionState {
    guard let reference = try? OAuthTokenReference(provider: provider, accountID: accountID) else {
      return .unavailable(reason: "account identifier is invalid")
    }
    do {
      guard let token = try await tokenStore.accessToken(for: reference), !token.isEmpty else {
        return .notProvisioned
      }
      return .connected(fingerprint: ProductivityRedaction.fingerprint(accountID))
    } catch ProductivityError.tokenExpiredOrRevoked {
      return .credentialExpiredOrRevoked
    } catch {
      return .unavailable(reason: ProductivityRedaction.diagnostic(for: error))
    }
  }

  public func records() -> [IntegrationAccountRecord] {
    enrolledAccounts.values.sorted { $0.enrolledAt < $1.enrolledAt }
  }

  public func approvedAccountIDs() -> [String] { approvedAccounts.accountIDs }

  /// Escalation to compose/send authority. Deliberately refused: SP-010 wires
  /// read-first capabilities only, and `mail.send` has no adapter, no
  /// confirmation flow, and no post-action verification in this pass. The
  /// method exists so the refusal is a tested postcondition rather than the
  /// absence of code that could be added later without noticing the missing
  /// gates.
  public func escalateScope(
    provider: OAuthProviderID,
    accountID: String,
    to tier: OAuthScopeTier
  ) async throws(ProductivityError) -> Never {
    throw .insufficientScope(
      required:
        "scope escalation to \(tier.rawValue) requires the destructive oauth.escalate capability, "
        + "which no read-first path may request")
  }

  // MARK: - Browser profiles

  /// Enroll one explicitly authorized Safari profile by pinning the key its
  /// extension published.
  ///
  /// Pinning is trust-on-first-use, and the "first use" is deliberately the
  /// user's click rather than the extension's first appearance: whatever key
  /// is published at that moment becomes the only one this profile will ever
  /// accept, and a later key is rejected as an impersonation until the user
  /// disconnects and reconnects. Nothing is returned — there is no secret for
  /// a caller to handle.
  public func enrollBrowserProfile(
    _ authorization: BrowserProfileAuthorization,
    publishedKey: SafariBridgeExtensionKey
  ) async throws(ProductivityError) {
    try requireAuthority(authorization.source)
    let profileID = try approvedProfiles.resolve(requestedID: authorization.profileID)
    guard let browserSecretStore else {
      throw .notConfigured
    }
    // A key published for another profile must not be pinned to this one.
    guard publishedKey.profileID == profileID else {
      throw .profileAmbiguous(candidates: [profileID, publishedKey.profileID].sorted())
    }
    try await browserSecretStore.pin(publicKey: publishedKey.publicKey, profileID: profileID)
    enrolledProfiles.insert(profileID)
  }

  public func revokeBrowserProfile(profileID: String) async throws(ProductivityError) {
    guard let browserSecretStore else { throw .notConfigured }
    try await browserSecretStore.revoke(profileID: profileID)
    enrolledProfiles.remove(profileID)
  }

  public func browserProfileState(profileID: String) async -> IntegrationConnectionState {
    guard let browserSecretStore else { return .unavailable(reason: "bridge is not configured") }
    guard (try? approvedProfiles.resolve(requestedID: profileID)) != nil else {
      return .unavailable(reason: "profile is not approved")
    }
    do {
      guard let pinned = try await browserSecretStore.pinnedPublicKey(profileID: profileID),
        !pinned.isEmpty
      else {
        return .notProvisioned
      }
      return .connected(fingerprint: ProductivityRedaction.fingerprint(profileID))
    } catch let error as ProductivityError {
      return .unavailable(reason: ProductivityRedaction.diagnostic(for: error))
    } catch {
      return .unavailable(reason: "the bridge key store is unavailable")
    }
  }

  // MARK: - Authority

  private func requireAuthority(
    _ source: IntegrationAuthorizationSource
  ) throws(ProductivityError) {
    switch source {
    case .userOnboardingConsent:
      return
    case .explicitTestAuthorization:
      guard allowsTestAuthorization else {
        throw .permissionDenied
      }
      return
    case .inferred:
      throw .permissionRequired
    }
  }
}
