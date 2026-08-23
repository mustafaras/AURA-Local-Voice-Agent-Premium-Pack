import AuraContext
import AuraCore
import AuraIntent
import AuraMemory
import AuraStore
import Foundation
import Testing

private struct ReferenceFixtureClassifier: UtteranceClassifying {
  func classify(normalized: String, raw: String) -> ClassificationResult {
    switch normalized {
    case "open /repo/only.txt":
      return ClassificationResult(
        kind: .fileOpen, semanticCategory: .fileOpen,
        slots: [IntentSlot(name: IntentSlotName.filePath, value: "/repo/only.txt")],
        confidence: 0.95, dialogueAct: .execute)
    case "open /repo/a.txt":
      return ClassificationResult(
        kind: .fileOpen, semanticCategory: .fileOpen,
        slots: [IntentSlot(name: IntentSlotName.filePath, value: "/repo/a.txt")],
        confidence: 0.95, dialogueAct: .execute)
    case "open /repo/b.txt":
      return ClassificationResult(
        kind: .fileOpen, semanticCategory: .fileOpen,
        slots: [IntentSlot(name: IntentSlotName.filePath, value: "/repo/b.txt")],
        confidence: 0.95, dialogueAct: .execute)
    case "open the file":
      return ClassificationResult(
        kind: .fileOpen, semanticCategory: .fileOpen, confidence: 0.95,
        dialogueAct: .execute)
    case "delete the file":
      return ClassificationResult(
        kind: .shellExecute, semanticCategory: .shellDestructive, confidence: 0.95,
        dialogueAct: .execute)
    default:
      return ClassificationResult(
        kind: .converse, semanticCategory: .converse, confidence: 0.95)
    }
  }
}

private func makeReferenceEngine(
  now: Date,
  provider: @escaping ReferenceContextProvider
) async throws -> IntentEngine {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraIntentTests", category: "reference-wiring"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let context = ContextEngine(store: store, memory: memory, eventBus: bus)
  let builder = ContextBuilder(engine: context, memory: memory, eventBus: bus)
  return IntentEngine(
    classifier: ReferenceFixtureClassifier(), contextEngine: context,
    contextBuilder: builder, memoryEngine: memory, contextConfiguration: ContextConfiguration(),
    referenceContextProvider: provider, eventBus: bus, sessionID: UUID(), now: { now })
}

@Test
func productionCompositionResolvesARecentFileThroughContextBuilder() async throws {
  let now = Date()
  let engine = try await makeReferenceEngine(now: now) { _ in
    ReferenceContextSnapshot(
      activeWorkspace: ActiveWorkspaceSnapshot(
        workspaceFolderPaths: ["/repo"], capturedAt: now))
  }

  _ = await engine.classify(
    TurnCompletedEvent(text: "open /repo/only.txt", confidence: 1, isFinal: true),
    correlationID: UUID(), causationID: UUID())
  let intent = await engine.classify(
    TurnCompletedEvent(text: "open the file", confidence: 1, isFinal: true),
    correlationID: UUID(), causationID: UUID())
  let result = try #require(await engine.inspectLastContext())

  #expect(!intent.isAmbiguous)
  #expect(intent.slotValue(IntentSlotName.filePath) == "/repo/only.txt")
  #expect(
    await engine.dialogueContextItems().contains {
      $0.summary == "file: /repo/only.txt"
    })
  guard case .resolved(let candidate) = result.referenceResolution else {
    Issue.record("expected the recent file to resolve, got \(result.referenceResolution)")
    return
  }
  #expect(candidate.description == "file: /repo/only.txt")
}

@Test
func productionCompositionClarifiesAmbiguousRecentFilesBeforeMutation() async throws {
  let now = Date()
  let engine = try await makeReferenceEngine(now: now) { _ in
    ReferenceContextSnapshot(
      activeWorkspace: ActiveWorkspaceSnapshot(
        workspaceFolderPaths: ["/repo"], capturedAt: now))
  }

  for path in ["open /repo/a.txt", "open /repo/b.txt"] {
    _ = await engine.classify(
      TurnCompletedEvent(text: path, confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
  }
  let intent = await engine.classify(
    TurnCompletedEvent(text: "delete the file", confidence: 1, isFinal: true),
    correlationID: UUID(), causationID: UUID())
  let result = try #require(await engine.inspectLastContext())

  #expect(intent.isAmbiguous)
  guard case .ambiguous(let candidates) = result.referenceResolution else {
    Issue.record("expected ambiguous resolution, got \(result.referenceResolution)")
    return
  }
  #expect(candidates.count == 2)
}

@Test
func productionCompositionSurfacesWorkspaceTaskAndBackendIdentityAsLocalEntities() async throws {
  let now = Date()
  let task = TaskStatus(
    id: UUID(), state: .running, objective: "run previous test", priority: .normal,
    createdAt: now.addingTimeInterval(-10), updatedAt: now)
  let engine = try await makeReferenceEngine(now: now) { _ in
    ReferenceContextSnapshot(
      activeWorkspace: ActiveWorkspaceSnapshot(
        appBundleIdentifier: "com.example.Editor", appDisplayName: "Editor",
        workspaceFolderPaths: ["/repo"], activeFilePath: "/repo/Tests.swift", capturedAt: now),
      durableTasks: [task])
  }
  let context = TurnContext(
    sessionID: UUID(), activationSource: .text, actor: .user,
    authority: .userUtterance, sensitivity: .sensitive,
    backendIDs: TurnBackendIDs(model: "ollama", tool: "filesystem.open_file"))

  _ = await engine.classify(
    TurnCompletedEvent(text: "open the file", confidence: 1, isFinal: true), context: context)
  let result = try #require(await engine.inspectLastContext())
  let labels = Set(result.entities.map(\.label))

  #expect(labels.contains("file: /repo/Tests.swift"))
  #expect(labels.contains("repository: /repo"))
  #expect(labels.contains { $0.contains("task \(task.id.uuidString.prefix(8))") })
  #expect(labels.contains("backend: ollama"))
  #expect(labels.contains("backend: filesystem.open_file"))
  #expect(result.bundle.items.contains { $0.sourceID == .activeWorkspace })
}
