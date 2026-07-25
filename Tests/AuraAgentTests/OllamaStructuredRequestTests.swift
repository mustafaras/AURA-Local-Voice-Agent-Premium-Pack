import AuraAgent
import AuraCore
import Foundation
import Testing

@Test
func ollamaStructuredRequestClassifyDecodesValidResponse() async throws {
  let client = FakeOllamaAPIClient()
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(
      model: model, response: #"{"classification":"urgent"}"#, done: true, doneReason: "stop")
  }

  let result = try await OllamaStructuredRequest.classify(
    apiClient: client, model: "gemma4:latest", prompt: "please help urgently", labels: ["urgent", "normal"],
    keepAliveSeconds: 300)
  #expect(result.classification == "urgent")
}

@Test
func ollamaStructuredRequestClassifyRejectsLabelOutsideRequestedSet() async throws {
  let client = FakeOllamaAPIClient()
  await client.setGenerateHandler { model, _, _, _ in
    // Simulate the model ignoring the schema's enum constraint — this must
    // never be trusted just because `format` was supplied.
    OllamaGenerateResponse(model: model, response: #"{"classification":"maybe"}"#, done: true)
  }

  await #expect(throws: AuraError.self) {
    try await OllamaStructuredRequest.classify(
      apiClient: client, model: "gemma4:latest", prompt: "x", labels: ["urgent", "normal"],
      keepAliveSeconds: 300)
  }
}

@Test
func ollamaStructuredRequestClassifyRejectsMalformedJSON() async throws {
  let client = FakeOllamaAPIClient()
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: "not json at all", done: true)
  }

  await #expect(throws: AuraError.self) {
    try await OllamaStructuredRequest.classify(
      apiClient: client, model: "gemma4:latest", prompt: "x", labels: ["urgent", "normal"],
      keepAliveSeconds: 300)
  }
}

@Test
func ollamaStructuredRequestClassifyRejectsEmptyLabelSet() async throws {
  let client = FakeOllamaAPIClient()
  await #expect(throws: AuraError.self) {
    try await OllamaStructuredRequest.classify(
      apiClient: client, model: "gemma4:latest", prompt: "x", labels: [], keepAliveSeconds: 300)
  }
}

@Test
func ollamaStructuredRequestSummarizeDecodesValidResponse() async throws {
  let client = FakeOllamaAPIClient()
  await client.setGenerateHandler { model, _, _, _ in
    OllamaGenerateResponse(model: model, response: #"{"summary":"a short summary"}"#, done: true)
  }

  let result = try await OllamaStructuredRequest.summarize(
    apiClient: client, model: "gemma4:latest", prompt: "long text", keepAliveSeconds: 300)
  #expect(result.summary == "a short summary")
}

@Test
func ollamaStructuredRequestPropagatesGenerateFailureAsAuraError() async throws {
  let client = FakeOllamaAPIClient()
  await client.setGenerateHandler { _, _, _, _ in
    throw AuraError.ollamaError("simulated network failure")
  }

  await #expect(throws: AuraError.self) {
    try await OllamaStructuredRequest.summarize(
      apiClient: client, model: "gemma4:latest", prompt: "x", keepAliveSeconds: 300)
  }
}
