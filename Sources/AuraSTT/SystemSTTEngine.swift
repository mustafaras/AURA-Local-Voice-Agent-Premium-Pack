import AVFoundation
import AuraAudio
import AuraCore
import Foundation
import Speech

/// On-device streaming STT engine using Apple `Speech.framework`.
///
/// This adapter keeps all recognition local via `requiresOnDeviceRecognition`.
/// It forwards real-time audio frames from `AuraAudio` into an
/// `SFSpeechAudioBufferRecognitionRequest`, maps `SFSpeechRecognitionResult`
/// values to typed `STTTranscriptResult`s, and exposes them through the
/// standard `AsyncStream` defined by `STTEngine`.
///
/// Failures are typed into `AuraError.permissionDenied` when authorization is
/// missing and `AuraError.sttEngineError` for runtime recognition failures.
public final class SystemSTTEngine: STTEngine, @unchecked Sendable {
  public let engineID: String
  public let locale: Locale

  private let recognizer: SFSpeechRecognizer?
  private let vocabulary: UserVocabulary?
  private let enableCustomVocabulary: Bool

  // MARK: - Isolation

  /// Recursive lock because `cancel()` may be invoked from the stream's
  /// `onTermination` handler while another operation (e.g. `start()` or
  /// `finalizeSession()`) holds the lock.
  private let lock = NSRecursiveLock()

  // MARK: - Mutable state

  private enum State {
    case idle
    case streaming(
      sessionID: UUID,
      request: SFSpeechAudioBufferRecognitionRequest,
      task: SFSpeechRecognitionTask,
      streamState: StreamState
    )
    case finalized(StreamState)
    case cancelled
  }

  private struct StreamState: Sendable {
    var activationTime: TimeInterval = 0
    var firstPartialTimestamp: TimeInterval = 0
    var lastResultID: UUID = UUID()
  }

  private var stateValue: State = .idle
  private let stream: AsyncStream<STTTranscriptResult>
  private let unsafeContinuation: UnsafeContinuationBox

  // MARK: - Initialization

  /// Creates a new native-speech STT engine.
  ///
  /// - Parameters:
  ///   - engineID: Adapter identifier; defaults to "native-speech".
  ///   - locale: Locale for recognition. Use a tag recognized by
  ///     `SFSpeechRecognizer.supportedLocales()`.
  ///   - vocabulary: Optional vocabulary hints. Used only when
  ///     `enableCustomVocabulary` is `true` and the engine supports
  ///     `contextualStrings`.
  ///   - enableCustomVocabulary: Whether to inject vocabulary hints into the
  ///     recognition request.
  public init(
    engineID: String = "native-speech",
    locale: Locale = Locale(identifier: "tr-TR"),
    vocabulary: UserVocabulary? = nil,
    enableCustomVocabulary: Bool = true
  ) {
    self.engineID = engineID
    self.locale = locale
    self.vocabulary = vocabulary
    self.enableCustomVocabulary = enableCustomVocabulary
    self.recognizer = SFSpeechRecognizer(locale: locale)
    let (stream, continuation) = AsyncStream<STTTranscriptResult>.makeStream()
    self.stream = stream
    self.unsafeContinuation = UnsafeContinuationBox(continuation: continuation)
    continuation.onTermination = { [weak self] _ in
      Task { [weak self] in await self?.cancel() }
    }
  }

  public var results: AsyncStream<STTTranscriptResult> { stream }

  deinit {
    unsafeContinuation.finish()
  }

  // MARK: - STTEngine

  public func start() async throws -> STTHealth {
    let health = try await Task { @MainActor [weak self] () -> STTHealth in
      guard let self else {
        throw AuraError.sttEngineError("SystemSTTEngine deallocated during start")
      }
      return try self.startLocked()
    }.value
    return health
  }

