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

  func hold() async {
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
}

actor Capture {
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
