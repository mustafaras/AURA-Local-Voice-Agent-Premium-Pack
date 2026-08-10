import AuraCore
import AuraSecurity
import Foundation

// MARK: - Browser

public struct BrowserProfileScope: Sendable, Equatable, Hashable {
  public let profileID: String

  public init(profileID: String) throws(ProductivityError) {
    guard !profileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw .invalidInput("browser profile ID must not be empty")
    }
    self.profileID = profileID
  }
}

public struct BrowserTabSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let profileID: String
  public let url: URL
  public let title: ExternalContent
  public let visibleText: ExternalContent

  public init(
    id: String,
    profileID: String,
    url: URL,
    title: ExternalContent,
    visibleText: ExternalContent
  ) {
    self.id = id
    self.profileID = profileID
    self.url = url
    self.title = title
    self.visibleText = visibleText
  }
}

public struct SafariWebExtensionTabResponse: Sendable, Equatable {
  public let tabID: String
  public let profileID: String
  public let url: URL
  public let title: String
  public let visibleText: String

  public init(
    tabID: String,
    profileID: String,
    url: URL,
    title: String,
    visibleText: String
  ) {
    self.tabID = tabID
    self.profileID = profileID
    self.url = url
    self.title = title
    self.visibleText = visibleText
  }
}

/// The containing macOS app communicates with a Safari Web Extension through
/// this structured bridge. The bridge never exposes cookies, passwords,
/// hidden page state, or arbitrary page-script execution.
public protocol SafariWebExtensionTransport: Sendable {
  func readActiveTab(profileID: String) async throws -> SafariWebExtensionTabResponse
}

public protocol BrowserReadAdapter: Sendable {
  func readActiveTab() async throws(ProductivityError) -> BrowserTabSnapshot
}

public struct SafariBrowserReadAdapter: BrowserReadAdapter, Sendable {
  private let profile: BrowserProfileScope
  private let networkPolicy: ProductivityNetworkPolicy
  private let transport: any SafariWebExtensionTransport
  private let classifier: PromptInjectionClassifier

  public init(
    profile: BrowserProfileScope,
    networkPolicy: ProductivityNetworkPolicy,
    transport: any SafariWebExtensionTransport,
    classifier: PromptInjectionClassifier = PromptInjectionClassifier()
  ) {
    self.profile = profile
    self.networkPolicy = networkPolicy
    self.transport = transport
    self.classifier = classifier
  }

  public func readActiveTab() async throws(ProductivityError) -> BrowserTabSnapshot {
    let response: SafariWebExtensionTabResponse
    do {
      response = try await transport.readActiveTab(profileID: profile.profileID)
    } catch {
      throw .providerUnavailable
    }
    guard response.profileID == profile.profileID else {
      throw .profileAmbiguous(candidates: [profile.profileID, response.profileID])
    }
    try networkPolicy.validate(response.url)
    let title = ExternalContent(
      sourceID: "browser:\(response.tabID):title",
      text: response.title,
      provenance: .webContent,
      classifier: classifier)
    let visibleText = ExternalContent(
      sourceID: "browser:\(response.tabID):visible-text",
      text: response.visibleText,
      provenance: .webContent,
      classifier: classifier)
    guard !visibleText.isBlocked else {
      throw .privacyBlocked(reason: "page text matched an injection-blocking rule")
    }
    return BrowserTabSnapshot(
      id: response.tabID,
      profileID: response.profileID,
      url: response.url,
      title: title,
      visibleText: visibleText)
  }
}

// MARK: - Mail

public struct MailAccountSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let displayName: String
  public let provider: OAuthProviderID

  public init(id: String, displayName: String, provider: OAuthProviderID) {
    self.id = id
    self.displayName = displayName
    self.provider = provider
  }
}

public struct MailMessageHeader: Sendable, Equatable, Identifiable {
  public let id: String
  public let threadID: String
  public let sender: String
  public let recipients: [String]
  public let subject: ExternalContent
  public let receivedAt: Date
  public let isUnread: Bool
  public let attachments: [AttachmentMetadata]

  public init(
    id: String,
    threadID: String,
    sender: String,
    recipients: [String],
    subject: ExternalContent,
    receivedAt: Date,
    isUnread: Bool,
    attachments: [AttachmentMetadata] = []
  ) {
    self.id = id
    self.threadID = threadID
    self.sender = sender
    self.recipients = recipients
    self.subject = subject
    self.receivedAt = receivedAt
    self.isUnread = isUnread
    self.attachments = attachments
  }
}

