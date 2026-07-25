import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

/// A working directory that passes `ClaudeConfiguration`'s default
/// `allowedWorkingDirectories` ("$HOME", "$TMPDIR") allowlist check.
private let claudeTaskAllowedWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

// MARK: - Test doubles

/// Fake `AdapterProcessExecuting` that never spawns a real process. Yields
/// scripted lines (typically real fixture JSONL) and records cancellation.
private actor FakeClaudeProcessExecutor: AdapterProcessExecuting {
  private let lines: [String]
  private let completion: ProcessResult
  private let gate: ClaudeTestGate?
  private(set) var runInvoked = false
  private(set) var cancelledExecutionIDs: [UUID] = []
  private var cancelled = false

  init(lines: [String], completion: ProcessResult? = nil, gate: ClaudeTestGate? = nil) {
    self.lines = lines
    self.completion =
      completion
      ?? ProcessResult(
        executionID: UUID(), exitCode: 0, stdout: "", stderr: "", durationSeconds: 0.01,
        wasCancelled: false, wasTimedOut: false, stdoutTruncated: false, stderrTruncated: false)
    self.gate = gate
  }

  func run(
    command: Command, actor: ActorID, sessionID: UUID, executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    runInvoked = true
    let lines = self.lines
    let completion = self.completion
    return AsyncThrowingStream { continuation in
      Task {
        if let gate = self.gate {
          await gate.hold()
        }
        if self.cancelled {
          continuation.finish(throwing: AuraError.shellError("cancelled"))
          return
        }
        for (index, line) in lines.enumerated() {
          continuation.yield(
            .line(
              ProcessOutputLine(
                executionID: executionID, stream: .stdout, text: line, sequence: index + 1)))
        }
        continuation.yield(.completed(completion))
        continuation.finish()
      }
    }
  }

  func cancel(executionID: UUID) async {
    cancelled = true
    cancelledExecutionIDs.append(executionID)
    await gate?.release()
  }
}

private actor ClaudeTestGate {
  private var continuation: CheckedContinuation<Void, Never>?
  private var open = false

  func hold() async {
    guard !open else { return }
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
      self.continuation = c
    }
  }

  func release() {
    open = true
    continuation?.resume()
    continuation = nil
  }
}

private actor ClaudeTestCapture {
  var payloads: [any EventPayload] = []

  func append(_ payload: any EventPayload) {
    payloads.append(payload)
  }

  func waitForEvent<E: EventPayload>(
    _ type: E.Type,
    timeoutNanoseconds: UInt64 = 500_000_000
  ) async -> E? {
    let deadline = ContinuousClock().now + .nanoseconds(Int64(timeoutNanoseconds))
    while ContinuousClock().now < deadline {
      if let found = payloads.first(where: { $0 is E }) as? E {
        return found
      }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return nil
  }
}

// MARK: - Fixtures

private func loadClaudeFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

// MARK: - Policy engine helpers

private func makeClaudeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeClaudePolicyEngine(
  configuration: PolicyConfiguration = PolicyConfiguration(
    defaultConfirmationTier: .destructive,
    allowByDefaultTiers: [.observation, .reversible],
    denyByDefaultTiers: [.mutation, .destructive]
  ),
  eventBus: AuraEventBus
) async throws -> PolicyEngine {
  let store = try await makeClaudeTempStore()
  return try await PolicyEngine(configuration: configuration, eventBus: eventBus, store: store)
}

private func drainClaude(
  _ stream: AsyncThrowingStream<ClaudeNormalizedEvent, Error>
) async throws -> [ClaudeNormalizedEvent] {
  var events: [ClaudeNormalizedEvent] = []
  for try await event in stream {
    events.append(event)
  }
  return events
}

// MARK: - ClaudeAdapter: policy gate

@Test
func claudeAdapterDenyPathNeverInvokesExecutor() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeDeny"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  let executor = FakeClaudeProcessExecutor(lines: [])
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = ClaudeRunRequest(
    objective: "do it", workingDirectory: claudeTaskAllowedWorkingDirectory,
    toolProfile: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainClaude(stream)

  #expect(events.count == 1)
  guard case .approvalDecision(_, let allowed, _) = events[0] else {
    Issue.record("expected approvalDecision, got \(events[0])")
    return
  }
  #expect(!allowed)
  #expect(await executor.runInvoked == false)
}

@Test
func claudeAdapterAllowByDefaultPathInvokesExecutorAndParsesRealFixture() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "claudeAllow"))
  let policyEngine = try await makeClaudePolicyEngine(eventBus: bus)
  let fixtureLines = try loadClaudeFixtureLines("claude_smoke_success.jsonl")
  let executor = FakeClaudeProcessExecutor(lines: fixtureLines)
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  // .readOnly maps to Capability.agentClaudeReadOnly (.reversible), allowed
  // by default in this test's policy configuration.
  let request = ClaudeRunRequest(
    objective: "reply ping", workingDirectory: claudeTaskAllowedWorkingDirectory,
    toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainClaude(stream)

  #expect(await executor.runInvoked)
  let assistantTexts = events.compactMap { event -> String? in
    if case .message("assistant", let text, _) = event { return text }
    return nil
  }
  #expect(assistantTexts == ["ping"])
  guard case .turnCompleted(let resultText, let cost, _, _, _, _) = events.last(where: {
    if case .turnCompleted = $0 { return true } else { return false }
  }) else {
    Issue.record("expected a turnCompleted event, got \(events)")
    return
  }
  #expect(resultText == "ping")
  #expect(cost > 0)
}

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
      if case .budgetExceeded(let kind, _, _) = $0 { return kind == "costUSD" } else { return false }
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
  await bus.subscribe(TaskCompletedEvent.self) { (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
  await bus.subscribe(TaskCompletedEvent.self) { (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
