import AuraAgent
import AuraAudio
import AuraCore
import Foundation
import Testing

/// Collects envelopes from the event bus in a thread-safe way for test
/// inspection. The box is `@unchecked Sendable` because it is protected by
/// `NSLock`, matching the pattern used in `AuraSTTEngineTests`.
final class EventBox: @unchecked Sendable {
  let lock = NSLock()
  var payloads: [any EventPayload] = []

  func append(_ payload: any EventPayload) {
    lock.lock()
    defer { lock.unlock() }
    payloads.append(payload)
  }

  var events: [any EventPayload] {
    lock.lock()
    defer { lock.unlock() }
    return payloads
  }

  func clear() {
    lock.lock()
    defer { lock.unlock() }
    payloads.removeAll()
  }
}

@Suite("Conversation State Machine", .serialized)
struct ConversationTests {

  struct ConversationFixture {
    let conversation: Conversation
    let eventBus: AuraEventBus
    let logger: AuraLogger
    let engine: MockTTSEngine
    let box: EventBox
  }

  /// Creates a conversation wired to an event box that captures all
  /// conversation and TTS payloads used by the tests.
  func makeConversation(
    conversationConfig: ConversationConfiguration = ConversationConfiguration(),
    ttsConfig: TTSConfiguration = TTSConfiguration(),
    engine: MockTTSEngine? = nil
  ) async -> ConversationFixture {
    let logger = AuraLogger(
      subsystem: "ai.aura.tests", category: "ConversationTests", minimumLevel: .debug)
    let eventBus = AuraEventBus(logger: logger)
    let box = EventBox()

    await eventBus.subscribe(ConversationStateEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(TurnCompletedEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(TTSStartedEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(TTSStoppedEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(TTSChunkEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(BargeInEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(ConversationTimeoutEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(ResponsePlanEvent.self) { envelope in
      box.append(envelope.payload)
    }
    await eventBus.subscribe(LatencyMeasuredEvent.self) { envelope in
      box.append(envelope.payload)
    }

    let ttsEngine = engine ?? MockTTSEngine(engineID: "mock-tts")
    let conversation = Conversation(
      configuration: conversationConfig,
      ttsConfiguration: ttsConfig,
      ttsEngine: ttsEngine,
      eventBus: eventBus,
      logger: logger
    )
    return ConversationFixture(
      conversation: conversation, eventBus: eventBus, logger: logger, engine: ttsEngine, box: box)
  }

  func stateEvents(_ box: EventBox) -> [ConversationStateEvent] {
    box.events.compactMap { $0 as? ConversationStateEvent }
  }

  // MARK: - Idle to listening and timeout

  @Test("wake activation moves idle to listening")
  func wakeActivationMovesToListening() async throws {
    let fixture = await makeConversation()
    let conversation = fixture.conversation
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    try? await Task.sleep(nanoseconds: 30_000_000)

    #expect(await conversation.state == .listening)
    let states = stateEvents(box)
    #expect(states.contains { $0.state == .listening })
  }

  @Test("stable STT segment completes turn and moves to thinking")
  func stableSegmentCompletesTurn() async throws {
    let fixture = await makeConversation()
    let conversation = fixture.conversation
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "run the test suite", confidence: 0.9)
    )
    try? await Task.sleep(nanoseconds: 30_000_000)

    #expect(await conversation.state == .thinking)
    let turns = box.events.compactMap { $0 as? TurnCompletedEvent }
    #expect(turns.count == 1)
    #expect(turns.first?.text == "run the test suite")
    #expect(turns.first?.requiresPolicyReview == true)
  }

  @Test("incomplete stable segment gets a bounded continuation window")
  func incompleteStableSegmentWaitsBriefly() async throws {
    let config = ConversationConfiguration(continuationWindowSeconds: 0.01)
    let fixture = await makeConversation(conversationConfig: config)
    let conversation = fixture.conversation
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "run the tests and", confidence: 0.9)
    )
    #expect(await conversation.state == .listening)
    #expect(box.events.compactMap { $0 as? TurnCompletedEvent }.isEmpty)

    try? await Task.sleep(for: .milliseconds(40))
    #expect(await conversation.state == .thinking)
    #expect(box.events.compactMap { $0 as? TurnCompletedEvent }.count == 1)
  }

  @Test("deterministic stop command stops assistant")
  func deterministicStopCommand() async throws {
    let config = ConversationConfiguration(
      deterministicStopCommands: ["stop"],
      deterministicPauseResumeCommands: []
    )
    let fixture = await makeConversation(conversationConfig: config)
    let conversation = fixture.conversation
    let engine = fixture.engine

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "stop", confidence: 0.95, deterministicCommand: "stop")
    )

    #expect(await conversation.state == .idle)
    #expect(engine.currentPromptForTest() == nil)
  }

  // MARK: - Spoken response and TTS

  @Test("response plan with summary starts TTS")
  func responsePlanStartsTTS() async throws {
    let fixture = await makeConversation()
    let conversation = fixture.conversation
    let engine = fixture.engine
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "hello", confidence: 0.9)
    )
    await conversation.responsePlanReceived(
      ResponsePlanEvent(planID: "plan-1", summary: "Hello there", hasSpokenResponse: true)
    )

