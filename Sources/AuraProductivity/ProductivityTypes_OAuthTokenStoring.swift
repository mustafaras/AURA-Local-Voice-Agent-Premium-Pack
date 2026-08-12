import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

public protocol OAuthTokenStoring: Sendable {
  func save(
    _ material: OAuthTokenMaterial,
    for reference: OAuthTokenReference
  ) async throws(ProductivityError)
  func accessToken(
    for reference: OAuthTokenReference
  ) async throws(ProductivityError) -> String?
  func revoke(_ reference: OAuthTokenReference) async throws(ProductivityError)
}
