import AuraCore
import Foundation

/// A deterministic, model-free TTS engine used to validate the `TTSEngine`
/// protocol and downstream conversation state machines without generating
/// real audio or depending on external speech frameworks.
///
/// The mock splits the prompt text into fragments by word boundaries, emits
/// progress markers, and respects immediate `stopSpeaking()`. It is safe to use
/// in CI and unit tests.
public final class MockTTSEngine: TTSEngine, @unchecked Sendable {
  public let engineID: String

  private let lock = NSRecursiveLock()
  private var isRunning = false
  private var isStopped = false
  private var currentPrompt: TTSPrompt?
  private var currentContinuation: UnsafeContinuationBox?
  private let clock: () -> TimeInterval

  public init(
    engineID: String = "mock-tts",
    clock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }
  ) {
    self.engineID = engineID
    self.clock = clock
  }

  public func start() async throws(AuraError) -> TTSHealth {
    lock.withLock { isRunning = true }
    return TTSHealth(
      ready: true,
      status: "ready",
      detail: "Mock TTS engine initialized"
    )
  }

  public func speak(_ prompt: TTSPrompt) -> AsyncStream<TTSChunk> {
    let (stream, continuation) = AsyncStream<TTSChunk>.makeStream()
    let box = UnsafeContinuationBox(continuation: continuation)

    lock.withLock {
      isStopped = false
      currentPrompt = prompt
      currentContinuation = box
    }

    continuation.onTermination = { [weak self] _ in
      Task { [weak self] in
        await self?.stopSpeaking()
      }
    }

    // Drive synthesis on a detached task so the caller can collect chunks
    // concurrently. For real-time safety, real adapters must not do this
    // on the audio callback thread.
    Task.detached { [weak self] in
      guard let self = self else {
        box.finish()
        return
      }
      await self.synthesize(prompt: prompt, box: box)
      // Clean up current prompt once synthesis finishes.
      self.lock.withLock {
        if self.currentContinuation === box {
          self.currentContinuation = nil
          self.currentPrompt = nil
        }
      }
    }

    return stream
  }

  private func synthesize(prompt: TTSPrompt, box: UnsafeContinuationBox) async {
    let fragments = prompt.text.split(separator: " ").map(String.init)
    var offset: UInt64 = 0

    for fragment in fragments {
      let shouldStop = lock.withLock { isStopped }
      guard !shouldStop, !Task.isCancelled else {
        box.yield(.failed("Synthesis interrupted"))
        box.finish()
        return
      }

      // Simulate work without blocking. In production the real adapter
      // would yield an audio buffer here.
      try? await Task.sleep(nanoseconds: 1_000_000)

      let wordSize = UInt64(fragment.utf8.count)
      let nextOffset = offset + wordSize
      box.yield(.progress(fragment: fragment, byteOffset: nextOffset))
      offset = nextOffset
    }

    let shouldStop = lock.withLock { isStopped }
    if !shouldStop {
      box.yield(.complete)
    }
    box.finish()
  }

  public func stopSpeaking() async {
    let box: UnsafeContinuationBox? = lock.withLock {
      isStopped = true
      let box = currentContinuation
      currentContinuation = nil
      currentPrompt = nil
      return box
    }
    box?.finish()
  }

  public func pauseSpeaking() async {
    // The mock has no true pause semantics; just record that pause was
    // requested. Real system/chatterbox adapters would pause the queue.
  }

  public func resumeSpeaking() async {
    // The mock has no true resume semantics.
  }

  public func health() -> TTSHealth {
    let running = lock.withLock { isRunning }
    return TTSHealth(
      ready: running,
      status: running ? "ready" : "idle",
      detail: "Mock TTS \(running ? "running" : "not running")"
    )
  }

  /// Exposes the prompt currently being spoken for test observation.
  public func currentPromptForTest() -> TTSPrompt? {
    lock.withLock { currentPrompt }
  }
}

// MARK: - Thread-safe continuation box

private final class UnsafeContinuationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<TTSChunk>.Continuation?

  init(continuation: AsyncStream<TTSChunk>.Continuation) {
    self.continuation = continuation
  }

  func yield(_ chunk: TTSChunk) {
    lock.lock()
    let c = continuation
    lock.unlock()
    c?.yield(chunk)
  }

  func finish() {
    lock.lock()
    let c = continuation
    continuation = nil
    lock.unlock()
    c?.finish()
  }
}
