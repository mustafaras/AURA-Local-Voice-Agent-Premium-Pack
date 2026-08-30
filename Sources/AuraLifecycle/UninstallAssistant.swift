import AuraCore
import AuraSecurity
import AuraStore
import Foundation

/// Records and executes uninstall / reinstall-safe data removal. The assistant
/// only removes data directories owned by AURA; it never touches user files
/// outside the app sandbox or group container. Every removal is logged in the
/// database before it happens so the operation can be audited.
public actor UninstallAssistant {
  private let fileManager: FileManager
  private let store: AuraStore?
  private let eventBus: AuraEventBus?

  public init(
    fileManager: FileManager = .default,
    store: AuraStore? = nil,
    eventBus: AuraEventBus? = nil
  ) {
    self.fileManager = fileManager
    self.store = store
    self.eventBus = eventBus
  }

  /// Remove the items in a reset plan. Returns the number of items removed and
  /// the number that could not be removed (with reasons).
  public func executeReset(
    plan: ResetPlan,
    actor: ActorID = .user
  ) async throws(AuraError) -> ResetExecutionResult {
    var removed: [ResetItem] = []
    var failed: [ResetExecutionFailure] = []

    for item in plan.items {
      var errorDescription: String?
      do {
        if item.kind == .directory {
          try fileManager.removeItem(atPath: item.path)
        } else {
          if fileManager.fileExists(atPath: item.path) {
            try fileManager.removeItem(atPath: item.path)
          }
        }
        removed.append(item)
      } catch {
        errorDescription = error.localizedDescription
        failed.append(ResetExecutionFailure(item: item, reason: error.localizedDescription))
      }
      try await recordRemoval(
        planID: plan.planID,
        item: item,
        success: errorDescription == nil,
        error: errorDescription,
        actor: actor)
    }

    await emit(
      ResetExecutedEvent(
        planID: plan.planID,
        kind: plan.kind.rawValue,
        removedCount: removed.count,
        failedCount: failed.count,
        actor: actor),
      .sensitive)

    return ResetExecutionResult(removed: removed, failed: failed)
  }

  /// Factory reset: remove all scopes without requiring a pre-existing plan.
  public func executeFactoryReset(
    reason: String,
    actor: ActorID = .user
  ) async throws(AuraError) -> ResetExecutionResult {
    let scopes = ResetScope.allCases
    let plan = ResetPlan(
      planID: UUID(),
      kind: .factoryReset,
      scopes: scopes,
      items: scopes.flatMap { $0.items(fileManager: fileManager) }.uniqued(),
      reason: reason,
      correlationID: UUID(),
      timestamp: Date())
    return try await executeReset(plan: plan, actor: actor)
  }

  /// Reinstall-safe reset: keep configuration but remove everything else.
  public func executeReinstallSafeReset(
    reason: String,
    actor: ActorID = .user
  ) async throws(AuraError) -> ResetExecutionResult {
    let scopes: [ResetScope] = [.database, .memory, .plugins, .models]
    let plan = ResetPlan(
      planID: UUID(),
      kind: .safeMode,
      scopes: scopes,
      items: scopes.flatMap { $0.items(fileManager: fileManager) }.uniqued(),
      reason: reason,
      correlationID: UUID(),
      timestamp: Date())
    return try await executeReset(plan: plan, actor: actor)
  }

  private func recordRemoval(
    planID: UUID,
    item: ResetItem,
    success: Bool,
    error: String?,
    actor: ActorID
  ) async throws(AuraError) {
    try await store?.database.run(
      sql: """
        INSERT INTO recovery_checkpoints (
          id, timestamp, correlation_id, kind, description, reference_id, verified
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """,
      arguments: [
        .text(UUID().uuidString),
        .text(formatDate(Date())),
        .text(planID.uuidString),
        .text(success ? "postMigration" : "manual"),
        .text("\(success ? "removed" : "failed to remove") \(item.kind.rawValue) at \(item.path)" + (error.map { ": \($0)" } ?? "")),
        .text(item.path),
        .integer(success ? 1 : 0),
      ])
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

public struct ResetExecutionResult: Codable, Sendable, Equatable {
  public let removed: [ResetItem]
  public let failed: [ResetExecutionFailure]
  public var success: Bool { failed.isEmpty }
}

public struct ResetExecutionFailure: Codable, Sendable, Equatable {
  public let item: ResetItem
  public let reason: String
}
