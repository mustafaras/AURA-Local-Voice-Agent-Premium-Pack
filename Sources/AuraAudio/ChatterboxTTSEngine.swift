import AuraCore
import Foundation

/// A boundary-only adapter for a future on-device Chatterbox neural TTS.
///
/// This prototype implements the `TTSEngine` contract without embedding model
/// weights or performing real neural inference. It is intended to exercise
/// the adapter wiring in `AuraKernel` and to provide a typed placeholder for
/// a future MLX / Python-helper / verified-GGUF implementation.
///
/// By default the engine reports `ready: false`, so `AuraKernel` falls back
/// to `SystemTTSEngine` unless a user-configured helper path and model path
/// are both present.
public final class ChatterboxTTSEngine: TTSEngine, Sendable {
  public let engineID: String = "chatterbox"

  /// A stub streaming synthesizer that honors the `TTSEngine` contract.
  ///
  /// When the engine is not ready it emits `.failed("chatterbox not ready")`
  /// followed by `.complete`. When ready it emits deterministic progress
  /// markers (one per whitespace-separated fragment) followed by `.complete`.
  public func speak(_ prompt: TTSPrompt) -> AsyncStream<TTSChunk> {
    AsyncStream { continuation in
      let box = ChatterboxContinuationBox(continuation: continuation)

      continuation.onTermination = { _ in
        box.finish()
      }

      Task.detached { [weak self] in
        guard let self = self else {
          box.finish()
          return
        }

        guard await self.isReady() else {
          box.yield(.failed("chatterbox not ready: helper or model path missing"))
          box.yield(.complete)
          box.finish()
          return
        }

        let fragments = prompt.text.split(separator: " ", omittingEmptySubsequences: true)
        var byteOffset: UInt64 = 0
        for fragment in fragments {
          // Cooperative cancellation point between fragments.
          try? await Task.sleep(nanoseconds: 1_000_000)
          if Task.isCancelled {
            box.yield(.failed("Synthesis cancelled"))
            box.yield(.complete)
            box.finish()
            return
          }
          let text = String(fragment)
          byteOffset += UInt64(text.utf8.count)
          box.yield(.progress(fragment: text, byteOffset: byteOffset))
        }

        box.yield(.complete)
        box.finish()
      }
    }
  }

  public func start() async throws(AuraError) -> TTSHealth {
    if await isReady() {
      return TTSHealth(
        ready: true,
        status: "ready",
        detail: "Chatterbox adapter ready (external helper configured)")
    }
    // Boundary prototype: we do not throw here; we report not-ready so the
    // adapter chain can fall back cleanly to the next engine.
    return TTSHealth(
      ready: false,
      status: "not-ready",
      detail: "Chatterbox model/helper not configured")
  }

  public func stopSpeaking() async {
    // The detached speak task checks `Task.isCancelled` between fragments.
    // No persistent synthesizer state is kept in this stub.
  }

  public func pauseSpeaking() async {
    // Placeholder for a future real pause/resume state machine.
  }

  public func resumeSpeaking() async {
    // Placeholder for a future real pause/resume state machine.
  }

  public func health() -> TTSHealth {
    let ready = configuration.modelPath != nil && configuration.helperPath != nil
    return TTSHealth(
      ready: ready,
      status: ready ? "ready" : "not-ready",
      detail: ready
        ? "Chatterbox helper and model path configured"
        : "Chatterbox helper or model path missing")
  }

  // MARK: - Configuration

  /// Lightweight configuration describing where a future helper and model
  /// would live. Both are `nil` by default, so the adapter stays inert.
  public struct Configuration: Sendable, Equatable {
    public var helperPath: String?
    public var modelPath: String?

    public init(helperPath: String? = nil, modelPath: String? = nil) {
      self.helperPath = helperPath
      self.modelPath = modelPath
    }
  }

  private let configuration: Configuration

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  private func isReady() async -> Bool {
    configuration.helperPath != nil && configuration.modelPath != nil
  }
}

// MARK: - Continuation box

/// Thread-safe wrapper around an `AsyncStream<TTSChunk>.Continuation`.
private final class ChatterboxContinuationBox: @unchecked Sendable {
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
