import AuraAgent
import AuraAutomation
import AuraCore
import AuraIntent
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation

// MARK: - ApplicationControlling fake (mirrors Tests/AuraIntentTests/Fakes.swift)

final class ApplicationControllerSpy: ApplicationControlling, @unchecked Sendable {
  nonisolated(unsafe) var activatedBundleIdentifiers: [String] = []
  nonisolated(unsafe) var quitBundleIdentifiers: [String] = []

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
    throw AuraError.automationError("not used by EndToEndPipelineTests")
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

// MARK: - AuraStore helper

func makeTestStore() async throws -> AuraStore {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  let path = dir.appendingPathComponent("test.sqlite").path
  return try await AuraStore(path: path)
}

// MARK: - PolicyEngine helper

func makeTestPolicyEngine(
  eventBus: AuraEventBus,
  allowByDefaultTiers: Set<PermissionRiskTier> = [.observation, .reversible, .mutation, .destructive],
  grantConfirmationNoneFor: [Capability] = []
) async throws(AuraError) -> PolicyEngine {
  let config = PolicyConfiguration(
    allowByDefaultTiers: allowByDefaultTiers,
    denyByDefaultTiers: Set(PermissionRiskTier.allCases).subtracting(allowByDefaultTiers)
  )
  let engine = try await PolicyEngine(configuration: config, eventBus: eventBus, store: nil)
  for capability in grantConfirmationNoneFor {
    try await engine.issueGrant(
      Grant(capability: capability, patterns: [.any], confirmationRequirement: .none))
  }
  return engine
}

// MARK: - Minimal, unexercised coding-agent backend (ToolRouter requires one)

actor NoOpAdapterProcessExecutor: AdapterProcessExecuting {
  func run(
    command: Command, actor: ActorID, sessionID: UUID, executionID: UUID
  ) async -> AsyncThrowingStream<ProcessStreamEvent, Error> {
    AsyncThrowingStream { continuation in
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

func makeAgentBackendTaskRunner(policyEngine: PolicyEngine, eventBus: AuraEventBus)
  -> AgentBackendTaskRunner
{
  let sessionID = UUID()
  let codexAdapter = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: NoOpAdapterProcessExecutor(), eventBus: eventBus)
  let claudeAdapter = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: NoOpAdapterProcessExecutor(), eventBus: eventBus)
  let copilotAdapter = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: NoOpAdapterProcessExecutor(), eventBus: eventBus)
  return AgentBackendTaskRunner(
    codex: CodexTaskRunner(
      adapter: codexAdapter, sessionID: sessionID, defaultWorkingDirectory: agentWorkingDirectory),
    claude: ClaudeTaskRunner(
      adapter: claudeAdapter, sessionID: sessionID,
      defaultWorkingDirectory: agentWorkingDirectory),
    copilot: CopilotTaskRunner(
      adapter: copilotAdapter, sessionID: sessionID,
      defaultWorkingDirectory: agentWorkingDirectory)
  )
}
