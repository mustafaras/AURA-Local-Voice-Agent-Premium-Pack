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
let allowedWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

// MARK: - Test doubles

/// Fake `AdapterProcessExecuting` that never spawns a real process. Yields
/// scripted lines (typically real fixture JSONL) and records cancellation.
actor FakeCodexProcessExecutor: AdapterProcessExecuting {
  let lines: [String]
  let completion: ProcessResult
  let gate: Gate?
  private(set) var runInvoked = false
  private(set) var cancelledExecutionIDs: [UUID] = []
  var cancelled = false

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
actor Gate {
  var continuation: CheckedContinuation<Void, Never>?
  var open = false
  private var heldWaiters: [CheckedContinuation<Void, Never>] = []

  func hold() async {
    let waiters = heldWaiters
    heldWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
    guard !open else { return }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      self.continuation = continuation
    }
  }

  func release() {
    open = true
    continuation?.resume()
    continuation = nil
  }

  /// Deterministic rendezvous for the cancel tests: resolves once a run is
  /// actually parked inside `hold()` (or the gate is already open), replacing
  /// the fixed 50 ms sleep. Bounded: falls through after 10 s so a wiring
  /// failure surfaces as a failed expectation, not a hung test.
  func waitUntilHeld(timeoutNanoseconds: UInt64 = 10_000_000_000) async {
    await withTaskGroup(of: Void?.self) { group in
      group.addTask {
        await self.suspendUntilHeld()
        return nil
      }
      group.addTask {
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        await self.releaseHeldWaiters()
        return nil
      }
      _ = await group.next()
      group.cancelAll()
    }
  }

  /// The parked check and the waiter registration run in one synchronous,
  /// actor-isolated section, so no `release()` can land between them and
  /// strand a waiter.
  private func suspendUntilHeld() async {
    if open || continuation != nil { return }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      heldWaiters.append(continuation)
    }
  }

  private func releaseHeldWaiters() {
    let waiters = heldWaiters
    heldWaiters = []
    for waiter in waiters {
      waiter.resume()
    }
  }
}

actor Capture {
  private struct Waiter {
    let id: UUID
    let matches: @Sendable (any EventPayload) -> Bool
    let continuation: CheckedContinuation<(any EventPayload)?, Never>
  }

  private var payloads: [any EventPayload] = []
  private var waiters: [Waiter] = []

  func append(_ payload: any EventPayload) {
    if let index = waiters.firstIndex(where: { $0.matches(payload) }) {
      waiters.remove(at: index).continuation.resume(returning: payload)
    } else {
      payloads.append(payload)
    }
  }

  /// Returns the first matching payload, waiting event-driven instead of
  /// polling: `append` resumes a registered waiter the moment a matching
  /// payload arrives. Bounded at 10 s so a missing event fails the test
  /// rather than hanging it. Replaces the old 0.5–1 s wall-clock poll loop,
  /// which flaked when the task engine finished just past the deadline.
  func waitForEvent<E: EventPayload>(
    _ type: E.Type,
    timeoutNanoseconds: UInt64 = 10_000_000_000
  ) async -> E? {
    let waiterID = UUID()
    let received = await nextPayload(
      id: waiterID, timeoutNanoseconds: timeoutNanoseconds, matches: { $0 is E })
    return received as? E
  }

  private func nextPayload(
    id: UUID,
    timeoutNanoseconds: UInt64,
    matches: @escaping @Sendable (any EventPayload) -> Bool
  ) async -> (any EventPayload)? {
    await withTaskGroup(of: (any EventPayload)?.self) { group in
      group.addTask { await self.receive(id: id, matches: matches) }
      group.addTask {
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        await self.cancelWaiter(id: id)
        return nil
      }
      let received = (await group.next()) ?? nil
      group.cancelAll()
      return received
    }
  }

  /// The stored-payload scan and the waiter registration run in one
  /// synchronous, actor-isolated section, so no `append` can land between
  /// them and strand a waiter.
  private func receive(
    id: UUID,
    matches: @escaping @Sendable (any EventPayload) -> Bool
  ) async -> (any EventPayload)? {
    if let found = payloads.first(where: matches) {
      return found
    }
    return await withCheckedContinuation { continuation in
      waiters.append(Waiter(id: id, matches: matches, continuation: continuation))
    }
  }

  private func cancelWaiter(id: UUID) {
    guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
    waiters.remove(at: index).continuation.resume(returning: nil)
  }
}

// MARK: - Fixtures

func loadFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

// MARK: - Policy engine helpers

func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

func makePolicyEngine(
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

func drain(
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
