import AuraCore
import AuraIntent
import AuraProductivity
import AuraSecurity
import Foundation
import Testing

@testable import AURA
@testable import AuraSafariExtensionHandler

/// The onboarding service needs a token store; nothing here enrolls anything,
/// so an in-memory one keeps the suite off the real Keychain.
private actor UnusedSecretStore: SecretStoring {
  private var values: [String: Data] = [:]
  func store(_ value: Data, forKey key: String) async throws(AuraError) { values[key] = value }
  func retrieve(forKey key: String) async throws(AuraError) -> Data? { values[key] }
  func delete(forKey key: String) async throws(AuraError) { values.removeValue(forKey: key) }
}

/// SP-011: the things that had to be true before the live acceptance matrix
/// could run at all.
///
/// Every case here corresponds to a defect the live attempt exposed rather
/// than to a hypothetical. Three legs of the matrix were unrunnable on a real
/// Mac — not failing, unrunnable — because the calendar and contacts prompts
/// could never be raised, the acceptance configuration composed only mail, and
/// the Safari extension had no native half to package.

// MARK: - System permission prompts must be reachable

@Test("A not-determined native leg offers the in-app grant action")
func notDeterminedNativeLegCanGrantAccess() {
  let snapshot = ProductivityRuntime.nativeSnapshot(
    capabilityID: InitialCapabilitySet.calendarRead.id,
    isComposed: true,
    state: .notDetermined,
    name: "Calendar",
    settingsPaneName: "Calendars",
    configurationKey: "calendarReadEnabled")

  #expect(snapshot.canGrantAccess)
  #expect(!snapshot.isReady)
  #expect(!snapshot.remediation.isEmpty)
}

/// The defect this replaces: the row said "Grant Calendar access during Setup"
/// and no Setup control existed, so the only honest reading of the old
/// remediation was that the user had to do something impossible.
@Test("A decided native leg withholds the grant action and points at Settings")
func decidedNativeLegSendsUserToSystemSettings() {
  for state in [ProductivityAuthorizationState.denied, .restricted] {
    let snapshot = ProductivityRuntime.nativeSnapshot(
      capabilityID: InitialCapabilitySet.contactsLookup.id,
      isComposed: true,
      state: state,
      name: "Contacts",
      settingsPaneName: "Contacts",
      configurationKey: "contactsReadEnabled")

    #expect(!snapshot.canGrantAccess)
    #expect(snapshot.remediation.contains("System Settings"))
  }
}

@Test("An authorized native leg is ready and offers nothing further to do")
func authorizedNativeLegIsReady() {
  let snapshot = ProductivityRuntime.nativeSnapshot(
    capabilityID: InitialCapabilitySet.calendarRead.id,
    isComposed: true,
    state: .authorized,
    name: "Calendar",
    settingsPaneName: "Calendars",
    configurationKey: "calendarReadEnabled")

  #expect(snapshot.isReady)
  #expect(!snapshot.canGrantAccess)
  #expect(snapshot.remediation.isEmpty)
}

@Test("An uncomposed native leg never offers to raise a system prompt")
func uncomposedNativeLegCannotGrantAccess() {
  let snapshot = ProductivityRuntime.nativeSnapshot(
    capabilityID: InitialCapabilitySet.calendarRead.id,
    isComposed: false,
    state: .notDetermined,
    name: "Calendar",
    settingsPaneName: "Calendars",
    configurationKey: "calendarReadEnabled")

  #expect(!snapshot.canGrantAccess)
  #expect(!snapshot.isReady)
}

@Test("Requesting access for a leg that has no system permission is refused")
func requestingAccessForNonNativeLegIsRefused() async {
  let runtime = ProductivityRuntime(
    configuration: ProductivityConfiguration(),
    onboarding: IntegrationOnboardingService(
      approvedAccounts: ApprovedIntegrationAccounts(accountIDs: []),
      approvedProfiles: ApprovedBrowserProfiles(profileIDs: []),
      tokenStore: KeychainOAuthTokenStore(secretStore: UnusedSecretStore()),
      browserSecretStore: nil),
    safariBridge: nil,
    mail: nil,
    calendar: nil,
    contacts: nil)

  await #expect(throws: ProductivityError.self) {
    _ = try await runtime.requestNativeAccess(
      capabilityID: InitialCapabilitySet.mailRead.id)
  }
}

