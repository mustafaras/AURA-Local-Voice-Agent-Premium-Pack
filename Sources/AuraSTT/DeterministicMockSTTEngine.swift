import AuraAudio
import AuraCore
import Foundation

/// A deterministic, model-free STT engine used to validate the `STTEngine`
/// protocol and downstream consumers without requiring real Speech.framework
/// models or microphone access.
///
/// The mock matches a scripted sequence of expected frame indices to transcript
/// outputs. It emits partial results as the audio crosses a configurable partial
/// boundary, then promotes them to stable segments after a stabilization delay.
public final class DeterministicMockSTTEngine: STTEngine, @unchecked Sendable {
  private let stream: AsyncStream<STTTranscriptResult>
  private let unsafeContinuation: UnsafeContinuationBox
  public let engineID: String
  public let locale: Locale

  /// A recursive lock is used because `cancel()` may be invoked re-entrantly
  /// from the stream's `onTermination` handler while another locked operation
  /// (e.g. `finalizeSession`) is still on the stack.
  private let lock = NSRecursiveLock()

  private var stateValue: State = .idle
  private let script: [MockSegment]
  private let partialBoundaryFrames: UInt64
  private let stabilizationDelayFrames: UInt64
  private let confidence: Double
  private let clock: () -> TimeInterval

  private var activationTime: TimeInterval = 0
  private var totalFramesIngested: UInt64 = 0
  private var currentSegmentIndex: Int = 0
  private var currentSegmentFrames: UInt64 = 0
  private var pendingResult: STTTranscriptResult?

  public init(
    engineID: String = "mock-stt",
    locale: Locale = Locale(identifier: "tr-TR"),
    script: [MockSegment],
    partialBoundaryFrames: UInt64 = 3,
    stabilizationDelayFrames: UInt64 = 2,
    confidence: Double = 0.92,
    clock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }
  ) {
    self.engineID = engineID
    self.locale = locale
    self.script = script
    self.partialBoundaryFrames = partialBoundaryFrames
    self.stabilizationDelayFrames = stabilizationDelayFrames
    self.confidence = confidence
    self.clock = clock
    let (stream, continuation) = AsyncStream<STTTranscriptResult>.makeStream()
    self.stream = stream
    self.unsafeContinuation = UnsafeContinuationBox(continuation: continuation)
    continuation.onTermination = { [weak self] _ in
      self?.cancel()
    }
  }

  public var results: AsyncStream<STTTranscriptResult> { stream }

  private func withLock<T>(_ block: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try block()
  }

  public func start() async throws -> STTHealth {
    guard !script.isEmpty else {
      throw AuraError.invalidConfiguration("mock STT script must not be empty")
    }
    withLock { stateValue = .streaming }
    return STTHealth(
      ready: true,
      status: "ready",
      detail: "Mock engine initialized with \(script.count) segment(s)"
    )
  }

  public func ingest(_ frame: AudioFrame, activationTime: TimeInterval) {
    withLock {
      guard stateValue == .streaming else { return }
      if self.activationTime == 0 {
        self.activationTime = activationTime
      }
      totalFramesIngested += 1
      currentSegmentFrames += 1
      emitProgressIfNeeded()
    }
  }

  public func finalizeSession() {
    withLock {
      guard stateValue == .streaming else { return }
      emitStableForCurrentSegment(force: true)
      currentSegmentIndex += 1
      stateValue = .finalized
    }
  }

  public func cancel() {
    withLock {
      stateValue = .cancelled
    }
    unsafeContinuation.finish()
  }

  public func health() -> STTHealth {
    let (state, consumed) = withLock { (stateValue, currentSegmentIndex) }
    switch state {
    case .idle:
      return STTHealth(
        ready: false,
        status: "idle",
        detail: "Mock engine not started; \(script.count) segment(s) scripted"
      )
    case .streaming:
      return STTHealth(
        ready: true,
        status: "ready",
        detail: "Mock engine streaming with \(consumed)/\(script.count) segment(s) consumed"
      )
    case .finalized:
      return STTHealth(
        ready: true,
        status: "finalized",
        detail: "Mock engine finalized with \(consumed)/\(script.count) segment(s) consumed"
      )
    case .cancelled:
      return STTHealth(
        ready: false,
        status: "cancelled",
        detail: "Mock engine cancelled"
      )
    }
  }

  private func emitProgressIfNeeded() {
    guard currentSegmentIndex < script.count else { return }
    let segment = script[currentSegmentIndex]

    if currentSegmentFrames == partialBoundaryFrames {
      let partial = makeResult(segment: segment, isStable: false)
      pendingResult = partial
      unsafeContinuation.yield(partial)
    }

    let segmentDone =
      segment.expectedFrameCount > 0
      && currentSegmentFrames >= segment.expectedFrameCount
    let stabilizationMet = currentSegmentFrames >= partialBoundaryFrames + stabilizationDelayFrames
    if (segmentDone || stabilizationMet) && pendingResult?.isStable == false {
      emitStableForCurrentSegment(force: false)
      currentSegmentIndex += 1
      currentSegmentFrames = 0
      pendingResult = nil
    }
  }

  private func emitStableForCurrentSegment(force: Bool) {
    guard currentSegmentIndex < script.count else {
      if force { unsafeContinuation.finish() }
      return
    }
    let segment = script[currentSegmentIndex]
    let stable = makeResult(segment: segment, isStable: true)
    unsafeContinuation.yield(stable)
    if force {
      unsafeContinuation.finish()
    }
  }

  private func makeResult(segment: MockSegment, isStable: Bool) -> STTTranscriptResult {
    let now = clock()
    let latency = activationTime > 0 ? now - activationTime : 0
    let alternatives = segment.alternatives.map {
      STTAlternative(text: $0, confidence: confidence * 0.8)
    }
    return STTTranscriptResult(
      resultID: UUID(),
      isStable: isStable,
      text: segment.text,
      alternatives: alternatives,
      confidence: isStable ? confidence : confidence * 0.7,
      audioStartTime: activationTime,
      audioEndTime: now,
      metadata: [
        "engineID": engineID,
        "latencySeconds": String(format: "%.4f", latency),
        "frameIndex": String(totalFramesIngested),
        "segmentIndex": String(currentSegmentIndex),
      ]
    )
  }

  public struct MockSegment: Sendable, Equatable {
    public let text: String
    public let expectedFrameCount: UInt64
    public let alternatives: [String]

    public init(
      text: String,
      expectedFrameCount: UInt64,
      alternatives: [String] = []
    ) {
      self.text = text
      self.expectedFrameCount = expectedFrameCount
      self.alternatives = alternatives
    }
  }

  private enum State {
    case idle
    case streaming
    case finalized
    case cancelled
  }
}

// MARK: - Thread-safe continuation box

/// Holds an `AsyncStream` continuation behind a lock so a non-isolated engine
/// can yield results from arbitrary threads/queues without creating actor
/// isolation boundaries for the protocol.
private final class UnsafeContinuationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<STTTranscriptResult>.Continuation?

  init(continuation: AsyncStream<STTTranscriptResult>.Continuation) {
    self.continuation = continuation
  }

  func yield(_ result: STTTranscriptResult) {
    lock.lock()
    let continuationSnapshot = continuation
    lock.unlock()
    continuationSnapshot?.yield(result)
  }

  func finish() {
    lock.lock()
    let continuationSnapshot = continuation
    continuation = nil
    lock.unlock()
    continuationSnapshot?.finish()
  }
}
