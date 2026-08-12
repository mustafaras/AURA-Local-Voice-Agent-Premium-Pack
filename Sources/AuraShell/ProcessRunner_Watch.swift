import AuraCore
import Foundation

struct ProcessWatchOutcome {
  let wasCancelled: Bool
  let wasTimedOut: Bool
  let wasBoundExceeded: Bool
}

extension ProcessRunner {
  func watchStreamingProcess(
    executionID: UUID,
    process: Process,
    deadline: Date,
    stdoutAccumulator: LineAccumulator,
    stderrAccumulator: LineAccumulator
  ) async -> ProcessWatchOutcome {
    var wasCancelled = false
    var wasTimedOut = false
    var wasBoundExceeded = false

    while process.isRunning {
      if Task.isCancelled || cancellationRequested.contains(executionID) {
        wasCancelled = true
        process.terminate()
        process.waitUntilExit()
        break
      }
      if Date() >= deadline {
        wasTimedOut = true
        process.terminate()
        process.waitUntilExit()
        break
      }
      let stdoutBoundExceeded = await stdoutAccumulator.boundExceeded
      let stderrBoundExceeded = await stderrAccumulator.boundExceeded
      if stdoutBoundExceeded || stderrBoundExceeded {
        wasBoundExceeded = true
        process.terminate()
        process.waitUntilExit()
        break
      }
      try? await Task.sleep(nanoseconds: 20_000_000)  // 20 ms
    }

    if cancellationRequested.contains(executionID) {
      wasCancelled = true
    }
    cancellationRequested.remove(executionID)
    activeProcesses.removeValue(forKey: executionID)

    return ProcessWatchOutcome(
      wasCancelled: wasCancelled,
      wasTimedOut: wasTimedOut,
      wasBoundExceeded: wasBoundExceeded
    )
  }

  /// Cancel an in-flight command by execution ID.
  public func cancel(executionID: UUID) async {
    cancellationRequested.insert(executionID)
    activeProcesses[executionID]?.terminate()
    // Yield so the termination signal has a chance to land before the
    // caller checks the result synchronously.
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
}
