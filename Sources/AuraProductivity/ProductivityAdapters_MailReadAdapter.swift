import AuraCore
import AuraSecurity
import Foundation

public protocol MailReadAdapter: Sendable {
  func accounts() async throws(ProductivityError) -> [MailAccountSnapshot]
  func unreadCount(accountID: String) async throws(ProductivityError) -> Int
  func search(accountID: String, query: String, limit: Int) async throws(ProductivityError)
    -> [MailMessageHeader]
  func readThread(accountID: String, threadID: String) async throws(ProductivityError)
    -> MailThreadSnapshot
  func revoke(accountID: String) async throws(ProductivityError)
}
