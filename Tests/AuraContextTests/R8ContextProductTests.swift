import AuraContext
import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

private func r8ContextStack(
  configuration: ContextConfiguration = ContextConfiguration()
) async throws -> (ContextEngine, ContextBuilder, MemoryEngine) {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraContextTests", category: "r8"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let engine = ContextEngine(
    store: store, memory: memory, eventBus: bus, configuration: configuration)
  let builder = ContextBuilder(
    engine: engine, memory: memory, eventBus: bus, configuration: configuration)
  return (engine, builder, memory)
}

@Test
func r8ContextSurfacesUnresolvedContradictionButUsesAuthorityWinner() async throws {
  var configuration = ContextConfiguration()
  configuration.maxPreferences = 5
  let (engine, _, memory) = try await r8ContextStack(configuration: configuration)
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "reply.language", statement: "Turkish",
    evidenceReferences: ["user-turn-1"], provenance: .userStated,
    sensitivity: .internalLevel, retention: .indefinite, purpose: "explicit language preference")
  try await memory.append(first)
  let weakerRecent = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "reply.language", statement: "English",
    evidenceReferences: ["classifier-2"], provenance: .inferred(basis: "recent transcript"),
    sensitivity: .internalLevel, retention: .indefinite, purpose: "inference test")
  try await memory.append(weakerRecent)

  let bundle = try await engine.reconstruct(
    utterance: "what language should you use", sessionID: UUID(),
    conversationState: .thinking)
  #expect(bundle.unresolvedContradictions.count == 1)
  #expect(bundle.unresolvedContradictions.first?.subject == "reply.language")
  #expect(bundle.items.contains { $0.summary == "Turkish" })
  #expect(!bundle.items.contains { $0.summary == "English" })
}

@Test
func r8ContextBundleCarriesPurposeProvenanceAndBoundedBudget() async throws {
  var configuration = ContextConfiguration()
  configuration.maxTokenBudget = 240
  let (_, builder, memory) = try await r8ContextStack(configuration: configuration)
  try await memory.append(
    MemoryRecordDraft(
      memoryClass: .projectFact, subject: "project.toolchain",
      statement: "Swift package build evidence", evidenceReferences: ["build.log"],
      provenance: .observed(source: .automation), sensitivity: .internalLevel,
      retention: .indefinite, purpose: "verified tool result"))

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "what build toolchain evidence exists", sessionID: UUID(),
      purpose: "tool selection", requestingComponent: .intent,
      conversationState: .thinking, intent: ContextIntentSchema(
        name: "toolchain.lookup", confidence: 0.95)))
  #expect(result.bundle.purpose == "tool selection")
  #expect(result.bundle.requestingComponent == .intent)
  #expect(result.bundle.deliveryPolicy.destination == .localModel)
  #expect(result.estimatedTokenCount <= 240)
  #expect(result.bundle.estimatedTokenCount == result.estimatedTokenCount)
  #expect(result.inspection.allSatisfy { $0.estimatedTokens > 0 })
  #expect(result.bundle.items.contains { !$0.provenanceNodeIDs.isEmpty })
}

@Test
func r8RemoteContextFailsClosedBeforeAnyTransmission() async throws {
  let (_, builder, _) = try await r8ContextStack()
  await #expect(throws: AuraError.self) {
    try await builder.build(
      DeepContextRequest(
        utterance: "send this private draft", sessionID: UUID(),
        conversationState: .thinking,
        intent: ContextIntentSchema(name: "mail.send", confidence: 0.9),
        deliveryPolicy: .remotePublicOnly))
  }
}
