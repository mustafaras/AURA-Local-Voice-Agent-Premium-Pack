import AuraCore
import Foundation

extension WakeWordPipeline {
  /// Start listening to audio frame events.
  public func start() async {
    guard subscriptionTask == nil else { return }
    state = privacyMode ? .privacyArmed : .listening
    await eventBus.subscribe(AudioFrameEvent.self) { [weak self] envelope in
      guard let self = self, !Task.isCancelled else { return }
      await self.handleFrameEvent(envelope.payload)
    }
    subscriptionTask = Task {
      // Keep the task alive while subscribed; the handler closure is invoked by the bus.
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    await logger.info("Wake-word pipeline started", actor: .audio)
  }

  /// Stop listening and reset detectors.
  public func stop() async {
    subscriptionTask?.cancel()
    subscriptionTask = nil
    activationEndTask?.cancel()
    activationEndTask = nil
    state = privacyMode ? .privacyArmed : .idle
    activeTurnContext = nil
    retainedFrames.removeAll(keepingCapacity: true)
    vad.reset()
    wakeDetector.reset()
    await logger.info("Wake-word pipeline stopped", actor: .audio)
  }

  /// Enable or disable privacy mode. When enabled and keyboard-shortcut-only
  /// is required, wake-word detection is suppressed until the keyboard
  /// shortcut arms the pipeline.
  public func setPrivacyMode(_ enabled: Bool, triggeredByKeyboardShortcut: Bool = false) async {
    privacyMode = enabled
    await emitPrivacyModeEvent(
      enabled: enabled, triggeredByKeyboardShortcut: triggeredByKeyboardShortcut)
    if enabled {
      state =
        privacyModeRequiresShortcut && !triggeredByKeyboardShortcut ? .privacyArmed : .listening
    } else {
      state = .listening
    }
    await logger.info("Privacy mode \(enabled ? "enabled" : "disabled")", actor: .audio)
  }

  /// Arm privacy-mode listening when the user presses the configured keyboard
  /// shortcut. This is the only way to re-arm listening in shortcut-only mode.
  public func privacyShortcutPressed() async {
    guard privacyMode else { return }
    state = .listening
    await logger.info("Privacy mode listening armed by keyboard shortcut", actor: .audio)
  }

  /// Notify the pipeline that assistant output is currently playing. This is
  /// used by anti-trigger suppression to reject wake hypotheses caused by TTS
  /// or other system audio.
  public func setOutputActive(_ active: Bool) async {
    isOutputActive = active
  }

  /// Current metrics snapshot.
  public func currentMetrics() -> Metrics {
    metrics
  }

  /// Current pipeline state.
  public func currentState() -> State {
    state
  }
}
