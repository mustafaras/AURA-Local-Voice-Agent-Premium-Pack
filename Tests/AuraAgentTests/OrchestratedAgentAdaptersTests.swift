import AuraAgent
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import Foundation
import Testing

/// Verifies each `OrchestratedAgentRunning` wrapper correctly reduces its
/// backend's already-verified normalized events (real captured fixtures
/// where available) to `OrchestrationAgentEvent` — no new backend behavior
/// is introduced by these wrappers, only remapping.

private let orchestratedAgentAllowedWorkingDirectory =
  ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

// MARK: - Shared fake executor

private actor FakeOrchestratedProcessExecutor: AdapterProcessExecuting {
  private let lines: [String]
  private let completion: ProcessResult
  private(set) var runInvoked = false
  private(set) var cancelledExecutionIDs: [UUID] = []

  init(lines: [String], completion: ProcessResult? = nil) {
    self.lines = lines
    self.completion =
      completion
      ?? ProcessResult(
        executionID: UUID(), exitCode: 0, stdout: "", stderr: "", durationSeconds: 0.01,
        wasCancelled: false, wasTimedOut: false, stdoutTruncated: false, stderrTruncated: false)
  }

  func run(
    command: Command, actor: ActorID, sessionID: UUID, executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    runInvoked = true
    let lines = self.lines
    let completion = self.completion
    return AsyncThrowingStream { continuation in
      Task {
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
    cancelledExecutionIDs.append(executionID)
  }
}

private func loadFixtureLines(_ name: String) throws -> [String] {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  let contents = try String(contentsOf: url, encoding: .utf8)
  return contents.split(separator: "\n").map(String.init)
}

private func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeAllowingPolicyEngine(eventBus: AuraEventBus) async throws -> PolicyEngine {
  let store = try await makeTempStore()
  return try await PolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .destructive,
      allowByDefaultTiers: [.observation, .reversible, .mutation],
      denyByDefaultTiers: [.destructive]
    ),
    eventBus: eventBus, store: store)
}

private func drain(
  _ stream: AsyncThrowingStream<OrchestrationAgentEvent, Error>
) async throws -> [OrchestrationAgentEvent] {
  var events: [OrchestrationAgentEvent] = []
  for try await event in stream {
    events.append(event)
  }
  return events
}

// MARK: - Codex

@Test
func codexOrchestratedAgentMapsRealSuccessFixtureToTextAndCompletion() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchCodex"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let executor = FakeOrchestratedProcessExecutor(
    lines: try loadFixtureLines("codex_smoke_success.jsonl"))
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine, processExecutor: executor,
    eventBus: bus)
  let orchestrated = CodexOrchestratedAgent(adapter: adapter)

  let stream = await orchestrated.run(
    objective: "reply ping", workingDirectory: orchestratedAgentAllowedWorkingDirectory,
    writable: false, actor: .agentCodex, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(events.contains(.text(role: "agent_message", content: "ping")))
  #expect(events.contains(.turnCompleted))
  #expect(events.allSatisfy {
    if case .approvalDenied = $0 { return false }
    if case .turnFailed = $0 { return false }
    return true
  })
}

@Test
func codexOrchestratedAgentMapsDenialToApprovalDenied() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchCodexDeny"))
  let policyEngine = try await PolicyEngine(
    configuration: PolicyConfiguration(
      defaultConfirmationTier: .destructive,
      allowByDefaultTiers: [.observation, .reversible],
      denyByDefaultTiers: [.mutation, .destructive]
    ),
    eventBus: bus, store: try await makeTempStore())
  let executor = FakeOrchestratedProcessExecutor(lines: [])
  let adapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine, processExecutor: executor,
    eventBus: bus)
  let orchestrated = CodexOrchestratedAgent(adapter: adapter)

  // writable: true -> .agentCodexRun (.destructive), denied by this policy.
  let stream = await orchestrated.run(
    objective: "do it", workingDirectory: orchestratedAgentAllowedWorkingDirectory, writable: true,
    actor: .agentCodex, sessionID: UUID(), correlationID: UUID(), causationID: UUID())
  let events = try await drain(stream)

  #expect(events.count == 1)
  guard case .approvalDenied = events[0] else {
    Issue.record("expected approvalDenied, got \(events[0])")
    return
  }
  #expect(await executor.runInvoked == false)
}

// MARK: - Claude

@Test
func claudeOrchestratedAgentMapsRealSuccessFixtureToTextAndCompletion() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchClaude"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let executor = FakeOrchestratedProcessExecutor(
    lines: try loadFixtureLines("claude_smoke_success.jsonl"))
  let adapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine, processExecutor: executor,
    eventBus: bus)
  let orchestrated = ClaudeOrchestratedAgent(adapter: adapter)

  let stream = await orchestrated.run(
    objective: "reply ping", workingDirectory: orchestratedAgentAllowedWorkingDirectory,
    writable: false, actor: .agentClaude, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(events.contains(.text(role: "assistant", content: "ping")))
  #expect(events.contains(.turnCompleted))
}

// MARK: - Copilot

@Test
func copilotOrchestratedAgentMapsQuotaErrorFixtureToTurnFailed() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchCopilot"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let executor = FakeOrchestratedProcessExecutor(
    lines: try loadFixtureLines("copilot_smoke_quota_error.jsonl"))
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine, processExecutor: executor,
    eventBus: bus)
  let orchestrated = CopilotOrchestratedAgent(adapter: adapter)

  let stream = await orchestrated.run(
    objective: "reply ping", workingDirectory: orchestratedAgentAllowedWorkingDirectory,
    writable: false, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(events.contains { if case .turnFailed = $0 { return true } else { return false } })
}

@Test
func copilotOrchestratedAgentMapsConfirmedUserMessageShapeToText() async throws {
  // `user.message` (role always "user", echoing the submitted prompt) is the
  // one real, confirmed text-bearing shape for Copilot per ADR-013 — no
  // successful assistant-text event was ever captured. This line matches
  // that confirmed schema (`UserMessageEnvelope`/`UserMessageData` in
  // `CopilotEventNormalizer`), not a fabricated one.
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraAgentTests", category: "orchCopilotMessage"))
  let policyEngine = try await makeAllowingPolicyEngine(eventBus: bus)
  let userMessageLine =
    #"{"type":"user.message","id":"1","parentId":null,"timestamp":"2026-01-01T00:00:00Z","data":{"content":"reply ping"}}"#
  let executor = FakeOrchestratedProcessExecutor(lines: [userMessageLine])
  let adapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine, processExecutor: executor,
    eventBus: bus)
  let orchestrated = CopilotOrchestratedAgent(adapter: adapter)

  let stream = await orchestrated.run(
    objective: "reply ping", workingDirectory: orchestratedAgentAllowedWorkingDirectory,
    writable: false, actor: .agentCopilot, sessionID: UUID(), correlationID: UUID(),
    causationID: UUID())
  let events = try await drain(stream)

  #expect(events.contains(.text(role: "user", content: "reply ping")))
}
