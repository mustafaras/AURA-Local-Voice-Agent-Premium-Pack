import AuraAgent
import AuraAudio
import AuraCore
import AuraSTT
import Foundation
import Testing

@testable import AURA

private actor PushToTalkEventRecorder {
  private(set) var inactiveActivations = 0
  private(set) var stableTexts: [String] = []
  private(set) var healthErrors: [String] = []

  func record(_ event: WakeActivationEvent) {
    if !event.isActive {
      inactiveActivations += 1
    }
  }

  func record(_ event: STTStableSegmentEvent) {
    stableTexts.append(event.text)
  }

  func record(_ event: STTHealthEvent) {
    if !event.ready {
      healthErrors.append(event.detail)
    }
  }
}

private final class ReusableTurnSTTEngine: STTEngine, @unchecked Sendable {
  let engineID = "reusable-turn-test"
  let locale = Locale(identifier: "tr-TR")
  let results: AsyncStream<STTTranscriptResult>

  private let continuation: AsyncStream<STTTranscriptResult>.Continuation
  private let lock = NSLock()
  private var completedTurns = 0
  private let emitError: Bool

  init(emitError: Bool = false) {
    self.emitError = emitError
    (results, continuation) = AsyncStream.makeStream()
  }

  func start() async throws -> STTHealth {
    STTHealth(ready: true, status: "ready", detail: "test engine")
  }

  func ingest(_ frame: AudioFrame, activationTime: TimeInterval) async {}

  func finalizeSession() async {
    let turn = lock.withLock {
      completedTurns += 1
      return completedTurns
    }
    continuation.yield(
      STTTranscriptResult(
        resultID: UUID(),
        isStable: true,
        text: emitError ? "No speech detected" : "turn \(turn)",
        confidence: emitError ? 0 : 0.95,
        audioStartTime: 0,
        audioEndTime: 1,
        metadata: emitError ? ["error": "true"] : [:]))
  }

  func cancel() async {}

  func health() -> STTHealth {
    STTHealth(ready: true, status: "ready", detail: "test engine")
  }
}

@Test("Push to Talk ends exactly once after observed speech and configured silence")
func pushToTalkEndsAfterSpeechAndSilence() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "ptt-finalizer"))
  let recorder = PushToTalkEventRecorder()
  await bus.subscribe(WakeActivationEvent.self) { envelope in
    await recorder.record(envelope.payload)
  }
  let finalizer = PushToTalkSessionFinalizer(
    vad: EnergyVAD(silenceFrames: 2), eventBus: bus, maxDurationSeconds: 1)
  await finalizer.start()

  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))
  await finalizer.ingest(
    AudioFrame(samples: [0.8, -0.8], timestamp: 1, sequenceIndex: 1))
  await finalizer.ingest(
    AudioFrame(samples: [0, 0], timestamp: 2, sequenceIndex: 2))
  await finalizer.ingest(
    AudioFrame(samples: [0, 0], timestamp: 3, sequenceIndex: 3))

  #expect(await recorder.inactiveActivations == 1)
  await finalizer.ingest(
    AudioFrame(samples: [0, 0], timestamp: 4, sequenceIndex: 4))
  try await Task.sleep(for: .milliseconds(50))
  #expect(await recorder.inactiveActivations == 1)
}

@Test("Push to Talk hard deadline closes a session even when no speech is observed")
func pushToTalkHardDeadlineEndsSilentSession() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "ptt-deadline"))
  let recorder = PushToTalkEventRecorder()
  await bus.subscribe(WakeActivationEvent.self) { envelope in
    await recorder.record(envelope.payload)
  }
  let finalizer = PushToTalkSessionFinalizer(
    vad: EnergyVAD(silenceFrames: 2), eventBus: bus, maxDurationSeconds: 0.05)
  await finalizer.start()

  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))
  try await Task.sleep(for: .milliseconds(150))

  #expect(await recorder.inactiveActivations == 1)
}

@Test("STT pipeline emits stable segments for two consecutive finalized turns")
func sttPipelineSupportsConsecutiveTurns() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt-repeat"))
  let recorder = PushToTalkEventRecorder()
  await bus.subscribe(STTStableSegmentEvent.self) { envelope in
    await recorder.record(envelope.payload)
  }
  let pipeline = STTPipeline(
    engine: ReusableTurnSTTEngine(),
    vocabulary: UserVocabulary(),
    eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt"))
  try await pipeline.start()

  for turn in 1...2 {
    await bus.emit(
      EventEnvelope(
        correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: true, privacyMode: false)))
    await pipeline.ingestSampleFrame(
      AudioFrame(samples: [0.5], timestamp: Double(turn), sequenceIndex: UInt64(turn)))
    await bus.emit(
      EventEnvelope(
        correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
        payload: WakeActivationEvent(isActive: false, privacyMode: false)))

    var attempts = 0
    while await recorder.stableTexts.count < turn, attempts < 50 {
      try await Task.sleep(for: .milliseconds(10))
      attempts += 1
    }
  }

  #expect(await recorder.stableTexts == ["turn 1", "turn 2"])
}

@Test("STT errors are health events and never stable user intent")
func sttErrorsDoNotBecomeStableUserText() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt-error"))
  let recorder = PushToTalkEventRecorder()
  await bus.subscribe(STTStableSegmentEvent.self) { envelope in
    await recorder.record(envelope.payload)
  }
  await bus.subscribe(STTHealthEvent.self) { envelope in
    await recorder.record(envelope.payload)
  }
  let pipeline = STTPipeline(
    engine: ReusableTurnSTTEngine(emitError: true),
    vocabulary: UserVocabulary(),
    eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt"))
  try await pipeline.start()

  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))
  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: false, privacyMode: false)))

  var attempts = 0
  while await recorder.healthErrors.isEmpty, attempts < 50 {
    try await Task.sleep(for: .milliseconds(10))
    attempts += 1
  }

  #expect(await recorder.healthErrors == ["No speech detected"])
  #expect(await recorder.stableTexts.isEmpty)
}

@Test("STT health failures end listening with the concrete error")
func sttHealthFailureEndsConversationListening() async throws {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "stt-error-bridge"))
  let conversation = Conversation(
    configuration: ConversationConfiguration(listenTimeoutSeconds: 1),
    ttsConfiguration: TTSConfiguration(),
    ttsEngine: MockTTSEngine(),
    eventBus: bus,
    logger: AuraLogger(subsystem: "AURAIntegrationTests", category: "conversation"))
  let bridge = ConversationEventBridge(conversation: conversation, eventBus: bus)
  await bridge.start()

  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .user, sensitivity: .sensitive,
      payload: WakeActivationEvent(isActive: true, privacyMode: false)))
  #expect(await conversation.state == .listening)

  await bus.emit(
    EventEnvelope(
      correlationID: UUID(), causationID: UUID(), actor: .audio,
      sensitivity: .internalLevel,
      payload: STTHealthEvent(ready: false, status: "error", detail: "No speech detected")))

  #expect(await conversation.state == .error)
}
