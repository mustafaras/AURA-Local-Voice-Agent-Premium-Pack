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

  let recognizer: SFSpeechRecognizer?
  let vocabulary: UserVocabulary?
  let enableCustomVocabulary: Bool

  // MARK: - Isolation

  /// Recursive lock because `cancel()` may be invoked from the stream's
  /// `onTermination` handler while another operation (e.g. `start()` or
  /// `finalizeSession()`) holds the lock.
  let lock = NSRecursiveLock()

  // MARK: - Mutable state

  enum State {
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

  struct StreamState: Sendable {
    var activationTime: TimeInterval = 0
    var firstPartialTimestamp: TimeInterval = 0
    var lastResultID: UUID = UUID()
  }

  var stateValue: State = .idle
  let stream: AsyncStream<STTTranscriptResult>
  let unsafeContinuation: SystemSTTContinuationBox

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
    self.unsafeContinuation = SystemSTTContinuationBox(continuation: continuation)
    continuation.onTermination = { [weak self] _ in
      Task { [weak self] in await self?.cancel() }
    }
  }

  deinit {
    unsafeContinuation.finish()
  }
}

// MARK: - Thread-safe continuation box

final class SystemSTTContinuationBox: @unchecked Sendable {
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
