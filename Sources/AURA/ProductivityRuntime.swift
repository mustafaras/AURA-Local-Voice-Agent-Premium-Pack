import AuraCore
import AuraIntent
import AuraProductivity
import AuraSecurity
import Foundation

/// One integration's user-facing state: what it is, whether it can be used
/// right now, and — when it cannot — the single next thing the user can do
/// about it.
///
/// `remediation` is what makes the R9 capability surface *actionable* rather
/// than merely honest. "Disabled" without "connect an account in Setup" tells
/// the user their assistant is broken; with it, it tells them what to do.
struct ProductivityIntegrationSnapshot: Sendable, Equatable, Identifiable {
  let capabilityID: String
  let availability: CapabilityAvailability
  /// Masked account or profile label for the user's own screen, or `nil` when
  /// nothing is enrolled. Never the full address.
  let accountLabel: String?
  /// Irreversible fingerprint safe for logs and evidence records.
  let sourceFingerprint: String?
  /// The next concrete user action; empty when the integration is ready.
  let remediation: String
  /// Whether a connected credential exists that the user could revoke.
  let isRevocable: Bool
  /// Whether the user can start an in-app OAuth enrollment flow.
  let canConnect: Bool
  /// Whether the user can trigger this leg's *system* permission prompt from
  /// inside AURA. Only ever true for a composed native leg whose authorization
  /// is still `notDetermined`: once macOS has recorded a decision the prompt
  /// never appears again, and the remediation has to point at System Settings
  /// instead. A row that says "grant access during Setup" without this flag is
  /// a dead end — the exact defect SP-011 found on the calendar and contacts
  /// rows.
  let canGrantAccess: Bool

  init(
    capabilityID: String,
    availability: CapabilityAvailability,
    accountLabel: String?,
    sourceFingerprint: String?,
    remediation: String,
    isRevocable: Bool,
    canConnect: Bool = false,
    canGrantAccess: Bool = false
  ) {
    self.capabilityID = capabilityID
    self.availability = availability
    self.accountLabel = accountLabel
    self.sourceFingerprint = sourceFingerprint
    self.remediation = remediation
    self.isRevocable = isRevocable
    self.canConnect = canConnect
    self.canGrantAccess = canGrantAccess
  }

  var id: String { capabilityID }

  var isReady: Bool {
    if case .ready = availability { return true }
    return false
  }
}

/// The composition unit for the read-first productivity capabilities.
///
/// SP-009 wired the browser leg through `SafariBridgeRuntime`; this type owns
/// the other three and the onboarding service all four share, so one place
/// answers "can this capability actually run, and for whose account?".
///
/// Three rules hold across every leg:
///
/// * **Availability is derived, never declared.** Each value is recomputed
///   from the live authorization status, the token store, and the bridge
///   probe. The registry's previous behavior — a hardcoded disabled reason —
///   went stale the moment SP-009 wired the bridge, and the user was told the
///   extension was unpackaged when it no longer was.
/// * **No enrollment, no adapter.** An approved-but-unconnected account
///   yields a `.disabled` capability, so the router refuses the intent before
///   any adapter is asked for data.
/// * **Read only.** Nothing here can compose, send, or mutate. The mail
///   adapter is built with read scopes validated against the reviewed
///   manifest, and no write adapter is constructed at all.
struct ProductivityRuntime: Sendable {
  let configuration: ProductivityConfiguration
  let onboarding: IntegrationOnboardingService
  let gmailOAuth: GmailOAuthAuthorizationCoordinator?
  let gmailTransport: GmailReadTransport?
  let safariBridge: SafariBridgeRuntime?
  let mail: GmailReadAdapter?
  let calendar: EventKitCalendarReadAdapter?
  let contacts: ContactsFrameworkLookupAdapter?
  /// Why a leg is absent when it could not be composed at all (bad endpoint,
  /// unusable scope manifest). Keyed by capability ID.
  let compositionFailures: [String: String]

  init(
    configuration: ProductivityConfiguration,
    onboarding: IntegrationOnboardingService,
    gmailOAuth: GmailOAuthAuthorizationCoordinator? = nil,
    gmailTransport: GmailReadTransport? = nil,
    safariBridge: SafariBridgeRuntime?,
    mail: GmailReadAdapter?,
    calendar: EventKitCalendarReadAdapter?,
    contacts: ContactsFrameworkLookupAdapter?,
    compositionFailures: [String: String] = [:]
  ) {
    self.configuration = configuration
    self.onboarding = onboarding
    self.gmailOAuth = gmailOAuth
    self.gmailTransport = gmailTransport
    self.safariBridge = safariBridge
    self.mail = mail
    self.calendar = calendar
    self.contacts = contacts
    self.compositionFailures = compositionFailures
  }

