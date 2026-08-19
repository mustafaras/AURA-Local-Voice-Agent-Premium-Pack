import AuraCore
import AuraIntent
import AuraProductivity
import AuraSecurity
import Foundation
import Testing

@testable import AURA

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

  _ = try await runtime.onboarding.enrollBrowserProfile(
    BrowserProfileAuthorization(profileID: "personal", source: .userOnboardingConsent))

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
  let bundleID = try #require(info["CFBundleIdentifier"] as? String)
  let relativePath = try #require(info["AURASharedContainerPath"] as? String)

  let resolved = ProductivityConfiguration.defaultSafariSharedContainerPath(
    extensionBundleID: bundleID, homeDirectory: "/Users/example")
  // The app's default must name the exact file the sandboxed extension writes:
  // its container's Data directory joined with the extension's own relative
  // path. Anything else and the bridge looks for an envelope nothing places.
  #expect(resolved == "/Users/example/Library/Containers/\(bundleID)/Data/\(relativePath)")

  // An unset path must resolve to that default rather than to the process's
  // working directory.
  #expect(
    ProductivityConfiguration().resolvedSafariSharedContainerPath
      == ProductivityConfiguration.defaultSafariSharedContainerPath())
  #expect(
    ProductivityConfiguration(safariSharedContainerPath: "/tmp/x.json")
      .resolvedSafariSharedContainerPath == "/tmp/x.json")
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
