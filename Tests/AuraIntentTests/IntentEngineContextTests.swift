import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation
import Testing

private func makeContextAwareIntentEngine(
  contextConfiguration: ContextConfiguration = ContextConfiguration()
) async throws -> (IntentEngine, MemoryEngine) {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraIntentTests", category: "deep-context"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let context = ContextEngine(
    store: store, memory: memory, eventBus: bus, configuration: contextConfiguration)
  let builder = ContextBuilder(
    engine: context, memory: memory, eventBus: bus, configuration: contextConfiguration)
  return (
    IntentEngine(
      classifier: RuleBasedUtteranceClassifier(), contextEngine: context,
      contextBuilder: builder, memoryEngine: memory, eventBus: bus, sessionID: UUID()),
    memory
  )
}

@Test
func intentEngineBuildsInspectableCrossSessionContextBeforeRouting() async throws {
  let (engine, memory) = try await makeContextAwareIntentEngine()
  let preference = try await memory.append(
    MemoryRecordDraft(
      memoryClass: .userPreference, subject: "response-style",
      statement: "Use concise answers", evidenceReferences: ["user-setting"],
      provenance: .userStated, confidence: 1, sensitivity: .internalLevel,
      retention: .indefinite, scope: .global))
  let preferenceID: UUID
  switch preference {
  case .recorded(let record), .recordedWithConflict(let record, _):
    preferenceID = record.id
  }

  let correlationID = UUID()
  let intent = await engine.classify(
    TurnCompletedEvent(text: "what time is it", confidence: 1, isFinal: true),
    correlationID: correlationID, causationID: UUID())
  let result = try #require(await engine.inspectLastContext())

  #expect(intent.kind == .converse)
  #expect(
    result.bundle.items.contains {
      $0.sourceID == .memoryRecord(recordID: preferenceID)
    })
  #expect(result.trace.map(\.stage) == ContextBuilderStage.allCases)
  #expect(result.estimatedTokenCount <= ContextConfiguration().maxTokenBudget)
}

@Test
func contextFailureDoesNotBlockIntentClassification() async throws {
  var configuration = ContextConfiguration()
  configuration.maxTokenBudget = 1
  let (engine, _) = try await makeContextAwareIntentEngine(contextConfiguration: configuration)

  let intent = await engine.classify(
    TurnCompletedEvent(text: "activate safari", confidence: 1, isFinal: true),
    correlationID: UUID(), causationID: UUID())

  #expect(intent.kind == .appActivate)
  #expect(await engine.inspectLastContext() == nil)
}
