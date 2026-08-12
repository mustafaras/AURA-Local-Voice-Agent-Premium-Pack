import AuraAudio
import AuraCore
import Foundation

extension Conversation {
  // MARK: - Timeout handling

  func scheduleTimeout(for targetState: ConversationState, after seconds: Double) {
    timeoutTask?.cancel()
    timeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      guard let self = self else { return }
      await self.timeoutReached(target: targetState)
    }
  }

  func timeoutReached(target targetState: ConversationState) async {
    guard state == targetState else { return }
    await cancelTimeout()
    await stopSpeaking(reason: .timeout)
    emit(
      ConversationTimeoutEvent(
        stateAtTimeout: targetState, timeoutKind: "\(targetState.rawValue) timeout"))
    transition(to: .timeout, reason: "\(targetState.rawValue) timeout")
  }

  func cancelTimeout() async {
    timeoutTask?.cancel()
    timeoutTask = nil
  }
}
