import AuraCore
import Foundation

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

  func collectAndBound(
    pipe: Pipe,
    maxBytes: Int,
    maxLines: Int
  ) -> (text: String, truncated: Bool) {
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
