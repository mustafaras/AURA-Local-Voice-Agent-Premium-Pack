import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

/// A working directory that passes `CopilotConfiguration`'s default
/// `allowedWorkingDirectories` ("$HOME", "$TMPDIR") allowlist check.
private let copilotTaskAllowedWorkingDirectory =
  ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

/// Hand-built, schema-consistent JSONL for a successful run. Not captured
/// from a real invocation (both authorized smoke tests hit the account's
/// exhausted quota before any completion — see ADR-013) — every field name
/// and shape here matches what `CopilotEventNormalizer`'s doc comment
/// confirms was actually observed (`session.tools_updated`, `user.message`,
/// `assistant.turn_start`/`turn_end`, `result`).
private let copilotSuccessfulRunLines: [String] = [
  #"{"type":"session.tools_updated","data":{"model":"gpt-5-mini"}}"#,
  #"{"type":"user.message","data":{"content":"reply with pong"}}"#,
  #"{"type":"assistant.turn_start","data":{"turnId":"0","model":"gpt-5-mini"}}"#,
  #"{"type":"assistant.turn_end","data":{"turnId":"0"}}"#,
  #"{"type":"assistant.idle","data":{}}"#,
  #"{"type":"result","exitCode":0,"usage":{"premiumRequests":1,"totalApiDurationMs":400,"sessionDurationMs":900,"codeChanges":{"linesAdded":0,"linesRemoved":0,"filesModified":[]}}}"#,
]

// MARK: - Test doubles

private actor FakeCopilotProcessExecutor: AdapterProcessExecuting {
  private let lines: [String]
  private let completion: ProcessResult
  private let gate: CopilotTestGate?
  private(set) var runInvoked = false
  private(set) var cancelledExecutionIDs: [UUID] = []
  private var cancelled = false

  init(lines: [String], completion: ProcessResult? = nil, gate: CopilotTestGate? = nil) {
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

private actor CopilotTestGate {
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

private actor CopilotTestCapture {
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

// MARK: - Policy engine helpers

private func makeCopilotTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeCopilotPolicyEngine(
  configuration: PolicyConfiguration = PolicyConfiguration(
    defaultConfirmationTier: .destructive,
    allowByDefaultTiers: [.observation, .reversible],
    denyByDefaultTiers: [.mutation, .destructive]
  ),
  eventBus: AuraEventBus
) async throws -> PolicyEngine {
  let store = try await makeCopilotTempStore()
  return try await PolicyEngine(configuration: configuration, eventBus: eventBus, store: store)
}

private func drainCopilot(
  _ stream: AsyncThrowingStream<CopilotNormalizedEvent, Error>
) async throws -> [CopilotNormalizedEvent] {
  var events: [CopilotNormalizedEvent] = []
  for try await event in stream {
    events.append(event)
  }
  return events
}

// MARK: - CopilotAdapter: policy gate

@Test
func copilotAdapterDenyPathNeverInvokesExecutor() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotDeny"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let executor = FakeCopilotProcessExecutor(lines: [])
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = CopilotRunRequest(
    objective: "do it", workingDirectory: copilotTaskAllowedWorkingDirectory,
    toolProfile: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  guard case .approvalDecision(_, let allowed, _) = events.last(where: {
    if case .approvalDecision = $0 { return true } else { return false }
  }) else {
    Issue.record("expected an approvalDecision, got \(events)")
    return
  }
  #expect(!allowed)
  #expect(await executor.runInvoked == false)
}

@Test
func copilotAdapterAllowByDefaultPathInvokesExecutorAndParsesSuccessfulRun() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotAllow"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  let executor = FakeCopilotProcessExecutor(lines: copilotSuccessfulRunLines)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: executor, eventBus: bus)

  let request = CopilotRunRequest(
    objective: "reply with pong", workingDirectory: copilotTaskAllowedWorkingDirectory,
    toolProfile: .readOnly)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  #expect(await executor.runInvoked)
  guard case .turnCompleted(let exitCode, _, _, let filesModifiedCount, _, _) = events.last(where: {
    if case .turnCompleted = $0 { return true } else { return false }
  }) else {
    Issue.record("expected turnCompleted, got \(events)")
    return
  }
  #expect(exitCode == 0)
  #expect(filesModifiedCount == 0)
}

@Test
func copilotAdapterConfirmPathRoundTripsThroughPolicyEngine() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotConfirm"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentCopilotRun,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let executor = FakeCopilotProcessExecutor(lines: copilotSuccessfulRunLines)
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    approvalPresenter: CopilotAlwaysAllowApprovalPresenter(),
    processExecutor: executor, eventBus: bus)

  let request = CopilotRunRequest(
    objective: "reply with pong", workingDirectory: copilotTaskAllowedWorkingDirectory,
    toolProfile: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  guard case .approvalRequested = events.first(where: {
    if case .approvalRequested = $0 { return true } else { return false }
  }) else {
    Issue.record("expected approvalRequested, got \(events)")
    return
  }
  #expect(await executor.runInvoked)
}

@Test
func copilotAdapterConfirmPathDeniedWhenPresenterRefuses() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "copilotConfirmDeny"))
  let policyEngine = try await makeCopilotPolicyEngine(eventBus: bus)
  try await policyEngine.issueGrant(
    Grant(
      capability: .agentCopilotRun,
      confirmationRequirement: .always,
      issuer: .user,
      purpose: "test"
    ))
  let executor = FakeCopilotProcessExecutor(lines: [])
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    approvalPresenter: CopilotAlwaysDenyApprovalPresenter(),
    processExecutor: executor, eventBus: bus)

  let request = CopilotRunRequest(
    objective: "reply with pong", workingDirectory: copilotTaskAllowedWorkingDirectory,
    toolProfile: .workspaceWrite)
  let stream = await adapter.run(
    request: request, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drainCopilot(stream)

  #expect(
    events.contains {
      if case .approvalDecision(_, false, _) = $0 { return true } else { return false }
    })
  #expect(await executor.runInvoked == false)
}

// MARK: - Repository instructions safety gate

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

  guard case .repositoryInstructionsScanned(_, let secretsDetected, let blockedFiles) = events
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
    #"{"type":"result","exitCode":0,"usage":{"premiumRequests":1,"totalApiDurationMs":400,"sessionDurationMs":900,"codeChanges":{"linesAdded":5,"linesRemoved":1,"filesModified":["a.txt","b.txt","c.txt"]}}}"#
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
      if case .budgetExceeded(let kind, _, _) = $0 { return kind == "fileWrites" } else {
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
  await bus.subscribe(TaskCompletedEvent.self) { (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
  await bus.subscribe(TaskCompletedEvent.self) { (envelope: EventEnvelope<TaskCompletedEvent>) async in
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
