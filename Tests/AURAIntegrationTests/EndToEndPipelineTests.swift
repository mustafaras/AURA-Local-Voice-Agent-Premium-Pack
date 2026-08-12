import AuraAgent
import AuraAudio
import AuraCore
import AuraIntent
import AuraPolicy
import AuraSTT
import AuraShell
import AuraTasks
import Foundation
import Testing

@testable import AURA

/// The headline proof for this integration phase: wake → STT → intent
/// classification → policy-gated tool dispatch → response → TTS, exercised
/// as one real chain of real actors (`Conversation`, `STTPipeline`,
/// `IntentEngine`, `ToolRouter`, `AuraAutomation`, `PolicyEngine`,
/// `IntentDispatchCoordinator`, `ConversationEventBridge`) — the first test
/// in this project's history to do so. Only the acoustic/CLI legs are
/// faked: `DeterministicMockSTTEngine` (no real speech recognition exists
/// yet) and a fake `ApplicationControlling` (mirrors `AuraAutomationTests`'
/// own precedent, avoiding a dependency on a real installed application).
@Test
func endToEndPipelineActivatesApplicationFromScriptedUtterance() async throws {
  let fixture = try await makeEndToEndFixture(utterance: "activate safari")
  await fixture.activate()
  #expect(await fixture.conversation.state == .listening)
  try await fixture.driveUtterance()

  // --- Assertions, in causal order ---

  let classified = await fixture.classifiedEvents.value
  #expect(classified.count == 1)
  #expect(classified.first?.kind == IntentKind.appActivate.rawValue)
  #expect(classified.first?.isAmbiguous == false)

  #expect(fixture.spy.activatedBundleIdentifiers == ["com.apple.Safari"])

  let plans = await fixture.responsePlans.value
  #expect(plans.count == 1)
  #expect(plans.first?.hasSpokenResponse == true)
  let trace = await fixture.traceCorrelations.value
  #expect(trace.count >= 5)
  #expect(Set(trace).count == 1)
  #expect(plans.first?.turnContext?.turnID != nil)

  // MockTTSEngine drains quickly; poll briefly rather than a fixed sleep.
  var attempts = 0
  var finalState = await fixture.conversation.state
  while finalState != .idle, attempts < 50 {
    try await Task.sleep(nanoseconds: 20_000_000)
    finalState = await fixture.conversation.state
    attempts += 1
  }
  #expect(finalState == .idle)

  // Release-readiness latency assertion: mock-engine wake-to-ack must remain
  // under 500 ms (ADR-023 budget). The deterministic clock lets the test prove
  // the instrumentation, not a real acoustic pipeline.
  let latencies = await fixture.latencyMeasurements.value
  let wakeToAck = latencies.first { $0.kind == .wakeToAck }
  #expect(wakeToAck != nil)
  #expect(wakeToAck!.latencySeconds < 0.5)
  #expect(wakeToAck!.budgetSeconds == 0.5)
  #expect(wakeToAck!.isMockEngine == true)
  #expect(wakeToAck!.backendIDs?.tts?.hasPrefix("mock") == true)
}

/// Proves the ambiguity guardrail survives the full chain, not just
/// `ToolRouter` in isolation: an utterance naming an unrecognized
/// application must never silently resolve to a guessed bundle
/// identifier, and `AuraAutomation` must never be called.
@Test
func endToEndPipelineNeverGuessesAnUnresolvedApplication() async throws {
  let fixture = try await makeEndToEndFixture(
    utterance: "activate some totally unknown application",
    grantConfirmationNoneFor: [])
  await fixture.activate()
  try await fixture.driveUtterance()

  #expect(fixture.spy.activatedBundleIdentifiers.isEmpty)
  let plans = await fixture.responsePlans.value
  #expect(plans.count == 1)
  #expect(plans.first?.summary.lowercased().contains("which application") == true)
}

