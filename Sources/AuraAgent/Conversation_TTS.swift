import AuraAudio
import AuraCore
import Foundation

extension Conversation {
  // MARK: - Internal TTS scheduling

  func scheduleNextSpeech() async {
    guard !speechQueue.isEmpty else {
      transition(to: .idle, reason: "speech queue empty")
      return
    }

    let prompt = speechQueue.removeFirst()
    let promptID = UUID().uuidString
    emit(TTSStartedEvent(engineID: ttsEngine.engineID, promptID: promptID, text: prompt.text))

    let speechTimeoutSeconds = configuration.speechTimeoutSeconds
    activeSpeechTask = Task { [weak self] in
      guard let self = self else { return }
      let stream = self.ttsEngine.speak(prompt)

      await self.runSpeechStream(
        stream,
        promptID: promptID,
        speechTimeoutSeconds: speechTimeoutSeconds,
        timedOutRef: SentValueBox(initial: false)
      )
    }
  }

  func runSpeechStream(
    _ stream: AsyncStream<TTSChunk>,
    promptID: String,
    speechTimeoutSeconds: Double,
    timedOutRef: SentValueBox<Bool>
  ) async {
    let timeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(speechTimeoutSeconds * 1_000_000_000))
      timedOutRef.value = true
      await self?.stopSpeaking(reason: .timeout)
    }

    for await chunk in stream {
      if Task.isCancelled { break }
      emit(TTSChunkEvent(promptID: promptID, chunk: chunk))
      if case .failed(let detail) = chunk {
        await logger.error(
          "TTS failed [detailPresent=\(!detail.isEmpty)]", actor: .audio)
        emit(TTSStoppedEvent(promptID: promptID, reason: .error))
        timeoutTask.cancel()
        break
      }
    }

    if timedOutRef.value {
      emit(TTSStoppedEvent(promptID: promptID, reason: .timeout))
    } else if !Task.isCancelled {
      emit(TTSStoppedEvent(promptID: promptID, reason: .completed))
    }

    timeoutTask.cancel()
    await onSpeechFinished()
  }

  func onSpeechFinished() async {
    // A barge-in cancels the active speech task and clears the queue. Guard
    // so we do not transition back to idle or start the next queued prompt.
    guard !bargeInStopping, state != .listening else {
      bargeInStopping = false
      return
    }
    if speechQueue.isEmpty {
      recordSimpleCommandCompletionLatencyIfNeeded()
      transition(to: .idle, reason: "speech complete")
    } else {
      await scheduleNextSpeech()
    }
  }
}
