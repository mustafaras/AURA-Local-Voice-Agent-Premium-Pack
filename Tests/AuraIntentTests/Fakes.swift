import AuraAgent
import AuraAutomation
import AuraCore
import AuraIntent
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation

// MARK: - ApplicationControlling fake (mirrors the automation test spy)

final class ApplicationControllerSpy: ApplicationControlling, @unchecked Sendable {
  nonisolated(unsafe) var activatedBundleIdentifiers: [String] = []
  nonisolated(unsafe) var quitBundleIdentifiers: [String] = []
  nonisolated(unsafe) var shouldFail = false

  func runningApplications() -> [NativeApplicationDescriptor] { [] }

  func launchApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: bundleIdentifier, processID: 1, isActive: true,
      isHidden: false)
  }

  func activateApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    if shouldFail { throw AuraError.automationError("activation failed") }
    activatedBundleIdentifiers.append(bundleIdentifier)
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: bundleIdentifier, processID: 1, isActive: true,
      isHidden: false)
  }

  func hideApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: bundleIdentifier, processID: 1, isActive: false,
      isHidden: true)
  }

  func quitApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    if shouldFail { throw AuraError.automationError("quit failed") }
    quitBundleIdentifiers.append(bundleIdentifier)
    return NativeApplicationDescriptor(
      bundleIdentifier: bundleIdentifier, name: bundleIdentifier, processID: 1, isActive: false,
      isHidden: true)
  }
}

final class AccessibilityObserverStub: AccessibilityObserving, @unchecked Sendable {
  func observeFirstElement(
    bundleIdentifier: String, role: String?, title: String?, timeout: TimeInterval
  ) async throws(AuraError) -> AccessibleElementObservation {
    throw AuraError.automationError("not used by ToolRouterTests")
  }
}

func makeAutomation(spy: ApplicationControllerSpy, eventBus: AuraEventBus) -> AuraAutomation {
  AuraAutomation(
    config: AutomationConfiguration(),
    applicationController: spy,
    accessibilityHealth: AccessibilityHealth(),
    accessibilityObserver: AccessibilityObserverStub(),
    eventBus: eventBus
  )
}

// MARK: - AuraStore / PolicyEngine helpers (mirrors Tests/AuraPluginsTests/Fakes.swift)

func makeTestStore() async throws -> AuraStore {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  let path = dir.appendingPathComponent("test.sqlite").path
  return try await AuraStore(path: path)
}

/// `allowByDefaultTiers` defaults to every tier; `grantConfirmationNoneFor`
/// additionally seeds `.none`-confirmation grants for the listed
/// capabilities, since `PolicyEngine`'s separate default-confirmation-tier
/// check would otherwise route a `.destructive`-tier capability to
/// `.confirm` even when its risk tier is allowed by default (there is no
/// tier above `.destructive` to raise `defaultConfirmationTier` past).
func makeTestPolicyEngine(
  store: AuraStore? = nil,
  eventBus: AuraEventBus,
  allowByDefaultTiers: Set<PermissionRiskTier> = [
    .observation, .reversible, .mutation, .destructive,
  ],
  grantConfirmationNoneFor: [Capability] = []
) async throws(AuraError) -> PolicyEngine {
  let config = PolicyConfiguration(
    allowByDefaultTiers: allowByDefaultTiers,
    denyByDefaultTiers: Set(PermissionRiskTier.allCases).subtracting(allowByDefaultTiers)
  )
  let engine = try await PolicyEngine(configuration: config, eventBus: eventBus, store: store)
  for capability in grantConfirmationNoneFor {
    try await engine.issueGrant(
      Grant(capability: capability, patterns: [.any], confirmationRequirement: .none))
  }
  return engine
}

// MARK: - Coding-agent backend fakes

/// Minimal `AdapterProcessExecuting` fake shared by Codex/Claude/Copilot in
/// these tests — none of them need to reach a real completed turn, since
/// `ToolRouter.handleCodingAgentRun` returns `.acknowledgedAsync` as soon as
/// `AuraTaskEngine.enqueue` succeeds, before the enqueued task actually runs.
actor FakeAdapterProcessExecutor: AdapterProcessExecuting {
  private(set) var runInvoked = false

  func run(
    command: Command, actor: ActorID, sessionID: UUID, executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    runInvoked = true
    return AsyncThrowingStream { continuation in
      continuation.yield(
        .completed(
          ProcessResult(
            executionID: executionID, exitCode: 0, stdout: "", stderr: "", durationSeconds: 0.001,
            wasCancelled: false, wasTimedOut: false, stdoutTruncated: false,
            stderrTruncated: false)))
      continuation.finish()
    }
  }

  func cancel(executionID: UUID) async {}
}

private let agentWorkingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"

/// Builds a real `AgentBackendTaskRunner` wired to real `CodexAdapter`/
/// `ClaudeAdapter`/`CopilotAdapter` instances, each backed by a
/// `FakeAdapterProcessExecutor` so no real CLI process is ever spawned.
func makeAgentBackendTaskRunner(policyEngine: PolicyEngine, eventBus: AuraEventBus) -> (
  runner: AgentBackendTaskRunner, sessionID: UUID
) {
  let sessionID = UUID()
  let codexAdapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: FakeAdapterProcessExecutor(), eventBus: eventBus)
  let claudeAdapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: FakeAdapterProcessExecutor(), eventBus: eventBus)
  let copilotAdapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: FakeAdapterProcessExecutor(), eventBus: eventBus)

  let runner = AgentBackendTaskRunner(
    codex: CodexTaskRunner(
      adapter: codexAdapter, sessionID: sessionID, defaultWorkingDirectory: agentWorkingDirectory),
    claude: ClaudeTaskRunner(
      adapter: claudeAdapter, sessionID: sessionID,
      defaultWorkingDirectory: agentWorkingDirectory),
    copilot: CopilotTaskRunner(
      adapter: copilotAdapter, sessionID: sessionID,
      defaultWorkingDirectory: agentWorkingDirectory)
  )
  return (runner, sessionID)
}