/// Proves the deterministic mock-engine pipeline can keep a simple command
/// completion under the ADR-023 budget (1.5 s), using the same injected
/// monotonic clock and mock TTS engine that the wake-to-ack test uses.
@Test
func endToEndPipelineCompletesSimpleCommandUnderBudget() async throws {
  let fixture = try await makeEndToEndFixture(utterance: "activate safari")
  await fixture.activate()
  try await fixture.driveUtterance()

  #expect(fixture.spy.activatedBundleIdentifiers == ["com.apple.Safari"])

  // MockTTSEngine drains quickly; poll briefly rather than a fixed sleep.
  var attempts = 0
  var finalState = await fixture.conversation.state
  while finalState != .idle, attempts < 50 {
    try await Task.sleep(nanoseconds: 20_000_000)
    finalState = await fixture.conversation.state
    attempts += 1
  }
  #expect(finalState == .idle)

  let latencies = await fixture.latencyMeasurements.value
  let wakeToAck = latencies.first { $0.kind == .wakeToAck }
  let simpleCompletion = latencies.first { $0.kind == .simpleCommandCompletion }
  #expect(wakeToAck != nil)
  #expect(wakeToAck!.latencySeconds < 0.5)
  #expect(simpleCompletion != nil)
  #expect(simpleCompletion!.latencySeconds < 1.5)
  #expect(simpleCompletion!.budgetSeconds == 1.5)
  #expect(simpleCompletion!.isMockEngine == true)
}

private struct EndToEndRuntime {
  let bus: AuraEventBus
  let spy: ApplicationControllerSpy
  let toolRouter: ToolRouter
  let intentEngine: IntentEngine
}

private struct EndToEndEventBoxes {
  let classifiedEvents: AtomicBox<[IntentClassifiedEvent]>
  let traceCorrelations: AtomicBox<[UUID]>
  let responsePlans: AtomicBox<[ResponsePlanEvent]>
  let latencyMeasurements: AtomicBox<[LatencyMeasuredEvent]>
}

private struct EndToEndFixture {
  let bus: AuraEventBus
  let spy: ApplicationControllerSpy
  let clockBox: MutableClock
  let conversation: Conversation
  let coordinator: IntentDispatchCoordinator
  let conversationBridge: ConversationEventBridge
  let sttPipeline: STTPipeline
  let classifiedEvents: AtomicBox<[IntentClassifiedEvent]>
  let traceCorrelations: AtomicBox<[UUID]>
  let responsePlans: AtomicBox<[ResponsePlanEvent]>
  let latencyMeasurements: AtomicBox<[LatencyMeasuredEvent]>

  func activate() async {
    clockBox.current = 0.0
    await bus.emit(
      EventEnvelope(
        correlationID: UUID(), causationID: UUID(), actor: .audio,
        sensitivity: .internalLevel,
        payload: WakeActivationEvent(isActive: true, privacyMode: false)))
  }

  func driveUtterance() async throws {
    clockBox.current = 0.100
    for index in 0..<10 {
      let frame = AudioFrame(
        samples: [0.0], timestamp: Double(index), sequenceIndex: UInt64(index),
        isDiscontinuity: false)
      await sttPipeline.ingestSampleFrame(frame)
      if await responsePlans.value.count > 0 { break }
      try await Task.sleep(nanoseconds: 20_000_000)
    }
  }
}

private func makeEndToEndRuntime(
  grantConfirmationNoneFor: [Capability]
) async throws -> EndToEndRuntime {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "e2e"))
  let policyEngine = try await makeTestPolicyEngine(
    eventBus: bus, grantConfirmationNoneFor: grantConfirmationNoneFor)
  let spy = ApplicationControllerSpy()
  let automation = makeAutomation(spy: spy, eventBus: bus)
  let shell = AuraShell(configuration: ShellConfiguration())
  let store = try await makeTestStore()
  let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
  let agentTaskRunner = makeAgentBackendTaskRunner(policyEngine: policyEngine, eventBus: bus)
  let capabilityRegistry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: capabilityRegistry)
  let toolRouter = ToolRouter(
    policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
    agentTaskRunner: agentTaskRunner, capabilityRegistry: capabilityRegistry,
    confirmationPresenter: IntentAlwaysAllowConfirmationPresenter(), eventBus: bus,
    configuration: IntentEngineConfiguration())
  let intentEngine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(), configuration: IntentEngineConfiguration(),
    eventBus: bus)
  return EndToEndRuntime(bus: bus, spy: spy, toolRouter: toolRouter, intentEngine: intentEngine)
}