public struct MailMessageSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let header: MailMessageHeader
  public let body: ExternalContent

  public init(id: String, header: MailMessageHeader, body: ExternalContent) {
    self.id = id
    self.header = header
    self.body = body
  }
}

public struct MailThreadSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let messages: [MailMessageSnapshot]

  public init(id: String, messages: [MailMessageSnapshot]) {
    self.id = id
    self.messages = messages
  }
}

public protocol MailReadAdapter: Sendable {
  func accounts() async throws(ProductivityError) -> [MailAccountSnapshot]
  func unreadCount(accountID: String) async throws(ProductivityError) -> Int
  func search(accountID: String, query: String, limit: Int) async throws(ProductivityError)
    -> [MailMessageHeader]
  func readThread(accountID: String, threadID: String) async throws(ProductivityError)
    -> MailThreadSnapshot
  func revoke(accountID: String) async throws(ProductivityError)
}

public struct GmailRawMessage: Sendable, Equatable {
  public let id: String
  public let threadID: String
  public let sender: String
  public let recipients: [String]
  public let subject: String
  public let body: String
  public let receivedAt: Date
  public let isUnread: Bool
  public let attachments: [AttachmentMetadata]

  public init(
    id: String,
    threadID: String,
    sender: String,
    recipients: [String],
    subject: String,
    body: String,
    receivedAt: Date,
    isUnread: Bool,
    attachments: [AttachmentMetadata] = []
  ) {
    self.id = id
    self.threadID = threadID
    self.sender = sender
    self.recipients = recipients
    self.subject = subject
    self.body = body
    self.receivedAt = receivedAt
    self.isUnread = isUnread
    self.attachments = attachments
  }
}

public protocol GmailReadTransport: Sendable {
  var endpoint: URL { get }
  func accounts(accessToken: String) async throws -> [MailAccountSnapshot]
  func unreadCount(accountID: String, accessToken: String) async throws -> Int
  func search(
    accountID: String,
    query: String,
    limit: Int,
    accessToken: String
  ) async throws -> [GmailRawMessage]
  func thread(
    accountID: String,
    threadID: String,
    accessToken: String
  ) async throws -> [GmailRawMessage]
}

public struct GmailReadAdapter: MailReadAdapter, Sendable {
  private let approvedAccounts: ApprovedIntegrationAccounts
  private let scopeManifest: OAuthScopeManifest
  private let configuredScopes: Set<String>
  private let tokenStore: any OAuthTokenStoring
  private let transport: any GmailReadTransport
  private let networkPolicy: ProductivityNetworkPolicy
  private let referenceProvider: OAuthProviderID
  private let classifier: PromptInjectionClassifier

  public init(
    approvedAccounts: ApprovedIntegrationAccounts,
    scopeManifest: OAuthScopeManifest = .gmailReadFirst,
    configuredScopes: Set<String>,
    tokenStore: any OAuthTokenStoring,
    transport: any GmailReadTransport,
    networkPolicy: ProductivityNetworkPolicy,
    classifier: PromptInjectionClassifier = PromptInjectionClassifier()
  ) throws(ProductivityError) {
    guard scopeManifest.provider == .gmail else {
      throw .invalidInput("Gmail adapter requires a Gmail OAuth scope manifest")
    }
    try scopeManifest.validate(requestedScopes: configuredScopes, for: .read)
    guard transport.endpoint.host?.lowercased() == "gmail.googleapis.com" else {
      throw .hostNotAllowed(host: transport.endpoint.host ?? "missing")
    }
    try networkPolicy.validate(transport.endpoint)
    self.approvedAccounts = approvedAccounts
    self.scopeManifest = scopeManifest
    self.configuredScopes = configuredScopes
    self.tokenStore = tokenStore
    self.transport = transport
    self.networkPolicy = networkPolicy
    self.referenceProvider = .gmail
    self.classifier = classifier
  }

  public func accounts() async throws(ProductivityError) -> [MailAccountSnapshot] {
    try await withAccessToken { token in
      try await transport.accounts(accessToken: token)
    }
  }

  public func unreadCount(accountID: String) async throws(ProductivityError) -> Int {
    let account = try approvedAccounts.resolve(requestedID: accountID)
    return try await withAccessToken(accountID: account) { token in
      try await transport.unreadCount(accountID: account, accessToken: token)
    }
  }