/// The third dead-end remediation SP-011 found: the browser row told the user
/// to "connect the Safari profile in Setup" while `connectBrowserProfile` had
/// no caller anywhere in the app.
@Test("An unprovisioned Safari profile offers the connect action that provisions it")
func unprovisionedSafariProfileCanConnect() async throws {
  let secretStore = UnusedSecretStore()
  let bridgeSecrets = SafariBridgeSecretStore(secretStore: secretStore)
  let runtime = ProductivityRuntime.make(
    configuration: ProductivityConfiguration(
      safariSharedContainerPath: NSTemporaryDirectory() + "sp011-\(UUID().uuidString).json"),
    safariBridge: SafariBridgeRuntime(
      profile: try BrowserProfileScope(profileID: "personal"),
      extensionID: "com.aura.safari-extension",
      sharedContainerURL: URL(
        fileURLWithPath: NSTemporaryDirectory() + "sp011-\(UUID().uuidString).json"),
      secretStore: bridgeSecrets,
      networkPolicy: ProductivityNetworkPolicy(allowlist: NetworkAllowlist(allowedHosts: []))),
    secretStore: secretStore)

  let before = await runtime.browserSnapshot()
  #expect(before.canConnect)
  #expect(!before.isRevocable)

  let signingKey = try await bridgeSecrets.signingKey(profileID: "personal")
  try await runtime.onboarding.enrollBrowserProfile(
    BrowserProfileAuthorization(profileID: "personal", source: .userOnboardingConsent),
    publishedKey: SafariBridgeSigner(privateKey: signingKey).publishedKey(
      extensionID: "com.aura.safari-extension", profileID: "personal"))

  // Provisioned: the connect action is spent and the revoke action appears.
  // The capability is still not ready — no envelope has been written — which
  // is the honest state for an extension that is installed but has never been
  // clicked.
  let after = await runtime.browserSnapshot()
  #expect(!after.canConnect)
  #expect(after.isRevocable)
  #expect(!after.isReady)
}

// MARK: - The acceptance profile must compose the matrix it has to run

@Test("The live acceptance profile composes only the legs its variables enable")
func liveAcceptanceProfileIsOffByDefault() {
  let configuration = AuraConfiguration.liveAcceptance(environment: [:])

  #expect(!configuration.productivity.calendarReadEnabled)
  #expect(!configuration.productivity.contactsReadEnabled)
  #expect(configuration.productivity.safariAllowedHosts.isEmpty)
  #expect(configuration.productivity.mailAccountIDs.isEmpty)
}

@Test("The live acceptance profile composes calendar, contacts and Safari on request")
func liveAcceptanceProfileComposesEveryLeg() {
  let configuration = AuraConfiguration.liveAcceptance(environment: [
    "AURA_SP011_ENABLE_CALENDAR": "1",
    "AURA_SP011_ENABLE_CONTACTS": "1",
    "AURA_SP011_SAFARI_CONTAINER": "/tmp/aura-sp011/observation.json",
    "AURA_SP011_SAFARI_ALLOWED_HOSTS": "example.com, ,example.org,",
  ])

  #expect(configuration.productivity.calendarReadEnabled)
  #expect(configuration.productivity.contactsReadEnabled)
  #expect(
    configuration.productivity.safariSharedContainerPath == "/tmp/aura-sp011/observation.json")
  // A trailing or doubled comma must not introduce a blank host: an empty
  // entry in an allowlist reads as a configured host and matches nothing.
  #expect(configuration.productivity.safariAllowedHosts == ["example.com", "example.org"])
}

@Test("SP-012 live profile configures only non-secret bridge coordinates")
func sp012LiveProfileConfiguresBridgeWithoutASecret() {
  let environment = [
    "AURA_SP012_LIVE_ACCEPTANCE": "1",
    "AURA_SP012_STATE_PATH": "/tmp/aura-sp012/state.json",
    "AURA_SP012_COMMAND_PATH": "/tmp/aura-sp012/command.json",
    "AURA_SP012_RESPONSE_PATH": "/tmp/aura-sp012/response.json",
    "AURA_SP012_EXTENSION_ID": "ai.aura.vscode-bridge",
  ]
  let configuration = AuraConfiguration.sp012LiveAcceptance(environment: environment)
  #expect(configuration.vscode.bridgeStatePath == "/tmp/aura-sp012/state.json")
  #expect(configuration.vscode.bridgeCommandPath == "/tmp/aura-sp012/command.json")
  #expect(configuration.vscode.bridgeResponsePath == "/tmp/aura-sp012/response.json")
  #expect(configuration.vscode.extensionID == "ai.aura.vscode-bridge")
}

