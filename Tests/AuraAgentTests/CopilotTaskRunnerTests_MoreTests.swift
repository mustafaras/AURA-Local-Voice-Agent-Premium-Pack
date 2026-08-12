import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

@Test
func copilotAdapterBlocksRunWhenRepositoryInstructionsContainSecrets() async throws {
  // A subdirectory of the allowlisted $HOME-based constant, not the raw
  // system temp directory: $TMPDIR's own trailing slash makes
  // WorkingDirectoryAllowlist's prefix check reject a bare temp-dir path.
  let repo = URL(fileURLWithPath: copilotTaskAllowedWorkingDirectory)
    .appendingPathComponent("aura-test-scratch-\(UUID().uuidString)")
  try FileManager.default.createDirectory(
    at: repo.appendingPathComponent(".github"), withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: repo) }
  let fakeKey = "sk-" + String(repeating: "a", count: 40)
  try "Use key \(fakeKey)."
    .write(
      to: repo.appendingPathComponent(".github/copilot-instructions.md"), atomically: true,
      encoding: .utf8)

  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotSecretBlock"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let executor = FakeCopilotProcessExecutor(lines: copilotSuccessfulRunLines)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = CopilotRunRequest(
    objective: "reply with pong", workingDirectory: repo.path, toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  guard
    case .repositoryInstructionsScanned(_, let secretsDetected, let blockedFiles) =
      events
      .first(where: {
        if case .repositoryInstructionsScanned = $0 { return true } else { return false }
      })
  else {
    Issue.record("expected repositoryInstructionsScanned, got \(events)")
    return
  }
  #expect(secretsDetected)
  #expect(blockedFiles.count == 1)
  #expect(events.contains { if case .copilotError = $0 { return true } else { return false } })
  #expect(await executor.runInvoked == false)
}

@Test
func copilotAdapterAllowsRunWhenRepositoryInstructionsAreClean() async throws {
  let repo = URL(fileURLWithPath: copilotTaskAllowedWorkingDirectory)
    .appendingPathComponent("aura-test-scratch-\(UUID().uuidString)")
  try FileManager.default.createDirectory(
    at: repo.appendingPathComponent(".github"), withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: repo) }
  try "Prefer functional style."
    .write(
      to: repo.appendingPathComponent(".github/copilot-instructions.md"), atomically: true,
      encoding: .utf8)

  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotSecretClean"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let executor = FakeCopilotProcessExecutor(lines: copilotSuccessfulRunLines)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = CopilotRunRequest(
    objective: "reply with pong", workingDirectory: repo.path, toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  #expect(await executor.runInvoked)
  #expect(events.contains { if case .turnCompleted = $0 { return true } else { return false } })
}

// MARK: - File-write budget (post-hoc)

@Test
func copilotAdapterFlagsFileWriteBudgetExceededAfterCompletion() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotBudget"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  var configuration = CopilotConfiguration()
  configuration.maxFileWritesPerRun = 1
  let resultLine =
    #"{"type":"result","exitCode":0,"usage":{"premiumRequests":1,"totalApiDurationMs":400,"#
    + #""sessionDurationMs":900,"codeChanges":{"linesAdded":5,"linesRemoved":1,"#
    + #""filesModified":["a.txt","b.txt","c.txt"]}}}"#
  let executor = FakeCopilotProcessExecutor(lines: [resultLine])
  let adapter = CopilotAdapter(
    configuration: configuration, policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  // .readOnly (allowed by default in this test's policy configuration) is
  // sufficient here — this test exercises the post-hoc file-write budget
  // check against a scripted result line, not real tool-profile semantics.
  let request = CopilotRunRequest(
    objective: "edit files", workingDirectory: copilotTaskAllowedWorkingDirectory,
    toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  #expect(
    events.contains {
      if case .budgetExceeded(let kind, _, _) = $0 {
        return kind == "fileWrites"
      } else {
        return false
      }
    })
}

// MARK: - Cancellation

@Test
func copilotAdapterCancelStopsInFlightRun() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotCancel"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let gate = CopilotTestGate()
  let executor = FakeCopilotProcessExecutor(lines: ["irrelevant"], gate: gate)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let correlationID = UUID()

  let request = CopilotRunRequest(
    objective: "reply with pong", workingDirectory: copilotTaskAllowedWorkingDirectory,
    toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: correlationID,
    causationID: correlationID)

  let consumeTask = Task<[CopilotNormalizedEvent], Error> {
    try await drainCopilot(stream)
  }

  try? await Task.sleep(nanoseconds: 50_000_000)
  await adapter.cancel(correlationID: correlationID)

  var threw = false
  do {
    _ = try await consumeTask.value
  } catch {
    threw = true
  }

  #expect(threw)
  #expect(await executor.cancelledExecutionIDs.contains(correlationID))
}

// MARK: - Process-level failure surfaced even without a native result line

@Test
func copilotTaskRunnerThrowsWhenProcessTimesOutWithoutResultLine() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotTimeout"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let timedOutResult = ProcessResult(
    executionID: UUID(), exitCode: -1, stdout: "", stderr: "", durationSeconds: 5,
    wasCancelled: false, wasTimedOut: true, stdoutTruncated: false, stderrTruncated: false)
  let executor = FakeCopilotProcessExecutor(lines: [], completion: timedOutResult)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let store = try await makeCopilotTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = CopilotTaskRunner(
    adapter: adapter, sessionID: UUID(),
    defaultWorkingDirectory: copilotTaskAllowedWorkingDirectory, defaultToolProfile: .readOnly)

  let capture = CopilotTestCapture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  _ = try await engine.enqueue(request: TaskRequest(objective: "reply with pong"), runner: runner)

  let completed = await capture.waitForEvent(
    TaskCompletedEvent.self, timeoutNanoseconds: 1_000_000_000)
  #expect(completed?.outcome == .failed)
}

// MARK: - Full AuraTaskEngine integration (happy path)

@Test
func copilotTaskRunnerHappyPathCompletesTaskViaEngine() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotHappy"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let executor = FakeCopilotProcessExecutor(lines: copilotSuccessfulRunLines)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let store = try await makeCopilotTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = CopilotTaskRunner(
    adapter: adapter, sessionID: UUID(),
    defaultWorkingDirectory: copilotTaskAllowedWorkingDirectory, defaultToolProfile: .readOnly)

  let capture = CopilotTestCapture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let status = try await engine.enqueue(
    request: TaskRequest(objective: "reply with pong"), runner: runner)
  #expect(status.state == .pending)

  let completed = await capture.waitForEvent(
    TaskCompletedEvent.self, timeoutNanoseconds: 1_000_000_000)
  #expect(completed?.outcome == .succeeded)
  #expect(await engine.status(id: status.id)?.state == .completed)
}
