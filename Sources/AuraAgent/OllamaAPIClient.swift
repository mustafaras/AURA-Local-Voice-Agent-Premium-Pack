import AuraCore
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

/// One entry of `GET /api/tags`'s `models` array.
public struct OllamaTagsModel: Codable, Sendable, Equatable {
  public let name: String
  public let remoteHost: String?
  public let size: UInt64
  public let details: Details
  public let capabilities: [String]

  public init(
    name: String, remoteHost: String? = nil, size: UInt64, details: Details,
    capabilities: [String]
  ) {
    self.name = name
    self.remoteHost = remoteHost
    self.size = size
    self.details = details
    self.capabilities = capabilities
  }

  public struct Details: Codable, Sendable, Equatable {
    public let family: String?
    public let parameterSize: String?
    public let quantizationLevel: String?
    /// Only reliably present for `:cloud` models in real observations; local
    /// GGUF entries (e.g. `gemma4:latest`) omitted it entirely. Treated as
    /// best-effort, never required.
    public let contextLength: Int?

    public init(
      family: String? = nil, parameterSize: String? = nil, quantizationLevel: String? = nil,
      contextLength: Int? = nil
    ) {
      self.family = family
      self.parameterSize = parameterSize
      self.quantizationLevel = quantizationLevel
      self.contextLength = contextLength
    }
  }
}

/// `GET /api/tags`'s top-level envelope.
public struct OllamaTagsResponse: Codable, Sendable, Equatable {
  public let models: [OllamaTagsModel]

  public init(models: [OllamaTagsModel]) {
    self.models = models
  }
}

/// One entry of `GET /api/ps`'s `models` array — currently resident models.
public struct OllamaPsModel: Codable, Sendable, Equatable {
  public let name: String
  public let size: UInt64
  public let sizeVram: UInt64
  public let expiresAt: String
  public let contextLength: Int?

  public init(
    name: String, size: UInt64, sizeVram: UInt64, expiresAt: String, contextLength: Int? = nil
  ) {
    self.name = name
    self.size = size
    self.sizeVram = sizeVram
    self.expiresAt = expiresAt
    self.contextLength = contextLength
  }
}

/// `GET /api/ps`'s top-level envelope.
public struct OllamaPsResponse: Codable, Sendable, Equatable {
  public let models: [OllamaPsModel]

  public init(models: [OllamaPsModel]) {
    self.models = models
  }
}

/// `POST /api/generate` (`stream: false`) response.
public struct OllamaGenerateResponse: Codable, Sendable, Equatable {
  public let model: String
  public let response: String
  public let done: Bool
  public let doneReason: String?
  public let totalDuration: Int?
  public let evalCount: Int?

  public init(
    model: String, response: String, done: Bool, doneReason: String? = nil,
    totalDuration: Int? = nil, evalCount: Int? = nil
  ) {
    self.model = model
    self.response = response
    self.done = done
    self.doneReason = doneReason
    self.totalDuration = totalDuration
    self.evalCount = evalCount
  }
}

/// The error envelope Ollama returns on non-2xx responses, e.g.
/// `{"error":"model 'x' not found"}` with HTTP 404.
public struct OllamaErrorResponse: Codable, Sendable, Equatable {
  public let error: String

  public init(error: String) {
    self.error = error
  }
}

/// A narrow, purpose-built JSON Schema representation covering exactly the
/// shape verified to work against `/api/generate`'s `format` parameter — a
/// flat object with string/enum properties. This is not a general JSON
/// Schema DSL; AURA only ever asks Ollama to constrain output to the two
/// capability-shaped schemas below.
public struct OllamaFormatSchema: Codable, Sendable, Equatable {
  public let type: String
  public let properties: [String: Property]
  public let required: [String]

  public struct Property: Codable, Sendable, Equatable {
    public let type: String
    public let `enum`: [String]?

    public init(type: String, enum values: [String]? = nil) {
      self.type = type
      self.enum = values
    }
  }

  /// `{"classification": {"type": "string", "enum": labels}}`, required.
  /// Verified: this exact shape, sent as `format`, made a real local model
  /// return `{"classification": "urgent"}` for a two-label request.
  public static func classification(labels: [String]) -> OllamaFormatSchema {
    OllamaFormatSchema(
      type: "object",
      properties: ["classification": Property(type: "string", enum: labels)],
      required: ["classification"]
    )
  }

  /// `{"summary": {"type": "string"}}`, required.
  public static let summary = OllamaFormatSchema(
    type: "object",
    properties: ["summary": Property(type: "string")],
    required: ["summary"]
  )

  public static let nlu = OllamaFormatSchema(
    type: "object",
    properties: [
      "dialogue_act": Property(
        type: "string", enum: ["answer", "execute", "clarify", "confirm", "delegate", "cancel"]),
      "language": Property(type: "string", enum: ["turkish", "english", "mixed", "unknown"]),
      "capability_id": Property(type: "string"),
      "confidence": Property(type: "string"),
      "ambiguity_reason": Property(type: "string"),
    ],
    required: ["dialogue_act", "language", "capability_id", "confidence", "ambiguity_reason"]
  )
}

/// Decoded, schema-validated result of a classification request.
public struct OllamaClassificationResult: Codable, Sendable, Equatable {
  public let classification: String
}

/// Decoded, schema-validated result of a summarization request.
public struct OllamaSummaryResult: Codable, Sendable, Equatable {
  public let summary: String
}

