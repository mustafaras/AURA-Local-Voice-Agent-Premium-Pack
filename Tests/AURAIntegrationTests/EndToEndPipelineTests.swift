@testable import AURA
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
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "e2e"))

  let policyEngine = try await makeTestPolicyEngine(
    eventBus: bus, grantConfirmationNoneFor: [.appActivate])
  let spy = ApplicationControllerSpy()
  let automation = makeAutomation(spy: spy, eventBus: bus)
  let shell = AuraShell(configuration: ShellConfiguration())
  let store = try await makeTestStore()
  let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
  let agentTaskRunner = makeAgentBackendTaskRunner(policyEngine: policyEngine, eventBus: bus)

  let toolRouter = ToolRouter(
    policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
    agentTaskRunner: agentTaskRunner, registry: .defaultRegistry(),
    confirmationPresenter: IntentAlwaysAllowConfirmationPresenter(), eventBus: bus,
    configuration: IntentEngineConfiguration())
  let intentEngine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(), configuration: IntentEngineConfiguration(),
    eventBus: bus)

  let conversation = Conversation(
    configuration: ConversationConfiguration(), ttsConfiguration: TTSConfiguration(),
    ttsEngine: MockTTSEngine(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "conversation"))

  let coordinator = IntentDispatchCoordinator(
    intentEngine: intentEngine, toolRouter: toolRouter, conversation: conversation,
    eventBus: bus, sessionID: UUID())
  let conversationBridge = ConversationEventBridge(conversation: conversation, eventBus: bus)

  // Subscribe-before-publish, matching AuraKernel's real ordering.
  await coordinator.start()
  await conversationBridge.start()

  let classifiedEvents = AtomicBox<[IntentClassifiedEvent]>([])
  await bus.subscribe(IntentClassifiedEvent.self) { envelope in
    await classifiedEvents.withValue { $0 + [envelope.payload] }
  }
  let responsePlans = AtomicBox<[ResponsePlanEvent]>([])
  await bus.subscribe(ResponsePlanEvent.self) { envelope in
    await responsePlans.withValue { $0 + [envelope.payload] }
  }

  let sttEngine = DeterministicMockSTTEngine(
    script: [
      DeterministicMockSTTEngine.MockSegment(text: "activate safari", expectedFrameCount: 3)
    ], partialBoundaryFrames: 1, stabilizationDelayFrames: 1)
  let sttPipeline = STTPipeline(
    engine: sttEngine, vocabulary: UserVocabulary(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt"))
  try await sttPipeline.start()

  // Real wake activation: STTPipeline self-subscribes to this event; the
  // bridge added by this phase (ConversationEventBridge) is what makes
  // Conversation itself react too.
  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))
  #expect(await conversation.state == .listening)

  // Drive the scripted mock engine to a stable segment via the same
  // `ingestSampleFrame` seam AudioSampleBridge uses in production.
  for index in 0..<10 {
    let frame = AudioFrame(
      samples: [0.0], timestamp: Double(index), sequenceIndex: UInt64(index),
      isDiscontinuity: false)
    await sttPipeline.ingestSampleFrame(frame)
    if await responsePlans.value.count > 0 { break }
    try await Task.sleep(nanoseconds: 20_000_000)
  }

  // --- Assertions, in causal order ---

  let classified = await classifiedEvents.value
  #expect(classified.count == 1)
  #expect(classified.first?.kind == IntentKind.appActivate.rawValue)
  #expect(classified.first?.isAmbiguous == false)

  #expect(spy.activatedBundleIdentifiers == ["com.apple.Safari"])

  let plans = await responsePlans.value
  #expect(plans.count == 1)
  #expect(plans.first?.hasSpokenResponse == true)

  // MockTTSEngine drains quickly; poll briefly rather than a fixed sleep.
  var attempts = 0
  var finalState = await conversation.state
  while finalState != .idle, attempts < 50 {
    try await Task.sleep(nanoseconds: 20_000_000)
    finalState = await conversation.state
    attempts += 1
  }
  #expect(finalState == .idle)
}

/// Proves the ambiguity guardrail survives the full chain, not just
/// `ToolRouter` in isolation: an utterance naming an unrecognized
/// application must never silently resolve to a guessed bundle
/// identifier, and `AuraAutomation` must never be called.
@Test
func endToEndPipelineNeverGuessesAnUnresolvedApplication() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "e2e-ambiguous"))
  let policyEngine = try await makeTestPolicyEngine(eventBus: bus)
  let spy = ApplicationControllerSpy()
  let automation = makeAutomation(spy: spy, eventBus: bus)
  let shell = AuraShell(configuration: ShellConfiguration())
  let store = try await makeTestStore()
  let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
  let agentTaskRunner = makeAgentBackendTaskRunner(policyEngine: policyEngine, eventBus: bus)

  let toolRouter = ToolRouter(
    policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
    agentTaskRunner: agentTaskRunner, registry: .defaultRegistry(),
    confirmationPresenter: IntentAlwaysAllowConfirmationPresenter(), eventBus: bus,
    configuration: IntentEngineConfiguration())
  let intentEngine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(), configuration: IntentEngineConfiguration(),
    eventBus: bus)
  let conversation = Conversation(
    configuration: ConversationConfiguration(), ttsConfiguration: TTSConfiguration(),
    ttsEngine: MockTTSEngine(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "conversation"))
  let coordinator = IntentDispatchCoordinator(
    intentEngine: intentEngine, toolRouter: toolRouter, conversation: conversation,
    eventBus: bus, sessionID: UUID())
  let conversationBridge = ConversationEventBridge(conversation: conversation, eventBus: bus)
  await coordinator.start()
  await conversationBridge.start()

  let responsePlans = AtomicBox<[ResponsePlanEvent]>([])
  await bus.subscribe(ResponsePlanEvent.self) { envelope in
    await responsePlans.withValue { $0 + [envelope.payload] }
  }

  let sttEngine = DeterministicMockSTTEngine(
    script: [
      DeterministicMockSTTEngine.MockSegment(
        text: "activate some totally unknown application", expectedFrameCount: 3)
    ], partialBoundaryFrames: 1, stabilizationDelayFrames: 1)
  let sttPipeline = STTPipeline(
    engine: sttEngine, vocabulary: UserVocabulary(), eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt"))
  try await sttPipeline.start()

  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio, sensitivity: .internalLevel,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))

  for index in 0..<10 {
    let frame = AudioFrame(
      samples: [0.0], timestamp: Double(index), sequenceIndex: UInt64(index),
      isDiscontinuity: false)
    await sttPipeline.ingestSampleFrame(frame)
    if await responsePlans.value.count > 0 { break }
    try await Task.sleep(nanoseconds: 20_000_000)
  }

  #expect(spy.activatedBundleIdentifiers.isEmpty)
  let plans = await responsePlans.value
  #expect(plans.count == 1)
  #expect(plans.first?.summary.lowercased().contains("which application") == true)
}
