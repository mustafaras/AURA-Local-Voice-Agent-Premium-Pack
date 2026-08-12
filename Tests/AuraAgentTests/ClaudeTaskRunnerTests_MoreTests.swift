import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

@Test
func claudeAdapterConfirmPathRoundTripsThroughPolicyEngine() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeConfirm"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentClaudeRun,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let executor = FakeClaudeProcessExecutor(
    lines: try loadClaudeFixtureLines("claude_smoke_success.jsonl"))
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    approvalPresenter: ClaudeAlwaysAllowApprovalPresenter(),
    processExecutor: executor, eventBus: bus)

  let request = ClaudeRunRequest(
    objective: "reply ping", workingDirectory: claudeTaskAllowedWorkingDirectory,
    toolProfile: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainClaude(stream)

  guard case .approvalRequested = events.first else {
    Issue.record("expected approvalRequested first, got \(String(describing: events.first))")
    return
  }
  #expect(await executor.runInvoked)
}

@Test
func claudeAdapterConfirmPathDeniedWhenPresenterRefuses() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeConfirmDeny"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentClaudeRun,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let executor = FakeClaudeProcessExecutor(lines: [])
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    approvalPresenter: ClaudeAlwaysDenyApprovalPresenter(),
    processExecutor: executor, eventBus: bus)

  let request = ClaudeRunRequest(
    objective: "reply ping", workingDirectory: claudeTaskAllowedWorkingDirectory,
    toolProfile: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainClaude(stream)

  #expect(
    events.contains {
      if case .approvalDecision(_, false, _) = $0 { return true } else { return false }
    })
  #expect(await executor.runInvoked == false)
}

// MARK: - Cost budget (post-hoc observability)

@Test
func claudeAdapterFlagsCostBudgetExceededAfterRealCompletedRun() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeBudget"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  var configuration = ClaudeConfiguration()
  // The real fixture's actual cost (~$0.026) exceeds this tiny budget.
  configuration.maxEstimatedCostUSD = 0.001
  let executor = FakeClaudeProcessExecutor(
    lines: try loadClaudeFixtureLines("claude_smoke_success.jsonl"))
  let adapter = ClaudeAdapter(
    configuration: configuration, policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = ClaudeRunRequest(
    objective: "reply ping", workingDirectory: claudeTaskAllowedWorkingDirectory,
    toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainClaude(stream)

  #expect(
    events.contains {
      if case .budgetExceeded(let kind, _, _) = $0 {
        return kind == "costUSD"
      } else {
        return false
      }
    })
}

// MARK: - Cancellation

@Test
func claudeAdapterCancelStopsInFlightRun() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeCancel"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  let gate = ClaudeTestGate()
  let executor = FakeClaudeProcessExecutor(lines: ["irrelevant"], gate: gate)
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let correlationID = UUID()

  let request = ClaudeRunRequest(
    objective: "reply ping", workingDirectory: claudeTaskAllowedWorkingDirectory,
    toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentClaude, sessionID: UUID(), correlationID: correlationID,
    causationID: correlationID)

  let consumeTask = Task<[ClaudeNormalizedEvent], Error> {
    try await drainClaude(stream)
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

// MARK: - Process-level failure surfaced even without a native error line

@Test
func claudeTaskRunnerThrowsWhenProcessTimesOutWithoutResultLine() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeTimeout"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  let timedOutResult = ProcessResult(
    executionID: UUID(), exitCode: -1, stdout: "", stderr: "", durationSeconds: 5,
    wasCancelled: false, wasTimedOut: true, stdoutTruncated: false, stderrTruncated: false)
  let executor = FakeClaudeProcessExecutor(lines: [], completion: timedOutResult)
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let store = try await makeClaudeTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = ClaudeTaskRunner(
    adapter: adapter, sessionID: UUID(), defaultWorkingDirectory: claudeTaskAllowedWorkingDirectory,
    defaultToolProfile: .readOnly)

  let capture = ClaudeTestCapture()
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
func claudeTaskRunnerHappyPathCompletesTaskViaEngine() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeHappy"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  let executor = FakeClaudeProcessExecutor(
    lines: try loadClaudeFixtureLines("claude_smoke_success.jsonl"))
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)
  let store = try await makeClaudeTempStore()
  let engine = await AuraTaskEngine(store: store, eventBus: bus)
  try await engine.recoverState()

  let runner = ClaudeTaskRunner(
    adapter: adapter, sessionID: UUID(), defaultWorkingDirectory: claudeTaskAllowedWorkingDirectory,
    defaultToolProfile: .readOnly)

  let capture = ClaudeTestCapture()
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