    // Wait for the mock TTS to finish yielding fragments.
    try? await Task.sleep(nanoseconds: 200_000_000)

    #expect(await conversation.state == .idle)
    #expect(engine.currentPromptForTest() == nil)
    let started = box.events.compactMap { $0 as? TTSStartedEvent }
    let stopped = box.events.compactMap { $0 as? TTSStoppedEvent }
    #expect(started.count == 1)
    #expect(started.first?.text == "Hello there")
    #expect(stopped.count == 1)
    #expect(stopped.first?.reason == .completed)
  }

  @Test("response plan without spoken response returns to idle")
  func responsePlanWithoutSpeechReturnsIdle() async throws {
    let conversation = (await makeConversation()).conversation

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "hello", confidence: 0.9)
    )
    await conversation.responsePlanReceived(
      ResponsePlanEvent(planID: "plan-1", summary: "", hasSpokenResponse: false)
    )

    #expect(await conversation.state == .idle)
  }

  // MARK: - Interruption and barge-in

  @Test("barge-in during speaking stops TTS and returns to listening")
  func bargeInDuringSpeaking() async throws {
    let ttsConfig = TTSConfiguration(enableBargeIn: true)
    let fixture = await makeConversation(ttsConfig: ttsConfig)
    let conversation = fixture.conversation
    let engine = fixture.engine
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "hello", confidence: 0.9)
    )
    await conversation.responsePlanReceived(
      ResponsePlanEvent(
        planID: "plan-1", summary: "This is a long response that takes several chunks",
        hasSpokenResponse: true)
    )

    // Wait until the state machine confirms it is speaking.
    var attempts = 0
    while await conversation.state != .speaking, attempts < 50 {
      try? await Task.sleep(nanoseconds: 10_000_000)
      attempts += 1
    }
    #expect(await conversation.state == .speaking)

    await conversation.bargeInDetected(reason: "user spoke over assistant")

    var settleAttempts = 0
    while await conversation.state != .listening, settleAttempts < 100 {
      try? await Task.sleep(nanoseconds: 10_000_000)
      settleAttempts += 1
    }

    #expect(await conversation.state == .listening)
    // Allow the detached event bus handlers to record the barge-in event.
    try? await Task.sleep(nanoseconds: 50_000_000)
    let barges = box.events.compactMap { $0 as? BargeInEvent }
    #expect(barges.count == 1)
    #expect(barges.first?.atState == .speaking)
    #expect(engine.currentPromptForTest() == nil)
  }

  @Test("barge-in grace window suppresses repeated interruptions")
  func bargeInGraceWindowSuppressesRepeatedInterruptions() async throws {
    let config = ConversationConfiguration(bargeInGraceMilliseconds: 1000)
    let ttsConfig = TTSConfiguration(enableBargeIn: true)
    let fixture = await makeConversation(conversationConfig: config, ttsConfig: ttsConfig)
    let conversation = fixture.conversation
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "hello", confidence: 0.9)
    )
    await conversation.responsePlanReceived(
      ResponsePlanEvent(planID: "plan-1", summary: "A response", hasSpokenResponse: true)
    )

    var attempts = 0
    while await conversation.state != .speaking, attempts < 50 {
      try? await Task.sleep(nanoseconds: 10_000_000)
      attempts += 1
    }

    await conversation.bargeInDetected(reason: "first")
    await conversation.bargeInDetected(reason: "second within grace")
    try? await Task.sleep(nanoseconds: 30_000_000)

    let barges = box.events.compactMap { $0 as? BargeInEvent }
    #expect(barges.count == 1)
  }

  // MARK: - Queueing and sequencing

}

/// A thread-safe mutable clock source for deterministic latency tests.
final class EventBoxClock: @unchecked Sendable {
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