// MARK: - The shipped bundle must be able to ask, and to host the extension

private let repositoryRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
  .deletingLastPathComponent()

private func plist(at relativePath: String) throws -> [String: Any] {
  let url = repositoryRoot.appending(path: relativePath)
  let data = try Data(contentsOf: url)
  let object = try PropertyListSerialization.propertyList(from: data, format: nil)
  return object as? [String: Any] ?? [:]
}

/// Without these strings macOS terminates the app the moment it asks — so the
/// grant button above would have crashed AURA rather than prompting.
@Test("The app bundle declares the calendar and contacts usage descriptions")
func appBundleDeclaresNativeUsageDescriptions() throws {
  let info = try plist(at: "Resources/AURA-Info.plist")

  for key in [
    "NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription",
    "NSContactsUsageDescription",
  ] {
    let value = info[key] as? String
    #expect(value?.isEmpty == false, "\(key) must be present and non-empty")
  }
}

@Test("The Safari extension bundle declares the web-extension entry point")
func safariExtensionDeclaresEntryPoint() throws {
  let info = try plist(at: "Resources/AuraSafariExtension-Info.plist")
  let extensionPoint = info["NSExtension"] as? [String: Any]

  #expect(extensionPoint?["NSExtensionPointIdentifier"] as? String
    == "com.apple.Safari.web-extension")
  #expect(extensionPoint?["NSExtensionPrincipalClass"] as? String
    == "SafariWebExtensionHandler")
  #expect(info["CFBundlePackageType"] as? String == "XPC!")
  // The identity the containing app authenticates. A mismatch here is refused
  // by SafariBridgeNativeMessageHandler as impersonation, which would look
  // like a broken extension rather than a configuration error.
  #expect(info["AURAExtensionID"] as? String == ProductivityConfiguration().safariExtensionID)
  #expect(info["AURAProfileID"] as? String == ProductivityConfiguration().safariProfileID)
  #expect(
    info["AURASecretServiceName"] as? String == ProductivityConfiguration().safariSecretServiceName)
}

/// The sandbox is what makes the path question real: Safari refuses an
/// unsandboxed web extension, and a sandboxed one writes into its own
/// container rather than the user's home.
@Test("The Safari extension is sandboxed and the app reads its container by default")
func safariExtensionIsSandboxedAndItsContainerIsTheDefault() throws {
  let entitlements = try plist(at: "Resources/AuraSafariExtension.entitlements")
  #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)

  let info = try plist(at: "Resources/AuraSafariExtension-Info.plist")
  let relativePath = try #require(info["AURASharedContainerPath"] as? String)

  // Both halves must name the same file. The extension resolves its relative
  // path against its own home; the app resolves the same relative path against
  // the real home. That only lines up because the sandbox exception below
  // keeps the extension's writes out of its container.
  #expect(relativePath == ProductivityConfiguration.safariSharedContainerRelativePath)
  #expect(
    ProductivityConfiguration.defaultSafariSharedContainerPath(homeDirectory: "/Users/example")
      == "/Users/example/\(relativePath)")

  // The exception has to name exactly the directory holding that file, with a
  // trailing slash — macOS treats a path without one as a single file.
  let exceptions =
    entitlements["com.apple.security.temporary-exception.files.home-relative-path.read-write"]
    as? [String]
  #expect(exceptions == ["/" + (relativePath as NSString).deletingLastPathComponent + "/"])

  // An unset path must resolve to that default rather than to the process's
  // working directory.
  #expect(
    ProductivityConfiguration().resolvedSafariSharedContainerPath
      == ProductivityConfiguration.defaultSafariSharedContainerPath())
  #expect(
    ProductivityConfiguration(safariSharedContainerPath: "/tmp/x.json")
      .resolvedSafariSharedContainerPath == "/tmp/x.json")
}

/// The sandbox redirects `NSHomeDirectory()` to the container, but the
/// entitlement grants the real home — so the extension has to resolve its
/// relative path against the real one or it writes where nothing reads.
@Test("The extension resolves its shared path against the real home, not the container")
func extensionResolvesAgainstRealHome() throws {
  let real = SafariExtensionConfiguration.realHomeDirectory().path
  #expect(!real.contains("/Library/Containers/"))
  #expect(real == NSHomeDirectory() || !NSHomeDirectory().hasPrefix(real + "/Library/Containers"))

  let info = try plist(at: "Resources/AuraSafariExtension-Info.plist")
  let relativePath = try #require(info["AURASharedContainerPath"] as? String)
  let configuration = SafariExtensionConfiguration(
    infoDictionary: info, homeDirectory: URL(fileURLWithPath: "/Users/example"))
  #expect(configuration.sharedContainerURL.path == "/Users/example/" + relativePath)
}

