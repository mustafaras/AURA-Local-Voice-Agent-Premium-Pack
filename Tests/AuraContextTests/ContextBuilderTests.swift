import AuraContext
import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

private func makeBuilder(
  configuration: ContextConfiguration = ContextConfiguration()
) async throws -> (ContextBuilder, MemoryEngine) {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraContextTests", category: "builder"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let engine = ContextEngine(
    store: store, memory: memory, eventBus: bus, configuration: configuration)
  return (
    ContextBuilder(
      engine: engine, memory: memory, eventBus: bus, configuration: configuration),
    memory
  )
}

private func schema(
  _ name: String = "fileDelete", capability: Capability? = .fileDelete
) -> ContextIntentSchema {
  ContextIntentSchema(name: name, capability: capability, confidence: 0.95)
}

private func candidate(
  _ description: String,
  capability: Capability? = nil,
  confidence: Double = 0.95,
  evidence: Bool = true,
  scopeMatch: Bool = true,
  kind: ReferenceEntityKind = .file,
  salience: Double = 0.8,
  observedAt: Date = Date()
) -> ReferenceCandidate {
  ReferenceCandidate(
    sourceID: .activeWorkspace, description: description, capability: capability,
    authority: evidence ? .userStated : .inferred, confidence: confidence,
    observedAt: observedAt, hasDirectEvidence: evidence, scopeMatch: scopeMatch,
    entityKind: kind, conversationalSalience: salience)
}

@Test
func deepPipelineIsInspectableAndBlocksWeakDestructiveReference() async throws {
  let (builder, _) = try await makeBuilder()
  let weak = candidate(
    "/tmp/decoy", confidence: 0.4, evidence: false, salience: 1)

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "delete it", sessionID: UUID(), conversationState: .thinking,
      intent: schema(), referenceCandidates: [weak]))

  #expect(result.trace.map(\.stage) == ContextBuilderStage.allCases)
  #expect(result.parsedUtterance.implicitReference == "it")
  guard case .blockedWeakEvidence(let blocked) = result.referenceResolution else {
    Issue.record("expected weak destructive candidate to be blocked")
    return
  }
  #expect(blocked.id == weak.id)
  #expect(result.referenceGraph?.nodes.first?.candidate.id == weak.id)
  #expect(result.estimatedTokenCount <= ContextConfiguration().maxTokenBudget)
}

@Test
func ambiguousReferenceNeverGuessesBetweenTwoStrongFiles() async throws {
  let (builder, _) = try await makeBuilder()
  let now = Date()
  let first = candidate("/tmp/a.txt", observedAt: now)
  let second = candidate("/tmp/b.txt", observedAt: now)

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "delete the file", sessionID: UUID(), conversationState: .thinking,
      intent: schema(), referenceCandidates: [first, second], referenceDate: now))

  guard case .ambiguous(let ranked) = result.referenceResolution else {
    Issue.record("expected ambiguity for tied strong candidates")
    return
  }
  #expect(ranked.count == 2)
}

@Test
func explicitConfirmationIsBoundToTheConfirmedCandidateID() async throws {
  let (builder, _) = try await makeBuilder()
  let weak = candidate("/tmp/confirmed.txt", confidence: 0.2, evidence: false)
  let other = candidate("/tmp/other.txt", confidence: 0.99, evidence: true)

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "delete it", sessionID: UUID(), conversationState: .thinking,
      intent: schema(), referenceCandidates: [weak, other],
      explicitlyConfirmedTargetID: weak.id))

  guard case .resolved(let resolved) = result.referenceResolution else {
    Issue.record("expected exact explicitly-confirmed target to resolve")
    return
  }
  #expect(resolved.id == weak.id)
}

