import AVFoundation
import AuraAudio
import AuraCore
import Foundation
import Speech

extension SystemSTTEngine {
  public var results: AsyncStream<STTTranscriptResult> { stream }

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

  func startLocked() throws -> STTHealth {
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
        "Speech recognition authorization denied; enable in System Settings > "
          + "Privacy & Security > Speech Recognition"
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
}
