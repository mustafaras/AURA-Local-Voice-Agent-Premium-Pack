import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

extension ProductivityError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "The productivity integration is not configured."
    case .permissionRequired:
      return "The user must grant access before this integration can be read."
    case .permissionDenied:
      return "Access to this productivity integration was denied."
    case .tokenExpiredOrRevoked:
      return "The provider token is expired or revoked."
    case .networkUnavailable:
      return "The provider network is unavailable."
    case .providerUnavailable:
      return "The productivity provider is unavailable."
    case .insufficientScope(let required):
      return "The configured read scope is insufficient: \(required)."
    case .accountAmbiguous(let candidates):
      return "The account is ambiguous: \(candidates.joined(separator: ", "))."
    case .profileAmbiguous(let candidates):
      return "The browser profile is ambiguous: \(candidates.joined(separator: ", "))."
    case .privacyBlocked(let reason):
      return "Content was blocked by the privacy policy: \(reason)."
    case .invalidInput(let detail):
      return "Invalid productivity input: \(detail)."
    case .invalidRedirect(let host):
      return "The provider redirect is not allowed: \(host)."
    case .hostNotAllowed(let host):
      return "The provider host is not allowed: \(host)."
    case .unsupported(let detail):
      return "This productivity integration is unsupported: \(detail)."
    case .cancelled:
      return "The productivity request was cancelled."
    }
  }
}
