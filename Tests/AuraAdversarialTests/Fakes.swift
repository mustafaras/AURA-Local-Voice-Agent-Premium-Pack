import AuraAgent
import AuraAutomation
import AuraConfig
import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraPlugins
import AuraPolicy
import AuraSecurity
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

// MARK: - Event capture

actor EventBusCapture {
  private(set) var payloads: [any EventPayload] = []

  func capture(_ payload: any EventPayload) {
    payloads.append(payload)
  }

  func clear() {
    payloads.removeAll()
  }

  func last<T: EventPayload>(ofType: T.Type) -> T? {
    payloads.last { $0 is T } as? T
  }

  func all<T: EventPayload>(ofType: T.Type) -> [T] {
    payloads.compactMap { $0 as? T }
  }
}

// MARK: - Temporary stores

func makeTempDirectory() -> URL {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  do {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  } catch {
    preconditionFailure("test temporary directory creation failed: \(error)")
  }
  return dir
}

func makeTestStore() async throws -> AuraStore {
  let path = makeTempDirectory().appendingPathComponent("test.sqlite").path
  return try await AuraStore(path: path)
}

// MARK: - Policy engine fixture

func makeAdversarialPolicyEngine(
  store: AuraStore? = nil,
  allowByDefaultTiers: Set<PermissionRiskTier> = [.observation, .reversible, .mutation],
  grantConfirmationNoneFor: [Capability] = [],
  confirmationExpirySeconds: Double = 60,
  capture: EventBusCapture = EventBusCapture()
) async throws(AuraError) -> (PolicyEngine, EventBusCapture) {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAdversarialTests", category: "policy"))
  let config = PolicyConfiguration(
    defaultConfirmationTier: .mutation,
    confirmationExpirySeconds: confirmationExpirySeconds,
    allowByDefaultTiers: allowByDefaultTiers,
    denyByDefaultTiers: Set(PermissionRiskTier.allCases).subtracting(allowByDefaultTiers)
  )
  let engine = try await PolicyEngine(configuration: config, eventBus: bus, store: store)
  for capability in grantConfirmationNoneFor {
    try await engine.issueGrant(
      Grant(capability: capability, patterns: [.any], confirmationRequirement: .none))
  }
  return (engine, capture)
}

func policyRequest(
  capability: Capability,
  actor: ActorID = .user,
  target: PolicyTarget = .empty,
  arguments: [String] = [],
  environment: [String: String] = [:],
  sessionID: UUID = UUID()
) -> PolicyEvaluationRequest {
  PolicyEvaluationRequest(
    capability: capability,
    actor: actor,
    target: target,
    arguments: arguments,
    environment: environment,
    sessionID: sessionID,
    correlationID: UUID(),
    causationID: UUID()
  )
}

// MARK: - Tool router fixture

final class ApplicationControllerSpy: ApplicationControlling, @unchecked Sendable {
  nonisolated(unsafe) var activatedBundleIdentifiers: [String] = []
  nonisolated(unsafe) var quitBundleIdentifiers: [String] = []
  nonisolated(unsafe) var launchedBundleIdentifiers: [String] = []
  nonisolated(unsafe) var shouldFail = false

  func runningApplications() -> [NativeApplicationDescriptor] { [] }