  private func startLocked() throws -> STTHealth {
    lock.lock()
    defer { lock.unlock() }

    if case .cancelled = stateValue {
      // Cancellation ends only the current recognition request. The
      // engine-lifetime result stream remains reusable for the next PTT turn.
      stateValue = .idle
    }
    guard case .idle = stateValue else {
      return healthForCurrentState()
    }

    let status = SFSpeechRecognizer.authorizationStatus()
    switch status {
    case .notDetermined:
      throw AuraError.permissionDenied(
        "Speech recognition authorization not determined; request authorization before starting STT"
      )
    case .denied:
      throw AuraError.permissionDenied(
        "Speech recognition authorization denied; enable in System Settings > Privacy & Security > Speech Recognition"
      )
    case .restricted:
      throw AuraError.permissionDenied(
        "Speech recognition authorization restricted on this device")
    case .authorized:
      break
    @unknown default:
      throw AuraError.permissionDenied(
        "Speech recognition authorization status unrecognized: \(status.rawValue)")
    }

    guard let recognizer, recognizer.isAvailable else {
      throw AuraError.sttEngineError(
        "SFSpeechRecognizer unavailable for locale \(locale.identifier)")
    }

    guard recognizer.supportsOnDeviceRecognition else {
      throw AuraError.sttEngineError(
        "On-device Speech.framework recognition unavailable for locale \(locale.identifier)")
    }

    return STTHealth(
      ready: true,
      status: "ready",
      detail: "Native Speech.framework STT ready for \(locale.identifier); on-device only",
      engineID: engineID,
      locale: locale.identifier,
      supportsOffline: true
    )
  }

  public func ingest(_ frame: AudioFrame, activationTime: TimeInterval) async {
    withLock {
      switch stateValue {
      case .idle, .finalized, .cancelled:
        do {
          try startRecognition(activationTime: activationTime)
        } catch {
          unsafeContinuation.yield(
            makeErrorResult(text: "Recognition start failed: \(error.localizedDescription)")
          )
          return
        }
      default:
        break
      }

      guard case .streaming(let sessionID, let request, let task, var streamState) = stateValue
      else {
        return
      }

      if streamState.activationTime == 0 {
        streamState.activationTime = activationTime
      }

      guard let buffer = makePCMBuffer(samples: frame.samples) else {
        return
      }

      request.append(buffer)
      stateValue = .streaming(
        sessionID: sessionID, request: request, task: task, streamState: streamState)
    }
  }

  public func finalizeSession() async {
    withLock {
      guard case .streaming(_, let request, _, _) = stateValue else {
        return
      }
      request.endAudio()
    }
  }

  public func cancel() async {
    withLock {
      if case .streaming(_, let request, let task, _) = stateValue {
        request.endAudio()
        task.cancel()
      }
      stateValue = .cancelled
    }
  }

  public func health() -> STTHealth {
    return healthForCurrentState()
  }

  // MARK: - Private helpers

  private func startRecognition(activationTime: TimeInterval) throws {
    guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
      throw AuraError.sttEngineError("Recognizer unavailable")
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true

    if enableCustomVocabulary, let vocabulary {
      let hints = vocabulary.allContextualHints()
      if !hints.isEmpty {
        request.contextualStrings = hints
      }
    }

    var streamState = StreamState()
    streamState.activationTime = activationTime
    let sessionID = UUID()

    let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      self.handleRecognitionResult(result, error: error, sessionID: sessionID)
    }

