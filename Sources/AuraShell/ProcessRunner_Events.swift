import AuraCore
import Foundation

/// Lock-protected accumulator for `drainPipeBounded`. A reference type so the
/// `@Sendable` `readabilityHandler` closure can mutate it without capturing
/// mutable value state.
private final class PipeDrainBox: @unchecked Sendable {
  let lock = NSLock()
  var data = Data()
  var reachedEOF = false
}

struct ProcessOutputEventInput {
  let executionID: UUID
  let stdout: String
  let stderr: String
  let stdoutTruncated: Bool
  let stderrTruncated: Bool
  let redactor: OutputRedactor
}

struct ProcessCompletionInput {
  let executionID: UUID
  let redactor: OutputRedactor
  let start: Date
  let outcome: CommandCompletedEvent.Outcome
  let exitCode: Int?
  let stdoutBytes: Int
  let stderrBytes: Int
}

extension ProcessRunner {
  // MARK: - Helpers

  static func mergeEnvironment(
    commandEnvironment: [String: String],
    allowedKeys: Set<String>
  ) -> [String: String]? {
    var merged = ProcessInfo.processInfo.environment
    for (key, value) in commandEnvironment where allowedKeys.contains(key) {
      merged[key] = value
    }
    return merged
  }

  /// Drain a pipe's buffered output with a bounded EOF wait.
  ///
  /// `readDataToEndOfFile()` blocks until the pipe reaches EOF. A child that
  /// inherits the write end of the pipe (e.g. `claude --help` spawning a
  /// helper) keeps the write end open after the parent exits, so EOF never
  /// arrives and the read hangs the whole bundle past the test watchdog.
  /// This mirrors the streaming path: a `readabilityHandler` drains whatever
  /// is available and marks EOF, and we wait a bounded grace window for it
  /// before returning what we have rather than blocking forever.
  func drainPipeBounded(_ pipe: Pipe, maxWaitSeconds: Double = 0.5) -> Data {
    let handle = pipe.fileHandleForReading
    let box = PipeDrainBox()
    handle.readabilityHandler = { h in
      let chunk = h.availableData
      box.lock.lock()
      if chunk.isEmpty {
        box.reachedEOF = true
        h.readabilityHandler = nil
      } else {
        box.data.append(chunk)
      }
      box.lock.unlock()
    }
    let deadline = Date().addingTimeInterval(maxWaitSeconds)
    while Date() < deadline {
      box.lock.lock()
      let done = box.reachedEOF
      box.lock.unlock()
      if done { break }
      Thread.sleep(forTimeInterval: 0.005)
    }
    handle.readabilityHandler = nil
    box.lock.lock()
    let result = box.data
    box.lock.unlock()
    return result
  }

  func collectAndBound(
    pipe: Pipe,
    maxBytes: Int,
    maxLines: Int
  ) -> (text: String, truncated: Bool) {
    let data = drainPipeBounded(pipe)
    var text = String(data: data, encoding: .utf8) ?? ""
    var truncated = false

    let lines = text.components(separatedBy: "\n")
    if lines.count > maxLines {
      text = lines.prefix(maxLines).joined(separator: "\n") + "\n"
      truncated = true
    }
    if text.utf8.count > maxBytes {
      let maxIndex =
        text.index(text.startIndex, offsetBy: maxBytes, limitedBy: text.endIndex)
        ?? text.endIndex
      text = String(text[..<maxIndex])
      truncated = true
    }
    return (text, truncated)
  }

  func emitOutputEvents(_ input: ProcessOutputEventInput) async {
    let redactedStdout = input.redactor.redact(input.stdout)
    let redactedStderr = input.redactor.redact(input.stderr)

    let stdoutPayload = CommandOutputEvent(
      executionID: input.executionID,
      stream: .stdout,
      text: redactedStdout,
      isComplete: true,
      truncated: input.stdoutTruncated
    )
    let stderrPayload = CommandOutputEvent(
      executionID: input.executionID,
      stream: .stderr,
      text: redactedStderr,
      isComplete: true,
      truncated: input.stderrTruncated
    )
    let stdoutEnvelope = EventEnvelope<CommandOutputEvent>(
      correlationID: input.executionID,
      causationID: input.executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: stdoutPayload
    )
    let stderrEnvelope = EventEnvelope<CommandOutputEvent>(
      correlationID: input.executionID,
      causationID: input.executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: stderrPayload
    )
    await AuraEventBus.shared.emit(stdoutEnvelope)
    await AuraEventBus.shared.emit(stderrEnvelope)
  }

  func emitCompletion(_ input: ProcessCompletionInput) async {
    let payload = CommandCompletedEvent(
      executionID: input.executionID,
      outcome: input.outcome,
      exitCode: input.exitCode,
      durationSeconds: Date().timeIntervalSince(input.start),
      stdoutByteCount: input.stdoutBytes,
      stderrByteCount: input.stderrBytes,
      redacted: !input.redactor.rules.isEmpty
    )
    let envelope = EventEnvelope<CommandCompletedEvent>(
      correlationID: input.executionID,
      causationID: input.executionID,
      actor: .automation,
      sensitivity: .internalLevel,
      payload: payload
    )
    await AuraEventBus.shared.emit(envelope)
  }
}