  /// Build every leg the configuration authorizes.
  ///
  /// A leg that cannot be composed is recorded in `compositionFailures` and
  /// left `nil` rather than throwing: one malformed mail endpoint must not
  /// take the calendar and contacts capabilities down with it, and the
  /// failure has to stay visible in the health surface instead of vanishing
  /// into a construction error.
  static func make(
    configuration: ProductivityConfiguration,
    safariBridge: SafariBridgeRuntime?,
    secretStore: any SecretStoring,
    gmailOAuthClientSecret: String? = nil,
    fetcher: any HTTPProviderFetching = URLSessionProviderFetcher(),
    injectionClassifier: PromptInjectionClassifier = PromptInjectionClassifier(),
    openURL: @escaping @Sendable (URL) -> Bool = { _ in false }
  ) -> ProductivityRuntime {
    let approvedAccounts = ApprovedIntegrationAccounts(accountIDs: configuration.mailAccountIDs)
    let approvedProfiles = ApprovedBrowserProfiles(profileIDs: [configuration.safariProfileID])
    let tokenStore = KeychainOAuthTokenStore(secretStore: secretStore)
    let onboarding = IntegrationOnboardingService(
      approvedAccounts: approvedAccounts,
      approvedProfiles: approvedProfiles,
      tokenStore: tokenStore,
      browserSecretStore: safariBridge?.secretStore,
      allowsTestAuthorization: configuration.allowsTestAccountAuthorization)

    var failures: [String: String] = [:]
    var mail: GmailReadAdapter?
    var gmailTransport: GmailReadTransport?
    if !configuration.mailAccountIDs.isEmpty {
      let networkPolicy = ProductivityNetworkPolicy(
        allowlist: NetworkAllowlist(allowedHosts: Set(configuration.mailAllowedHosts)))
      do {
        guard let endpoint = URL(string: configuration.mailEndpoint) else {
          throw ProductivityError.invalidInput("mail endpoint is not a URL")
        }
        let transport = try URLSessionGmailReadTransport(
          endpoint: endpoint, fetcher: fetcher, networkPolicy: networkPolicy)
        gmailTransport = transport
        mail = try GmailReadAdapter(
          approvedAccounts: approvedAccounts,
          configuredScopes: OAuthScopeManifest.gmailReadFirst.scopes(for: .read),
          tokenStore: tokenStore,
          transport: transport,
          networkPolicy: networkPolicy,
          classifier: injectionClassifier)
      } catch let error as ProductivityError {
        failures[InitialCapabilitySet.mailRead.id] = ProductivityRedaction.diagnostic(for: error)
      } catch {
        failures[InitialCapabilitySet.mailRead.id] = "the mail adapter could not be composed"
      }
    }

    let gmailOAuth: GmailOAuthAuthorizationCoordinator?
    if !configuration.gmailOAuthClientID.isEmpty,
      let redirectURI = URL(string: configuration.gmailOAuthRedirectURI),
      let oauthConfiguration = try? GmailOAuthConfiguration(
        clientID: configuration.gmailOAuthClientID,
        clientSecret: gmailOAuthClientSecret,
        redirectURI: redirectURI)
    {
      gmailOAuth = GmailOAuthAuthorizationCoordinator(
        configuration: oauthConfiguration, fetcher: fetcher, openURL: openURL)
    } else {
      gmailOAuth = nil
    }

    return ProductivityRuntime(
      configuration: configuration,
      onboarding: onboarding,
      gmailOAuth: gmailOAuth,
      gmailTransport: gmailTransport,
      safariBridge: safariBridge,
      mail: mail,
      calendar: configuration.calendarReadEnabled
        ? EventKitCalendarReadAdapter(classifier: injectionClassifier) : nil,
      contacts: configuration.contactsReadEnabled
        ? ContactsFrameworkLookupAdapter(classifier: injectionClassifier) : nil,
      compositionFailures: failures)
  }

