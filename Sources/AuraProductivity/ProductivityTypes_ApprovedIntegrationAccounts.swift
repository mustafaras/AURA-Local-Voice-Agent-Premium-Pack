import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

public struct ApprovedIntegrationAccounts: Sendable, Equatable {
  public let accountIDs: [String]

  public init(accountIDs: [String]) {
    self.accountIDs = Array(Set(accountIDs.filter { !$0.isEmpty })).sorted()
  }

  public func resolve(requestedID: String?) throws(ProductivityError) -> String {
    if let requestedID {
      guard accountIDs.contains(requestedID) else {
        throw .accountAmbiguous(candidates: accountIDs)
      }
      return requestedID
    }
    guard accountIDs.count == 1, let only = accountIDs.first else {
      if accountIDs.isEmpty { throw .notConfigured }
      throw .accountAmbiguous(candidates: accountIDs)
    }
    return only
  }
}
