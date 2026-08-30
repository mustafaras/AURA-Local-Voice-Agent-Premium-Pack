import AuraCore
import Foundation

// MARK: - Launch-at-login events

public struct LaunchAtLoginRequestedEvent: EventPayload {
  public static let eventType = "lifecycle.launchAtLogin.requested"

  public let enabled: Bool
  public let actor: ActorID

  public init(enabled: Bool, actor: ActorID) {
    self.enabled = enabled
    self.actor = actor
  }
}

public struct LaunchAtLoginChangedEvent: EventPayload {
  public static let eventType = "lifecycle.launchAtLogin.changed"

  public let enabled: Bool
  public let statusRawValue: Int
  public let actor: ActorID

  public init(enabled: Bool, statusRawValue: Int, actor: ActorID) {
    self.enabled = enabled
    self.statusRawValue = statusRawValue
    self.actor = actor
  }
}

// MARK: - Lifecycle state events

public struct LifecycleHeartbeatEvent: EventPayload {
  public static let eventType = "lifecycle.heartbeat"

  public let sessionID: String
  public let kind: LifecycleHeartbeatKind

  public init(sessionID: String, kind: LifecycleHeartbeatKind) {
    self.sessionID = sessionID
    self.kind = kind
  }
}

public enum LifecycleHeartbeatKind: String, Codable, Sendable, Equatable {
  case launch
  case sleep
  case wake
  case cleanShutdown
  case crashRecovery
}

// MARK: - Update events

public struct UpdateCheckRequestedEvent: EventPayload {
  public static let eventType = "lifecycle.update.checkRequested"

  public let channel: String
  public let actor: ActorID

  public init(channel: String, actor: ActorID) {
    self.channel = channel
    self.actor = actor
  }
}

public struct UpdateStagedEvent: EventPayload {
  public static let eventType = "lifecycle.update.staged"

  public let stagedUpdateID: UUID
  public let version: String
  public let actor: ActorID

  public init(stagedUpdateID: UUID, version: String, actor: ActorID) {
    self.stagedUpdateID = stagedUpdateID
    self.version = version
    self.actor = actor
  }
}

public struct UpdateRolledBackEvent: EventPayload {
  public static let eventType = "lifecycle.update.rolledBack"

  public let stagedUpdateID: UUID
  public let version: String
  public let reason: String
  public let actor: ActorID

  public init(stagedUpdateID: UUID, version: String, reason: String, actor: ActorID) {
    self.stagedUpdateID = stagedUpdateID
    self.version = version
    self.reason = reason
    self.actor = actor
  }
}

// MARK: - Safe mode / reset events

public struct SafeModeEnteredEvent: EventPayload {
  public static let eventType = "lifecycle.safeMode.entered"

  public let reason: String
  public let actor: ActorID

  public init(reason: String, actor: ActorID) {
    self.reason = reason
    self.actor = actor
  }
}

public struct ResetPlannedEvent: EventPayload {
  public static let eventType = "lifecycle.reset.planned"

  public let planID: UUID
  public let kind: String
  public let scopes: [String]
  public let itemCount: Int
  public let actor: ActorID

  public init(planID: UUID, kind: String, scopes: [String], itemCount: Int, actor: ActorID) {
    self.planID = planID
    self.kind = kind
    self.scopes = scopes
    self.itemCount = itemCount
    self.actor = actor
  }
}

public struct ResetExecutedEvent: EventPayload {
  public static let eventType = "lifecycle.reset.executed"

  public let planID: UUID
  public let kind: String
  public let removedCount: Int
  public let failedCount: Int
  public let actor: ActorID

  public init(planID: UUID, kind: String, removedCount: Int, failedCount: Int, actor: ActorID) {
    self.planID = planID
    self.kind = kind
    self.removedCount = removedCount
    self.failedCount = failedCount
    self.actor = actor
  }
}

// MARK: - Migration audit events

public struct MigrationAuditedEvent: EventPayload {
  public static let eventType = "lifecycle.migration.audited"

  public let kind: String
  public let fromVersion: String
  public let toVersion: String
  public let result: String

  public init(kind: String, fromVersion: String, toVersion: String, result: String) {
    self.kind = kind
    self.fromVersion = fromVersion
    self.toVersion = toVersion
    self.result = result
  }
}
