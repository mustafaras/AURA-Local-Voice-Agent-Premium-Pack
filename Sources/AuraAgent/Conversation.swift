import AuraAudio
import AuraCore
import Foundation

struct PendingConversationContinuation {
  let event: STTStableSegmentEvent
  let context: TurnContext?
  let id: UUID
}

/// Conversation state machine and TTS scheduler.
///
/// This actor owns the canonical turn state, handles barge-in, timeout, and
/// deterministic voice commands, and coordinates with the TTS adapter. It does
/// not execute tools or access LLM output directly; it consumes typed intent
/// and response-plan events and emits typed conversation and TTS events.
public actor Conversation {
  public var state: ConversationState = .idle

  let configuration: ConversationConfiguration
  let ttsConfiguration: TTSConfiguration
  let eventBus: AuraEventBus
  let logger: AuraLogger
  let sessionID: UUID

  /// The active TTS engine. In a full build this would be selected from the
  /// adapter chain by the orchestrator; for the Phase 4 slice the engine is
  /// injected directly so tests can use the mock.
  let ttsEngine: any TTSEngine

  /// Queue of prompts awaiting speech. The first prompt is the active one.
  var speechQueue: [TTSPrompt] = []
  var activeSpeechTask: Task<Void, Never>?
  var bargeInGraceUntil: TimeInterval = 0
  var bargeInStopping: Bool = false

  /// Timer for the listening timeout. Cancelled on state change.
  var timeoutTask: Task<Void, Never>?
  var continuationTask: Task<Void, Never>?
  var pendingContinuation: PendingConversationContinuation?

  /// Accumulated transcript text for the current listening turn.
  var currentTurnText: String = ""
  var currentTurnConfidence: Double = 0
  var activeTurnContext: TurnContext?

  /// Monotonic clock source used for all latency math in this actor.
  let monotonicClock: () -> TimeInterval

  /// Timestamp of the most recent accepted wake activation, measured with
  /// `monotonicClock`. Nil when not in an active turn.
  var wakeStartTime: TimeInterval?

  /// Set to true once the first spoken response plan of the current turn has
  /// been used to emit a wake-to-ack latency measurement.
  var wakeToAckRecorded: Bool = false

  /// Set to true when the current turn carries a deterministic command that
  /// does not require a remote model, so `onSpeechFinished()` can record the
  /// simple-command completion latency.
  var simpleCommandTurn: Bool = false

  public init(
    configuration: ConversationConfiguration,
    ttsConfiguration: TTSConfiguration,
    ttsEngine: any TTSEngine,
    eventBus: AuraEventBus,
    logger: AuraLogger,
    monotonicClock: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() },
    sessionID: UUID = UUID()
  ) {
    self.configuration = configuration
    self.ttsConfiguration = ttsConfiguration
    self.ttsEngine = ttsEngine
    self.eventBus = eventBus
    self.logger = logger
    self.sessionID = sessionID
    self.monotonicClock = monotonicClock
  }

}

// MARK: - Thread-safe mutable box for isolated non-Sendable state

/// Holds a mutable value in a `@unchecked Sendable` box. Used inside an actor
/// task boundary to avoid capturing non-Sendable state across `Task` closures.
final class SentValueBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T

  init(initial value: T) {
    self._value = value
  }

  var value: T {
    get {
      lock.withLock { _value }
    }
    set {
      lock.withLock { _value = newValue }
    }
  }
}