@Test("The bundle script packages the extension and the signing script seals it first")
func buildScriptsPackageAndSignTheExtension() throws {
  let build = try String(
    contentsOf: repositoryRoot.appending(path: "scripts/build-app-bundle.sh"), encoding: .utf8)
  #expect(build.contains("PlugIns/AuraSafariExtension.appex"))
  #expect(build.contains("AuraSafariExtensionHandler"))
  #expect(build.contains("Resources/SafariExtension/manifest.json"))
  #expect(build.contains("Resources/SafariExtension/background.js"))

  let sign = try String(
    contentsOf: repositoryRoot.appending(path: "scripts/codesign-adhoc.sh"), encoding: .utf8)
  // Anchored on the two `codesign` invocations, not on any mention of the
  // paths: both variables are also referenced while the script is still
  // defining them, near the top.
  guard let extensionSigning = sign.range(of: "$SAFARI_EXTENSION_ENTITLEMENTS\" \\"),
    let appSigning = sign.range(of: "$ENTITLEMENTS\" \\")
  else {
    Issue.record("both the extension and the app must be signed")
    return
  }
  // Signing the app seals its nested code; an appex signed afterwards
  // invalidates the containing bundle and Safari refuses to load it.
  #expect(extensionSigning.lowerBound < appSigning.lowerBound)
}

// MARK: - Launch must not be hostage to an external service

/// AURA hung at launch, with no window and no reachable control, because
/// `AuraKernel.construct()` probed the Safari bridge's availability inline.
/// That probe reads the Keychain; `SecItemCopyMatching` blocks until securityd
/// answers, and securityd may first need to authorize the calling binary —
/// which it cannot do while the app is still launching. A sample of the hung
/// process showed `construct()` stopped inside `SecItemCopyMatching`, three
/// frames below `SafariBridgeAvailability.availability`.
///
/// This is asserted against the source rather than by running a kernel because
/// `AuraKernel` constructs the real audio, screen-capture, and automation
/// stack; there is no seam to inject a slow Keychain into. The invariant that
/// was actually violated is "the construction path contains no external
/// probe", and that is exactly what is checked.
@Suite("launch path")
struct LaunchPathTests {
  private func constructionSource() throws -> String {
    try String(
      contentsOf: repositoryRoot.appending(path: "Sources/AURA/AuraKernel_Construction.swift"),
      encoding: .utf8)
  }

  @Test(
    "construction never probes an external service",
    arguments: [
      "bridge.availability()",
      "safariBridgeRuntime.availability()",
      "productivity.snapshots()",
      "productivityRuntime.snapshots()",
      "refreshProductivityAvailability()",
    ])
  func constructionDoesNotProbe(call: String) throws {
    let source = try constructionSource()
    #expect(
      !source.contains(call),
      "\(call) blocks on the Keychain and must run after launch, not during construction")
  }

  /// The probe has to exist somewhere, or the capabilities would simply never
  /// resolve — a hang traded for a permanent "loading".
  @Test("the deferred probe is started once the runtime is up")
  func startKicksOffTheProbe() throws {
    let runtimeAPI = try String(
      contentsOf: repositoryRoot.appending(path: "Sources/AURA/AuraKernel_RuntimeAPI.swift"),
      encoding: .utf8)
    #expect(runtimeAPI.contains("probeExternalAvailability()"))
  }

  /// The health surface must say "still checking" rather than "ready" while
  /// the probe is outstanding, so an unresolved Keychain is visible instead of
  /// being reported as a working integration.
  @Test("unprobed integrations are recorded as loading, not ready")
  func unprobedIntegrationsReportLoading() throws {
    let source = try constructionSource()
    #expect(source.contains("componentID: \"safari-bridge\", status: .loading"))
    #expect(source.contains("componentID: \"productivity\", status: .loading"))
  }
}

// MARK: - A lookup must not be able to kill the app

