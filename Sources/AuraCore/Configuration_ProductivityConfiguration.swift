import Foundation

/// Configuration for the R5 productivity integrations: the Safari read
/// bridge (SP-009) and the provider/account composition SP-010 adds.
///
/// This file is the *approval* record, not the credential store. Listing an
/// address here says the user is willing to consider that account; it does
/// not enroll it, and it grants nothing on its own. Enrollment additionally
/// requires an explicit `IntegrationAuthorizationSource` and writes the token
/// to the Keychain, which is the only place a credential exists.
public struct ProductivityConfiguration: Codable, Sendable, Equatable {
  /// The approved Safari profile the read bridge is bound to.
  public var safariProfileID: String

  /// The Safari Web Extension bundle identifier the bridge authenticates.
  public var safariExtensionID: String

  /// Absolute path to the shared container file where the extension writes
  /// its signed observation envelope. Empty means "use
  /// `defaultSafariSharedContainerPath`", which is where the shipped
  /// extension actually writes.
  public var safariSharedContainerPath: String

  /// Keychain service name for the Safari bridge shared secret.
  public var safariSecretServiceName: String

  /// Hosts the Safari bridge may read (the approved page domains).
  public var safariAllowedHosts: [String]

  /// Mail accounts the user has approved for consideration. Empty by
  /// default: no mailbox is reachable until the user names one *and*
  /// completes onboarding for it.
  public var mailAccountIDs: [String]

  /// Read-only provider API base. Constrained to HTTPS by `validate()` and
  /// re-checked against the transport's own host allowlist at construction.
  public var mailEndpoint: String

  /// Hosts the mail transport may reach. Deny-by-default: an endpoint whose
  /// host is absent from this list fails closed at construction.
  public var mailAllowedHosts: [String]

  /// Whether the calendar read adapter is composed at all. The user's
  /// EventKit authorization remains the real gate; this only decides whether
  /// AURA offers the capability.
  public var calendarReadEnabled: Bool

  /// Whether the contacts lookup adapter is composed at all. The user's
  /// Contacts authorization remains the real gate.
  public var contactsReadEnabled: Bool

  /// Whether `IntegrationAuthorizationSource.explicitTestAuthorization` is
  /// accepted. Off in production defaults: an acceptance run must turn it on
  /// deliberately, so a test-shaped enrollment can never happen silently on a
  /// user's machine. SP-011 turns this on through `AuraConfiguration.default`.
  public var allowsTestAccountAuthorization: Bool

  /// Public Desktop OAuth client ID used only to construct the user-present
  /// Gmail authorization URL. No client secret is Codable or stored here;
  /// the SP-011 compatibility input, when needed by an existing client, is
  /// process-scoped and reaches only the token POST body.
  public var gmailOAuthClientID: String

  /// Loopback callback used by the in-app Gmail OAuth flow. The callback
  /// listener binds only to this local endpoint and accepts one request.
  public var gmailOAuthRedirectURI: String

  /// Where the shipped Safari extension writes its envelope.
  ///
  /// Both halves have to name the same file, and neither default location
  /// works. Safari refuses a web extension that is not App Sandbox confined,
  /// so the extension's own `NSHomeDirectory()` is its sandbox container — and
  /// macOS protects one app's container from every other process, so the
  /// containing app cannot read it. An App Group would be the usual shared
  /// location and needs a provisioned Team ID.
  ///
  /// So the bridge uses one ordinary Application Support directory, which the
  /// unsandboxed app reads freely and the extension reaches through a
  /// home-relative-path sandbox exception scoped to exactly this directory.
  ///
  /// Leaving this unset used to leave the path empty, which resolved to the
  /// process's working directory: the bridge could never find an envelope the
  /// extension had genuinely written, and reported itself unavailable for a
  /// reason no user could act on.
  public static let safariSharedContainerRelativePath =
    "Library/Application Support/AURA/SafariBridge/observation.json"

  public static func defaultSafariSharedContainerPath(
    homeDirectory: String = NSHomeDirectory()
  ) -> String {
    "\(homeDirectory)/\(safariSharedContainerRelativePath)"
  }

