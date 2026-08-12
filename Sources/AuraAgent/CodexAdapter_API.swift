import AuraCore
import AuraPolicy
import AuraShell
import Foundation

extension CodexAdapter {
  /// Run a single Codex turn. The returned stream yields every normalized
  /// event — including the upfront approval cycle — in the order it occurs,
  /// and finishes when the run completes, is denied, or fails.
  public func run(
    request: CodexRunRequest,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async -> AsyncThrowingStream<CodexNormalizedEvent, Error> {
    let runID = correlationID

    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          try await self.perform(
            request: request,
            context: CodexPerformContext(
              actor: actor,
              sessionID: sessionID,
              correlationID: correlationID,
              causationID: causationID,
              runID: runID,
              continuation: continuation
            )
          )
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      // Only propagate cancellation to the underlying process when the
      // *consumer* stops iterating early (`.cancelled`). On `.finished`
      // (success or a thrown error), `perform(...)` already ran to
      // completion and the process has already exited on its own —
      // cancelling here too would be redundant on every single run.
      continuation.onTermination = { @Sendable termination in
        guard case .cancelled = termination else { return }
        task.cancel()
        Task { await self.processExecutor.cancel(executionID: correlationID) }
      }
    }
  }

  /// Cancel an in-flight run by correlation ID.
  public func cancel(correlationID: UUID) async {
    await processExecutor.cancel(executionID: correlationID)
  }
}
