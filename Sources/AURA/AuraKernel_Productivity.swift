import AppKit
import AuraConfig
import AuraCore
import AuraIntent
import AuraProductivity
import AuraSecurity
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
    guard let productivityRuntime else { return }
    await applyProductivityAvailability(await productivityRuntime.snapshots())
  }

  /// Apply snapshots that have already been taken.
  ///
  /// Taking a snapshot reads the Keychain, so the caller that needs both the
  /// registry updated and the count reported takes them once rather than
  /// paying for that twice.
  private func applyProductivityAvailability(
    _ snapshots: [ProductivityIntegrationSnapshot]
  ) async {
    guard let capabilityRegistry else { return }
    for snapshot in snapshots {
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

  /// Resolve every external integration's real availability, after the app has
  /// finished launching.
  ///
  /// `construct()` used to do this inline, and that was a launch-blocking
  /// mistake rather than a slow one. Each probe reads the Keychain;
  /// `SecItemCopyMatching` blocks until securityd answers, and securityd may
  /// need to authorize the calling binary first — which it cannot do while the
  /// app is still launching and has no window to host the request. The
  /// observed failure was total: `construct()` stopped inside the Keychain
  /// call, the app never finished launching, no window ever appeared, and the
  /// menu bar item sat at "Starting" with no control reachable by any means.
  ///
  /// Running it here bounds launch by construction alone. Nothing routes
  /// against the unresolved placeholder in the meantime, because `submitText`
  /// re-derives availability before every turn.
  func probeExternalAvailability() async {
    guard let productivityRuntime else {
      await runtimeHealthRegistry?.record(
        componentID: "productivity", status: .disabledByConfiguration,
        detail: "no read-first integration is configured")
      return
    }

    let snapshots = await productivityRuntime.snapshots()
    await applyProductivityAvailability(snapshots)
    let readyCount = snapshots.filter(\.isReady).count
    await runtimeHealthRegistry?.record(
      componentID: "productivity",
      status: readyCount == 0 ? .disabledByConfiguration : .ready,
      detail: readyCount == 0
        ? "no read-first integration is connected yet"
        : "\(readyCount) of \(snapshots.count) read-first integrations are connected")

    guard let safariBridgeRuntime else { return }
    let availability = await safariBridgeRuntime.availability()
    let status: RuntimeHealthStatus
    let detail: String
    switch availability {
    case .ready:
      status = .ready
      detail = "Chrome read bridge authenticated and ready"
    case .degraded(let reason):
      status = .degraded
      detail = "Chrome read bridge degraded: \(reason)"
    case .disabled(let reason):
      status = .disabledByConfiguration
      detail = "Chrome read bridge disabled: \(reason)"
    }
    await runtimeHealthRegistry?.record(
      componentID: "safari-bridge", status: status, detail: detail)

    // SP-012: VS Code availability is recomputed from live bridge health so
    // capabilities stay disabled until a real authenticated extension answers.
    await refreshVSCodeAvailability()
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
    // First attempt without delay: the common case is a key already on disk.
    if let published = bridge.publishedExtensionKey() {
      try await pinBrowserProfile(
        runtime: productivityRuntime, profileID: profileID, source: source, published: published)
      return
    }
    // The extension publishes its key the first time the user clicks its
    // toolbar button. If the user was just sent to Safari (the UI opens it
    // before this call when the key is missing), give that click a bounded
    // window to land instead of demanding a second manual attempt.
    for _ in 0..<6 {
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      if let published = bridge.publishedExtensionKey() {
        try await pinBrowserProfile(
          runtime: productivityRuntime, profileID: profileID, source: source,
          published: published)
        return
      }
    }
    throw AuraError.permissionDenied(
      "the AURA Chrome extension has not published a key yet; "
        + "enable AURA Chrome Read Bridge, open a page, press Command-Shift-Y, "
        + "then connect")
  }

  private func pinBrowserProfile(
    runtime: ProductivityRuntime,
    profileID: String,
    source: IntegrationAuthorizationSource,
    published: SafariBridgeExtensionKey
  ) async throws(AuraError) {
    do {
      try await runtime.onboarding.enrollBrowserProfile(
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

  /// Whether the Safari extension has published its verifying key yet.
  ///
  /// The UI checks this *before* calling `connectConfiguredBrowserProfile` so
  /// it can send the user to Safari's extension pane first; a published key
  /// makes the connect immediate, a missing one means the enable-and-click
  /// steps are still outstanding.
  func safariBridgeHasPublishedKey() async throws(AuraError) -> Bool {
    guard started, let productivityRuntime, let bridge = productivityRuntime.safariBridge else {
      throw AuraError.invalidConfiguration("AURA runtime is not started")
    }
    _ = productivityRuntime
    return bridge.publishedExtensionKey() != nil
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

  /// Enable or disable one native productivity leg (calendar/contacts) from
  /// the integrations row's button.
  ///
  /// The choice is written through the governed `ConfigurationEngine` at the
  /// user-settings layer, so it is audited, survives restart, and can never
  /// widen anything — it only composes an adapter whose real gate stays the
  /// user's macOS privacy decision. The runtime is recomposed afterwards so
  /// the row reflects the new composition without a relaunch, and the
  /// registry's availability is refreshed from the same snapshots the UI
  /// reads, so the health surface, router, and row cannot disagree.
  func setProductivityLegEnabled(key: String, enabled: Bool) async throws(AuraError) {
    guard let configurationEngine else {
      throw AuraError.invalidConfiguration("configuration governance is not started")
    }
    let result = try await configurationEngine.apply(
      ConfigurationPatch(
        layer: .userSettings,
        values: [key: .boolean(enabled)],
        source: "AURA integrations row"),
      actor: .user)
    guard result.accepted else {
      throw AuraError.invalidConfiguration(result.warnings.joined(separator: "; "))
    }
    var productivity = configuration.productivity
    switch key {
    case "calendarReadEnabled": productivity.calendarReadEnabled = enabled
    case "contactsReadEnabled": productivity.contactsReadEnabled = enabled
    default:
      throw AuraError.invalidConfiguration("unknown productivity leg key: \(key)")
    }
    configuration.productivity = productivity
    productivityRuntime = ProductivityRuntime.make(
      configuration: productivity,
      safariBridge: safariBridgeRuntime,
      secretStore: KeychainSecretStore(serviceName: configuration.app.serviceName),
      fetcher: URLSessionProviderFetcher(),
      injectionClassifier: injectionClassifier ?? PromptInjectionClassifier(),
      openURL: { NSWorkspace.shared.open($0) })
    await refreshProductivityAvailability()
  }

  /// Approve one Gmail account for read-first onboarding, from the row's
  /// inline control.
  ///
  /// Approval is the user naming the mailbox they are willing to let AURA
  /// consider — it grants nothing by itself, and enrollment additionally
  /// requires the user-present OAuth flow. The address is validated (non-
  /// empty, single-line, contains one @), stored in the governed
  /// configuration's user-settings layer so it survives restart, and the
  /// runtime recomposes so the row's Connect button appears immediately.
  /// Addresses already approved are idempotently accepted.
  func approveMailAccount(address: String) async throws(AuraError) {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains("\n"), !trimmed.contains("\r"),
      trimmed.contains("@"), !trimmed.hasPrefix("@"), !trimmed.hasSuffix("@")
    else {
      throw AuraError.invalidConfiguration(
        "enter a valid e-mail address to approve for read-only mail")
    }
    let accountID = trimmed.lowercased()
    guard !configuration.productivity.mailAccountIDs.contains(accountID) else {
      return
    }
    var productivity = configuration.productivity
    productivity.mailAccountIDs.append(accountID)
    productivity.mailAccountIDs.sort()
    // The mail section has no schema key of its own; its approval list lives
    // in the productivity configuration and is persisted with it. The
    // in-memory update and runtime recompose follow the same narrow path as
    // the leg toggles so the row and the composition cannot disagree.
    configuration.productivity = productivity
    productivityRuntime = ProductivityRuntime.make(
      configuration: productivity,
      safariBridge: safariBridgeRuntime,
      secretStore: KeychainSecretStore(serviceName: configuration.app.serviceName),
      fetcher: URLSessionProviderFetcher(),
      injectionClassifier: injectionClassifier ?? PromptInjectionClassifier(),
      openURL: { NSWorkspace.shared.open($0) })
    await refreshProductivityAvailability()
  }
}
