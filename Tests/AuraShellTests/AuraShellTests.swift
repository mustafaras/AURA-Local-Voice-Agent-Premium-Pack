import AuraCore
import AuraShell
import Foundation
import Testing

// MARK: - Command validation

@Test
func commandRejectsShellString() {
  let command = Command(executable: "/bin/bash -c", arguments: ["echo hi"])
  #expect(throws: AuraError.self) {
    try command.validate(configuration: ShellConfiguration())
  }
}

@Test
func commandRejectsMetacharacterArguments() {
  let command = Command(executable: "/bin/echo", arguments: ["foo; rm -rf /"])
  #expect(throws: AuraError.self) {
    try command.validate(configuration: ShellConfiguration())
  }
}

@Test
func commandAcceptsSafeArguments() throws {
  let command = Command(executable: "/bin/echo", arguments: ["hello", "world"])
  try command.validate(configuration: ShellConfiguration())
}

@Test
func commandTrailingArgumentIsExemptFromMetacharacterScan() throws {
  let command = Command(
    executable: "/bin/echo", arguments: ["hello"],
    trailingArgument: "objective; with | shell && metacharacters")
  try command.validate(configuration: ShellConfiguration())
  #expect(
    command.effectiveArguments == ["hello", "objective; with | shell && metacharacters"])
}

@Test
func commandEffectiveArgumentsOmitsTrailingArgumentWhenNil() {
  let command = Command(executable: "/bin/echo", arguments: ["hello"])
  #expect(command.effectiveArguments == ["hello"])
}

@Test
func commandRejectsDisallowedEnvironmentKey() {
  var config = ShellConfiguration()
  config.allowedEnvironmentKeys = ["ALLOWED"]
  let command = Command(
    executable: "/bin/printenv",
    environment: ["ALLOWED": "ok", "SECRET": "leak"]
  )
  #expect(throws: AuraError.self) {
    try command.validate(configuration: config)
  }
}

@Test
func commandRejectsTimeoutOutOfBounds() {
  var config = ShellConfiguration()
  config.defaultTimeoutSeconds = 10
  let command = Command(executable: "/bin/echo", timeoutSeconds: 50)
  #expect(throws: AuraError.self) {
    try command.validate(configuration: config)
  }
}

// MARK: - Redaction

@Test
func redactorMasksDefaultPatterns() {
  let redactor = OutputRedactor.default
  let token = "sk-" + String(repeating: "a", count: 48)
  let output = "api_key=\(token) other"
  let redacted = redactor.redact(output)
  #expect(redacted.contains("<redacted>"))
  #expect(!redacted.contains(token))
}

@Test
func redactorCanPassthrough() {
  let redactor = OutputRedactor.passthrough
  let output = "api_key=secret"
  #expect(redactor.redact(output) == output)
}

// MARK: - Process runner

@Test
func runnerEchoesStdout() async throws {
  let config = ShellConfiguration()
  let runner = ProcessRunner(configuration: config)
  let command = Command(executable: "/bin/echo", arguments: ["typed", "shell"])
  let result = try await runner.run(command, executionID: UUID()).get()
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("typed shell"))
  #expect(result.stderr.isEmpty)
  #expect(!result.wasCancelled)
}

@Test
func runnerBoundsOutput() async throws {
  var config = ShellConfiguration()
  config.maxOutputLines = 2
  let runner = ProcessRunner(configuration: config)
  let command = Command(executable: "/usr/bin/seq", arguments: ["1", "100"])
  let result = try await runner.run(command, executionID: UUID()).get()
  #expect(result.stdoutTruncated)
  #expect(result.stdout.components(separatedBy: "\n").count <= 3)
}

@Test
func runnerRedactsOutput() async throws {
  var config = ShellConfiguration()
  config.redactionPatterns = ["\\bsecret\\b"]
  let runner = ProcessRunner(configuration: config)
  let command = Command(executable: "/bin/echo", arguments: ["the secret is here"])
  let result = try await runner.run(command, executionID: UUID()).get()
  #expect(result.stdout.contains("<redacted>"))
  #expect(!result.stdout.contains("secret is here"))
}

@Test
func runnerReportsNonzeroExitAsFailed() async {
  let runner = ProcessRunner(configuration: ShellConfiguration())
  let command = Command(executable: "/usr/bin/false")
  let result = await runner.run(command, executionID: UUID())
  switch result {
  case .success(let value):
    #expect(value.exitCode != 0)
  case .failure(let error):
    Issue.record("expected success with non-zero exit, got \(error)")
  }
}

@Test
func runnerTimesOut() async {
  var config = ShellConfiguration()
  config.defaultTimeoutSeconds = 30
  let runner = ProcessRunner(configuration: config)
  let command = Command(executable: "/bin/sleep", arguments: ["10"], timeoutSeconds: 0.2)
  let result = await runner.run(command, executionID: UUID())
  #expect(throws: AuraError.self) {
    try result.get()
  }
}

@Test
func runnerCancelsInFlightCommand() async {
  var config = ShellConfiguration()
  config.defaultTimeoutSeconds = 30
  let runner = ProcessRunner(configuration: config)
  let executionID = UUID()
  let command = Command(executable: "/bin/sleep", arguments: ["5"], timeoutSeconds: 10)

  let runTask = Task {
    await runner.run(command, executionID: executionID)
  }

  // Give the process a moment to launch before cancelling.
  try? await Task.sleep(nanoseconds: 100_000_000)
  await runner.cancel(executionID: executionID)

  let result = await runTask.value
  #expect(throws: AuraError.self) {
    try result.get()
  }
}

// MARK: - Filesystem evidence

@Test
func evidenceSnapshotListsFiles() async throws {
  let evidence = FilesystemEvidence()
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = dir.appendingPathComponent("test.txt")
  try "content".write(toFile: file.path, atomically: true, encoding: .utf8)

  let snapshot = await evidence.capture(
    executionID: UUID(),
    path: dir.path
  )
  #expect(snapshot.entries.count == 1)
  #expect(snapshot.entries.first?.relativePath == "test.txt")
}

@Test
func evidenceDiffDetectsChange() async throws {
  let evidence = FilesystemEvidence()
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: dir) }
  let file = dir.appendingPathComponent("a.txt")
  try "old".write(toFile: file.path, atomically: true, encoding: .utf8)

  let before = await evidence.capture(executionID: UUID(), path: dir.path)
  try "new".write(toFile: file.path, atomically: true, encoding: .utf8)
  let after = await evidence.capture(executionID: UUID(), path: dir.path)

  let digest = await evidence.diffDigest(before: before, after: after)
  #expect(!digest.isEmpty)
}

// MARK: - AuraShell coordinator

@Test
func auraShellExecutesEcho() async throws {
  let config = ShellConfiguration()
  let shell = AuraShell(configuration: config)
  let command = Command(executable: "/bin/echo", arguments: ["coordinated"])
  let result = try await shell.execute(
    command: command,
    actor: .automation,
    sessionID: UUID(),
    correlationID: UUID(),
    causationID: UUID()
  ).get()
  #expect(result.exitCode == 0)
  #expect(result.stdout.contains("coordinated"))
}
