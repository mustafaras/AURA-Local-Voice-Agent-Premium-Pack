import AuraAudio
import AuraCore
import Foundation

extension Conversation {
  // MARK: - Latency measurement

  func recordWakeToAckLatencyIfNeeded() {
    guard let start = wakeStartTime, !wakeToAckRecorded else { return }
    let latency = monotonicClock() - start
    wakeToAckRecorded = true
    emit(
      LatencyMeasuredEvent(
        kind: .wakeToAck,
        latencySeconds: latency,
        budgetSeconds: 0.5,
        turnContext: activeTurnContext))
  }

  func recordSimpleCommandCompletionLatencyIfNeeded() {
    guard simpleCommandTurn, let start = wakeStartTime else { return }
    emit(
      LatencyMeasuredEvent(
        kind: .simpleCommandCompletion,
        latencySeconds: monotonicClock() - start,
        budgetSeconds: 1.5,
        turnContext: activeTurnContext))
  }

  func stopSpeaking(reason: TTSStopReason) async {
    activeSpeechTask?.cancel()
    activeSpeechTask = nil
    await ttsEngine.stopSpeaking()
    // Any in-flight stream will finish; the task loop emits TTSStoppedEvent.
  }
}