  public func search(
    accountID: String,
    query: String,
    limit: Int
  ) async throws(ProductivityError) -> [MailMessageHeader] {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw .invalidInput("mail search query must not be empty")
    }
    let account = try approvedAccounts.resolve(requestedID: accountID)
    let boundedLimit = min(max(limit, 1), 50)
    let raw = try await withAccessToken(accountID: account) { token in
      try await transport.search(
        accountID: account, query: query, limit: boundedLimit, accessToken: token)
    }
    guard
      raw.allSatisfy({
        !makeHeader($0).subject.isBlocked
      })
    else {
      throw .privacyBlocked(reason: "mail subject matched an injection-blocking rule")
    }
    return raw.map { makeHeader($0) }
  }

  public func readThread(
    accountID: String,
    threadID: String
  ) async throws(ProductivityError) -> MailThreadSnapshot {
    let account = try approvedAccounts.resolve(requestedID: accountID)
    guard !threadID.isEmpty else { throw .invalidInput("mail thread ID must not be empty") }
    let raw = try await withAccessToken(accountID: account) { token in
      try await transport.thread(accountID: account, threadID: threadID, accessToken: token)
    }
    let messages = raw.map { message in
      MailMessageSnapshot(
        id: message.id,
        header: makeHeader(message),
        body: ExternalContent(
          sourceID: "mail:\(message.id):body",
          text: message.body,
          provenance: .mailBody,
          classifier: classifier))
    }
    guard messages.allSatisfy({ !$0.body.isBlocked && !$0.header.subject.isBlocked }) else {
      throw .privacyBlocked(reason: "mail content matched an injection-blocking rule")
    }
    return MailThreadSnapshot(id: threadID, messages: messages)
  }

  public func revoke(accountID: String) async throws(ProductivityError) {
    let account = try approvedAccounts.resolve(requestedID: accountID)
    let reference = try OAuthTokenReference(provider: referenceProvider, accountID: account)
    try await tokenStore.revoke(reference)
  }

  private func makeHeader(_ message: GmailRawMessage) -> MailMessageHeader {
    MailMessageHeader(
      id: message.id,
      threadID: message.threadID,
      sender: message.sender,
      recipients: message.recipients,
      subject: ExternalContent(
        sourceID: "mail:\(message.id):subject",
        text: message.subject,
        provenance: .mailBody,
        classifier: classifier),
      receivedAt: message.receivedAt,
      isUnread: message.isUnread,
      attachments: message.attachments)
  }

  private func withAccessToken<T: Sendable>(
    accountID: String? = nil,
    _ operation: @Sendable (String) async throws -> T
  ) async throws(ProductivityError) -> T {
    guard scopeManifest.isReadOnly(configuredScopes) else {
      throw .insufficientScope(required: "Gmail read adapter accepts only read scopes")
    }
    try networkPolicy.validate(transport.endpoint)
    let resolvedAccount = try approvedAccounts.resolve(requestedID: accountID)
    let reference = try OAuthTokenReference(provider: referenceProvider, accountID: resolvedAccount)
    guard let token = try await tokenStore.accessToken(for: reference) else {
      throw .tokenExpiredOrRevoked
    }
    do {
      return try await operation(token)
    } catch let error as ProductivityError {
      throw error
    } catch {
      throw .providerUnavailable
    }
  }
}

// MARK: - Calendar and contacts ports

public struct CalendarEventSnapshot: Sendable, Equatable, Identifiable {
  public let id: String
  public let calendarID: String
  public let title: ExternalContent
  public let range: CalendarTimeRange
  public let timeZoneIdentifier: String?
  public let location: ExternalContent?
  public let recurrenceDescription: ExternalContent?

  public init(
    id: String,
    calendarID: String,
    title: ExternalContent,
    range: CalendarTimeRange,
    timeZoneIdentifier: String?,
    location: ExternalContent? = nil,
    recurrenceDescription: ExternalContent? = nil
  ) {
    self.id = id
    self.calendarID = calendarID
    self.title = title
    self.range = range
    self.timeZoneIdentifier = timeZoneIdentifier
    self.location = location
    self.recurrenceDescription = recurrenceDescription
  }
}

public protocol CalendarReadAdapter: Sendable {
  func agenda(
    from start: Date,
    to end: Date,
    calendarIDs: Set<String>?
  ) async throws(ProductivityError) -> [CalendarEventSnapshot]
}

public protocol ContactsLookupAdapter: Sendable {
  func lookup(query: String, limit: Int) async throws(ProductivityError) -> ScopedContactResolution
}