@Test
func salienceAndLexicalKindAffectRankWithoutBypassingEvidenceGuard() {
  var configuration = ContextConfiguration()
  configuration.referenceSalienceWeight = 0.4
  let resolver = ReferenceResolver(configuration: configuration)
  let now = Date()
  let salientFile = candidate(
    "/tmp/current.txt", capability: .fileDelete, evidence: false, kind: .file, salience: 1,
    observedAt: now)
  let backgroundTask = candidate(
    "task 17", capability: .fileDelete, evidence: true, kind: .task, salience: 0,
    observedAt: now)

  let graph = resolver.graph(
    reference: "the file", candidates: [backgroundTask, salientFile], referenceDate: now)
  #expect(graph.nodes.first?.candidate.id == salientFile.id)
  guard
    case .blockedWeakEvidence = resolver.resolve(
      reference: "delete the file", candidates: [backgroundTask, salientFile], referenceDate: now)
  else {
    Issue.record("salience must not bypass destructive evidence guard")
    return
  }
}

@Test
func tokenBudgetRetainsMandatoryContextAndDropsOptionalTail() async throws {
  var configuration = ContextConfiguration()
  configuration.maxTokenBudget = 80
  configuration.maxBundleItems = 20
  let (builder, memory) = try await makeBuilder(configuration: configuration)
  for index in 0..<12 {
    _ = try await memory.append(
      MemoryRecordDraft(
        memoryClass: .userPreference, subject: "preference-\(index)",
        statement: String(repeating: "compact preference \(index) ", count: 5),
        evidenceReferences: ["user-\(index)"], provenance: .userStated,
        confidence: 1, sensitivity: .internalLevel, retention: .indefinite))
  }

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "summarize it", sessionID: UUID(), conversationState: .thinking,
      intent: schema("converse", capability: nil)))

  #expect(result.estimatedTokenCount <= configuration.maxTokenBudget)
  #expect(result.bundle.items.contains { $0.stage == .currentUtterance })
  #expect(result.bundle.items.contains { $0.stage == .conversationState })
  #expect(result.bundle.droppedCandidateCount > 0)
}

@Test
func multiHopFileTaskDecisionPreferenceLineageIsInjected() async throws {
  var configuration = ContextConfiguration()
  configuration.maxGraphItems = 8
  configuration.maxGraphDepth = 5
  let (builder, memory) = try await makeBuilder(configuration: configuration)
  let scope = MemoryScope(projectID: "AURA")
  let outcome = try await memory.append(
    MemoryRecordDraft(
      memoryClass: .projectFact, subject: "release-workflow",
      statement: "release workflow uses the signed manifest",
      evidenceReferences: ["manifest"], provenance: .userStated, confidence: 1,
      sensitivity: .internalLevel, retention: .indefinite, scope: scope))
  let record: MemoryRecord
  switch outcome {
  case .recorded(let value), .recordedWithConflict(let value, _): record = value
  }
  let root = try #require((try await memory.provenance(for: record.id)).rootNodeID)
  let file = try await memory.annotate(
    recordID: record.id, nodeKind: .file, label: "file: release.json",
    authority: .derivedTool, confidence: 1, outgoingEdges: [(.derivedFrom, root)])
  let task = try await memory.annotate(
    recordID: record.id, nodeKind: .task, label: "task: validate release",
    authority: .derivedPolicy, confidence: 1, outgoingEdges: [(.derivedFrom, file.id)])
  let decision = try await memory.annotate(
    recordID: record.id, nodeKind: .decision, label: "decision: require signature",
    authority: .userStated, confidence: 1, outgoingEdges: [(.derivedFrom, task.id)])
  _ = try await memory.annotate(
    recordID: record.id, nodeKind: .preference, label: "preference: fail closed",
    authority: .userConfirmed, confidence: 1, outgoingEdges: [(.derivedFrom, decision.id)])

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "show the release workflow file", sessionID: UUID(),
      conversationState: .thinking, intent: schema("converse", capability: nil),
      scope: scope))

  let summaries = result.bundle.items.map(\.summary)
  #expect(summaries.contains("file: release.json"))
  #expect(summaries.contains("task: validate release"))
  #expect(summaries.contains("decision: require signature"))
  #expect(summaries.contains("preference: fail closed"))
  let graphItems = result.bundle.items.filter {
    if case .provenanceNode = $0.sourceID { return true }
    return false
  }
  #expect(graphItems.allSatisfy { !$0.provenanceNodeIDs.isEmpty })
  #expect(result.elapsedSeconds <= configuration.lookupLatencyBudgetSeconds)
}

