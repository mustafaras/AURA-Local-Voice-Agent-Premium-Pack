import AuraCore
import AVFoundation
import Foundation

/// A macOS system speech-synthesis adapter using `AVSpeechSynthesizer`.
///
/// This is the production fallback TTS engine. It keeps all speech synthesis
/// on-device and never sends text to a remote service. It is used when no
/// higher-priority neural adapter (Chatterbox/Dia) is configured or ready.
///
/// The adapter is `Sendable` by isolating all `AVSpeechSynthesizer` access on a
/// dedicated serial dispatch queue. Callers interact with it via the async
/// `TTSEngine` methods; synthesis progress is reported as `TTSChunk` markers.
public final class SystemTTSEngine: TTSEngine, @unchecked Sendable {
  public let engineID: String = "system"

  private let synthesizerQueue = DispatchQueue(label: "ai.aura.systemtts.synthesizer", qos: .userInitiated)
  private let lock = NSRecursiveLock()
  private var isRunning = false
  private var currentBox: UnsafeContinuationBox?

  public init() {}

  public func start() async throws(AuraError) -> TTSHealth {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    guard !voices.isEmpty else {
      throw AuraError.ttsAdapterFailed("No system voices available")
    }
    lock.withLock { isRunning = true }
    return TTSHealth(
      ready: true,
      status: "ready",
      detail: "System TTS ready with \(voices.count) voices")
  }

  public func speak(_ prompt: TTSPrompt) -> AsyncStream<TTSChunk> {
    let (stream, continuation) = AsyncStream<TTSChunk>.makeStream()
    let box = UnsafeContinuationBox(continuation: continuation)

    lock.withLock {
      currentBox = box
    }

    continuation.onTermination = { [weak self] _ in
      Task { [weak self] in
        await self?.stopSpeaking()
      }
    }

    Task.detached { [weak self] in
      guard let self = self else {
        box.finish()
        return
      }
      await self.synthesize(prompt: prompt, box: box)
      self.lock.withLock {
        if self.currentBox === box {
          self.currentBox = nil
        }
      }
    }

    return stream
  }

  private func synthesize(prompt: TTSPrompt, box: UnsafeContinuationBox) async {
    let semaphore = DispatchSemaphore(value: 0)
    var completionState: TTSChunk = .complete
    var byteOffset: UInt64 = 0

    let delegate = SystemTTSDelegate {
      [weak box] fragment, length in
      byteOffset += UInt64(length)
      box?.yield(.progress(fragment: fragment, byteOffset: byteOffset))
    } didFinish: { [weak box] success, error in
      if let error = error {
        completionState = .failed(error.localizedDescription)
      } else if !success {
        completionState = .failed("Synthesis did not complete")
      }
      box?.yield(completionState)
      box?.finish()
      semaphore.signal()
    } didCancel: { [weak box] in
      box?.yield(.failed("Synthesis cancelled"))
      box?.finish()
      semaphore.signal()
    }

    synthesizerQueue.sync { [weak delegate] in
      guard let delegate = delegate else {
        box.finish()
        semaphore.signal()
        return
      }
      let utterance = makeUtterance(prompt: prompt)
      delegate.attach(to: utterance)
      let synthesizer = AVSpeechSynthesizer()
      delegate.holdSynthesizer(synthesizer)
      synthesizer.delegate = delegate
      synthesizer.speak(utterance)
    }

    await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in
      semaphore.wait()
    }
  }

  private func makeUtterance(prompt: TTSPrompt) -> AVSpeechUtterance {
    let utterance = AVSpeechUtterance(string: prompt.text)
    let locale = prompt.locale.isEmpty ? "en-US" : prompt.locale
    utterance.voice = AVSpeechSynthesisVoice(language: locale)
      ?? AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = Float(clamp(prompt.rate, 0.5...2.0))
    utterance.pitchMultiplier = 1.0
    return utterance
  }

  public func stopSpeaking() async {
    let box: UnsafeContinuationBox? = lock.withLock {
      let box = currentBox
      currentBox = nil
      return box
    }
    synthesizerQueue.sync {
      // There is no strong reference kept to the synthesizer; the delegate
      // holds it. Finishing the stream is enough for the consumer to stop.
    }
    box?.finish()
  }

  public func pauseSpeaking() async {
    synthesizerQueue.sync {
      // AVSpeechSynthesizer pause is best-effort; we do not track a separate
      // paused state here because the consumer cancels/resumes via speak/stop.
    }
  }

  public func resumeSpeaking() async {
    synthesizerQueue.sync {
      // Resume is a no-op for the system adapter; a new speak call replaces
      // the interrupted stream.
    }
  }

  public func health() -> TTSHealth {
    let running = lock.withLock { isRunning }
    let voices = AVSpeechSynthesisVoice.speechVoices()
    return TTSHealth(
      ready: running && !voices.isEmpty,
      status: running ? "ready" : "idle",
      detail: "System TTS \(running ? "running" : "idle") with \(voices.count) voices")
  }
}

// MARK: - Delegate

private final class SystemTTSDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
  private let onSpeakRange: (String, Int) -> Void
  private let onFinish: (Bool, Error?) -> Void
  private let onCancel: () -> Void
  private var synthesizer: AVSpeechSynthesizer?

  init(
    onSpeakRange: @escaping (String, Int) -> Void,
    didFinish: @escaping (Bool, Error?) -> Void,
    didCancel: @escaping () -> Void
  ) {
    self.onSpeakRange = onSpeakRange
    self.onFinish = didFinish
    self.onCancel = didCancel
  }

  func holdSynthesizer(_ synthesizer: AVSpeechSynthesizer) {
    self.synthesizer = synthesizer
  }

  func attach(to utterance: AVSpeechUtterance) {
    // No-op: delegate is set after synthesizer creation.
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {}

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    let range = Range(characterRange, in: utterance.speechString)
    let fragment = range.map { String(utterance.speechString[$0]) } ?? ""
    onSpeakRange(fragment, characterRange.length)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    onFinish(true, nil)
    self.synthesizer = nil
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    onCancel()
    self.synthesizer = nil
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didPause utterance: AVSpeechUtterance
  ) {}

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didContinue utterance: AVSpeechUtterance
  ) {}
}

// MARK: - Helpers

private func clamp<T: Comparable>(_ value: T, _ range: ClosedRange<T>) -> T {
  min(max(value, range.lowerBound), range.upperBound)
}

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
