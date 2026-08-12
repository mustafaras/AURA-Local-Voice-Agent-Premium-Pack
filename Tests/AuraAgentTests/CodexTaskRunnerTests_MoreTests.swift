import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

@Test
func codexAdapterConfirmPathRoundTripsThroughPolicyEngine() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "confirm"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentCodexRun,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let executor = FakeCodexProcessExecutor(lines: try loadFixtureLines("codex_smoke_success.jsonl"))
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    approvalPresenter: CodexAlwaysAllowApprovalPresenter(),
    processExecutor: executor, eventBus: bus)

  let request = CodexRunRequest(
    prompt: "reply ping", workingDirectory: allowedWorkingDirectory, sandbox: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  guard case .approvalRequested = events.first else {
    Issue.record("expected approvalRequested first, got \(String(describing: events.first))")
    return
  }
  #expect(await executor.runInvoked)
}

@Test
func codexAdapterConfirmPathDeniedWhenPresenterRefuses() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "confirmDeny"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentCodexRun,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let executor = FakeCodexProcessExecutor(lines: [])
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    approvalPresenter: CodexAlwaysDenyApprovalPresenter(),
    processExecutor: executor, eventBus: bus)

  let request = CodexRunRequest(
    prompt: "reply ping", workingDirectory: allowedWorkingDirectory, sandbox: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(
    events.contains {
      if case .approvalDecision(_, false, _) = $0 { return true } else { return false }
    })
  #expect(await executor.runInvoked == false)
}

// MARK: - Budget enforcement

@Test
func codexAdapterFileWriteBudgetCancelsRun() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "budget"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  var configuration = CodexConfiguration()
  configuration.maxFileWritesPerRun = 2
  let fileChangeLine = #"{"type":"item.completed","item":{"id":"x","type":"file_change"}}"#
  let executor = FakeCodexProcessExecutor(lines: Array(repeating: fileChangeLine, count: 5))
  let adapter = CodexAdapter(
    configuration: configuration, policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = CodexRunRequest(
    prompt: "edit files", workingDirectory: allowedWorkingDirectory, sandbox: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(
    events.contains {
      if case .budgetExceeded(let kind, _, _) = $0 {
        return kind == "fileWrites"
      } else {
        return false
      }
    })
  #expect(await executor.cancelledExecutionIDs.isEmpty == false)
}

// MARK: - Cancellation

@Test
func codexAdapterCancelStopsInFlightRun() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "cancel"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let gate = Gate()
  let executor = FakeCodexProcessExecutor(lines: ["irrelevant"], gate: gate)
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let correlationID = UUID()

  let request = CodexRunRequest(
    prompt: "reply ping", workingDirectory: allowedWorkingDirectory, sandbox: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCodex, sessionID: UUID(), correlationID: correlationID,
    causationID: correlationID)

  let consumeTask = Task<[CodexNormalizedEvent], Error> {
    try await drain(stream)
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

// MARK: - Process-level failure surfaced even without a Codex-native error line

@Test
func codexTaskRunnerThrowsWhenProcessTimesOutWithoutJSONLFailure() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "timeout"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let timedOutResult = ProcessResult(
    executionID: UUID(), exitCode: -1, stdout: "", stderr: "", durationSeconds: 5,
    wasCancelled: false, wasTimedOut: true, stdoutTruncated: false, stderrTruncated: false)
  let executor = FakeCodexProcessExecutor(lines: [], completion: timedOutResult)
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let store = try await makeTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = CodexTaskRunner(
    adapter: adapter, sessionID: UUID(), defaultWorkingDirectory: allowedWorkingDirectory,
    defaultSandbox: .readOnly)

  let capture = Capture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  _ = try await engine.enqueue(request: TaskRequest(objective: "reply ping"), runner: runner)

  let completed = await capture.waitForEvent(
    TaskCompletedEvent.self, timeoutNanoseconds: 1_000_000_000)
  #expect(completed?.outcome == .failed)
}

// MARK: - Full AuraTaskEngine integration (happy path)

@Test
func codexTaskRunnerHappyPathCompletesTaskViaEngine() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "happy"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let executor = FakeCodexProcessExecutor(lines: try loadFixtureLines("codex_smoke_success.jsonl"))
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let store = try await makeTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = CodexTaskRunner(
    adapter: adapter, sessionID: UUID(), defaultWorkingDirectory: allowedWorkingDirectory,
    defaultSandbox: .readOnly)

  let capture = Capture()
  await bus.subscribe(TaskCompletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let status = try await engine.enqueue(
    request: TaskRequest(objective: "reply ping"), runner: runner)
  #expect(status.state == .pending)

  let completed = await capture.waitForEvent(
    TaskCompletedEvent.self, timeoutNanoseconds: 1_000_000_000)
  #expect(completed?.outcome == .succeeded)
  #expect(await engine.status(id: status.id)?.state == .completed)
}
