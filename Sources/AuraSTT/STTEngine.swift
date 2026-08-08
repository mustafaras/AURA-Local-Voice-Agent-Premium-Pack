import AuraAudio
import AuraCore
import Foundation

/// Result of a streaming transcription call. Partials are volatile; stable
/// segments are finalized enough to be consumed by downstream intent engines.
public struct STTTranscriptResult: Sendable, Equatable {
  /// Identifies the result within a session. Correlated with the audio input
  /// frame index for latency accounting.
  public let resultID: UUID

  /// True when this is a stable segment. False when it is a partial
  /// hypothesis that may change in subsequent results.
  public let isStable: Bool

  /// Best transcript text in the current locale.
  public let text: String

  /// Alternative transcripts, ordered by confidence (highest first).
  public let alternatives: [STTAlternative]

  /// Confidence in [0, 1] for the best transcript. May be 0 for partials.
  public let confidence: Double

  /// Monotonic audio timestamp of the first sample that contributed to this
  /// result (seconds). Used for latency math, not wall-clock display.
  public let audioStartTime: TimeInterval

  /// Monotonic audio timestamp of the last sample that contributed to this
  /// result (seconds).
  public let audioEndTime: TimeInterval

  /// Engine-specific metadata, safe to log at `debug` level only.
  public let metadata: [String: String]

  public init(
    resultID: UUID,
    isStable: Bool,
    text: String,
    alternatives: [STTAlternative] = [],
    confidence: Double = 0,
    audioStartTime: TimeInterval = 0,
    audioEndTime: TimeInterval = 0,
    metadata: [String: String] = [:]
  ) {
    self.resultID = resultID
    self.isStable = isStable
    self.text = text
    self.alternatives = alternatives
    self.confidence = confidence
    self.audioStartTime = audioStartTime
    self.audioEndTime = audioEndTime
    self.metadata = metadata
  }
}

/// Health/status of an underlying STT engine.
public struct STTHealth: Sendable, Equatable {
  /// Overall readiness to accept streaming audio.
  public let ready: Bool

  /// Short machine-readable status label.
  public let status: String

  /// Human-readable detail. Avoid embedding private content.
  public let detail: String

  /// Actual adapter selected for the current session. Empty means the
  /// adapter has not selected a backend yet.
  public let engineID: String

  /// Locale currently presented by the selected adapter.
  public let locale: String

  /// Whether the adapter is configured to keep recognition local/offline.
  public let supportsOffline: Bool

  /// Timestamp of the last successful result, if any.
  public let lastResultTimestamp: Date?

  public init(
    ready: Bool,
    status: String,
    detail: String,
    lastResultTimestamp: Date? = nil,
    engineID: String = "",
    locale: String = "",
    supportsOffline: Bool = false
  ) {
    self.ready = ready
    self.status = status
    self.detail = detail
    self.lastResultTimestamp = lastResultTimestamp
    self.engineID = engineID
    self.locale = locale
    self.supportsOffline = supportsOffline
  }
}

/// Streaming STT engine contract.
///
/// Implementations produce `STTTranscriptResult` values asynchronously.
/// Consumers must distinguish `isStable` segments (safe for intent execution
/// under policy) from partials (display-only until they stabilize).
///
/// Cancellation is synchronous so that consumers can immediately tear down a
/// session without leaking audio. Implementations must complete any pending
/// work promptly.
public protocol STTEngine: Sendable {
  /// Unique identifier for this engine adapter.
  var engineID: String { get }

  /// The language tag the engine is currently configured for (e.g. "tr-TR",
  /// "en-US"). The orchestrator may select an engine per language or route
  /// both through a bilingual-capable engine.
  var locale: Locale { get }

  /// Start the engine, reporting initial health.
  func start() async throws -> STTHealth

  /// Submit one audio frame. Results are returned through `results`.
  /// `activationTime` is the monotonic timestamp when the wake activation
  /// began; engines use it to compute first-partial latency.
  func ingest(_ frame: AudioFrame, activationTime: TimeInterval) async

  /// Signal end of one user-speech session. The engine may finalize remaining
  /// segments, but must keep `results` usable for later sessions.
  func finalizeSession() async

  /// Cancel the current session immediately. Must stop emitting results and
  /// reset session state. This does not end the engine-lifetime `results`
  /// sequence; consumers cancel their own iterator when shutting down.
  func cancel() async

  /// Async sequence of transcription results. Implementations are responsible
  /// for backpressure handling.
  var results: AsyncStream<STTTranscriptResult> { get }

  /// Current engine health snapshot.
  func health() -> STTHealth
}
