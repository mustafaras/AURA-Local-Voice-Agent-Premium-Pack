import AuraCore
import AuraShell
import Foundation
import Testing

// MARK: - ProcessRunner.runStreaming

@Test
func streamingDeliversStdinAndLinesInOrder() async throws {
  let config = ShellConfiguration()
  let runner = ProcessRunner(configuration: config)
  let command = Command(
    executable: "/bin/cat",
    standardInputText: "line1\nline2\nline3\n"
  )

  var lines: [String] = []
  var completedResult: ProcessResult?
  for try await event in await runner.runStreaming(command, executionID: UUID()) {
    switch event {
    case .line(let outputLine):
      lines.append(outputLine.text)
    case .completed(let result):
      completedResult = result
    }
  }

  #expect(lines == ["line1", "line2", "line3"])
  #expect(completedResult?.exitCode == 0)
  #expect(completedResult?.wasCancelled == false)
}

@Test
func streamingDeliversSemicolonLadenPromptSafely() async throws {
  // Confirms the Command.standardInputText fix: text containing shell
  // metacharacters that Command.validate() rejects as an *argument* is
  // delivered safely via stdin instead.
  let config = ShellConfiguration()
  let runner = ProcessRunner(configuration: config)
  let prompt = "list files; then summarize && report | done"
  let command = Command(executable: "/bin/cat", standardInputText: prompt)

  var lines: [String] = []
  for try await event in await runner.runStreaming(command, executionID: UUID()) {
    if case .line(let outputLine) = event {
      lines.append(outputLine.text)
    }
  }
  #expect(lines.joined() == prompt)
}

@Test
func streamingDeliversTrailingArgumentContainingMetacharacters() async throws {
  // Confirms Command.trailingArgument reaches real argv intact: /bin/echo
  // prints its arguments verbatim, proving the semicolon/pipe/&& survive
  // process spawning without any shell reinterpreting them.
  let config = ShellConfiguration()
  let runner = ProcessRunner(configuration: config)
  let objective = "list files; then summarize && report | done"
  let command = Command(
    executable: "/bin/echo", arguments: ["prefix"], trailingArgument: objective)

  var lines: [String] = []
  for try await event in await runner.runStreaming(command, executionID: UUID()) {
    if case .line(let outputLine) = event {
      lines.append(outputLine.text)
    }
  }
  #expect(lines.joined(separator: "\n") == "prefix \(objective)")
}

@Test
func streamingCancelTerminatesInFlightProcess() async throws {
  var config = ShellConfiguration()
  config.defaultTimeoutSeconds = 30
  let runner = ProcessRunner(configuration: config)
  let executionID = UUID()
  // /usr/bin/yes never terminates on its own.
  let command = Command(executable: "/usr/bin/yes", timeoutSeconds: 30)

  let consumeTask = Task<Int, Never> {
    var count = 0
    do {
      for try await event in await runner.runStreaming(command, executionID: executionID) {
        if case .line = event {
          count += 1
        }
      }
    } catch {
      // Expected: cancellation surfaces as a thrown AuraError.
    }
    return count
  }

  // Let it produce some output before cancelling.
  try? await Task.sleep(nanoseconds: 100_000_000)
  await runner.cancel(executionID: executionID)

  let observedLines = await consumeTask.value
  #expect(observedLines > 0)
}

@Test
func streamingEnforcesOutputLineBound() async throws {
  var config = ShellConfiguration()
  config.maxOutputLines = 3
  let runner = ProcessRunner(configuration: config)
  let command = Command(executable: "/usr/bin/seq", arguments: ["1", "1000"])

  var lines: [String] = []
  var completedResult: ProcessResult?
  for try await event in await runner.runStreaming(command, executionID: UUID()) {
    switch event {
    case .line(let outputLine):
      lines.append(outputLine.text)
    case .completed(let result):
      completedResult = result
    }
  }

  #expect(lines.count <= 3)
  #expect(completedResult?.stdoutTruncated == true)
}
