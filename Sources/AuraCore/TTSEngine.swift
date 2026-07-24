import Foundation

/// A single text fragment prepared for speech synthesis, with optional
/// prosodic hints that adapters may interpret when supported.
public struct TTSPrompt: Sendable, Equatable, Codable {
  /// Text to speak. Must be already sanitized; secrets must never be passed.
  public let text: String

  /// Optional locale override (e.g. "tr-TR", "en-US"). Empty means default.
  public let locale: String

  /// Speech rate multiplier. 1.0 is normal; 0.5 is half speed; 2.0 is double.
  public let rate: Double

  /// Emphasis hint in [0, 1]. Higher values request stronger prominence.
  public let emphasis: Double

  /// Whether this prompt should interrupt any currently speaking prompt.
  public let interruptible: Bool

  public init(
    text: String,
    locale: String = "",
    rate: Double = 1.0,
    emphasis: Double = 0.0,
    interruptible: Bool = true
  ) {
    self.text = text
    self.locale = locale
    self.rate = rate
    self.emphasis = emphasis
    self.interruptible = interruptible
  }
}

/// A chunk of synthesized audio or a status marker emitted by a TTS engine.
/// Real adapters stream PCM buffers; the mock adapter emits progress markers.
public enum TTSChunk: Sendable, Equatable, Codable {
  /// A progress marker carrying the textual fragment just synthesized and the
  /// byte offset in the conceptual audio stream. Real adapters would carry a
  /// buffer identifier and sample count instead of raw samples.
  case progress(fragment: String, byteOffset: UInt64)

  /// Synthesis has completed for the current prompt.
  case complete

  /// Synthesis failed. The detail must not include secrets.
  case failed(String)
}

/// Health/status snapshot for a TTS engine.
public struct TTSHealth: Sendable, Equatable, Codable {
  public let ready: Bool
  public let status: String
  public let detail: String

  public init(ready: Bool, status: String, detail: String) {
    self.ready = ready
    self.status = status
    self.detail = detail
  }
}

/// Text-to-speech adapter contract. Implementations must be `Sendable`, handle
/// their own isolation, and never block callers.
///
/// All adapters are local by default. A remote adapter must only be selected
/// under an explicit user-controlled setting.
public protocol TTSEngine: Sendable {
  /// Unique adapter identifier (e.g. "chatterbox", "dia", "system").
  var engineID: String { get }

  /// Start the engine if needed. Idempotent.
  func start() async throws(AuraError) -> TTSHealth

  /// Speak a prompt. Returns an `AsyncStream` of synthesized audio/status
  /// chunks. Consumers must call `stopSpeaking()` to interrupt.
  func speak(_ prompt: TTSPrompt) -> AsyncStream<TTSChunk>

  /// Stop speaking the current prompt and drop queued prompts. The active
  /// stream must finish promptly.
  func stopSpeaking() async

  /// Pause/resume the current prompt if supported.
  func pauseSpeaking() async
  func resumeSpeaking() async

  /// Current health snapshot.
  func health() -> TTSHealth
}

/// A priority-ordered TTS engine selection. Adapters are tried in order; the
/// first one that reports `ready` is used for each prompt.
public struct TTSAdapterChain: Sendable, Equatable, Codable {
  public var adapterIDs: [String]

  public init(adapterIDs: [String] = ["chatterbox", "dia", "system"]) {
    self.adapterIDs = adapterIDs
  }

  public func validate() throws(AuraError) {
    guard !adapterIDs.isEmpty else {
      throw AuraError.invalidConfiguration("tts adapter chain must not be empty")
    }
    for id in adapterIDs {
      guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AuraError.invalidConfiguration("tts adapter id must not be empty")
      }
    }
  }
}
