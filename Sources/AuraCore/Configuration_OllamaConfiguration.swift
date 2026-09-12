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
  /// backend) may be used at all. On by default under ADR-055 (2026-09-07):
  /// the owner directed that cloud-proxied inference be enabled
  /// ("Etkinleştir"). Routing decisions still key off the real
  /// `remote_host` field — a `:cloud`-suffixed name alone never decides —
  /// and every cloud inference call still runs through the
  /// `.agentOllamaCloudInference` confirmation challenge.
  public var allowCloudModels: Bool

  /// The model AURA pins for every routed request, by its exact `/api/tags`
  /// name (for example `glm-5.3-flash:cloud`). Empty means "no pin" — fall
  /// back to the capability heuristic.
  ///
  /// A pin exists because the heuristic's last rule is "smallest
  /// `sizeBytes`", and `:cloud` entries report a placeholder size of a few
  /// hundred bytes while a real local model reports gigabytes. Size therefore
  /// stopped expressing memory pressure the moment cloud models were
  /// registered, and routing collapsed onto whichever cloud entry happened to
  /// report the smallest placeholder. Naming the model is the honest way to
  /// say which model should answer.
  ///
  /// The pin is applied **after** every policy filter, never before: pinning
  /// a `:cloud` model while `allowCloudModels` is `false` selects nothing and
  /// falls back, so a pin can never widen what routing is permitted to reach.
  public var preferredModel: String

  /// Upper bound on the tokens a free-text answer may consume, sent as
  /// Ollama's `options.num_predict`. Zero omits the option and leaves the
  /// daemon's own default in force.
  ///
  /// Applies to free-text generation only. Schema-constrained requests (the
  /// ones carrying a `format`) deliberately keep sending no budget: a cap that
  /// truncates a JSON document produces an unparseable answer, which is a
  /// worse failure than a long one.
  public var responseTokenBudget: Int

  /// Ollama's `think` parameter for free-text answers: `"low"`, `"medium"`,
  /// `"high"`, or empty to omit the field and accept the model's default.
  ///
  /// Defaults to `"low"` because the pinned reasoning model spends its whole
  /// budget thinking otherwise. Measured against `glm-5.3-flash:cloud` with a
  /// 4096-token budget: thinking left on produced 12,352 characters of
  /// reasoning and an **empty** answer (`done_reason: length`); `"low"`
  /// produced a complete 10,679-character Turkish answer and no reasoning at
  /// all. `think: false` is deliberately not the default — on this model it
  /// moves the reasoning *into* the answer text rather than suppressing it.
  ///
  /// AURA never reads Ollama's `thinking` field, so tokens spent there are
  /// spent on output the product discards.
  public var thinkingEffort: String

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
    allowCloudModels: Bool = true,
    preferredModel: String = "glm-5.3-flash:cloud",
    responseTokenBudget: Int = 4096,
    thinkingEffort: String = "low",
    thermalAwarenessEnabled: Bool = true
  ) {
    self.baseURL = baseURL
    self.requestTimeoutSeconds = requestTimeoutSeconds
    self.healthCheckTimeoutSeconds = healthCheckTimeoutSeconds
    self.maxResidentModelBytes = maxResidentModelBytes
    self.estimatedResidentMemoryRatio = estimatedResidentMemoryRatio
    self.keepAliveSeconds = keepAliveSeconds
    self.allowCloudModels = allowCloudModels
    self.preferredModel = preferredModel
    self.responseTokenBudget = responseTokenBudget
    self.thinkingEffort = thinkingEffort
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
      // Passed through unchanged rather than defaulted-when-empty: an empty
      // pin is a deliberate choice ("route by capability"), not a missing
      // value, so merging must not silently re-pin it.
      preferredModel: self.preferredModel,
      responseTokenBudget: self.responseTokenBudget < 0
        ? OllamaConfiguration().responseTokenBudget
        : self.responseTokenBudget,
      // Passed through unchanged: an empty effort is a deliberate "use the
      // model's own default", not a missing value.
      thinkingEffort: self.thinkingEffort,
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
      try container.decodeIfPresent(Bool.self, forKey: .allowCloudModels) ?? true
    preferredModel =
      try container.decodeIfPresent(String.self, forKey: .preferredModel)
      ?? "glm-5.3-flash:cloud"
    responseTokenBudget =
      try container.decodeIfPresent(Int.self, forKey: .responseTokenBudget) ?? 4096
    thinkingEffort =
      try container.decodeIfPresent(String.self, forKey: .thinkingEffort) ?? "low"
    thermalAwarenessEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .thermalAwarenessEnabled) ?? true
  }
}