@Test
func userCanInspectExcludeAndExplicitlyIncludeContext() async throws {
  let (builder, memory) = try await makeBuilder()
  let excludedOutcome = try await memory.append(
    MemoryRecordDraft(
      memoryClass: .userPreference, subject: "verbosity",
      statement: "Use terse responses", evidenceReferences: ["user"],
      provenance: .userStated, confidence: 1, sensitivity: .internalLevel,
      retention: .indefinite))
  let includedOutcome = try await memory.append(
    MemoryRecordDraft(
      memoryClass: .projectFact, subject: "unrelated",
      statement: "The verified release channel is local-only",
      evidenceReferences: ["decision"], provenance: .userStated, confidence: 1,
      sensitivity: .internalLevel, retention: .indefinite))
  let excluded: MemoryRecord
  let included: MemoryRecord
  switch excludedOutcome {
  case .recorded(let value), .recordedWithConflict(let value, _): excluded = value
  }
  switch includedOutcome {
  case .recorded(let value), .recordedWithConflict(let value, _): included = value
  }

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "hello", sessionID: UUID(), conversationState: .thinking,
      intent: schema("converse", capability: nil),
      inclusionOverride: ContextInclusionOverride(
        excludedSourceIDs: [.memoryRecord(recordID: excluded.id)],
        includedMemoryRecordIDs: [included.id])))

  #expect(!result.bundle.items.contains { $0.sourceID == .memoryRecord(recordID: excluded.id) })
  #expect(result.bundle.items.contains { $0.sourceID == .memoryRecord(recordID: included.id) })
  let inspected = try #require(
    result.inspection.first { $0.sourceID == .memoryRecord(recordID: included.id) })
  #expect(inspected.inclusionReason == "explicit per-turn inclusion override")
  #expect(!inspected.provenanceNodeIDs.isEmpty)
}

@Test
func impossibleMandatoryTokenBudgetFailsClosed() async throws {
  var configuration = ContextConfiguration()
  configuration.maxTokenBudget = 1
  let (builder, _) = try await makeBuilder(configuration: configuration)

  await #expect(throws: AuraError.self) {
    _ = try await builder.build(
      DeepContextRequest(
        utterance: "this utterance cannot fit", sessionID: UUID(),
        conversationState: .thinking, intent: schema("converse", capability: nil)))
  }
}

@Test
func contextConfigurationPartialDecodePreservesPhase22Defaults() throws {
  let data = try #require(#"{"maxTokenBudget":256,"maxGraphDepth":2}"#.data(using: .utf8))
  let decoded = try JSONDecoder().decode(ContextConfiguration.self, from: data)

  #expect(decoded.maxTokenBudget == 256)
  #expect(decoded.maxGraphDepth == 2)
  #expect(decoded.maxGraphItems == ContextConfiguration().maxGraphItems)
  #expect(decoded.referenceSalienceWeight == ContextConfiguration().referenceSalienceWeight)
}

@Test
func secretOrNonInjectableOverrideCannotEnterBundle() async throws {
  let (builder, memory) = try await makeBuilder()
  let outcome = try await memory.append(
    MemoryRecordDraft(
      memoryClass: .workingConversation, subject: "private-turn",
      statement: "private transient content", evidenceReferences: ["session"],
      provenance: .userStated, confidence: 1, sensitivity: .secret,
      retention: .sessionScoped, scope: MemoryScope(sessionID: UUID())))
  let recordID: UUID
  switch outcome {
  case .recorded(let record), .recordedWithConflict(let record, _): recordID = record.id
  }

  let result = try await builder.build(
    DeepContextRequest(
      utterance: "hello", sessionID: UUID(), conversationState: .thinking,
      intent: schema("converse", capability: nil),
      inclusionOverride: ContextInclusionOverride(includedMemoryRecordIDs: [recordID])))

  #expect(!result.bundle.items.contains { $0.sourceID == .memoryRecord(recordID: recordID) })
}