  /// The path actually used, resolving the empty default.
  public var resolvedSafariSharedContainerPath: String {
    safariSharedContainerPath.isEmpty
      ? Self.defaultSafariSharedContainerPath()
      : safariSharedContainerPath
  }

  public init(
    safariProfileID: String = "personal",
    safariExtensionID: String = "com.aura.safari-extension",
    safariSharedContainerPath: String = "",
    safariSecretServiceName: String = "com.aura.safari-bridge",
    safariAllowedHosts: [String] = [],
    mailAccountIDs: [String] = [],
    mailEndpoint: String = "https://gmail.googleapis.com/gmail/v1",
    mailAllowedHosts: [String] = ["gmail.googleapis.com"],
    calendarReadEnabled: Bool = false,
    contactsReadEnabled: Bool = false,
    allowsTestAccountAuthorization: Bool = false,
    gmailOAuthClientID: String = "",
    gmailOAuthRedirectURI: String = "http://127.0.0.1:48080/oauth2callback"
  ) {
    self.safariProfileID = safariProfileID
    self.safariExtensionID = safariExtensionID
    self.safariSharedContainerPath = safariSharedContainerPath
    self.safariSecretServiceName = safariSecretServiceName
    self.safariAllowedHosts = safariAllowedHosts
    self.mailAccountIDs = mailAccountIDs
    self.mailEndpoint = mailEndpoint
    self.mailAllowedHosts = mailAllowedHosts
    self.calendarReadEnabled = calendarReadEnabled
    self.contactsReadEnabled = contactsReadEnabled
    self.allowsTestAccountAuthorization = allowsTestAccountAuthorization
    self.gmailOAuthClientID = gmailOAuthClientID
    self.gmailOAuthRedirectURI = gmailOAuthRedirectURI
  }

  enum CodingKeys: String, CodingKey {
    case safariProfileID, safariExtensionID, safariSharedContainerPath
    case safariSecretServiceName, safariAllowedHosts
    case mailAccountIDs, mailEndpoint, mailAllowedHosts
    case calendarReadEnabled, contactsReadEnabled, allowsTestAccountAuthorization
    case gmailOAuthClientID, gmailOAuthRedirectURI
  }

