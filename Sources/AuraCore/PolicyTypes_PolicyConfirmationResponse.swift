import CryptoKit
import Foundation

/// Response to a confirmation challenge returned by the UI or caller.
public struct PolicyConfirmationResponse: Codable, Sendable, Equatable {
  public let requestID: UUID
  public let nonce: String
  public let responseHash: String
  public let accepted: Bool

  public init(
    requestID: UUID,
    nonce: String,
    responseHash: String,
    accepted: Bool
  ) {
    self.requestID = requestID
    self.nonce = nonce
    self.responseHash = responseHash
    self.accepted = accepted
  }
}
