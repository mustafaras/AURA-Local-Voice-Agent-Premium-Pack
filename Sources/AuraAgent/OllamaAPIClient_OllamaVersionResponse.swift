import AuraCore
import AuraSecurity
import Foundation

// MARK: - Real, verified Ollama HTTP API shapes
//
// Verified against a real, locally running `ollama serve` (version 0.32.3,
// installed at /opt/homebrew/bin/ollama) on 2026-07-25 via `GET
// /api/version`, `GET /api/tags`, `GET /api/ps`, `POST /api/generate`
// (both plain and with a `format` JSON Schema, and with `keep_alive: 0` to
// force an unload), and a request for a nonexistent model (404 + `{"error":
// ...}`). Every field decoded below was observed in a real response; fields
// this phase does not need (`context`, `tensors`, `model_info`'s dynamic
// per-architecture keys from `/api/show`) are deliberately not modeled —
// `/api/show` itself is not used at all, since `/api/tags` already carries
// every field this phase's registry needs (`size`, `capabilities`,
// `remote_host`), and `/api/show`'s `model_info` uses per-architecture key
// prefixes (e.g. `gemma4.context_length`) that would require fragile,
// unverifiable guessing to consume generically.
//
// All response bodies observed are consistently snake_case, so (unlike
// Claude's mixed-convention JSONL) a single `.convertFromSnakeCase` decoder
// strategy is sufficient and used throughout this file.

/// `GET /api/version`.
public struct OllamaVersionResponse: Codable, Sendable, Equatable {
  public let version: String

  public init(version: String) {
    self.version = version
  }
}