private func subscribeEndToEndEvents(_ bus: AuraEventBus) async -> EndToEndEventBoxes {
  let classifiedEvents = AtomicBox<[IntentClassifiedEvent]>([])
  let traceCorrelations = AtomicBox<[UUID]>([])
  await bus.subscribe(IntentClassifiedEvent.self) { envelope in
    await classifiedEvents.withValue { $0 + [envelope.payload] }
    await traceCorrelations.withValue { $0 + [envelope.correlationID] }
  }
  await bus.subscribe(IntentPlanGeneratedEvent.self) { envelope in
    await traceCorrelations.withValue { $0 + [envelope.correlationID] }
  }
  await bus.subscribe(ToolInvokedEvent.self) { envelope in
    await traceCorrelations.withValue { $0 + [envelope.correlationID] }
  }
  await bus.subscribe(ToolResultEvent.self) { envelope in
    await traceCorrelations.withValue { $0 + [envelope.correlationID] }
  }
  let responsePlans = AtomicBox<[ResponsePlanEvent]>([])
  await bus.subscribe(ResponsePlanEvent.self) { envelope in
    await responsePlans.withValue { $0 + [envelope.payload] }
    await traceCorrelations.withValue { $0 + [envelope.correlationID] }
  }
  let latencyMeasurements = AtomicBox<[LatencyMeasuredEvent]>([])
  await bus.subscribe(LatencyMeasuredEvent.self) { envelope in
    await latencyMeasurements.withValue { $0 + [envelope.payload] }
  }
  return EndToEndEventBoxes(
    classifiedEvents: classifiedEvents, traceCorrelations: traceCorrelations,
    responsePlans: responsePlans, latencyMeasurements: latencyMeasurements)
}

private func makeEndToEndFixture(
  utterance: String,
  grantConfirmationNoneFor: [Capability] = [.appActivate]
) async throws -> EndToEndFixture {
  let runtime = try await makeEndToEndRuntime(
    grantConfirmationNoneFor: grantConfirmationNoneFor)
  let clockBox = MutableClock(initial: 0.0)
  let clock: @Sendable () -> TimeInterval = { clockBox.current }
  let conversation = Conversation(
    configuration: ConversationConfiguration(), ttsConfiguration: TTSConfiguration(),
    ttsEngine: MockTTSEngine(), eventBus: runtime.bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "conversation"),
    monotonicClock: clock)
  let coordinator = IntentDispatchCoordinator(
    intentEngine: runtime.intentEngine, toolRouter: runtime.toolRouter,
    conversation: conversation, eventBus: runtime.bus, sessionID: UUID())
  let conversationBridge = ConversationEventBridge(
    conversation: conversation, eventBus: runtime.bus)
  await coordinator.start()
  await conversationBridge.start()
  let boxes = await subscribeEndToEndEvents(runtime.bus)
  let sttEngine = DeterministicMockSTTEngine(
    script: [DeterministicMockSTTEngine.MockSegment(text: utterance, expectedFrameCount: 3)],
    partialBoundaryFrames: 1, stabilizationDelayFrames: 1)
  let sttPipeline = STTPipeline(
    engine: sttEngine, vocabulary: UserVocabulary(), eventBus: runtime.bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt"))
  try await sttPipeline.start()
  return EndToEndFixture(
    bus: runtime.bus, spy: runtime.spy, clockBox: clockBox, conversation: conversation,
    coordinator: coordinator, conversationBridge: conversationBridge,
    sttPipeline: sttPipeline, classifiedEvents: boxes.classifiedEvents,
    traceCorrelations: boxes.traceCorrelations, responsePlans: boxes.responsePlans,
    latencyMeasurements: boxes.latencyMeasurements)
}

/// Thread-safe mutable clock source suitable for a `@Sendable` monotonic
/// clock closure in Swift 6 strict concurrency tests. The type is used only
/// inside a single test actor, so `NSLock` plus `@unchecked Sendable` is
/// acceptable here.
private final class MutableClock: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: TimeInterval

  init(initial: TimeInterval) {
    self.storage = initial
  }

  var current: TimeInterval {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storage
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      storage = newValue
    }
  }
}
