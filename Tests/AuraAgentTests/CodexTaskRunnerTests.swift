import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

/// A working directory that passes `CodexConfiguration`'s default
/// `allowedWorkingDirectories` ("$HOME", "$TMPDIR") allowlist check.
private let allowedWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

// MARK: - Test doubles

/// Fake `AdapterProcessExecuting` that never spawns a real process. Yields
/// scripted lines (typically real fixture JSONL) and records cancellation.
private actor FakeCodexProcessExecutor: AdapterProcessExecuting {
  private let lines: [String]
  private let completion: ProcessResult
  private let gate: Gate?
  private(set) var runInvoked = false
  private(set) var cancelledExecutionIDs: [UUID] = []
  private var cancelled = false

  init(lines: [String], completion: ProcessResult? = nil, gate: Gate? = nil) {
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

/// Minimal async rendezvous primitive, mirroring the `Gate` used in
/// `AuraTaskEngineTests` (not importable across test targets).
private actor Gate {
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

private actor Capture {
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

private func loadFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

// MARK: - Policy engine helpers

private func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makePolicyEngine(
  configuration: PolicyConfiguration = PolicyConfiguration(
    defaultConfirmationTier: .destructive,
    allowByDefaultTiers: [.observation, .reversible],
    denyByDefaultTiers: [.mutation, .destructive]
  ),
  eventBus: AuraEventBus
) async throws -> PolicyEngine {
  let store = try await makeTempStore()
  return try await PolicyEngine(configuration: configuration, eventBus: eventBus, store: store)
}

private func drain(
  _ stream: AsyncThrowingStream<CodexNormalizedEvent, Error>
) async throws -> [CodexNormalizedEvent] {
  var events: [CodexNormalizedEvent] = []
  for try await event in stream {
    events.append(event)
  }
  return events
}

// MARK: - CodexAdapter: policy gate

@Test
func codexAdapterDenyPathNeverInvokesExecutor() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "deny"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let executor = FakeCodexProcessExecutor(lines: [])
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = CodexRunRequest(
    prompt: "do it", workingDirectory: allowedWorkingDirectory, sandbox: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(events.count == 1)
  guard case .approvalDecision(_, let allowed, _) = events[0] else {
    Issue.record("expected approvalDecision, got \(events[0])")
    return
  }
  #expect(!allowed)
  #expect(await executor.runInvoked == false)
}

@Test
func codexAdapterAllowByDefaultPathInvokesExecutor() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "allow"))
  let policyEngine = try await makePolicyEngine(eventBus: bus)
  let fixtureLines = try loadFixtureLines("codex_smoke_success.jsonl")
  let executor = FakeCodexProcessExecutor(lines: fixtureLines)
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  // .readOnly maps to Capability.agentCodexReadOnly (.reversible), allowed by
  // default in this test's policy configuration.
  let request = CodexRunRequest(
    prompt: "reply ping", workingDirectory: allowedWorkingDirectory, sandbox: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(await executor.runInvoked)
  let agentMessages = events.compactMap { event -> String? in
    if case .agentText("agent_message", let text, _) = event { return text }
    return nil
  }
  #expect(agentMessages == ["ping"])
  #expect(events.contains { if case .turnCompleted = $0 { return true } else { return false } })
}

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
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
  await bus.subscribe(TaskCompletedEvent.self) {
    (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
