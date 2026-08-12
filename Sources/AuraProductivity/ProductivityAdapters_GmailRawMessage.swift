import AuraCore
import AuraSecurity
import Foundation

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