    stateValue = .streaming(
      sessionID: sessionID, request: request, task: task, streamState: streamState)
  }

  private func handleRecognitionResult(
    _ result: SFSpeechRecognitionResult?,
    error: Error?,
    sessionID: UUID
  ) {
    withLock {
      guard
        case .streaming(
          let currentSessionID, let request, let task, var streamState) = stateValue,
        currentSessionID == sessionID
      else {
        return
      }

      if let error {
        let mapped = mapSpeechError(error)
        unsafeContinuation.yield(
          makeErrorResult(text: mapped.localizedDescription)
        )
        stateValue = .finalized(streamState)
        return
      }

      guard let result = result else {
        stateValue = .streaming(
          sessionID: sessionID, request: request, task: task, streamState: streamState)
        return
      }
      let transcription = result.bestTranscription

      let mapped = mapTranscription(
        transcription,
        isFinal: result.isFinal,
        resultID: UUID(),
        activationTime: streamState.activationTime,
        streamState: &streamState,
        allTranscriptions: result.transcriptions
      )

      if !result.isFinal {
        streamState.lastResultID = mapped.resultID
        if streamState.firstPartialTimestamp == 0 {
          streamState.firstPartialTimestamp = CFAbsoluteTimeGetCurrent()
        }
      }

      unsafeContinuation.yield(mapped)

      if result.isFinal {
        stateValue = .finalized(streamState)
      } else {
        stateValue = .streaming(
          sessionID: sessionID, request: request, task: task, streamState: streamState)
      }
    }
  }

  private func mapTranscription(
    _ transcription: SFTranscription,
    isFinal: Bool,
    resultID: UUID,
    activationTime: TimeInterval,
    streamState: inout StreamState,
    allTranscriptions: [SFTranscription]
  ) -> STTTranscriptResult {
    let text = transcription.formattedString
    let segments = transcription.segments
    let confidenceSum = segments.reduce(0.0) { $0 + Double($1.confidence) }
    let confidence = confidenceSum / max(1.0, Double(segments.count))

    let alternatives: [STTAlternative] =
      allTranscriptions
      .dropFirst()
      .prefix(3)
      .map { alt in
        let altSegments = alt.segments
        let altSum = altSegments.reduce(0.0) { $0 + Double($1.confidence) }
        let altConfidence = altSum / max(1.0, Double(altSegments.count))
        return STTAlternative(text: alt.formattedString, confidence: altConfidence)
      }

    let firstSegment = segments.first
    let audioStartTime = firstSegment?.timestamp ?? activationTime
    let audioEndTime =
      (firstSegment?.timestamp ?? 0)
      + (firstSegment?.duration ?? 0)

    return STTTranscriptResult(
      resultID: resultID,
      isStable: isFinal,
      text: text,
      alternatives: alternatives,
      confidence: confidence,
      audioStartTime: audioStartTime,
      audioEndTime: audioEndTime,
      metadata: [
        "engineID": engineID,
        "locale": locale.identifier,
        "onDevice": "true",
        "segments": String(segments.count),
      ]
    )
  }

  private func mapSpeechError(_ error: Error) -> AuraError {
    let nsError = error as NSError
    if nsError.domain == "com.apple.speech.recognition" {
      switch nsError.code {
      case 1:
        return AuraError.permissionDenied("Speech recognition denied by user or system policy")
      case 2:
        return AuraError.sttEngineError(
          "Speech recognition unavailable for locale \(locale.identifier)")
      case 4:
        return AuraError.sttEngineError("Speech recognition request was cancelled")
      case 7:
        return AuraError.sttEngineError("No speech detected")
      default:
        return AuraError.sttEngineError(
          "Speech recognition error \(nsError.code): \(nsError.localizedDescription)")
      }
    }
    return AuraError.sttEngineError(error.localizedDescription)
  }

  private func makePCMBuffer(samples: [Float]) -> AVAudioPCMBuffer? {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 16000,
      channels: 1,
      interleaved: false
    )
    guard let format else { return nil }
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
    else {
      return nil
    }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    guard let channelData = buffer.floatChannelData else { return nil }
    for i in 0..<samples.count {
      channelData[0][i] = samples[i]
    }
    return buffer
  }

  private func makeErrorResult(text: String) -> STTTranscriptResult {
    return STTTranscriptResult(
      resultID: UUID(),
      isStable: true,
      text: text,
      confidence: 0,
      audioStartTime: 0,
      audioEndTime: 0,
      metadata: [
        "engineID": engineID,
        "error": "true",
      ]
    )
  }

  private func healthForCurrentState() -> STTHealth {
    switch stateValue {
    case .idle:
      return STTHealth(
        ready: false,
        status: "idle",
        detail: "Native STT engine idle",
        engineID: engineID,
        locale: locale.identifier,
        supportsOffline: true
      )
    case .streaming:
      return STTHealth(
        ready: true,
        status: "streaming",
        detail: "Native STT engine streaming on-device",
        engineID: engineID,
        locale: locale.identifier,
        supportsOffline: true
      )
    case .finalized:
      return STTHealth(
        ready: true,
        status: "finalized",
        detail: "Native STT session finalized",
        engineID: engineID,
        locale: locale.identifier,
        supportsOffline: true
      )
    case .cancelled:
      return STTHealth(
        ready: false,
        status: "cancelled",
        detail: "Native STT session cancelled",
        engineID: engineID,
        locale: locale.identifier,
        supportsOffline: true
      )
    }
  }

  @discardableResult
  private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try operation()
  }
}

// MARK: - Thread-safe continuation box

private final class UnsafeContinuationBox: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: AsyncStream<STTTranscriptResult>.Continuation?

  init(continuation: AsyncStream<STTTranscriptResult>.Continuation) {
    self.continuation = continuation
  }

  func yield(_ result: STTTranscriptResult) {
    lock.lock()
    let c = continuation
    lock.unlock()
    c?.yield(result)
  }

  func finish() {
    lock.lock()
    let c = continuation
    continuation = nil
    lock.unlock()
    c?.finish()
  }
}
