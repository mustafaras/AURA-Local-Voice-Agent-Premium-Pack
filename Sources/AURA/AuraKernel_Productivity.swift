import AuraCore
import AuraIntent
import AuraProductivity
import Foundation

extension AuraKernel {
  /// Recompute the four read-first capabilities' registry availability from
  /// the live composition.
  ///
  /// This fixes a specific class of untruthfulness. `InitialCapabilitySet`
  /// registers each read capability with a fixed disabled reason, and those
  /// strings age: after SP-009 packaged and wired the Safari bridge, the
  /// registry still told users the extension was "not packaged or wired into
  /// the composition root yet". Availability now comes from the same snapshot
  /// the UI shows, so the registry, the health surface, and the router cannot
  /// disagree with one another.
  func refreshProductivityAvailability() async {
    guard let capabilityRegistry, let productivityRuntime else { return }
    for snapshot in await productivityRuntime.snapshots() {
      guard let manifest = await capabilityRegistry.resolveLatest(id: snapshot.capabilityID) else {
        continue
      }
      // A disabled or degraded capability keeps its remediation inside the
      // reason string, because the capability panel renders the reason
      // verbatim and "disabled" alone gives the user nothing to act on.
      let availability: CapabilityAvailability
      switch snapshot.availability {
      case .ready:
        availability = .ready
      case .degraded(let reason):
        availability = .degraded(reason: Self.actionable(reason, snapshot.remediation))
      case .disabled(let reason):
        availability = .disabled(reason: Self.actionable(reason, snapshot.remediation))
      }
      await capabilityRegistry.setAvailability(availability, for: manifest.qualifiedID)
    }
  }

  private static func actionable(_ reason: String, _ remediation: String) -> String {
    remediation.isEmpty ? reason : "\(reason) \(remediation)"
  }

  /// The integration projection the R9 surfaces render. Gated by the same
  /// capability-health policy check the capability panel already uses, so
  /// inspecting integrations is audited like every other observation.
  func productivityIntegrationSnapshots() async throws(AuraError)
    -> [ProductivityIntegrationSnapshot]
  {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    try await evaluateDirectCapability(.capabilityHealthQuery)
    return await productivityRuntime.snapshots()
  }

  /// Enroll one explicitly authorized mail account.
  ///
  /// The token is passed in and handed straight to the Keychain-backed store;
  /// it is never logged, never returned, and never stored anywhere else. The
  /// onboarding service independently re-checks approval, authority, and
  /// scope tier, so this method cannot widen what it accepts.
  func connectMailAccount(
    accountID: String,
    accessToken: String,
    refreshToken: String? = nil,
    expiresAt: Date? = nil,
    source: IntegrationAuthorizationSource = .userOnboardingConsent
  ) async throws(AuraError) {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let scopes = OAuthScopeManifest.gmailReadFirst.scopes(for: .read)
    do {
      let material = try OAuthTokenMaterial(
        accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt,
        scopes: scopes)
      try await productivityRuntime.onboarding.enroll(
        IntegrationAccountAuthorization(
          provider: .gmail, accountID: accountID, tier: .read, grantedScopes: scopes,
          source: source, material: material))
    } catch {
      // Everything in the block above uses typed throws, so `error` is a
      // `ProductivityError`. The redacted diagnostic is used, never
      // `errorDescription`: an ambiguous account would otherwise put every
      // approved address into an error a caller may well log.
      throw AuraError.permissionDenied(ProductivityRedaction.diagnostic(for: error))
    }
    await refreshProductivityAvailability()
  }

  /// Start the user-present Gmail OAuth flow. The coordinator opens the
  /// provider page, validates the loopback callback and PKCE state, exchanges
  /// the code, probes the approved Gmail account, and writes the resulting
  /// credential only through the onboarding Keychain boundary.
  func connectMailAccountViaOAuth(
    source: IntegrationAuthorizationSource = .userOnboardingConsent
  ) async throws(AuraError) {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    do {
      _ = try await productivityRuntime.connectGmail(source: source)
    } catch {
      throw AuraError.permissionDenied(ProductivityRedaction.diagnostic(for: error))
    }
    await refreshProductivityAvailability()
  }

