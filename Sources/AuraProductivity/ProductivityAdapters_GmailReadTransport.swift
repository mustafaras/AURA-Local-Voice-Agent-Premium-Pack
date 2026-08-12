import AuraCore
import AuraSecurity
import Foundation

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
