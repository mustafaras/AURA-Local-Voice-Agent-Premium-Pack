import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

public struct ApprovedBrowserProfiles: Sendable, Equatable {
  public let profileIDs: [String]

  public init(profileIDs: [String]) {
    self.profileIDs = Array(Set(profileIDs.filter { !$0.isEmpty })).sorted()
  }

  public func resolve(requestedID: String?) throws(ProductivityError) -> String {
    if let requestedID {
      guard profileIDs.contains(requestedID) else {
        throw .profileAmbiguous(candidates: profileIDs)
      }
      return requestedID
    }
    guard profileIDs.count == 1, let only = profileIDs.first else {
      if profileIDs.isEmpty { throw .notConfigured }
      throw .profileAmbiguous(candidates: profileIDs)
    }
    return only
  }
}
