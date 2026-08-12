import AuraAgent
import AuraAudio
import AuraCore
import Foundation
import Testing

extension ConversationTests {
  @Test("queued prompts are spoken in order")
  func queuedPromptsSpokenInOrder() async throws {
    let fixture = await makeConversation()
    let conversation = fixture.conversation
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "hello", confidence: 0.9)
    )
    await conversation.responsePlanReceived(
      ResponsePlanEvent(planID: "plan-1", summary: "First", hasSpokenResponse: true)
    )

    // Wait until the first prompt is actively speaking, then append a second.
    var attempts = 0
    while await conversation.state != .speaking, attempts < 50 {
      try? await Task.sleep(nanoseconds: 10_000_000)
      attempts += 1
    }

    await conversation.responsePlanReceived(
      ResponsePlanEvent(planID: "plan-2", summary: "Second", hasSpokenResponse: true)
    )

    try? await Task.sleep(nanoseconds: 300_000_000)

    let started = box.events.compactMap { $0 as? TTSStartedEvent }
    #expect(started.count == 2)
    #expect(started[0].text == "First")
    #expect(started[1].text == "Second")
  }

  // MARK: - TTS chunk passthrough

  @Test("TTS chunks are emitted for spoken response")
  func ttsChunksEmitted() async throws {
    let fixture = await makeConversation()
    let conversation = fixture.conversation
    let box = fixture.box

    await conversation.wakeActivationStarted(privacyMode: false)
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "hello", confidence: 0.9)
    )
    await conversation.responsePlanReceived(
      ResponsePlanEvent(planID: "plan-1", summary: "Hello world", hasSpokenResponse: true)
    )

    try? await Task.sleep(nanoseconds: 200_000_000)

    let chunks = box.events.compactMap { $0 as? TTSChunkEvent }
    #expect(chunks.count >= 2)
    #expect(
      chunks.contains { chunk in
        if case .complete = chunk.chunk { return true }
        return false
      })
  }

  // MARK: - Latency measurement

  @Test("wake-to-ack latency is measured and labeled mock engine")
  func wakeToAckLatencyMeasured() async throws {
    let clockBox = EventBoxClock(initial: 0.0)
    let clock: @Sendable () -> TimeInterval = { clockBox.current }

    let logger = AuraLogger(
      subsystem: "ai.aura.tests", category: "ConversationLatencyTests", minimumLevel: .debug)
    let eventBus = AuraEventBus(logger: logger)
    let box = EventBox()
    await eventBus.subscribe(LatencyMeasuredEvent.self) { envelope in
      box.append(envelope.payload)
    }

    let conversation = Conversation(
      configuration: ConversationConfiguration(),
      ttsConfiguration: TTSConfiguration(),
      ttsEngine: MockTTSEngine(engineID: "mock-tts"),
      eventBus: eventBus,
      logger: logger,
      monotonicClock: clock)

    clockBox.current = 0.0
    await conversation.wakeActivationStarted(privacyMode: false)
    clockBox.current = 0.100
    await conversation.stableSegmentReceived(STTStableSegmentEvent(text: "hello", confidence: 0.9))
    clockBox.current = 0.200
    await conversation.responsePlanReceived(
      ResponsePlanEvent(
        planID: "plan-1", summary: "Hello", hasSpokenResponse: true, isSimpleCommand: true))

    try? await Task.sleep(nanoseconds: 200_000_000)

    let latencies = box.events.compactMap { $0 as? LatencyMeasuredEvent }
    #expect(latencies.count == 2)
    let wakeToAck = latencies.first { $0.kind == .wakeToAck }
    let completion = latencies.first { $0.kind == .simpleCommandCompletion }
    #expect(wakeToAck != nil)
    #expect(wakeToAck?.latencySeconds == 0.200)
    #expect(completion != nil)
    #expect(completion?.isMockEngine == true)
    #expect(completion?.budgetSeconds == 1.5)
    #expect((completion?.latencySeconds ?? 0) >= 0)
  }

  @Test("simple-command completion latency is measured after TTS")
  func simpleCommandCompletionLatencyMeasured() async throws {
    let clockBox = EventBoxClock(initial: 0.0)
    let clock: @Sendable () -> TimeInterval = { clockBox.current }

    let logger = AuraLogger(
      subsystem: "ai.aura.tests", category: "ConversationLatencyTests", minimumLevel: .debug)
    let eventBus = AuraEventBus(logger: logger)
    let box = EventBox()
    await eventBus.subscribe(LatencyMeasuredEvent.self) { envelope in
      box.append(envelope.payload)
    }

    let conversation = Conversation(
      configuration: ConversationConfiguration(
        deterministicStopCommands: ["stop"],
        deterministicPauseResumeCommands: []),
      ttsConfiguration: TTSConfiguration(),
      ttsEngine: MockTTSEngine(engineID: "mock-tts"),
      eventBus: eventBus,
      logger: logger,
      monotonicClock: clock)

    clockBox.current = 0.0
    await conversation.wakeActivationStarted(privacyMode: false)
    clockBox.current = 0.100
    await conversation.stableSegmentReceived(
      STTStableSegmentEvent(text: "what time is it", confidence: 0.9, deterministicCommand: nil))
    clockBox.current = 0.200
    await conversation.responsePlanReceived(
      ResponsePlanEvent(
        planID: "plan-1", summary: "The time", hasSpokenResponse: true, isSimpleCommand: true))

    try? await Task.sleep(nanoseconds: 200_000_000)

    let latencies = box.events.compactMap { $0 as? LatencyMeasuredEvent }
    let wakeToAck = latencies.first { $0.kind == .wakeToAck }
    let completion = latencies.first { $0.kind == .simpleCommandCompletion }
    #expect(wakeToAck != nil)
    #expect(wakeToAck?.latencySeconds == 0.200)
    #expect(completion != nil)
    #expect(completion?.isMockEngine == true)
    #expect(completion?.budgetSeconds == 1.5)
    #expect((completion?.latencySeconds ?? 0) >= 0)
  }

  @Test("non-simple response plan does not emit simple-command completion")
  func nonSimpleResponsePlanOmitsCompletionLatency() async throws {
    let clockBox = EventBoxClock(initial: 0.0)
    let clock: @Sendable () -> TimeInterval = { clockBox.current }

    let logger = AuraLogger(
      subsystem: "ai.aura.tests", category: "ConversationLatencyTests", minimumLevel: .debug)
    let eventBus = AuraEventBus(logger: logger)
    let box = EventBox()
    await eventBus.subscribe(LatencyMeasuredEvent.self) { envelope in
      box.append(envelope.payload)
    }

    let conversation = Conversation(
      configuration: ConversationConfiguration(),
      ttsConfiguration: TTSConfiguration(),
      ttsEngine: MockTTSEngine(engineID: "mock-tts"),
      eventBus: eventBus,
      logger: logger,
      monotonicClock: clock)

    clockBox.current = 0.0
    await conversation.wakeActivationStarted(privacyMode: false)
    clockBox.current = 0.100
    await conversation.stableSegmentReceived(STTStableSegmentEvent(text: "hello", confidence: 0.9))
    clockBox.current = 0.200
    await conversation.responsePlanReceived(
      ResponsePlanEvent(
        planID: "plan-1", summary: "Hello", hasSpokenResponse: true, isSimpleCommand: false))

    try? await Task.sleep(nanoseconds: 200_000_000)

    let latencies = box.events.compactMap { $0 as? LatencyMeasuredEvent }
    let completion = latencies.first { $0.kind == .simpleCommandCompletion }
    #expect(completion == nil)
  }
}
