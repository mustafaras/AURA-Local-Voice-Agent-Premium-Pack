import AuraConfig
import AuraCore
import AuraStore
import Foundation

/// Reset controller for user-controlled reset, uninstall, and reinstall
/// bookkeeping. It records reset plans and produces the list of files and
/// directories that would be removed, but does not delete data itself (the
/// uninstall assistant owns actual removal).
public actor ResetController {
  public static let factoryResetRequestedKey = "lifecycle.factoryResetRequested"

  private let configurationEngine: ConfigurationEngine?
  private let store: AuraStore?
  private let eventBus: AuraEventBus?

  public init(
    configurationEngine: ConfigurationEngine? = nil,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil
  ) {
    self.configurationEngine = configurationEngine
    self.store = store
    self.eventBus = eventBus
  }

  /// Plan a reset. Returns the plan and records it in the database.
  public func planReset(
    kind: ResetKind,
    scopes: [ResetScope],
    reason: String,
    actor: ActorID = .user,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> ResetPlan {
    let planID = UUID()
    let items = scopes.flatMap { $0.items(fileManager: FileManager.default) }.uniqued()
    let plan = ResetPlan(
      planID: planID,
      kind: kind,
      scopes: scopes,
      items: items,
      reason: reason,
      correlationID: correlationID,
      timestamp: Date())

    try await store?.database.run(
      sql: """
        INSERT INTO recovery_checkpoints (
          id, timestamp, correlation_id, kind, description, reference_id, verified
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(planID.uuidString),
        .text(formatDate(Date())),
        .text(correlationID.uuidString),
        .text("reset_\(kind.rawValue)"),
        .text("reset plan: \(reason); scopes: \(scopes.map(\.rawValue).joined(separator: ",")); items: \(items.count)"),
        .text(scopes.map(\.rawValue).joined(separator: ",")),
        .integer(1),
      ])

    await emit(
      ResetPlannedEvent(
        planID: planID,
        kind: kind.rawValue,
        scopes: scopes.map(\.rawValue),
        itemCount: items.count,
        actor: actor),
      .internalLevel)

    return plan

  }

  /// Mark factory reset as requested for the next launch. The actual reset
  /// runs at launch before any subsystem initializes.
  @discardableResult
  public func setFactoryResetRequested(
    _ requested: Bool,
    reason: String,
    actor: ActorID = .user
  ) async throws(AuraError) -> Bool {
    guard let engine = configurationEngine else {
      throw AuraError.lifecycleError("configuration engine not available")
    }
    let result = try await engine.apply(
      ConfigurationPatch(
        layer: actor == .user ? .userSettings : .sessionOverrides,
        values: [Self.factoryResetRequestedKey: .boolean(requested)],
        source: "ResetController"),
      actor: actor)
    guard result.accepted else {
      throw AuraError.lifecycleError("factory reset flag rejected")
    }
    if requested {
      _ = try await planReset(
        kind: .factoryReset,
        scopes: ResetScope.allCases,
        reason: reason,
        actor: actor)
    }
    return requested
  }

  /// Whether a factory reset has been requested for the next launch.
  public func isFactoryResetRequested() async -> Bool {
    guard let engine = configurationEngine else { return false }
    guard case .boolean(let value) = await engine.effectiveValue(for: Self.factoryResetRequestedKey)
    else { return false }
    return value
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private func emit<P: EventPayload>(_ payload: P, _ sensitivity: SensitivityLevel) async {
    guard let eventBus = eventBus else { return }
    await eventBus.emit(
      EventEnvelope(
        correlationID: UUID(),
        causationID: UUID(),
        actor: .lifecycle,
        sensitivity: sensitivity,
        payload: payload))
  }
}

public enum ResetKind: String, Codable, Sendable, Equatable {
  case safeMode
  case settings
  case memory
  case uninstall
  case factoryReset
}

public enum ResetScope: String, Codable, Sendable, Equatable, CaseIterable {
  case configuration
  case database
  case memory
  case plugins
  case models
  case applicationSupport

  func items(fileManager: FileManager = .default) -> [ResetItem] {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent("AURA")
    let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.aura.agent")
    switch self {
    case .configuration:
      return [ResetItem(path: base?.appendingPathComponent("preferences.json").path ?? "", kind: .file)]
    case .database:
      return [ResetItem(path: base?.appendingPathComponent("aura.sqlite").path ?? "", kind: .file)]
    case .memory:
      return [ResetItem(path: base?.appendingPathComponent("memory").path ?? "", kind: .directory)]
    case .plugins:
      return [ResetItem(path: base?.appendingPathComponent("plugins").path ?? "", kind: .directory)]
    case .models:
      return [ResetItem(path: group?.appendingPathComponent("Models").path ?? "", kind: .directory)]
    case .applicationSupport:
      guard let base = base else { return [] }
      return [ResetItem(path: base.path, kind: .directory)]
    }
  }
}

public struct ResetItem: Codable, Sendable, Equatable {
  public let path: String
  public let kind: ResetItemKind

  public init(path: String, kind: ResetItemKind) {
    self.path = path
    self.kind = kind
  }
}

public enum ResetItemKind: String, Codable, Sendable, Equatable {
  case file
  case directory
}

public struct ResetPlan: Codable, Sendable, Equatable, Identifiable {
  public let planID: UUID
  public let kind: ResetKind
  public let scopes: [ResetScope]
  public let items: [ResetItem]
  public let reason: String
  public let correlationID: UUID
  public let timestamp: Date

  public var id: UUID { planID }

  public init(
    planID: UUID,
    kind: ResetKind,
    scopes: [ResetScope],
    items: [ResetItem],
    reason: String,
    correlationID: UUID,
    timestamp: Date
  ) {
    self.planID = planID
    self.kind = kind
    self.scopes = scopes
    self.items = items
    self.reason = reason
    self.correlationID = correlationID
    self.timestamp = timestamp
  }
}

extension Array where Element == ResetItem {
  public func uniqued() -> [ResetItem] {
    var seen: Set<String> = []
    var result: [ResetItem] = []
    for item in self {
      if seen.insert(item.path).inserted {
        result.append(item)
      }
    }
    return result
  }
}