  /// Complete the user-present Gmail flow and enroll exactly one approved
  /// account. The OAuth result remains in memory only across the provider
  /// account probe and Keychain write; no token is returned to the UI.
  func connectGmail(
    source: IntegrationAuthorizationSource = .userOnboardingConsent
  ) async throws(ProductivityError) -> IntegrationAccountRecord {
    guard let gmailOAuth, let gmailTransport else {
      throw .notConfigured
    }
    let material = try await gmailOAuth.authorize()
    let snapshots: [MailAccountSnapshot]
    do {
      snapshots = try await gmailTransport.accounts(accessToken: material.accessToken)
    } catch let error as ProductivityError {
      throw error
    } catch {
      throw .providerUnavailable
    }
    let approved = await onboarding.approvedAccountIDs()
    let matches = snapshots.filter { approved.contains($0.id) }
    guard matches.count == 1, let account = matches.first else {
      throw .accountAmbiguous(candidates: matches.map(\.id).sorted())
    }
    return try await onboarding.enroll(
      IntegrationAccountAuthorization(
        provider: .gmail,
        accountID: account.id,
        tier: .read,
        grantedScopes: material.scopes,
        source: source,
        material: material))
  }

  /// The four snapshots, in the order the UI lists them.
  func snapshots() async -> [ProductivityIntegrationSnapshot] {
    [
      await browserSnapshot(),
      await mailSnapshot(),
      calendarSnapshot(),
      contactsSnapshot(),
    ]
  }

  // MARK: - Per-capability state