public struct OllamaNLUResult: Codable, Sendable, Equatable {
  public let dialogueAct: String
  public let language: String
  public let capabilityID: String
  public let confidence: String
  public let ambiguityReason: String

  public enum CodingKeys: String, CodingKey {
    case dialogueAct = "dialogue_act"
    case language
    case capabilityID = "capability_id"
    case confidence
    case ambiguityReason = "ambiguity_reason"
  }
}

/// Network seam for the Ollama local HTTP API, mirroring the
/// `AdapterProcessExecuting` seam used by the CLI-spawning adapters: a
/// protocol plus a production implementation, so tests never make a real
/// network call.
public protocol OllamaAPIClient: Sendable {
  func health() async throws -> OllamaVersionResponse
  func listModels() async throws -> [OllamaTagsModel]
  func listRunningModels() async throws -> [OllamaPsModel]
  func generate(
    model: String, prompt: String, format: OllamaFormatSchema?, keepAliveSeconds: Double
  ) async throws -> OllamaGenerateResponse
  /// Forces an immediate unload via `keep_alive: 0` — verified real
  /// behavior: the daemon evicts the model and returns `done_reason:
  /// "unload"` with an empty `response`.
  func unload(model: String) async throws
}

/// Production `OllamaAPIClient` backed by `URLSession`, talking only to the
/// configured (loopback-validated) `baseURL`.
public struct URLSessionOllamaAPIClient: OllamaAPIClient {
  private let baseURL: URL
  private let requestTimeoutSeconds: Double
  private let healthCheckTimeoutSeconds: Double
  private let session: URLSession

  public init(configuration: OllamaConfiguration) throws(AuraError) {
    guard let url = URL(string: configuration.baseURL) else {
      throw AuraError.invalidConfiguration("ollama baseURL is not a valid URL")
    }
    self.baseURL = url
    self.requestTimeoutSeconds = configuration.requestTimeoutSeconds
    self.healthCheckTimeoutSeconds = configuration.healthCheckTimeoutSeconds
    self.session = URLSession(configuration: .ephemeral)
  }

  public func health() async throws -> OllamaVersionResponse {
    try await get("/api/version", timeoutSeconds: healthCheckTimeoutSeconds)
  }

  public func listModels() async throws -> [OllamaTagsModel] {
    let response: OllamaTagsResponse = try await get(
      "/api/tags", timeoutSeconds: requestTimeoutSeconds)
    return response.models
  }

  public func listRunningModels() async throws -> [OllamaPsModel] {
    let response: OllamaPsResponse = try await get("/api/ps", timeoutSeconds: requestTimeoutSeconds)
    return response.models
  }

  public func generate(
    model: String, prompt: String, format: OllamaFormatSchema?, keepAliveSeconds: Double
  ) async throws -> OllamaGenerateResponse {
    struct Body: Encodable {
      let model: String
      let prompt: String
      let stream: Bool
      let format: OllamaFormatSchema?
      let keepAlive: Double

      enum CodingKeys: String, CodingKey {
        case model, prompt, stream, format
        case keepAlive = "keep_alive"
      }
    }
    let body = Body(
      model: model, prompt: prompt, stream: false, format: format, keepAlive: keepAliveSeconds)
    return try await post("/api/generate", body: body, timeoutSeconds: requestTimeoutSeconds)
  }

  public func unload(model: String) async throws {
    struct Body: Encodable {
      let model: String
      let keepAlive: Int

      enum CodingKeys: String, CodingKey {
        case model
        case keepAlive = "keep_alive"
      }
    }
    let _: OllamaGenerateResponse = try await post(
      "/api/generate", body: Body(model: model, keepAlive: 0), timeoutSeconds: requestTimeoutSeconds)
  }

  // MARK: - Transport

  private func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }

  private func get<Response: Decodable>(_ path: String, timeoutSeconds: Double) async throws
    -> Response
  {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "GET"
    request.timeoutInterval = timeoutSeconds
    return try await send(request)
  }

  private func post<Body: Encodable, Response: Decodable>(
    _ path: String, body: Body, timeoutSeconds: Double
  ) async throws -> Response {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = "POST"
    request.timeoutInterval = timeoutSeconds
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Every `Body` type below declares its own explicit `CodingKeys`
    // (matching the project convention of never relying on a blind
    // camel/snake-case conversion strategy), so no key-encoding strategy is
    // set here.
    request.httpBody = try JSONEncoder().encode(body)
    return try await send(request)
  }

  private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
    let (data, urlResponse): (Data, URLResponse)
    do {
      (data, urlResponse) = try await session.data(for: request)
    } catch {
      throw AuraError.ollamaError("network error: \(error.localizedDescription)")
    }
    guard let httpResponse = urlResponse as? HTTPURLResponse else {
      throw AuraError.ollamaError("non-HTTP response from Ollama daemon")
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      if let errorBody = try? makeDecoder().decode(OllamaErrorResponse.self, from: data) {
        throw AuraError.ollamaError("\(errorBody.error) (HTTP \(httpResponse.statusCode))")
      }
      throw AuraError.ollamaError("HTTP \(httpResponse.statusCode)")
    }
    do {
      return try makeDecoder().decode(Response.self, from: data)
    } catch {
      throw AuraError.ollamaError("decode failed: \(error)")
    }
  }
}
