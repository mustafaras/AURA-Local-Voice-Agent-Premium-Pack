import Foundation

/// Immutable security audit entry for a plugin lifecycle or grant change.
public struct PluginAuditRecord: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let timestamp: Date
  public let pluginID: String
  public let version: String
  public let action: String
  public let actor: ActorID
  public let outcome: String
  public let detail: String
  public let correlationID: UUID

  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    pluginID: String,
    version: String,
    action: String,
    actor: ActorID,
    outcome: String,
    detail: String = "",
    correlationID: UUID
  ) {
    self.id = id
    self.timestamp = timestamp
    self.pluginID = pluginID
    self.version = version
    self.action = action
    self.actor = actor
    self.outcome = outcome
    self.detail = detail
    self.correlationID = correlationID
  }
}
