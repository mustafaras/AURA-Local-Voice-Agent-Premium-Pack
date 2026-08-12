import AVFoundation
import AuraAudio
import AuraCore
import Foundation
import Speech

struct TranscriptionMappingInput {
  let transcription: SFTranscription
  let isFinal: Bool
  let resultID: UUID
  let activationTime: TimeInterval
  let allTranscriptions: [SFTranscription]
}

extension SystemSTTEngine {
  // MARK: - Private helpers

  func startRecognition(activationTime: TimeInterval) throws {
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

  func handleRecognitionResult(
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
        TranscriptionMappingInput(
          transcription: transcription,
          isFinal: result.isFinal,
          resultID: UUID(),
          activationTime: streamState.activationTime,
          allTranscriptions: result.transcriptions
        ),
        streamState: &streamState
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

  func mapTranscription(
    _ input: TranscriptionMappingInput,
    streamState: inout StreamState
  ) -> STTTranscriptResult {
    let transcription = input.transcription
    let text = transcription.formattedString
    let segments = transcription.segments
    let confidenceSum = segments.reduce(0.0) { $0 + Double($1.confidence) }
    let confidence = confidenceSum / max(1.0, Double(segments.count))

    let alternatives: [STTAlternative] =
      input.allTranscriptions
      .dropFirst()
      .prefix(3)
      .map { alt in
        let altSegments = alt.segments
        let altSum = altSegments.reduce(0.0) { $0 + Double($1.confidence) }
        let altConfidence = altSum / max(1.0, Double(altSegments.count))
        return STTAlternative(text: alt.formattedString, confidence: altConfidence)
      }

    let firstSegment = segments.first
    let audioStartTime = firstSegment?.timestamp ?? input.activationTime
    let audioEndTime =
      (firstSegment?.timestamp ?? 0) + (firstSegment?.duration ?? 0)

    return STTTranscriptResult(
      resultID: input.resultID,
      isStable: input.isFinal,
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

  func mapSpeechError(_ error: Error) -> AuraError {
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

  func makePCMBuffer(samples: [Float]) -> AVAudioPCMBuffer? {
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
    for sampleIndex in 0..<samples.count {
      channelData[0][sampleIndex] = samples[sampleIndex]
    }
    return buffer
  }

  func makeErrorResult(text: String) -> STTTranscriptResult {
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

  func healthForCurrentState() -> STTHealth {
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
  func withLock<T>(_ operation: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try operation()
  }
}
