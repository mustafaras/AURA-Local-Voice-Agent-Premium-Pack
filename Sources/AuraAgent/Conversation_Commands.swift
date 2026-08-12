import AuraAudio
import AuraCore
import Foundation

extension Conversation {
  // MARK: - Deterministic commands

  func handleDeterministicCommand(_ command: String) async {
    let normalized = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

    if configuration.deterministicStopCommands.contains(normalized) {
      await stop()
      return
    }

    if configuration.deterministicPauseResumeCommands.contains(normalized) {
      await pauseResumeToggled()
      return
    }

    // Otherwise treat it as a completed turn carrying the command.
    simpleCommandTurn = true
    let completed = TurnCompletedEvent(
      text: currentTurnText,
      confidence: currentTurnConfidence,
      isFinal: true,
      deterministicCommand: normalized,
      requiresPolicyReview: false,
      turnContext: activeTurnContext
    )
    emit(completed)
    await cancelTimeout()
    transition(to: .thinking, reason: "deterministic command: \(normalized)")
    scheduleTimeout(for: .thinking, after: configuration.thinkTimeoutSeconds)
  }
}
