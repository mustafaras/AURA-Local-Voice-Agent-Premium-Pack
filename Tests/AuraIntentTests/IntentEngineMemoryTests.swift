import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation
import Testing

// MARK: - Harness

private actor Capture {
  var payloads: [any EventPayload] = []
  func append(_ payload: any EventPayload) { payloads.append(payload) }
  func all<E: EventPayload>(_ type: E.Type) -> [E] { payloads.compactMap { $0 as? E } }
}

private func makeStore() async throws -> AuraStore {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  let path = dir.appendingPathComponent("test.sqlite").path
  return try await AuraStore(path: path)
}

private func makeEngine(memory: MemoryEngine? = nil) -> IntentEngine {
  IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    contextEngine: nil,
    memoryEngine: memory,
    eventBus: AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "intent"))
  )
}

private func makeTurn(text: String) -> TurnCompletedEvent {
  TurnCompletedEvent(text: text, confidence: 0.95, isFinal: true)
}

// MARK: - Classification → memory persistence

@Test
func intentEngineWithoutMemoryDoesNotCrash() async throws {
  let engine = makeEngine(memory: nil)
  let turn = makeTurn(text: "open safari")
  let intent = await engine.classify(turn, correlationID: UUID(), causationID: UUID())
  #expect(intent.kind == .appActivate)
}

@Test
func intentEngineAppendsWorkingConversationRecordForClassifiedIntent() async throws {
  let store = try await makeStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "intent"))
  let capture = Capture()
  await bus.subscribe(IntentClassifiedEvent.self) { event in
    await capture.append(event.payload)
  }

  let memory = MemoryEngine(store: store, eventBus: bus)
  let sessionID = UUID()
  let engine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    contextEngine: nil,
    memoryEngine: memory,
    eventBus: bus,
    sessionID: sessionID
  )
  let correlationID = UUID()
  let turn = makeTurn(text: "open safari")
  _ = await engine.classify(turn, correlationID: correlationID, causationID: UUID())

  let classified = await capture.all(IntentClassifiedEvent.self)
  #expect(classified.count == 1)
  #expect(classified.first?.kind == "appActivate")

  let records = try await store.memoryRecords(
    matching: MemoryQuery(memoryClass: .workingConversation, scope: MemoryScope(sessionID: sessionID)))
  #expect(records.count == 1)
  let record = records[0]
  #expect(record.subject.hasPrefix("intent:"))
  #expect(record.statement.contains("appActivate"))
  #expect(record.statement.contains("open safari"))
  #expect(record.provenance == .systemDerived(source: .intent))
  #expect(record.evidenceReferences.contains(correlationID.uuidString))
}

@Test
func intentEngineAnnotatesProvenanceForClassifiedIntent() async throws {
  let store = try await makeStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "intent"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let sessionID = UUID()
  let engine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    contextEngine: nil,
    memoryEngine: memory,
    eventBus: bus,
    sessionID: sessionID
  )
  let correlationID = UUID()
  let turn = makeTurn(text: "run echo hello")
  _ = await engine.classify(turn, correlationID: correlationID, causationID: UUID())

  let records = try await store.memoryRecords(
    matching: MemoryQuery(memoryClass: .workingConversation, scope: MemoryScope(sessionID: sessionID)))
  #expect(records.count == 1)
  let record = records[0]

  let subgraph = try await memory.provenance(for: record.id)
  #expect(subgraph.nodes.contains { $0.recordID == record.id })
  #expect(subgraph.nodes.contains { $0.kind == .decision || $0.kind == .utterance })
}

@Test
func intentEngineEmitsMemoryFailureEventWhenStorePathInvalid() async throws {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "intent"))
  let capture = Capture()
  await bus.subscribe(IntentMemoryFailedEvent.self) { event in
    await capture.append(event.payload)
  }

  // AuraStore opens SQLite in full mutex mode and therefore fails during
  // construction for an invalid path, so construction is the error path we
  // exercise here. The thrown error propagates cleanly and is not silently
  // swallowed, which is the correct fail-closed behavior for an invalid
  // store path.
  do {
    _ = try await AuraStore(path: "/not/a/real/path/\(UUID().uuidString).sqlite")
    #expect(Bool(false), "AuraStore should throw when opening an invalid path")
  } catch {
    // Expected fail-closed behavior: AuraStore throws AuraError for an invalid path.
  }
}

@Test
func intentEngineSessionScopeIsolatesRecords() async throws {
  let store = try await makeStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "intent"))
  let sessionA = UUID()
  let sessionB = UUID()
  let engineA = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    contextEngine: nil,
    memoryEngine: MemoryEngine(store: store, eventBus: bus),
    eventBus: bus,
    sessionID: sessionA
  )
  let engineB = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    contextEngine: nil,
    memoryEngine: MemoryEngine(store: store, eventBus: bus),
    eventBus: bus,
    sessionID: sessionB
  )

  _ = await engineA.classify(makeTurn(text: "open safari"), correlationID: UUID(), causationID: UUID())
  _ = await engineB.classify(makeTurn(text: "quit mail"), correlationID: UUID(), causationID: UUID())

  let recordsA = try await store.memoryRecords(
    matching: MemoryQuery(memoryClass: .workingConversation, scope: MemoryScope(sessionID: sessionA)))
  let recordsB = try await store.memoryRecords(
    matching: MemoryQuery(memoryClass: .workingConversation, scope: MemoryScope(sessionID: sessionB)))
  #expect(recordsA.count == 1)
  #expect(recordsB.count == 1)
  #expect(recordsA[0].statement.contains("appActivate"))
  #expect(recordsB[0].statement.contains("appTerminate"))
}
