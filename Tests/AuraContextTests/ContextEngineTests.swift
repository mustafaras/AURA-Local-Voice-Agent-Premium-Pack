import AuraCore
import AuraContext
import AuraMemory
import AuraStore
import Foundation
import Testing

private func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

private func makeEngine(configuration: ContextConfiguration = ContextConfiguration()) async throws
  -> (ContextEngine, AuraStore, MemoryEngine)
{
  let store = try await makeTempStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraContextTests", category: "engine"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let engine = ContextEngine(store: store, memory: memory, eventBus: bus, configuration: configuration)
  return (engine, store, memory)
}

private func makeLedgerEntry(
  taskID: String, title: String, timestamp: Date, decisions: [String] = [],
  evidenceInspected: [String] = ["AGENTS.md"]
) -> ProjectLedgerEntry {
  ProjectLedgerEntry(
    timestamp: timestamp, taskID: taskID, title: title, actor: "test", objective: "test objective",
    startingState: "n/a", evidenceInspected: evidenceInspected, decisions: decisions)
}

// MARK: - Mandatory stages always present

@Test
func bundleAlwaysIncludesUtteranceAndConversationState() async throws {
  let (engine, _, _) = try await makeEngine()
  let bundle = try await engine.reconstruct(
    utterance: "what time is it", sessionID: UUID(), conversationState: .listening)

  #expect(bundle.items[0].stage == .currentUtterance)
  #expect(bundle.items[0].sourceID == .utterance)
  #expect(bundle.items[1].stage == .conversationState)
  #expect(bundle.utterance == "what time is it")
}

@Test
func bundleIncludesPendingConfirmationAndTaskWhenProvided() async throws {
  let (engine, _, _) = try await makeEngine()
  let challenge = PolicyConfirmationChallenge(
    requestID: UUID(), sessionID: UUID(), nonce: "n", issuedAt: Date(),
    requestedAction: .fileDelete, targetSummary: "~/Desktop/report.docx",
    riskTier: .destructive, expiresAt: Date().addingTimeInterval(60), expectedHash: "h")
  let task = TaskStatus(
    id: UUID(), state: .running, objective: "sync files", priority: .normal, createdAt: Date(),
    updatedAt: Date())

  let bundle = try await engine.reconstruct(
    utterance: "cancel it", sessionID: UUID(), conversationState: .thinking,
    pendingConfirmation: challenge, pendingTask: task)

  let stages = bundle.items.map(\.stage)
  #expect(stages.contains(.pendingConfirmationOrTask))
  let sourceIDs = bundle.items.map(\.sourceID)
  #expect(sourceIDs.contains(.pendingConfirmation(requestID: challenge.requestID)))
  #expect(sourceIDs.contains(.pendingTask(taskID: task.id)))
}

@Test
func bundleIncludesActiveWorkspaceWhenProvided() async throws {
  let (engine, _, _) = try await makeEngine()
  let workspace = ActiveWorkspaceSnapshot(
    appBundleIdentifier: "com.microsoft.VSCode", appDisplayName: "Visual Studio Code",
    workspaceFolderPaths: ["/Users/dev/AURA"], activeFilePath: "/Users/dev/AURA/main.swift")

  let bundle = try await engine.reconstruct(
    utterance: "save the file", sessionID: UUID(), conversationState: .thinking,
    activeWorkspace: workspace)

  let workspaceItem = bundle.items.first { $0.stage == .activeAppOrWorkspace }
  #expect(workspaceItem != nil)
  #expect(workspaceItem?.sourceID == .activeWorkspace)
  #expect(workspaceItem?.summary.contains("main.swift") == true)
}

// MARK: - Project ledger and decisions