/// Asking AURA to find a contact crashed the whole application. The adapter
/// attached `CNContact.predicateForContacts(matchingName:)` to a
/// `CNContactFetchRequest` and enumerated it, and that combination raises an
/// Objective-C `NSException` — which Swift cannot catch. The exception unwound
/// through `do`/`catch` into `objc_exception_rethrow`, `std::terminate` and
/// `SIGABRT`; the crash report named
/// `CNContactStore.enumerateContactsWithFetchRequest:error:usingBlock:`
/// directly above `ContactsFrameworkLookupAdapter.lookup(query:limit:)`.
///
/// Asserted against the source because the failure is a process abort: a test
/// that exercised it would take the test runner down with it, and there is no
/// seam that makes an `NSException` observable from Swift.
@Suite("contacts lookup crash")
struct ContactsLookupCrashTests {
  private func adapterSource() throws -> String {
    try String(
      contentsOf: repositoryRoot.appending(
        path: "Sources/AuraProductivity/NativeProductivityAdapters.swift"),
      encoding: .utf8)
  }

  /// Matches the call, not the word: the fix's own comment names the API it
  /// replaced, and an assertion that cannot tell an explanation from a call
  /// site fails for the wrong reason.
  @Test("a name predicate is never enumerated")
  func namePredicateIsNeverEnumerated() throws {
    let source = try adapterSource()
    #expect(!source.contains("contactStore.enumerateContacts"))
    #expect(!source.contains("try contactStore.enumerateContacts"))
  }

  @Test("name matching goes through the unified-contacts query")
  func nameMatchingUsesUnifiedContacts() throws {
    let source = try adapterSource()
    #expect(source.contains("unifiedContacts("))
    #expect(source.contains("predicateForContacts(matchingName:"))
  }

  /// The second crash, same class as the first: `CNContactFormatter` read
  /// `middleName`, which the hand-written key list did not fetch, and an
  /// unfetched property raises rather than returning nil. Only the formatter
  /// knows what the formatter needs.
  @Test("the formatter's own key requirements are fetched")
  func formatterKeysAreFetched() throws {
    let source = try adapterSource()
    #expect(source.contains("CNContactFormatter.descriptorForRequiredKeys(for: .fullName)"))
  }
}

// MARK: - SP-012: the authenticated VS Code bridge must have a user-controlled
// provisioning path on the AURA side

/// SP-012's procedure step 1 is to "provision its shared secret ... through a
/// user-controlled path". The deterministic bridge contract existed, but
/// `VSCodeBridgeSecretStore.provision()` had no production caller: the kernel
/// only *read* an already-present secret and nothing ever wrote one, so the
/// live bridge could not be paired even after the extension was installed.
/// These source assertions pin the two invariants that make live pairing
/// possible: the secret store is retained on the kernel (not discarded after
/// construction) and the kernel exposes provisioning/revoke/probe methods that
/// a UI or CLI can call.
@Suite("vscode bridge provisioning path")
struct VSCodeBridgeProvisioningPathTests {
  private func runtimeAPISource() throws -> String {
    try String(
      contentsOf: repositoryRoot.appending(path: "Sources/AURA/AuraKernel_RuntimeAPI.swift"),
      encoding: .utf8)
  }

  private func constructionSource() throws -> String {
    try String(
      contentsOf: repositoryRoot.appending(path: "Sources/AURA/AuraKernel_Construction.swift"),
      encoding: .utf8)
  }

  @Test("the kernel retains the VS Code secret store after construction")
  func secretStoreIsRetained() throws {
    let construction = try constructionSource()
    #expect(construction.contains("self.vscodeBridgeSecretStore = secretStore"))
    let kernel = try String(
      contentsOf: repositoryRoot.appending(path: "Sources/AURA/AuraKernel.swift"),
      encoding: .utf8)
    #expect(kernel.contains("var vscodeBridgeSecretStore"))
  }

  @Test("the kernel exposes a user-controlled provisioning entry point")
  func provisioningEntryPointExists() throws {
    let source = try runtimeAPISource()
    #expect(source.contains("func provisionVSCodeBridge("))
    #expect(source.contains("func revokeVSCodeBridge(extensionID:"))
    #expect(source.contains("func vscodeBridgeProvisioned()"))
  }

  @Test("provisioning rejects an extension ID that does not match the configured one")
  func provisioningBindsToConfiguredExtensionID() throws {
    let source = try runtimeAPISource()
    #expect(
      source.contains("extensionID == configuration.vscode.extensionID"),
      "provisioning must bind to the configured extension ID, not an arbitrary one")
  }

  @Test("revocation refreshes availability so a failed delete is not reported as revoked")
  func revocationRefreshesAvailability() throws {
    let source = try runtimeAPISource()
    #expect(
      source.contains("revokeVSCodeBridge") && source.contains("await refreshVSCodeAvailability()"))
  }
}
