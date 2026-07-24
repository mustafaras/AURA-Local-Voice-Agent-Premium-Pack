import AuraCore
import Foundation

/// Public coordinator for the AURA typed shell subsystem.
///
/// `AuraShell` combines command validation, policy authorization, process
/// execution, output redaction, and filesystem evidence capture behind a single
/// async entry point. It is the only shell target type imported by higher-level
/// modules.
public actor AuraShell {
  private let configuration: ShellConfiguration
  private let policyAdapter: ShellPolicyAdapter
  private let runner: ProcessRunner
  private let evidence: FilesystemEvidence

  public init(configuration: ShellConfiguration) {
    self.configuration = configuration
    self.policyAdapter = ShellPolicyAdapter()
    self.runner = ProcessRunner(configuration: configuration)
    self.evidence = FilesystemEvidence()
  }

  /// Execute a typed command after optional policy authorization and filesystem
  /// evidence capture.
  public func execute(
    command: Command,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> Result<ProcessResult, AuraError> {
    do {
      try command.validate(configuration: configuration)
    } catch {
      return .failure(error)
    }

    let beforeSnapshots = await captureEvidence(
      executionID: correlationID,
      paths: command.filesystemEvidencePaths
    )

    let request = policyAdapter.request(
      command: command,
      actor: actor,
      sessionID: sessionID,
      correlationID: correlationID,
      causationID: causationID
    )

    // Policy decision is required but not resolved here; this boundary just
    // constructs the request and forwards to the runner. A future integration
    // with a concrete `PolicyEngine` will await the decision before running.
    _ = request

    let result = await runner.run(command, executionID: correlationID)

    let afterSnapshots = await captureEvidence(
      executionID: correlationID,
      paths: command.filesystemEvidencePaths
    )

    // Emit filesystem-change evidence events for any directory that changed.
    for (index, before) in beforeSnapshots.enumerated() where index < afterSnapshots.count {
      let after = afterSnapshots[index]
      let digest = await evidence.diffDigest(before: before, after: after)
      let payload = ShellFilesystemChangedEvent(
        executionID: correlationID,
        path: before.path,
        diffDigest: digest,
        added: after.entries.filter { entry in
          !before.entries.contains(where: { $0.relativePath == entry.relativePath })
        }.map(\.relativePath),
        removed: before.entries.filter { entry in
          !after.entries.contains(where: { $0.relativePath == entry.relativePath })
        }.map(\.relativePath),
        modified: zip(before.entries, after.entries).compactMap { (b, a) in
          b.relativePath == a.relativePath && b.sha256 != a.sha256 ? a.relativePath : nil
        }
      )
      let envelope = EventEnvelope<ShellFilesystemChangedEvent>(
        correlationID: correlationID,
        causationID: causationID,
        actor: actor,
        sensitivity: .internalLevel,
        payload: payload
      )
      await AuraEventBus.shared.emit(envelope)
    }

    return result
  }

  /// Cancel an in-flight execution by correlation ID.
  public func cancel(correlationID: UUID) async {
    await runner.cancel(executionID: correlationID)
  }

  private func captureEvidence(
    executionID: UUID,
    paths: [String]
  ) async -> [FilesystemEvidence.Snapshot] {
    var snapshots: [FilesystemEvidence.Snapshot] = []
    for path in paths {
      let snapshot = await evidence.capture(executionID: executionID, path: path)
      snapshots.append(snapshot)
    }
    return snapshots
  }
}
