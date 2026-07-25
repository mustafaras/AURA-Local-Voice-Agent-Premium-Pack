import AuraAgent
import Foundation
import Testing

// Fixture-based decode tests against real, authorized responses captured
// from a locally running `ollama serve` (version 0.32.3) — see
// Fixtures/ollama_*.json. No test in this file makes a real network call.

private func loadFixtureData(_ name: String) throws -> Data {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
  return try Data(contentsOf: url)
}

private func makeDecoder() -> JSONDecoder {
  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  return decoder
}

@Test
func ollamaVersionFixtureDecodes() throws {
  let data = try loadFixtureData("ollama_version_real.json")
  let decoded = try makeDecoder().decode(OllamaVersionResponse.self, from: data)
  #expect(!decoded.version.isEmpty)
}

@Test
func ollamaTagsFixtureDecodesEveryModel() throws {
  let data = try loadFixtureData("ollama_tags_real.json")
  let decoded = try makeDecoder().decode(OllamaTagsResponse.self, from: data)
  #expect(!decoded.models.isEmpty)
  for model in decoded.models {
    #expect(!model.name.isEmpty)
    #expect(!model.capabilities.isEmpty)
  }
}

@Test
func ollamaTagsFixtureDistinguishesLocalFromCloudModels() throws {
  let data = try loadFixtureData("ollama_tags_real.json")
  let decoded = try makeDecoder().decode(OllamaTagsResponse.self, from: data)

  guard let local = decoded.models.first(where: { $0.name == "gemma4:latest" }) else {
    Issue.record("fixture missing expected local model gemma4:latest")
    return
  }
  #expect(local.remoteHost == nil)

  let cloudModels = decoded.models.filter { $0.name.hasSuffix(":cloud") }
  #expect(!cloudModels.isEmpty)
  for cloud in cloudModels {
    #expect(cloud.remoteHost != nil && !(cloud.remoteHost ?? "").isEmpty)
  }
}

@Test
func ollamaTagsFixtureLocalModelContextLengthIsOptional() throws {
  // Real, observed asymmetry: cloud entries carry `details.context_length`;
  // the local `gemma4:latest` entry in this real capture did not. The
  // registry must never assume this field is universally present.
  let data = try loadFixtureData("ollama_tags_real.json")
  let decoded = try makeDecoder().decode(OllamaTagsResponse.self, from: data)
  guard let local = decoded.models.first(where: { $0.name == "gemma4:latest" }) else {
    Issue.record("fixture missing expected local model gemma4:latest")
    return
  }
  #expect(local.details.contextLength == nil)
}

@Test
func ollamaPsFixtureDecodesResidentModel() throws {
  let data = try loadFixtureData("ollama_ps_real.json")
  let decoded = try makeDecoder().decode(OllamaPsResponse.self, from: data)
  #expect(decoded.models.count == 1)
  let model = try #require(decoded.models.first)
  #expect(model.name == "gemma4:latest")
  #expect(model.sizeVram > 0)
  #expect(!model.expiresAt.isEmpty)
}

@Test
func ollamaGenerateStructuredFixtureDecodesAndParsesAsClassification() throws {
  let data = try loadFixtureData("ollama_generate_structured_real.json")
  let decoded = try makeDecoder().decode(OllamaGenerateResponse.self, from: data)
  #expect(decoded.done)
  let responseData = try #require(decoded.response.data(using: .utf8))
  let classification = try JSONDecoder().decode(OllamaClassificationResult.self, from: responseData)
  #expect(classification.classification == "urgent")
}

@Test
func ollamaError404FixtureDecodes() throws {
  let data = try loadFixtureData("ollama_error_404_real.json")
  let decoded = try makeDecoder().decode(OllamaErrorResponse.self, from: data)
  #expect(decoded.error.contains("not found"))
}

@Test
func ollamaFormatSchemaClassificationEncodesEnumProperty() throws {
  let schema = OllamaFormatSchema.classification(labels: ["urgent", "normal"])
  let data = try JSONEncoder().encode(schema)
  let json = try #require(String(data: data, encoding: .utf8))
  #expect(json.contains("classification"))
  #expect(json.contains("urgent"))
  #expect(json.contains("normal"))
}
