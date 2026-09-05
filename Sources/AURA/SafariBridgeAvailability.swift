import AuraCore
import AuraIntent
import AuraProductivity
import Foundation

/// Maps the Safari bridge transport's distinct failure states to truthful,
/// user-presentable `CapabilityAvailability` values so the UI and dialogue can
/// explain whether the user needs to install the extension, onboard a
/// profile, reconnect, or retry after an external outage. This is the
/// "visibly degraded when unavailable" half of the SP-009 completion gate.
public enum SafariBridgeAvailability {
  /// The bridge is provisioned and the transport is ready to read.
  public static func availability(
    transport: any SafariWebExtensionTransport,
    profileID: String,
    secretStore: SafariBridgeSecretStore
  ) async -> CapabilityAvailability {
    // A missing pinned key means the profile was never connected or was
    // revoked — the bridge is not authenticated.
    let pinned: String?
    do {
      pinned = try await secretStore.pinnedPublicKey(profileID: profileID)
    } catch {
      return .degraded(reason: "Chrome bridge key store is unavailable")
    }
    guard let pinned, !pinned.isEmpty else {
      return .disabled(reason: "Chrome bridge is not connected")
    }

    // Probe the transport. A successful read proves the live package and
    // trust path; every failure maps to a distinct degraded reason.
    do {
      _ = try await transport.readActiveTab(profileID: profileID)
      return .ready
    } catch let error as SafariBridgeTransportError {
      switch error {
      case .unavailable:
        return .degraded(reason: "Chrome extension or shared container is unavailable")
      case .stale:
        return .degraded(reason: "Chrome bridge observation is stale")
      case .profileMismatch:
        return .degraded(reason: "Chrome bridge profile does not match the approved profile")
      case .notProvisioned:
        return .disabled(reason: "Chrome bridge is not connected")
      case .authenticationFailed:
        return .degraded(reason: "Chrome bridge authentication failed")
      case .malformedMessage:
        return .degraded(reason: "Chrome extension sent a malformed observation")
      }
    } catch {
      return .degraded(reason: "Chrome bridge is unavailable")
    }
  }
}
