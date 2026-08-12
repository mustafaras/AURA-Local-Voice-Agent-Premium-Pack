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