  func browserSnapshot() async -> ProductivityIntegrationSnapshot {
    let capabilityID = InitialCapabilitySet.browserRead.id
    guard let safariBridge else {
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "The Chrome read bridge is not configured."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Reinstall the bundled Chrome bridge.",
        isRevocable: false)
    }
    let profileID = safariBridge.profile.profileID
    let state = await onboarding.browserProfileState(profileID: profileID)
    let availability = await safariBridge.availability()
    let remediation: String
    switch (state, availability) {
    case (_, .ready):
      remediation = ""
    case (.notProvisioned, _):
      remediation = "Connect Chrome to pin the local extension key."
    default:
      // Provisioned but the probe still failed — the extension is not
      // installed, not enabled, or has written no observation yet.
      remediation = "Enable AURA Chrome Read Bridge, then press Command-Shift-Y on a page."
    }
    return ProductivityIntegrationSnapshot(
      capabilityID: capabilityID,
      availability: availability,
      accountLabel: state == .notProvisioned ? nil : profileID,
      sourceFingerprint: ProductivityRedaction.fingerprint(profileID),
      remediation: remediation,
      isRevocable: state != .notProvisioned,
      // Provisioning writes the bridge secret the extension's native half
      // signs with. The kernel had this action from SP-009 and no caller ever
      // reached it, so "connect the Safari profile in Setup" named a control
      // that did not exist.
      canConnect: state == .notProvisioned)
  }

  func mailSnapshot() async -> ProductivityIntegrationSnapshot {
    let capabilityID = InitialCapabilitySet.mailRead.id
    if let failure = compositionFailures[capabilityID] {
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "Mail is not composed: \(failure)."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Correct the mail endpoint and allowed hosts in configuration.",
        isRevocable: false)
    }
    let approved = await onboarding.approvedAccountIDs()
    guard !approved.isEmpty else {
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "No mail account is approved yet."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Approve a mail account in Setup, then connect it.",
        isRevocable: false,
        canConnect: false)
    }
    if approved.count > 1 {
      var hasConnectedAccount = false
      for accountID in approved {
        if case .connected = await onboarding.connectionState(
          provider: .gmail, accountID: accountID)
        {
          hasConnectedAccount = true
          break
        }
      }
      // A connected but ambiguous set is ready to ask a clarification
      // question, not ready to read. Marking the registry disabled here used
      // to stop the turn before `ProductivityReadBridge` could ask which
      // account, producing a misleading "no tool registered" error. The
      // bridge still refuses before provider contact until an account is
      // explicitly selected.
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: hasConnectedAccount
          ? .ready
          : .disabled(
            reason: "\(approved.count) mail accounts are approved but none is connected."),
        accountLabel: nil,
        sourceFingerprint: nil,
        remediation: "Choose which approved account AURA should read.",
        isRevocable: false,
        canConnect: false)
    }
    let accountID = approved[0]
    guard mail != nil else {
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "The mail adapter is not composed in this build."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Approve a mail account in configuration to compose the adapter.",
        isRevocable: false)
    }
    let state = await onboarding.connectionState(provider: .gmail, accountID: accountID)
    let label = ProductivityRedaction.displayLabel(accountID)
    let fingerprint = ProductivityRedaction.fingerprint(accountID)
    switch state {
    case .connected:
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID, availability: .ready,
        accountLabel: label, sourceFingerprint: fingerprint,
        remediation: "", isRevocable: true)
    case .notProvisioned:
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "\(label) is approved but not connected."),
        accountLabel: label, sourceFingerprint: fingerprint,
        remediation: "Connect Gmail to store a read-only credential.",
        isRevocable: false,
        canConnect: gmailOAuth != nil)
    case .credentialExpiredOrRevoked:
      // Degraded, not disabled: the account is still the user's choice and one
      // reconnection away, which is a different ask from onboarding a new one.
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .degraded(reason: "The stored credential for \(label) is no longer valid."),
        accountLabel: label, sourceFingerprint: fingerprint,
        remediation: "Reconnect Gmail to restore read-only access.",
        isRevocable: true,
        canConnect: gmailOAuth != nil)
    case .unavailable(let reason):
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .degraded(reason: "Mail is unavailable: \(reason)."),
        accountLabel: label, sourceFingerprint: fingerprint,
        remediation: "Retry once the credential store is reachable.", isRevocable: false)
    }
  }

  func calendarSnapshot() -> ProductivityIntegrationSnapshot {
    Self.nativeSnapshot(
      capabilityID: InitialCapabilitySet.calendarRead.id,
      isComposed: calendar != nil,
      state: ProductivityAuthorizationProbe.calendarState(),
      name: "Calendar",
      settingsPaneName: "Calendars",
      configurationKey: "calendarReadEnabled")
  }

  func contactsSnapshot() -> ProductivityIntegrationSnapshot {
    Self.nativeSnapshot(
      capabilityID: InitialCapabilitySet.contactsLookup.id,
      isComposed: contacts != nil,
      state: ProductivityAuthorizationProbe.contactsState(),
      name: "Contacts",
      settingsPaneName: "Contacts",
      configurationKey: "contactsReadEnabled")
  }

  /// Ask macOS for one native leg's permission, from the user's click.
  ///
  /// This is the only production caller of the adapters' `requestReadAccess()`.
  /// Before SP-011 there was none: both adapters exposed the call, the health
  /// surface told the user to "grant access during Setup", and no Setup
  /// control existed — so a `notDetermined` calendar or contacts row could
  /// never become ready through the product at all.
  ///
  /// The request is refused unless the leg is composed *and* still
  /// `notDetermined`. macOS shows its prompt exactly once; asking again after
  /// a decision returns the recorded answer silently, which would let the UI
  /// spin a button that can no longer do anything. In that state the snapshot
  /// withholds the button and points at System Settings instead.
  func requestNativeAccess(
    capabilityID: String
  ) async throws(ProductivityError) -> Bool {
    switch capabilityID {
    case InitialCapabilitySet.calendarRead.id:
      guard let calendar else { throw .notConfigured }
      guard ProductivityAuthorizationProbe.calendarState() == .notDetermined else {
        throw .permissionDenied
      }
      return try await calendar.requestReadAccess()
    case InitialCapabilitySet.contactsLookup.id:
      guard let contacts else { throw .notConfigured }
      guard ProductivityAuthorizationProbe.contactsState() == .notDetermined else {
        throw .permissionDenied
      }
      return try await contacts.requestReadAccess()
    default:
      throw .unsupported("that integration has no system permission to request")
    }
  }

  /// Calendar and contacts differ only in their names and probes; their state
  /// machine is identical, so it lives in one place.
  ///
  /// `static` and non-private so the suite can drive every authorization
  /// state. The instance path reads the live macOS status, which no test can
  /// choose — and "does a `notDetermined` row offer the grant button" is
  /// exactly the assertion that has to hold on a machine where the answer is
  /// already `denied`.
  static func nativeSnapshot(
    capabilityID: String,
    isComposed: Bool,
    state: ProductivityAuthorizationState,
    name: String,
    settingsPaneName: String,
    configurationKey: String
  ) -> ProductivityIntegrationSnapshot {
    guard isComposed else {
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "\(name) reading is turned off in configuration."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Set productivity.\(configurationKey) to enable \(name.lowercased()) reads.",
        isRevocable: false)
    }
    switch state {
    case .authorized:
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID, availability: .ready,
        accountLabel: "This Mac", sourceFingerprint: nil, remediation: "", isRevocable: false)
    case .notDetermined:
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "\(name) access has not been granted yet."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Grant \(name) access, then macOS will ask you to confirm.",
        isRevocable: false,
        canGrantAccess: true)
    case .denied, .restricted:
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .disabled(reason: "\(name) access is denied for AURA."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation:
          "Allow AURA in System Settings › Privacy & Security › \(settingsPaneName).",
        isRevocable: false)
    case .unavailable:
      return ProductivityIntegrationSnapshot(
        capabilityID: capabilityID,
        availability: .degraded(reason: "\(name) reported an unrecognized authorization state."),
        accountLabel: nil, sourceFingerprint: nil,
        remediation: "Re-check \(name) access in System Settings.", isRevocable: false)
    }
  }
}
