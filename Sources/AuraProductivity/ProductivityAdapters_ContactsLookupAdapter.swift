import AuraCore
import AuraSecurity
import Foundation

public protocol ContactsLookupAdapter: Sendable {
  func lookup(query: String, limit: Int) async throws(ProductivityError) -> ScopedContactResolution
}