  /// Decode partially, like every other configuration section.
  ///
  /// The synthesized decoder would require every key, so a configuration
  /// written against the SP-009 shape would stop decoding the moment SP-010
  /// added a field — the whole `productivity` section would be discarded and
  /// the Safari bridge would silently fall back to defaults. Each key is
  /// therefore optional with an explicit default.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = ProductivityConfiguration()
    self.init(
      safariProfileID: try container.decodeIfPresent(String.self, forKey: .safariProfileID)
        ?? defaults.safariProfileID,
      safariExtensionID: try container.decodeIfPresent(String.self, forKey: .safariExtensionID)
        ?? defaults.safariExtensionID,
      safariSharedContainerPath: try container.decodeIfPresent(
        String.self, forKey: .safariSharedContainerPath) ?? defaults.safariSharedContainerPath,
      safariSecretServiceName: try container.decodeIfPresent(
        String.self, forKey: .safariSecretServiceName) ?? defaults.safariSecretServiceName,
      safariAllowedHosts: try container.decodeIfPresent(
        [String].self, forKey: .safariAllowedHosts) ?? defaults.safariAllowedHosts,
      mailAccountIDs: try container.decodeIfPresent([String].self, forKey: .mailAccountIDs)
        ?? defaults.mailAccountIDs,
      mailEndpoint: try container.decodeIfPresent(String.self, forKey: .mailEndpoint)
        ?? defaults.mailEndpoint,
      mailAllowedHosts: try container.decodeIfPresent([String].self, forKey: .mailAllowedHosts)
        ?? defaults.mailAllowedHosts,
      calendarReadEnabled: try container.decodeIfPresent(Bool.self, forKey: .calendarReadEnabled)
        ?? defaults.calendarReadEnabled,
      contactsReadEnabled: try container.decodeIfPresent(Bool.self, forKey: .contactsReadEnabled)
        ?? defaults.contactsReadEnabled,
      allowsTestAccountAuthorization: try container.decodeIfPresent(
        Bool.self, forKey: .allowsTestAccountAuthorization)
        ?? defaults.allowsTestAccountAuthorization,
      gmailOAuthClientID: try container.decodeIfPresent(
        String.self, forKey: .gmailOAuthClientID) ?? defaults.gmailOAuthClientID,
      gmailOAuthRedirectURI: try container.decodeIfPresent(
        String.self, forKey: .gmailOAuthRedirectURI) ?? defaults.gmailOAuthRedirectURI)
  }

  /// Replace empty string/list fields with their defaults, matching the
  /// merge convention the other sections use. Booleans are left alone: `false`
  /// is a real choice here, not an unset value, and defaulting it to `true`
  /// would silently enable an integration the user turned off.
  public func mergedWithDefaults() -> ProductivityConfiguration {
    let defaults = ProductivityConfiguration()
    return ProductivityConfiguration(
      safariProfileID: safariProfileID.isEmpty ? defaults.safariProfileID : safariProfileID,
      safariExtensionID: safariExtensionID.isEmpty
        ? defaults.safariExtensionID : safariExtensionID,
      safariSharedContainerPath: safariSharedContainerPath,
      safariSecretServiceName: safariSecretServiceName.isEmpty
        ? defaults.safariSecretServiceName : safariSecretServiceName,
      safariAllowedHosts: safariAllowedHosts,
      mailAccountIDs: mailAccountIDs,
      mailEndpoint: mailEndpoint.isEmpty ? defaults.mailEndpoint : mailEndpoint,
      mailAllowedHosts: mailAllowedHosts.isEmpty ? defaults.mailAllowedHosts : mailAllowedHosts,
      calendarReadEnabled: calendarReadEnabled,
      contactsReadEnabled: contactsReadEnabled,
      allowsTestAccountAuthorization: allowsTestAccountAuthorization,
      gmailOAuthClientID: gmailOAuthClientID,
      gmailOAuthRedirectURI: gmailOAuthRedirectURI)
  }

  public func validate() throws(AuraError) {
    guard !safariProfileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuraError.invalidConfiguration("productivity safariProfileID must not be empty")
    }
    guard !safariExtensionID.isEmpty else {
      throw AuraError.invalidConfiguration("productivity safariExtensionID must not be empty")
    }
    guard !safariSecretServiceName.isEmpty else {
      throw AuraError.invalidConfiguration(
        "productivity safariSecretServiceName must not be empty")
    }
    for accountID in mailAccountIDs {
      let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
      // A blank or multi-line entry would become a Keychain key, so it is
      // rejected here rather than producing an unreachable account later.
      guard !trimmed.isEmpty, !accountID.contains("\n"), !accountID.contains("\r") else {
        throw AuraError.invalidConfiguration(
          "productivity mailAccountIDs entries must be non-empty and single-line")
      }
    }
    guard let endpoint = URL(string: mailEndpoint), endpoint.scheme?.lowercased() == "https",
      let host = endpoint.host, !host.isEmpty
    else {
      throw AuraError.invalidConfiguration(
        "productivity mailEndpoint must be an https URL with a host")
    }
    guard mailAllowedHosts.contains(where: { $0.lowercased() == host.lowercased() }) else {
      throw AuraError.invalidConfiguration(
        "productivity mailEndpoint host must appear in mailAllowedHosts")
    }
    guard !gmailOAuthClientID.contains("\n"), !gmailOAuthClientID.contains("\r") else {
      throw AuraError.invalidConfiguration("productivity gmailOAuthClientID must be single-line")
    }
    guard let redirect = URL(string: gmailOAuthRedirectURI),
      redirect.scheme?.lowercased() == "http",
      redirect.host?.lowercased() == "127.0.0.1",
      redirect.port != nil,
      redirect.path == "/oauth2callback",
      redirect.user == nil,
      redirect.password == nil
    else {
      throw AuraError.invalidConfiguration(
        "productivity gmailOAuthRedirectURI must be a loopback /oauth2callback URL")
    }
  }
}
