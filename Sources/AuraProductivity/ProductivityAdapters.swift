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
