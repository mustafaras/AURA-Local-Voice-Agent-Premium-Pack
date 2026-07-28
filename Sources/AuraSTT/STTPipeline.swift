import AuraAudio
import AuraCore
import Foundation

/// Coordinates wake activations, audio frames, and an `STTEngine` to produce
/// stable transcript segments. Intent execution is gated on stable text unless
/// the transcript matches a deterministic early-command rule.
public actor STTPipeline {
  public enum State: String, Sendable, Equatable, CaseIterable {
    case idle
    case activated
    case transcribing
    case finalizing
  }

  public struct Metrics: Sendable, Equatable {
    public var partialsEmitted: UInt64 = 0
    public var stableSegmentsEmitted: UInt64 = 0
    public var cancellations: UInt64 = 0
    public var deterministicEarlyCommands: UInt64 = 0
    public var firstPartialLatencySeconds: TimeInterval = 0
    public var lastStableLatencySeconds: TimeInterval = 0

    public init() {}
  }

  private let engine: any STTEngine
  private let vocabulary: UserVocabulary
  private let eventBus: AuraEventBus
  private let logger: AuraLogger
  private let monotonicClock: () -> TimeInterval

  private var state: State = .idle
  private var activationTime: TimeInterval = 0
  private var resultStreamTask: Task<Void, Never>?
  private var metrics: Metrics = Metrics()

  public init(
    engine: any STTEngine,
    vocabulary: UserVocabulary,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }
  ) {
    self.engine = engine
    self.vocabulary = vocabulary
    self.eventBus = eventBus
    self.logger = logger
    self.monotonicClock = monotonicClock
  }

  deinit {
    resultStreamTask?.cancel()
  }

  /// Start listening for wake activations and audio frames.
  public func start() async throws {
    guard state == .idle else { return }
    let health = try await engine.start()
    await logger.info("STT engine \(engine.engineID) started: \(health.status)", actor: .audio)
    await subscribeToEvents()
    state = .activated
  }

  /// Stop the pipeline, cancelling any active transcription.
  public func stop() async {
    resultStreamTask?.cancel()
    resultStreamTask = nil
    await engine.cancel()
    state = .idle
    await logger.info("STT pipeline stopped", actor: .audio)
  }

  /// Current state.
  public func currentState() -> State {
    state
  }

  /// Metrics snapshot.
  public func currentMetrics() -> Metrics {
    metrics
  }

  private func subscribeToEvents() async {
    await eventBus.subscribe(WakeActivationEvent.self) { [weak self] envelope in
      guard let self = self, !Task.isCancelled else { return }
      await self.handleWakeActivation(envelope.payload)
    }
    await eventBus.subscribe(AudioFrameEvent.self) { [weak self] envelope in
      guard let self = self, !Task.isCancelled else { return }
      await self.handleAudioFrame(envelope.payload)
    }
  }

  private func handleWakeActivation(_ event: WakeActivationEvent) async {
    if event.isActive {
      guard state == .activated || state == .idle else { return }
      activationTime = monotonicClock()
      state = .transcribing
      metrics.firstPartialLatencySeconds = 0
      await logger.info("STT session started", actor: .audio)
      startConsumingResults()
    } else {
      guard state == .transcribing else { return }
      state = .finalizing
      await engine.finalizeSession()
    }
  }

  private func handleAudioFrame(_ event: AudioFrameEvent) async {
    guard state == .transcribing else { return }
    // Forward only metadata; the engine will receive real sample data from
    // the realtime path via `ingestSampleFrame(_:)` in a later phase. For
    // now, create a placeholder frame so the engine can drive progress from
    // frame indices and timestamps.
    let frame = AudioFrame(
      samples: [],
      timestamp: event.timestamp,
      sequenceIndex: event.sequenceIndex,
      isDiscontinuity: event.isDiscontinuity
    )
    await engine.ingest(frame, activationTime: activationTime)
  }

  /// Ingest a frame with real sample data from the realtime audio path. Tests
  /// seed this directly; the audio service calls it in production.
  public func ingestSampleFrame(_ frame: AudioFrame) async {
    guard state == .transcribing else { return }
    await engine.ingest(frame, activationTime: activationTime)
  }

  private func startConsumingResults() {
    resultStreamTask?.cancel()
    let engineRef = engine
    resultStreamTask = Task { [weak self] in
      guard let self = self else { return }
      for await result in engineRef.results {
        guard !Task.isCancelled else { return }
        await self.handleResult(result)
      }
    }
  }

  private func handleResult(_ result: STTTranscriptResult) async {
    if result.isStable {
      metrics.stableSegmentsEmitted += 1
      metrics.lastStableLatencySeconds = monotonicClock() - activationTime
      await emitStableSegmentEvent(result)
    } else {
      metrics.partialsEmitted += 1
      if metrics.firstPartialLatencySeconds == 0 {
        metrics.firstPartialLatencySeconds = monotonicClock() - activationTime
      }
      await emitPartialEvent(result)
      if let command = vocabulary.matchDeterministicCommand(result.text) {
        metrics.deterministicEarlyCommands += 1
        await logger.info("Deterministic early command matched: \(command)", actor: .audio)
        await emitStableSegmentEvent(result)
      }
    }
  }

  private func emitPartialEvent(_ result: STTTranscriptResult) async {
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: result.resultID,
      actor: .audio,
      sensitivity: .internalLevel,
      payload: STTPartialEvent(text: result.text, confidence: result.confidence)
    )
    await eventBus.emit(envelope)
  }

  private func emitStableSegmentEvent(_ result: STTTranscriptResult) async {
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: result.resultID,
      actor: .audio,
      sensitivity: .internalLevel,
      payload: STTStableSegmentEvent(
        text: result.text,
        alternatives: result.alternatives,
        confidence: result.confidence,
        deterministicCommand: vocabulary.matchDeterministicCommand(result.text)
      )
    )
    await eventBus.emit(envelope)
  }

  /// Cancel the current transcription session immediately.
  public func cancel() async {
    metrics.cancellations += 1
    state = .activated
    resultStreamTask?.cancel()
    resultStreamTask = nil
    await engine.cancel()
    await emitCancelledEvent()
    await logger.info("STT session cancelled", actor: .audio)
  }

  private func emitCancelledEvent() async {
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: UUID(),
      actor: .audio,
      sensitivity: .internalLevel,
      payload: STTCancelledEvent()
    )
    await eventBus.emit(envelope)
  }
}
