import Foundation

public struct OllamaConfiguration: Codable, Sendable, Equatable {
  /// Base URL of the local Ollama daemon's HTTP API. Must resolve to a
  /// loopback host (`127.0.0.1`, `::1`, or `localhost`) — `validate()`
  /// rejects any other host so AURA can never be silently pointed at a
  /// remote Ollama instance.
  public var baseURL: String

  /// Timeout in seconds for a single inference request (`/api/generate` or
  /// `/api/chat`). Local models can take tens of seconds to load on first
  /// use, so this is deliberately generous.
  public var requestTimeoutSeconds: Double

  /// Timeout in seconds for the lightweight health probe (`/api/version`).
  public var healthCheckTimeoutSeconds: Double

  /// Soft ceiling on the combined `size_vram` of all currently resident
  /// models (per `/api/ps`) before a new model load is refused or a
  /// least-recently-used model is unloaded first. Defaults conservatively
  /// for the documented 16 GB unified-memory target profile, leaving
  /// headroom for STT/TTS/vision models running elsewhere in AURA.
  public var maxResidentModelBytes: UInt64

  /// A not-yet-resident candidate model is only known by its `/api/tags`
  /// on-disk file size; the budget check estimates its real resident
  /// footprint as `sizeBytes * estimatedResidentMemoryRatio` rather than
  /// treating on-disk size as if it were VRAM. Real quantized GGUF models
  /// commonly resolve to a resident footprint well under their on-disk
  /// size (observed: `gemma4:latest` at 9.6 GB on disk, ~3.2 GB
  /// `size_vram` once loaded, `EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01`).
  /// Defaults to 0.5 — a conservative margin above that ~0.33 observed
  /// ratio, so the estimate still overshoots real usage rather than
  /// risking under-budgeting. Already-resident models bypass this
  /// estimate entirely and use their real measured `size_vram`.
  public var estimatedResidentMemoryRatio: Double

  /// Seconds an idle model is kept resident before Ollama unloads it,
  /// passed as `keep_alive` on every request.
  public var keepAliveSeconds: Double

  /// Whether models whose `/api/tags` entry reports a non-empty
  /// `remote_host` (Ollama's `:cloud` models, proxied to Ollama's hosted
  /// backend) may be used at all. `false` by default — "local does not mean
  /// safe" cuts both ways: a `:cloud`-suffixed name is a naming convention,
  /// not a contract, so routing decisions must key off the real
  /// `remote_host` field, and cloud-proxied inference must be an explicit
  /// opt-in, not a silent default.
  public var allowCloudModels: Bool

  /// Whether a new model load is refused while
  /// `ProcessInfo.processInfo.thermalState` is `.critical`.
  public var thermalAwarenessEnabled: Bool

  public init(
    baseURL: String = "http://127.0.0.1:11434",
    requestTimeoutSeconds: Double = 120.0,
    healthCheckTimeoutSeconds: Double = 5.0,
    maxResidentModelBytes: UInt64 = 6_000_000_000,
    estimatedResidentMemoryRatio: Double = 0.5,
    keepAliveSeconds: Double = 300.0,
    allowCloudModels: Bool = false,
    thermalAwarenessEnabled: Bool = true
  ) {
    self.baseURL = baseURL
    self.requestTimeoutSeconds = requestTimeoutSeconds
    self.healthCheckTimeoutSeconds = healthCheckTimeoutSeconds
    self.maxResidentModelBytes = maxResidentModelBytes
    self.estimatedResidentMemoryRatio = estimatedResidentMemoryRatio
    self.keepAliveSeconds = keepAliveSeconds
    self.allowCloudModels = allowCloudModels
    self.thermalAwarenessEnabled = thermalAwarenessEnabled
  }

  /// Hosts AURA will accept as the Ollama daemon's `baseURL`. Anything else
  /// is rejected by `validate()`.
  public static let allowedLoopbackHosts: Set<String> = ["127.0.0.1", "::1", "localhost"]

  public func validate() throws(AuraError) {
    guard !baseURL.isEmpty else {
      throw AuraError.invalidConfiguration("ollama baseURL must not be empty")
    }
    guard let url = URL(string: baseURL), let host = url.host, !host.isEmpty else {
      throw AuraError.invalidConfiguration("ollama baseURL must be a valid URL with a host")
    }
    guard Self.allowedLoopbackHosts.contains(host) else {
      throw AuraError.invalidConfiguration(
        "ollama baseURL host '\(host)' must be a loopback address (127.0.0.1, ::1, or localhost)")
    }
    guard requestTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("ollama requestTimeoutSeconds must be positive")
    }
    guard healthCheckTimeoutSeconds > 0 else {
      throw AuraError.invalidConfiguration("ollama healthCheckTimeoutSeconds must be positive")
    }
    guard maxResidentModelBytes > 0 else {
      throw AuraError.invalidConfiguration("ollama maxResidentModelBytes must be positive")
    }
    guard estimatedResidentMemoryRatio > 0 && estimatedResidentMemoryRatio <= 1 else {
      throw AuraError.invalidConfiguration(
        "ollama estimatedResidentMemoryRatio must be in (0, 1]")
    }
    guard keepAliveSeconds >= 0 else {
      throw AuraError.invalidConfiguration("ollama keepAliveSeconds must be non-negative")
    }
  }

  /// Merge a partial configuration over the hard-coded defaults.
  public func mergedWithDefaults() -> OllamaConfiguration {
    OllamaConfiguration(
      baseURL: self.baseURL.isEmpty ? OllamaConfiguration().baseURL : self.baseURL,
      requestTimeoutSeconds: self.requestTimeoutSeconds <= 0
        ? OllamaConfiguration().requestTimeoutSeconds
        : self.requestTimeoutSeconds,
      healthCheckTimeoutSeconds: self.healthCheckTimeoutSeconds <= 0
        ? OllamaConfiguration().healthCheckTimeoutSeconds
        : self.healthCheckTimeoutSeconds,
      maxResidentModelBytes: self.maxResidentModelBytes == 0
        ? OllamaConfiguration().maxResidentModelBytes
        : self.maxResidentModelBytes,
      estimatedResidentMemoryRatio: self.estimatedResidentMemoryRatio <= 0
        || self.estimatedResidentMemoryRatio > 1
        ? OllamaConfiguration().estimatedResidentMemoryRatio
        : self.estimatedResidentMemoryRatio,
      keepAliveSeconds: self.keepAliveSeconds < 0
        ? OllamaConfiguration().keepAliveSeconds
        : self.keepAliveSeconds,
      allowCloudModels: self.allowCloudModels,
      thermalAwarenessEnabled: self.thermalAwarenessEnabled
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    baseURL =
      try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "http://127.0.0.1:11434"
    requestTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .requestTimeoutSeconds) ?? 120.0
    healthCheckTimeoutSeconds =
      try container.decodeIfPresent(Double.self, forKey: .healthCheckTimeoutSeconds) ?? 5.0
    maxResidentModelBytes =
      try container.decodeIfPresent(UInt64.self, forKey: .maxResidentModelBytes) ?? 6_000_000_000
    estimatedResidentMemoryRatio =
      try container.decodeIfPresent(Double.self, forKey: .estimatedResidentMemoryRatio) ?? 0.5
    keepAliveSeconds =
      try container.decodeIfPresent(Double.self, forKey: .keepAliveSeconds) ?? 300.0
    allowCloudModels =
      try container.decodeIfPresent(Bool.self, forKey: .allowCloudModels) ?? false
    thermalAwarenessEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .thermalAwarenessEnabled) ?? true
  }
}
