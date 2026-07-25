import AuraCore
import AuraShell
import Foundation

/// Seam between a CLI-backed coding-agent adapter (`CodexAdapter`,
/// `ClaudeAdapter`, …) and real process execution.
///
/// Production code uses `ShellAdapterProcessExecutor`. Tests inject a fake
/// that yields scripted events from fixture JSONL — no real subprocess is
/// ever spawned by the automated test suite.
public protocol AdapterProcessExecuting: Sendable {
  func run(
    command: Command,
    actor: ActorID,
    sessionID: UUID,
    executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error>

  func cancel(executionID: UUID) async
}

/// Production executor: runs the command through a dedicated `AuraShell`
/// instance scoped to only ever launch the configured CLI binary.
public struct ShellAdapterProcessExecutor: AdapterProcessExecuting {
  private let shell: AuraShell

  public init(shell: AuraShell) {
    self.shell = shell
  }

  public func run(
    command: Command,
    actor: ActorID,
    sessionID: UUID,
    executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    await shell.executeStreaming(
      command: command,
      actor: actor,
      sessionID: sessionID,
      correlationID: executionID,
      causationID: executionID
    )
  }

  public func cancel(executionID: UUID) async {
    await shell.cancel(correlationID: executionID)
  }
}
