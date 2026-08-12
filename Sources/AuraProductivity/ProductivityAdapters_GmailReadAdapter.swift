import AuraCore
import AuraSecurity
import Foundation

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
