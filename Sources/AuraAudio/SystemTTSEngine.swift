import AVFoundation
import AuraCore
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

  private let synthesizerQueue = DispatchQueue(
    label: "ai.aura.systemtts.synthesizer", qos: .userInitiated)
  private let preferredVoiceIdentifier: String?
  private let lock = NSRecursiveLock()
  private var isRunning = false
  private var currentBox: UnsafeContinuationBox?
  private var currentSynthesizer: AVSpeechSynthesizer?

  public init(preferredVoiceIdentifier: String? = nil) {
    self.preferredVoiceIdentifier = preferredVoiceIdentifier
  }

  public func start() async throws(AuraError) -> TTSHealth {
    let voices = AVSpeechSynthesisVoice.speechVoices()
    guard !voices.isEmpty else {
      throw AuraError.ttsAdapterFailed("No system voices available")
    }
    lock.withLock { isRunning = true }
    return TTSHealth(
      ready: true,
      status: "ready",
      detail: voiceHealthDetail(voices: voices))
  }

  public func speak(_ prompt: TTSPrompt) -> AsyncStream<TTSChunk> {
    let (stream, continuation) = AsyncStream<TTSChunk>.makeStream()
    let box = UnsafeContinuationBox(continuation: continuation)

    synthesizerQueue.sync {
      lock.withLock {
        currentSynthesizer?.stopSpeaking(at: .immediate)
        currentSynthesizer = nil
        currentBox = box
      }
    }

    continuation.onTermination = { [weak self] _ in
      Task { [weak self] in
        await self?.stopSpeaking(ifCurrent: box)
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

    let delegate = SystemTTSDelegate { [weak box] fragment, length in
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
      self.lock.withLock { self.currentSynthesizer = synthesizer }
      synthesizer.delegate = delegate
      synthesizer.speak(utterance)
    }

    await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in
      semaphore.wait()
    }
  }

  private func makeUtterance(prompt: TTSPrompt) -> AVSpeechUtterance {
    let utterance = AVSpeechUtterance(string: prompt.text)
    let locale = prompt.locale.isEmpty ? "tr-TR" : prompt.locale
    utterance.voice = Self.bestVoice(
      for: locale,
      preferredIdentifier: preferredVoiceIdentifier,
      voices: AVSpeechSynthesisVoice.speechVoices())
    utterance.rate = Self.systemRate(forMultiplier: prompt.rate)
    utterance.pitchMultiplier = Float(clamp(0.98 + (prompt.emphasis * 0.04), 0.8...1.2))
    utterance.preUtteranceDelay = 0.03
    utterance.postUtteranceDelay = 0.06
    return utterance
  }

  /// Select the highest-quality installed local voice for a BCP-47 locale.
  /// An explicit identifier wins when installed; otherwise exact locale,
  /// language-family match, and finally English fallback are ranked by
  /// platform quality and stable identifier.
  static func bestVoice(
    for locale: String,
    preferredIdentifier: String? = nil,
    voices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices()
  ) -> AVSpeechSynthesisVoice? {
    if let preferredIdentifier,
      let preferred = voices.first(where: { $0.identifier == preferredIdentifier })
    {
      return preferred
    }

    let normalizedLocale = locale.replacingOccurrences(of: "_", with: "-").lowercased()
    let language = normalizedLocale.split(separator: "-").first.map(String.init) ?? normalizedLocale

    func ranked(_ candidates: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
      candidates.sorted {
        if $0.quality.rawValue != $1.quality.rawValue {
          return $0.quality.rawValue > $1.quality.rawValue
        }
        return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
      }.first
    }

    let exact = voices.filter {
      $0.language.replacingOccurrences(of: "_", with: "-").lowercased() == normalizedLocale
    }
    if let voice = ranked(exact) { return voice }

    let sameLanguage = voices.filter {
      $0.language.replacingOccurrences(of: "_", with: "-").lowercased()
        .hasPrefix("\(language)-")
    }
    if let voice = ranked(sameLanguage) { return voice }

    return ranked(
      voices.filter {
        $0.language.replacingOccurrences(of: "_", with: "-").lowercased() == "en-us"
      })
  }

  /// Convert the public multiplier contract (1.0 = normal) into
  /// AVFoundation's absolute rate scale (0.5 = platform normal).
  static func systemRate(forMultiplier multiplier: Double) -> Float {
    let boundedMultiplier = clamp(multiplier, 0.5...2.0)
    let scaled = Double(AVSpeechUtteranceDefaultSpeechRate) * boundedMultiplier
    return Float(
      clamp(
        scaled,
        Double(
          AVSpeechUtteranceMinimumSpeechRate)...Double(
            AVSpeechUtteranceMaximumSpeechRate)))
  }

  private func voiceHealthDetail(voices: [AVSpeechSynthesisVoice]) -> String {
    guard
      let selected = Self.bestVoice(
        for: "tr-TR", preferredIdentifier: preferredVoiceIdentifier, voices: voices)
    else {
      return "System TTS ready with \(voices.count) voices"
    }
    return
      "System TTS ready with \(selected.name) (\(selected.language), "
      + "quality \(selected.quality.rawValue))"
  }

  public func stopSpeaking() async {
    await stopSpeaking(ifCurrent: nil)
  }

  /// Stop only when the stream that terminated is still the active stream.
  /// A cancelled predecessor must not terminate a newer barge-in response.
  private func stopSpeaking(ifCurrent expectedBox: UnsafeContinuationBox?) async {
    var box: UnsafeContinuationBox?
    synthesizerQueue.sync {
      lock.withLock {
        if let expectedBox, currentBox !== expectedBox {
          return
        }
        box = currentBox
        currentBox = nil
        currentSynthesizer?.stopSpeaking(at: .immediate)
        currentSynthesizer = nil
      }
    }
    box?.finish()
  }

  public func pauseSpeaking() async {
    synthesizerQueue.sync {
      lock.withLock {
        _ = currentSynthesizer?.pauseSpeaking(at: .word)
      }
    }
  }

  public func resumeSpeaking() async {
    synthesizerQueue.sync {
      lock.withLock {
        _ = currentSynthesizer?.continueSpeaking()
      }
    }
  }

  public func health() -> TTSHealth {
    let running = lock.withLock { isRunning }
    let voices = AVSpeechSynthesisVoice.speechVoices()
    return TTSHealth(
      ready: running && !voices.isEmpty,
      status: running ? "ready" : "idle",
      detail: running
        ? voiceHealthDetail(voices: voices)
        : "System TTS idle with \(voices.count) voices")
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

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didStart utterance: AVSpeechUtterance
  ) {}

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    let range = Range(characterRange, in: utterance.speechString)
    let fragment = range.map { String(utterance.speechString[$0]) } ?? ""
    onSpeakRange(fragment, characterRange.length)
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    onFinish(true, nil)
    self.synthesizer = nil
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
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
    let continuationSnapshot = continuation
    lock.unlock()
    continuationSnapshot?.yield(chunk)
  }

  func finish() {
    lock.lock()
    let continuationSnapshot = continuation
    continuation = nil
    lock.unlock()
    continuationSnapshot?.finish()
  }
}
