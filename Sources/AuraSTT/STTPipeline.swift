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
    /// Elapsed wall-clock time from activation to the first stable segment
    /// (R7 turn-end latency). 0 until a stable segment is emitted.
    public var turnEndLatencySeconds: TimeInterval = 0

    public init() {}
  }

  private let engine: any STTEngine
  private let vocabulary: UserVocabulary
  private let eventBus: AuraEventBus
  private let logger: AuraLogger
  private let monotonicClock: () -> TimeInterval
  private let sessionID: UUID

  private var state: State = .idle
  private var activeTurnContext: TurnContext?
  private var activationTime: TimeInterval = 0
  private var resultStreamTask: Task<Void, Never>?
  private var metrics: Metrics = Metrics()
  private var consumedResultIDs: Set<UUID> = []

  public init(
    engine: any STTEngine,
    vocabulary: UserVocabulary,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() },
    sessionID: UUID = UUID()
  ) {
    self.engine = engine
    self.vocabulary = vocabulary
    self.eventBus = eventBus
    self.logger = logger
    self.monotonicClock = monotonicClock
    self.sessionID = sessionID
  }

  deinit {
    resultStreamTask?.cancel()
  }

  /// Start listening for wake activations and engine results.
  public func start() async throws {
    guard state == .idle else { return }
    let health = try await engine.start()
    await logger.info("STT engine \(engine.engineID) started: \(health.status)", actor: .audio)
    await subscribeToEvents()
    startConsumingResults()
    state = .activated
  }

  /// Stop the pipeline, cancelling any active transcription.
  public func stop() async {
    resultStreamTask?.cancel()
    resultStreamTask = nil
    await engine.cancel()
    activeTurnContext = nil
    consumedResultIDs.removeAll(keepingCapacity: true)
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
      await self.handleWakeActivation(envelope)
    }
  }

  private func handleWakeActivation(_ envelope: EventEnvelope<WakeActivationEvent>) async {
    let event = envelope.payload
    if event.isActive {
      guard state == .activated || state == .idle else { return }
      activationTime = monotonicClock()
      let context =
        (event.turnContext
        ?? TurnContext(
          sessionID: sessionID,
          correlationID: envelope.correlationID,
          causationID: envelope.id,
          activationSource: .wakeWord,
          actor: envelope.actor,
          authority: .userUtterance,
          sensitivity: envelope.sensitivity,
          timingOrigin: activationTime
        )).advancing(causationID: envelope.id)
      activeTurnContext = context.withBackendIDs(
        TurnBackendIDs(
          stt: engine.engineID,
          tts: context.backendIDs.tts,
          model: context.backendIDs.model,
          tool: context.backendIDs.tool))
      state = .transcribing
      metrics.firstPartialLatencySeconds = 0
      metrics.turnEndLatencySeconds = 0
      await logger.info("STT session started", actor: .audio)
    } else {
      guard state == .transcribing else { return }
      state = .finalizing
      await engine.finalizeSession()
    }
  }

  /// Ingest a frame with real sample data from the realtime audio path.
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
    guard consumedResultIDs.insert(result.resultID).inserted else {
      await logger.debug("Duplicate STT result dropped: \(result.resultID)", actor: .audio)
      return
    }
    if result.metadata["error"] == "true" {
      state = .activated
      let context = activeTurnContext?.advancing(causationID: result.resultID)
      if let context {
        activeTurnContext = context
      }
      await eventBus.emit(
        envelope(
          payload: STTHealthEvent(
            ready: false, status: "error", detail: result.text, turnContext: context),
          context: context,
          causationID: result.resultID))
      return
    }

    if result.isStable {
      guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        state = .activated
        return
      }
      metrics.stableSegmentsEmitted += 1
      metrics.lastStableLatencySeconds = monotonicClock() - activationTime
      metrics.turnEndLatencySeconds = metrics.lastStableLatencySeconds
      state = .activated
      await emitStableSegmentEvent(result)
    } else {
      metrics.partialsEmitted += 1
      if metrics.firstPartialLatencySeconds == 0 {
        metrics.firstPartialLatencySeconds = monotonicClock() - activationTime
        // The value was already measured here; until now it was only kept in
        // `metrics` and never left the pipeline, so the R12 `stt_partial` SLO
        // had no readable source. Emitting it lets `PerformanceSampler`
        // aggregate real percentiles from a live session.
        await emitFirstPartialLatency(metrics.firstPartialLatencySeconds)
      }
      await emitPartialEvent(result)
      if let command = vocabulary.matchDeterministicCommand(result.text) {
        metrics.deterministicEarlyCommands += 1
        await logger.info("Deterministic early command matched: \(command)", actor: .audio)
        await emitStableSegmentEvent(result)
      }
    }
  }

  /// Publish the activation-to-first-partial latency as the `stt_partial` SLO
  /// sample. The 1.0 s budget is a reporting reference only — the SLO contract
  /// asserts no target, and none is claimed here.
  private func emitFirstPartialLatency(_ seconds: TimeInterval) async {
    await eventBus.emit(
      envelope(
        payload: LatencyMeasuredEvent(
          kind: .sttFirstPartial,
          latencySeconds: seconds,
          budgetSeconds: 1.0,
          turnContext: activeTurnContext),
        context: activeTurnContext,
        causationID: sessionID)
    )
  }

  private func emitPartialEvent(_ result: STTTranscriptResult) async {
    let context = activeTurnContext?.advancing(causationID: result.resultID)
    if let context {
      activeTurnContext = context
    }
    await eventBus.emit(
      envelope(
        payload: STTPartialEvent(
          text: result.text, confidence: result.confidence, turnContext: context),
        context: context,
        causationID: result.resultID)
    )
  }

  private func emitStableSegmentEvent(_ result: STTTranscriptResult) async {
    let context = activeTurnContext?.advancing(causationID: result.resultID)
    if let context {
      activeTurnContext = context
    }
    await eventBus.emit(
      envelope(
        payload: STTStableSegmentEvent(
          text: result.text,
          alternatives: result.alternatives,
          confidence: result.confidence,
          deterministicCommand: vocabulary.matchDeterministicCommand(result.text),
          turnContext: context),
        context: context,
        causationID: result.resultID)
    )
  }

  /// Cancel the current transcription session immediately.
  public func cancel() async {
    metrics.cancellations += 1
    state = .activated
    // The result stream belongs to the engine lifetime. Cancelling the
    // consumer task here would make later Push-to-Talk sessions permanently
    // deaf after one cancellation.
    await engine.cancel()
    await emitCancelledEvent()
    await logger.info("STT session cancelled", actor: .audio)
  }

  private func emitCancelledEvent() async {
    let causationID = activeTurnContext?.causationID ?? sessionID
    let context = activeTurnContext?.advancing(causationID: causationID)
    await eventBus.emit(
      envelope(
        payload: STTCancelledEvent(turnContext: context),
        context: context,
        causationID: causationID)
    )
    activeTurnContext = nil
  }

  private func envelope<Payload: EventPayload>(
    payload: Payload,
    context: TurnContext?,
    causationID: UUID
  ) -> EventEnvelope<Payload> {
    context?.envelope(actor: .audio, sensitivity: .internalLevel, payload: payload)
      ?? EventEnvelope(
        correlationID: sessionID,
        causationID: causationID,
        actor: .audio,
        sensitivity: .internalLevel,
        payload: payload)
  }
}