@Test
func bundleSurfacesRecentLedgerEntriesAndDecisions() async throws {
  let (engine, store, _) = try await makeEngine()
  let now = Date()
  try await store.append(
    makeLedgerEntry(
      taskID: "05_POLICY", title: "Policy engine", timestamp: now.addingTimeInterval(-3600),
      decisions: ["Deny by default for mutation and destructive tiers"]))
  try await store.append(
    makeLedgerEntry(
      taskID: "15_MEMORY", title: "Memory engine", timestamp: now.addingTimeInterval(-60),
      decisions: ["Append-only records, corrections supersede rather than overwrite"]))

  let bundle = try await engine.reconstruct(
    utterance: "what did we decide about memory", sessionID: UUID(), conversationState: .thinking,
    referenceDate: now)

  let ledgerSummaries = bundle.items.filter { $0.stage == .projectLedger }.map(\.summary)
  #expect(ledgerSummaries.contains { $0.contains("15_MEMORY") })

  let decisionSummaries = bundle.items.filter { $0.stage == .recentDecisions }.map(\.summary)
  #expect(decisionSummaries.contains("Append-only records, corrections supersede rather than overwrite"))
}

@Test
func moreRecentLedgerEntryOutranksOlderOneUnderTightBudget() async throws {
  var configuration = ContextConfiguration()
  configuration.maxLedgerEntries = 10
  configuration.maxDecisions = 1
  configuration.maxPreferences = 1
  configuration.maxSemanticMatches = 1
  configuration.maxBundleItems = 1
  let (engine, store, _) = try await makeEngine(configuration: configuration)
  let now = Date()
  try await store.append(
    makeLedgerEntry(taskID: "OLD", title: "Old phase", timestamp: now.addingTimeInterval(-90_000)))
  try await store.append(
    makeLedgerEntry(taskID: "NEW", title: "New phase", timestamp: now.addingTimeInterval(-30)))

  let bundle = try await engine.reconstruct(
    utterance: "status check", sessionID: UUID(), conversationState: .thinking, referenceDate: now)

  let tail = bundle.items.filter { !$0.stage.isMandatory }
  #expect(tail.count == 1)
  #expect(tail.first?.summary.contains("NEW") == true)
  #expect(bundle.droppedCandidateCount >= 1)
}

// MARK: - Preferences and scope

@Test
func scopeMatchingPreferenceOutranksMismatchedScopePreference() async throws {
  var configuration = ContextConfiguration()
  configuration.maxBundleItems = 1
  let (engine, _, memory) = try await makeEngine(configuration: configuration)
  let sessionA = UUID()
  let sessionB = UUID()

  // The scope-matching record is appended first (older) and the
  // mismatched-scope record second (more recent), so if the matching one
  // still wins, it proves scope match — not recency — decided the ranking.
  try await memory.append(
    MemoryRecordDraft(
      memoryClass: .userPreference, subject: "reply.tone", statement: "Reply concisely",
      evidenceReferences: ["user said so"], provenance: .userStated, sensitivity: .internalLevel,
      retention: .indefinite, scope: MemoryScope(sessionID: sessionA)))
  try await memory.append(
    MemoryRecordDraft(
      memoryClass: .userPreference, subject: "reply.language", statement: "Reply in Turkish",
      evidenceReferences: ["user said so"], provenance: .userStated, sensitivity: .internalLevel,
      retention: .indefinite, scope: MemoryScope(sessionID: sessionB)))

  let bundle = try await engine.reconstruct(
    utterance: "how should you respond", sessionID: sessionA, conversationState: .thinking,
    scope: MemoryScope(sessionID: sessionA))

  let tail = bundle.items.filter { !$0.stage.isMandatory }
  #expect(tail.count == 1)
  #expect(tail.first?.summary == "Reply concisely")
}

// MARK: - Semantic retrieval

