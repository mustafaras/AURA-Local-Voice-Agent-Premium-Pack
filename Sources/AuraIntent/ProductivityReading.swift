import AuraCore
import Foundation

/// The result of one read-first productivity capability, shaped for the
/// dialogue and event layers.
///
/// It carries no provider object, no message body, and no address. The
/// composition root redacts and bounds everything before building one of
/// these, so `ToolRouter` cannot leak private content into a `ToolResultEvent`
/// even by accident: there is nothing private in the type to leak.
public struct ProductivityReadResult: Sendable, Equatable {
  /// Registry capability ID this result came from, for the emitted events.
  public let capabilityID: String
  /// How many items the read returned — the part a user actually hears.
  public let itemCount: Int
  /// Bounded, redacted, user-presentable text. Already passed through
  /// `ProductivityRedaction.boundedText` at the composition boundary.
  public let summary: String
  /// Irreversible fingerprint of the account or profile the data came from.
  /// Never the address, never the profile name.
  public let sourceFingerprint: String
  /// True when the integration answered from a degraded state (for example a
  /// stale bridge observation) and the summary must be presented as such.
  public let isDegraded: Bool

  public init(
    capabilityID: String,
    itemCount: Int,
    summary: String,
    sourceFingerprint: String,
    isDegraded: Bool = false
  ) {
    self.capabilityID = capabilityID
    self.itemCount = itemCount
    self.summary = summary
    self.sourceFingerprint = sourceFingerprint
    self.isDegraded = isDegraded
  }
}

/// Why a read did not produce a result. The cases stay distinct because the
/// conversation has to say something different for each: onboarding an
/// account, granting a permission, choosing between two accounts, and an
/// outage are four different asks.
public enum ProductivityReadFailure: Error, Sendable, Equatable {
  /// No account or profile is onboarded for this capability yet.
  case notConfigured(reason: String)
  /// Onboarded, but currently unusable — permission denied, credential
  /// revoked, provider or bridge unavailable.
  case unavailable(reason: String)
  /// More than one approved account or profile matches and the user must
  /// choose. Carries the question to ask.
  case ambiguous(question: String)
  /// Anything else, already redacted.
  case failed(reason: String)
}

/// The port `ToolRouter` uses to reach the read-first productivity adapters.
///
/// `AuraIntent` deliberately does not depend on `AuraProductivity`
/// (`Package.swift`), so the decision layer never sees a provider type, a
/// token reference, or an `ExternalContent` value. The composition root owns
/// the conformer and is the only place adapter output is converted — and
/// redacted — into the results above.
public protocol ProductivityReading: Sendable {
  func readActiveBrowserTab(
    profileID: String?
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure>

  func searchMail(
    accountID: String?,
    query: String,
    limit: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure>

  /// Search for one matching thread and summarize it through the same
  /// read-only account/scope boundary. Implementations must screen every
  /// message before returning and must not place raw bodies in event output.
  func summarizeMailThread(
    accountID: String?,
    query: String
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure>

  func readCalendarAgenda(
    dayRange: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure>

  func lookupContacts(
    query: String,
    limit: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure>
}