  /// Connect the approved Safari profile by pinning the key its extension
  /// published.
  ///
  /// Nothing is returned and nothing secret is handled: the extension keeps
  /// its private key, and this only records which public key this profile will
  /// accept from now on. It fails when the extension has not published a key
  /// yet, which is the honest answer — the user has not run it once.
  func connectBrowserProfile(
    profileID: String,
    source: IntegrationAuthorizationSource = .userOnboardingConsent
  ) async throws(AuraError) {
    guard started, let productivityRuntime, let bridge = productivityRuntime.safariBridge else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    guard let published = bridge.publishedExtensionKey() else {
      throw AuraError.permissionDenied(
        "the AURA Safari extension has not published a key yet; "
          + "open a page and click its toolbar button once, then connect")
    }
    do {
      try await productivityRuntime.onboarding.enrollBrowserProfile(
        BrowserProfileAuthorization(profileID: profileID, source: source),
        publishedKey: published)
    } catch {
      throw AuraError.permissionDenied(ProductivityRedaction.diagnostic(for: error))
    }
    await refreshProductivityAvailability()
  }

  /// Provision the configured Safari profile's bridge secret. The kernel names
  /// the profile from its own configuration, mirroring the revoke path, so no
  /// caller can point provisioning at a profile the user never approved.
  func connectConfiguredBrowserProfile() async throws(AuraError) {
    try await connectBrowserProfile(profileID: configuration.productivity.safariProfileID)
  }

  /// Revoke a connected mail account. Revocation deletes the Keychain item
  /// first and refreshes availability only afterwards, so a failed deletion
  /// leaves the capability reported as connected rather than claiming a
  /// revocation that did not happen.
  func revokeMailAccount(accountID: String) async throws(AuraError) {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    do {
      try await productivityRuntime.onboarding.revokeAccount(
        provider: .gmail, accountID: accountID)
    } catch {
      throw AuraError.permissionDenied(ProductivityRedaction.diagnostic(for: error))
    }
    await refreshProductivityAvailability()
  }

  /// The approved mail accounts, for a UI that must disconnect one without
  /// ever handling an address itself when only one is approved.
  func approvedMailAccountIDs() async throws(AuraError) -> [String] {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    return await productivityRuntime.onboarding.approvedAccountIDs()
  }

  /// Ask macOS for a native leg's permission on the user's behalf.
  ///
  /// The prompt is a user-present system dialog; AURA can only cause it to
  /// appear. Availability is refreshed afterwards from the real authorization
  /// status rather than from the returned flag, so a dismissed or denied
  /// prompt leaves the capability disabled instead of optimistically ready.
  @discardableResult
  func grantNativeIntegrationAccess(
    capabilityID: String
  ) async throws(AuraError) -> Bool {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    let granted: Bool
    do {
      granted = try await productivityRuntime.requestNativeAccess(capabilityID: capabilityID)
    } catch {
      await refreshProductivityAvailability()
      throw AuraError.permissionDenied(ProductivityRedaction.diagnostic(for: error))
    }
    await refreshProductivityAvailability()
    return granted
  }

  /// Revoke the configured Safari profile's bridge secret. The kernel names
  /// the profile from its own configuration so no caller can point the
  /// revocation at a different one.
  func revokeConnectedBrowserProfile() async throws(AuraError) {
    try await revokeBrowserProfile(profileID: configuration.productivity.safariProfileID)
  }

  func revokeBrowserProfile(profileID: String) async throws(AuraError) {
    guard started, let productivityRuntime else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    do {
      try await productivityRuntime.onboarding.revokeBrowserProfile(profileID: profileID)
    } catch {
      throw AuraError.permissionDenied(ProductivityRedaction.diagnostic(for: error))
    }
    await refreshProductivityAvailability()
  }
}
