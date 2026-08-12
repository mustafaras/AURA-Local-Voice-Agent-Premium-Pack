import AuraCore
import AuraSecurity
import Foundation

public protocol BrowserReadAdapter: Sendable {
  func readActiveTab() async throws(ProductivityError) -> BrowserTabSnapshot
}
