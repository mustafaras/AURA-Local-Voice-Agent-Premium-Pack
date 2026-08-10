import AuraAudio
import AuraCore
import Foundation

/// Routes streaming recognition through an ordered set of local engines.
///
/// The router selects one engine per session, keeps the engine-lifetime result
/// stream intact across cancellations, and never forwards a failed adapter's
/// error text as if it were a user utterance. A fallback is selected only when
/// the preferred engine cannot start; quality-based switching remains explicit
/// rather than silently rewriting a transcript.
public final class STTRouter: STTEngine, @unchecked Sendable {
  public let engineID = "stt-router"
  public let locale: Locale

  private let candidates: [any STTEngine]
  private let governor: VoiceResourceGovernor?
  private let reservationMB: UInt64
  private let lock = NSLock()
  private let stream: AsyncStream<STTTranscriptResult>
  private let continuation: AsyncStream<STTTranscriptResult>.Continuation

  private var selected: (any STTEngine)?
  private var forwardTask: Task<Void, Never>?
  private var healthValue = STTHealth(
    ready: false,
    status: "idle",
    detail: "STT router has not started",
    engineID: "stt-router")
  private var started = false
  private var resourceReserved = false

  public init(
    candidates: [any STTEngine],
    governor: VoiceResourceGovernor? = nil,
    reservationMB: UInt64 = 768
  ) {
    precondition(!candidates.isEmpty, "STT router requires at least one engine")
    self.candidates = candidates
    self.locale = candidates[0].locale
    self.governor = governor
    self.reservationMB = max(1, reservationMB)
    let (stream, continuation) = AsyncStream<STTTranscriptResult>.makeStream()
    self.stream = stream
    self.continuation = continuation
  }

  deinit {
    forwardTask?.cancel()
    continuation.finish()
  }

  public var results: AsyncStream<STTTranscriptResult> { stream }

  public func start() async throws -> STTHealth {
    if let current = lock.withLock({ selected }) {
      if lock.withLock({ healthValue.ready }) {
        return healthValueSnapshot()
      }
      do {
        let health = try await current.start()
        if health.ready {
          select(current, health: health)
          return healthValueSnapshot()
        }
        lock.withLock { selected = nil }
      } catch {
        lock.withLock { selected = nil }
      }
    }

    if let governor, !lock.withLock({ resourceReserved }) {
      let decision = await governor.reserve(
        .stt, estimatedMemoryMB: reservationMB, priority: .speech)
      guard decision.granted else {
        let health = STTHealth(
          ready: false,
          status: "resource-denied",
          detail: decision.reason,
          engineID: engineID,
          locale: locale.identifier,
          supportsOffline: true)
        lock.withLock { healthValue = health }
        throw AuraError.sttEngineError(decision.reason)
      }
      lock.withLock { resourceReserved = true }
    }

    var failures: [String] = []
    for candidate in candidates {
      do {
        let health = try await candidate.start()
        guard health.ready else {
          failures.append(candidate.engineID + ": " + health.detail)
          continue
        }
        select(candidate, health: health)
        return healthValueSnapshot()
      } catch {
        failures.append(candidate.engineID + ": " + error.localizedDescription)
      }
    }

    if let governor, lock.withLock({ resourceReserved }) {
      await governor.release(.stt, estimatedMemoryMB: reservationMB)
      lock.withLock { resourceReserved = false }
    }
    let detail =
      failures.isEmpty
      ? "No local STT engine reported ready"
      : failures.joined(separator: " | ")
    let health = STTHealth(
      ready: false,
      status: "unavailable",
      detail: detail,
      engineID: engineID,
      locale: locale.identifier,
      supportsOffline: true)
    lock.withLock { healthValue = health }
    throw AuraError.sttEngineError(detail)
  }

  public func ingest(_ frame: AudioFrame, activationTime: TimeInterval) async {
    let engine = lock.withLock { selected }
    await engine?.ingest(frame, activationTime: activationTime)
  }

  public func finalizeSession() async {
    let engine = lock.withLock { selected }
    await engine?.finalizeSession()
  }

  public func cancel() async {
    let engine = lock.withLock { selected }
    await engine?.cancel()
    if let governor, lock.withLock({ resourceReserved }) {
      await governor.release(.stt, estimatedMemoryMB: reservationMB)
      lock.withLock { resourceReserved = false }
    }
    lock.withLock {
      healthValue = STTHealth(
        ready: false,
        status: "cancelled",
        detail: "STT router session cancelled; engine stream remains reusable",
        engineID: engineID,
        locale: locale.identifier,
        supportsOffline: true)
    }
  }

  public func health() -> STTHealth {
    lock.withLock { healthValue }
  }

  private func select(_ engine: any STTEngine, health: STTHealth) {
    let generation = UUID()
    lock.withLock {
      selected = engine
      started = true
      healthValue = STTHealth(
        ready: true,
        status: "ready",
        detail: "Selected local engine \(engine.engineID): \(health.detail)",
        engineID: engine.engineID,
        locale: engine.locale.identifier,
        supportsOffline: health.supportsOffline)
      forwardTask?.cancel()
      let source = engine.results
      forwardTask = Task { [weak self] in
        for await result in source {
          guard !Task.isCancelled else { return }
          self?.forward(result, engineID: engine.engineID, generation: generation)
        }
      }
    }
  }

  private func forward(
    _ result: STTTranscriptResult,
    engineID: String,
    generation: UUID
  ) {
    lock.withLock {
      guard started, selected?.engineID == engineID else { return }
      var metadata = result.metadata
      metadata["routerEngineID"] = self.engineID
      metadata["selectedEngineID"] = engineID
      metadata["routerGeneration"] = generation.uuidString
      continuation.yield(
        STTTranscriptResult(
          resultID: result.resultID,
          isStable: result.isStable,
          text: result.text,
          alternatives: result.alternatives,
          confidence: result.confidence,
          audioStartTime: result.audioStartTime,
          audioEndTime: result.audioEndTime,
          metadata: metadata))
    }
  }

  private func healthValueSnapshot() -> STTHealth {
    lock.withLock { healthValue }
  }
}
