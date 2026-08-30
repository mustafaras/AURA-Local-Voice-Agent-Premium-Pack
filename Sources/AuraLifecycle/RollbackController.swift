import AuraCore
import AuraStore
import Foundation

/// Coordinates rollback of staged updates using recovery checkpoints. Does not
/// perform actual bundle replacement; it records intent and delegates to the
/// stager so the operation is reversible until final apply.
public actor RollbackController {
  private let checkpoint: RecoveryCheckpoint
  private let stager: UpdateStager?
  private let eventBus: AuraEventBus?

  public init(
    checkpoint: RecoveryCheckpoint,
    stager: UpdateStager? = nil,
    eventBus: AuraEventBus? = nil
  ) {
    self.checkpoint = checkpoint
    self.stager = stager
    self.eventBus = eventBus
  }

  /// Record a verified rollback target before any update is applied. This is
  /// the checkpoint that `rollbackToLastCheckpoint` will restore.
  @discardableResult
  public func prepareRollbackTarget(
    version: String,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> UUID {
    try await checkpoint.record(
      kind: .rollbackTarget,
      description: "pre-update baseline version \(version)",
      referenceID: version,
      correlationID: correlationID,
      verified: true)
  }

  /// Roll back the staged update by ID and record a `postUpdate` checkpoint
  /// capturing the rollback action. Returns the staged update ID if successful.
  @discardableResult
  public func rollbackStagedUpdate(
    stagedUpdateID: UUID,
    reason: String,
    actor: ActorID = .user,
    correlationID: UUID = UUID()
  ) async throws(AuraError) -> UUID {
    guard let stager = stager else {
      throw AuraError.lifecycleError("stager not configured")
    }
    let result = try await stager.rollback(
      stagedUpdateID: stagedUpdateID,
      reason: reason,
      correlationID: correlationID)
    guard case .staged = result else {
      throw AuraError.lifecycleError("rollback failed: \(String(describing: result))")
    }
    let checkpointID = try await checkpoint.record(
      kind: .postUpdate,
      description: "rolled back staged update \(stagedUpdateID): \(reason)",
      referenceID: stagedUpdateID.uuidString,
      correlationID: correlationID,
      verified: true)
    await emit(
      UpdateRolledBackEvent(stagedUpdateID: stagedUpdateID, version: "", reason: reason, actor: actor),
      .internalLevel)
    return checkpointID
  }

  /// Return the most recent verified rollback target, if any.
  public func lastRollbackTarget() async throws(AuraError) -> RecoveryCheckpointRecord? {
    let targets = try await checkpoint.checkpoints(kind: .rollbackTarget, verifiedOnly: true, limit: 1)
    return targets.first
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
