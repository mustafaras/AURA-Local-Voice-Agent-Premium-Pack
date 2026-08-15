import Foundation

/// The bounded, privacy-safe projection used to prove runtime causality.
///
/// This record intentionally excludes prompts, transcripts, command arguments,
/// raw tool output, screenshots, audio, nonces, and plan hashes. It is an
/// audit trace, not a replay authorization.
public struct RedactedTraceRecord: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let timestamp: Date
  public let correlationID: UUID
  public let causationID: UUID
  public let phase: String
  public let eventType: String
  public let requestID: UUID?
  public let actionIdentifier: String?
  public let outcome: String

  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    correlationID: UUID,
    causationID: UUID,
    phase: String,
    eventType: String,
    requestID: UUID? = nil,
    actionIdentifier: String? = nil,
    outcome: String
  ) {
    self.id = id
    self.timestamp = timestamp
    self.correlationID = correlationID
    self.causationID = causationID
    self.phase = phase
    self.eventType = eventType
    self.requestID = requestID
    self.actionIdentifier = actionIdentifier
    self.outcome = outcome
  }
}

/// Narrow persistence boundary for redacted runtime trace records.
public protocol AuraTracePersistence: Sendable {
  func appendTrace(_ record: RedactedTraceRecord) async throws(AuraError)
}

public enum AuraTraceDisplay {
  /// Show only a short opaque prefix in the UI; the complete UUID remains in
  /// the local redacted trace store for exact correlation during acceptance.
  public static func redactedID(_ id: UUID) -> String {
    String(id.uuidString.prefix(8)).lowercased()
  }

  public static func summary(correlationID: UUID, causationID: UUID) -> String {
    "Trace c=\(redactedID(correlationID))… cause=\(redactedID(causationID))…"
  }
}
