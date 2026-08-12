import AuraCore
import AuraSecurity
import Foundation

private final class OllamaRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

private struct OllamaGenerateRequestBody: Encodable {
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

private struct OllamaUnloadRequestBody: Encodable {
  let model: String
  let keepAlive: Int

  enum CodingKeys: String, CodingKey {
    case model
    case keepAlive = "keep_alive"
  }
}

/// Production `OllamaAPIClient` backed by `URLSession`, talking only to the
/// configured (loopback-validated) `baseURL`.
public struct URLSessionOllamaAPIClient: OllamaAPIClient {
  private let baseURL: URL
  private let requestTimeoutSeconds: Double
  private let healthCheckTimeoutSeconds: Double
  private let session: URLSession
  private let endpointPolicy: NetworkEndpointPolicy

  public init(configuration: OllamaConfiguration) throws(AuraError) {
    guard let url = URL(string: configuration.baseURL) else {
      throw AuraError.invalidConfiguration("ollama baseURL is not a valid URL")
    }
    let policy = NetworkEndpointPolicy(
      allowlist: NetworkAllowlist(allowedHosts: OllamaConfiguration.allowedLoopbackHosts),
      allowedSchemes: ["http", "https"],
      allowedPorts: [11434],
      maximumResponseBytes: 10 * 1024 * 1024)
    do {
      try policy.validate(url)
    } catch {
      throw .invalidConfiguration(
        "ollama baseURL failed network policy: \(error.localizedDescription)")
    }
    self.baseURL = url
    self.requestTimeoutSeconds = configuration.requestTimeoutSeconds
    self.healthCheckTimeoutSeconds = configuration.healthCheckTimeoutSeconds
    self.endpointPolicy = policy
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.httpShouldSetCookies = false
    sessionConfiguration.httpCookieStorage = nil
    sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
    self.session = URLSession(
      configuration: sessionConfiguration,
      delegate: OllamaRedirectRejectingDelegate(),
      delegateQueue: nil)
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
    let body = OllamaGenerateRequestBody(
      model: model, prompt: prompt, stream: false, format: format, keepAlive: keepAliveSeconds)
    return try await post("/api/generate", body: body, timeoutSeconds: requestTimeoutSeconds)
  }

  public func unload(model: String) async throws {
    let _: OllamaGenerateResponse = try await post(
      "/api/generate",
      body: OllamaUnloadRequestBody(model: model, keepAlive: 0),
      timeoutSeconds: requestTimeoutSeconds
    )
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
    guard let requestURL = request.url else {
      throw AuraError.ollamaError("request has no URL")
    }
    do {
      try validateRequestURL(requestURL)
    } catch {
      throw AuraError.ollamaError(
        "network policy denied Ollama request: \(error.localizedDescription)")
    }
    let (data, urlResponse): (Data, URLResponse)
    do {
      (data, urlResponse) = try await session.data(for: request)
    } catch {
      throw AuraError.ollamaError("network error: \(error.localizedDescription)")
    }
    guard let httpResponse = urlResponse as? HTTPURLResponse else {
      throw AuraError.ollamaError("non-HTTP response from Ollama daemon")
    }
    guard let responseURL = httpResponse.url else {
      throw AuraError.ollamaError("Ollama response has no URL")
    }
    do {
      try endpointPolicy.validate(responseURL)
    } catch {
      throw AuraError.ollamaError(
        "network policy denied Ollama response: \(error.localizedDescription)")
    }
    guard data.count <= endpointPolicy.maximumResponseBytes else {
      throw AuraError.ollamaError("Ollama response exceeded the configured byte bound")
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      if let errorBody = try? makeDecoder().decode(OllamaErrorResponse.self, from: data) {
        throw AuraError.ollamaError("\(errorBody.error) (HTTP \(httpResponse.statusCode))")
      }
      throw AuraError.ollamaError("HTTP \(httpResponse.statusCode)")
    }
    return try decodeResponse(Response.self, data: data)
  }

  private func validateRequestURL(_ url: URL) throws {
    try endpointPolicy.validate(url)
    guard url.path.hasPrefix("/api/") else {
      throw AuraError.securityError("Ollama request path is outside /api/")
    }
  }

  private func decodeResponse<Response: Decodable>(
    _ type: Response.Type,
    data: Data
  ) throws -> Response {
    do {
      return try makeDecoder().decode(type, from: data)
    } catch {
      throw AuraError.ollamaError("decode failed: \(error)")
    }
  }
}