@Test
func semanticRetrievalMatchesRelevantFactAndSkipsUnrelatedOne() async throws {
  let (engine, _, memory) = try await makeEngine()
  try await memory.append(
    MemoryRecordDraft(
      memoryClass: .projectFact, subject: "project.toolchain",
      statement: "AURA uses Swift 6.4 with CommandLineTools, swift test does not work here",
      evidenceReferences: ["AGENTS.md"], provenance: .userStated, sensitivity: .internalLevel,
      retention: .indefinite))
  try await memory.append(
    MemoryRecordDraft(
      memoryClass: .projectFact, subject: "project.unrelated",
      statement: "The office coffee machine is broken",
      evidenceReferences: ["chat"], provenance: .userStated, sensitivity: .internalLevel,
      retention: .indefinite))

  let bundle = try await engine.reconstruct(
    utterance: "does swift test work in this toolchain", sessionID: UUID(),
    conversationState: .thinking)

  let semantic = bundle.items.filter { $0.stage == .semanticRetrieval }
  #expect(semantic.contains { $0.summary.contains("swift test does not work") })
  #expect(!semantic.contains { $0.summary.contains("coffee machine") })
}

// MARK: - Minimal and sufficient

@Test
func bundleIsBoundedByConfiguredBudgetEvenWithManyCandidates() async throws {
  var configuration = ContextConfiguration()
  configuration.maxPreferences = 20
  configuration.maxBundleItems = 3
  let (engine, _, memory) = try await makeEngine(configuration: configuration)
  for index in 0..<10 {
    try await memory.append(
      MemoryRecordDraft(
        memoryClass: .userPreference, subject: "pref.\(index)", statement: "Preference \(index)",
        evidenceReferences: ["evidence"], provenance: .userStated, sensitivity: .internalLevel,
        retention: .indefinite))
  }

  let bundle = try await engine.reconstruct(
    utterance: "what are my preferences", sessionID: UUID(), conversationState: .thinking)

  let tail = bundle.items.filter { !$0.stage.isMandatory }
  #expect(tail.count == 3)
  #expect(bundle.droppedCandidateCount == 7)
  #expect(bundle.consideredCandidateCount == 10)
}

@Test
func trueMostRecentLedgerEntrySurfacesEvenWithManyOlderEntries() async throws {
  // Regression test: `AuraStore.entries(limit:)` orders ascending and
  // applies `LIMIT` from the start, so a naive `store.entries(limit: N)`
  // call returns the OLDEST N rows, not the most recent ones. This inserts
  // more entries than a small limit would have covered and asserts the
  // engine still surfaces the genuinely most recent one, not merely the
  // most-recent-among-an-arbitrary-oldest-slice.
  var configuration = ContextConfiguration()
  configuration.maxLedgerEntries = 1
  configuration.maxBundleItems = 1
  let (engine, store, _) = try await makeEngine(configuration: configuration)
  let now = Date()
  for index in 0..<30 {
    try await store.append(
      makeLedgerEntry(
        taskID: "PHASE_\(index)", title: "Phase \(index)",
        timestamp: now.addingTimeInterval(Double(index) * 60)))
  }

  let bundle = try await engine.reconstruct(
    utterance: "status check", sessionID: UUID(), conversationState: .thinking,
    referenceDate: now.addingTimeInterval(30 * 60))

  let tail = bundle.items.filter { !$0.stage.isMandatory }
  #expect(tail.count == 1)
  #expect(tail.first?.summary.contains("PHASE_29") == true)
}

// MARK: - Reference resolution wired through the engine

@Test
func engineResolveReferenceEmitsBlockedWeakEvidenceForWeakDestructiveCandidate() async throws {
  let (engine, _, _) = try await makeEngine()
  let candidate = ReferenceCandidate(
    sourceID: .memoryRecord(recordID: UUID()), description: "~/Desktop/notes.txt",
    capability: .fileDelete, authority: .inferred, confidence: 0.4, observedAt: Date(),
    hasDirectEvidence: false, scopeMatch: true)

  let resolution = await engine.resolveReference("delete it", candidates: [candidate])

  guard case .blockedWeakEvidence(let blocked) = resolution else {
    Issue.record("expected blockedWeakEvidence, got \(resolution)")
    return
  }
  #expect(blocked.description == "~/Desktop/notes.txt")
}