  func launchApplication(bundleIdentifier: String, timeout: TimeInterval) async throws(AuraError)
    -> NativeApplicationDescriptor
  {
    launchedBundleIdentifiers.append(bundleIdentifier)
    return NativeApplicationDescriptor(
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

private final class AccessibilityObserverStub: AccessibilityObserving, @unchecked Sendable {
  func observeFirstElement(
    bundleIdentifier: String, role: String?, title: String?, timeout: TimeInterval
  ) async throws(AuraError) -> AccessibleElementObservation {
    throw AuraError.automationError("not used by adversarial tests")
  }
}

private func makeAutomation(
  spy: ApplicationControllerSpy,
  eventBus: AuraEventBus
) -> AuraAutomation {
  AuraAutomation(
    config: AutomationConfiguration(),
    applicationController: spy,
    accessibilityHealth: AccessibilityHealth(),
    accessibilityObserver: AccessibilityObserverStub(),
    eventBus: eventBus
  )
}

private actor FakeAdapterProcessExecutor: AdapterProcessExecuting {
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

private func makeAgentBackendTaskRunner(policyEngine: PolicyEngine, eventBus: AuraEventBus) -> (
  runner: AgentBackendTaskRunner, sessionID: UUID
) {
  let sessionID = UUID()
  let workingDirectory = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"
  let codex = CodexAdapter(
    configuration: CodexConfiguration(), policyEngine: policyEngine,
    processExecutor: FakeAdapterProcessExecutor(), eventBus: eventBus)
  let claude = ClaudeAdapter(
    configuration: ClaudeConfiguration(), policyEngine: policyEngine,
    processExecutor: FakeAdapterProcessExecutor(), eventBus: eventBus)
  let copilot = CopilotAdapter(
    configuration: CopilotConfiguration(), policyEngine: policyEngine,
    processExecutor: FakeAdapterProcessExecutor(), eventBus: eventBus)
  let runner = AgentBackendTaskRunner(
    codex: CodexTaskRunner(
      adapter: codex, sessionID: sessionID, defaultWorkingDirectory: workingDirectory),
    claude: ClaudeTaskRunner(
      adapter: claude, sessionID: sessionID, defaultWorkingDirectory: workingDirectory),
    copilot: CopilotTaskRunner(
      adapter: copilot, sessionID: sessionID, defaultWorkingDirectory: workingDirectory)
  )
  return (runner, sessionID)
}

struct RouterHarness {
  let router: ToolRouter
  let policyEngine: PolicyEngine
  let applicationSpy: ApplicationControllerSpy
  let sessionID: UUID
  let eventBus: AuraEventBus
}

func makeRouterHarness(
  allowByDefaultTiers: Set<PermissionRiskTier> = [
    .observation, .reversible, .mutation, .destructive,
  ],
  grantConfirmationNoneFor: [Capability] = [],
  confirmationPresenter: any IntentConfirmationPresenting = IntentAlwaysDenyConfirmationPresenter()
) async throws -> RouterHarness {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraAdversarialTests", category: "router"))
  let policyEngine = try await makeAdversarialPolicyEngine(
    allowByDefaultTiers: allowByDefaultTiers,
    grantConfirmationNoneFor: grantConfirmationNoneFor
  ).0
  let spy = ApplicationControllerSpy()
  let automation = makeAutomation(spy: spy, eventBus: bus)
  let shell = AuraShell(configuration: ShellConfiguration())
  let store = try await makeTestStore()
  let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
  let (agentRunner, sessionID) = makeAgentBackendTaskRunner(
    policyEngine: policyEngine, eventBus: bus)
  let capabilityRegistry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: capabilityRegistry)
  let router = ToolRouter(
    policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
    agentTaskRunner: agentRunner, capabilityRegistry: capabilityRegistry,
    confirmationPresenter: confirmationPresenter, eventBus: bus,
    configuration: IntentEngineConfiguration())
  return RouterHarness(
    router: router, policyEngine: policyEngine, applicationSpy: spy, sessionID: sessionID,
    eventBus: bus)
}

func makeAdversarialIntent(
  kind: IntentKind,
  category: IntentSemanticCategory,
  slots: [IntentSlot] = [],
  confidence: Double = 0.9,
  isAmbiguous: Bool = false
) -> TypedIntent {
  TypedIntent(
    turnCorrelationID: UUID(), kind: kind, semanticCategory: category, rawUtterance: "",
    normalizedUtterance: "", slots: slots, classificationConfidence: confidence,
    isAmbiguous: isAmbiguous)
}

// MARK: - Memory fixture

func makeMemoryEngine(store: AuraStore? = nil) async throws -> MemoryEngine {
  let actualStore: AuraStore
  if let store {
    actualStore = store
  } else {
    actualStore = try await makeTestStore()
  }
  return MemoryEngine(store: actualStore)
}

func makeMemoryDraft(
  statement: String,
  provenance: MemoryProvenance,
  confidence: Double = 0.9,
  sensitivity: SensitivityLevel = .internalLevel,
  evidenceReferences: [String] = []
) -> MemoryRecordDraft {
  MemoryRecordDraft(
    memoryClass: .userPreference,
    subject: "adversarial-test",
    statement: statement,
    evidenceReferences: evidenceReferences,
    provenance: provenance,
    confidence: confidence,
    sensitivity: sensitivity,
    observedAt: Date(),
    retention: .indefinite,
    scope: .global
  )
}

// MARK: - Configuration fixture

actor MemoryConfigurationStore: ConfigurationStateStoring {
  var stored: ConfigurationGovernanceState?

  func loadState() async throws(AuraError) -> ConfigurationGovernanceState? {
    stored
  }

  func saveState(_ state: ConfigurationGovernanceState) async throws(AuraError) {
    stored = state
  }
}

struct TestClock: @unchecked Sendable {
  var now: Date = Date(timeIntervalSince1970: 1_000_000)

  mutating func advance(by interval: TimeInterval) {
    now = now.addingTimeInterval(interval)
  }
}

func makeConfigurationEngine(
  store: MemoryConfigurationStore = MemoryConfigurationStore(),
  clock: TestClock = TestClock()
) async throws(AuraError) -> ConfigurationEngine {
  try await ConfigurationEngine.load(
    schema: .phase24,
    store: store,
    now: { clock.now }
  )
}
