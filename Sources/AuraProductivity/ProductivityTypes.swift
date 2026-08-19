import AuraCore
import AuraSecurity
import CryptoKit
import Foundation

/// User-presentable failure states for productivity integrations. These are
/// intentionally distinct so the dialogue/UI can explain whether the user
/// needs to configure an integration, grant access, reconnect an account, or
/// retry after an external outage.
public enum ProductivityError: Error, Sendable, Equatable {
  case notConfigured
  case permissionRequired
  case permissionDenied
  case oauthTokenExchangeRejected(OAuthTokenExchangeRejection)
  case tokenExpiredOrRevoked
  case networkUnavailable
  case providerUnavailable
  case insufficientScope(required: String)
  case accountAmbiguous(candidates: [String])
  case profileAmbiguous(candidates: [String])
  case privacyBlocked(reason: String)
  case invalidInput(String)
  case invalidRedirect(host: String)
  case hostNotAllowed(host: String)
  case unsupported(String)
  case cancelled
}

/// A bounded, provider-independent classification of an OAuth token endpoint
/// rejection. Only reviewed protocol error identifiers enter this type; the
/// provider's free-form response body and description are never surfaced.
public enum OAuthTokenExchangeRejection: String, Sendable, Equatable {
  case invalidGrant = "invalid_grant"
  case invalidClient = "invalid_client"
  case invalidRequest = "invalid_request"
  case redirectURIMismatch = "redirect_uri_mismatch"
  case unauthorizedClient = "unauthorized_client"
  case clientSecretRequired = "client_secret_required"
  case codeVerifierRejected = "code_verifier_rejected"
  case authorizationCodeRejected = "authorization_code_rejected"
  case unknown
}
