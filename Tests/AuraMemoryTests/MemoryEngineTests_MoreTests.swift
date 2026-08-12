import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

@Test
func memoryEngineEnforceRetentionPurgesExpiredEphemeralRecords() async throws {
  let engine = try await makeEngine()
  let ephemeralDraft = MemoryRecordDraft(
    memoryClass: .ephemeralAudio, subject: "audio.buffer.1", statement: "raw pre-roll audio ref",
    evidenceReferences: ["buffer-ref-1"], provenance: .observed(source: .audio),
    sensitivity: .internalLevel, retention: .ephemeral(seconds: 1))
  guard case .recorded(let ephemeralRecord) = try await engine.append(ephemeralDraft) else {
    Issue.record("expected recorded")
    return
  }
  let indefiniteDraft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.name", statement: "AURA",
    evidenceReferences: ["README.md"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  try await engine.append(indefiniteDraft)

  let purged = try await engine.enforceRetention(
    referenceDate: ephemeralRecord.createdAt.addingTimeInterval(2))
  #expect(purged == [ephemeralRecord.id])

  let remainingEphemeral = try await engine.inspect(memoryClass: .ephemeralAudio)
  #expect(remainingEphemeral.isEmpty)
  let remainingProjectFacts = try await engine.inspect(memoryClass: .projectFact)
  #expect(remainingProjectFacts.count == 1)
}

@Test
func memoryEngineEnforceRetentionPurgesSessionScopedRecordsForEndedSessions() async throws {
  let engine = try await makeEngine()
  let sessionID = UUID()
  let draft = MemoryRecordDraft(
    memoryClass: .workingConversation, subject: "conversation.turn.1", statement: "hello",
    evidenceReferences: ["turn-1"], provenance: .observed(source: .user),
    sensitivity: .internalLevel, retention: .sessionScoped, scope: MemoryScope(sessionID: sessionID)
  )
  guard case .recorded(let record) = try await engine.append(draft) else {
    Issue.record("expected recorded")
    return
  }

  let purgedBeforeEnd = try await engine.enforceRetention(endedSessionIDs: [])
  #expect(purgedBeforeEnd.isEmpty)

  let purgedAfterEnd = try await engine.enforceRetention(endedSessionIDs: [sessionID])
  #expect(purgedAfterEnd == [record.id])
}

@Test
func memoryEngineEnforceRetentionEventuallyPurgesAuditRecords() async throws {
  let engine = try await makeEngine()
  let auditDraft = MemoryRecordDraft(
    memoryClass: .auditSecurity, subject: "policy.grant.issued", statement: "granted shellExec",
    evidenceReferences: ["audit-event-2"], provenance: .systemDerived(source: .policy),
    sensitivity: .internalLevel, retention: .auditRetention(days: 1))
  guard case .recorded(let record) = try await engine.append(auditDraft) else {
    Issue.record("expected recorded")
    return
  }

  let purged = try await engine.enforceRetention(
    referenceDate: record.createdAt.addingTimeInterval(2 * 86_400))
  #expect(purged == [record.id])
}

// MARK: - Inspection and export exclude audit memory

@Test
func memoryEngineInspectExcludesAuditRecords() async throws {
  let engine = try await makeEngine()
  let auditDraft = MemoryRecordDraft(
    memoryClass: .auditSecurity, subject: "policy.grant.issued", statement: "granted shellExec",
    evidenceReferences: ["audit-event-3"], provenance: .systemDerived(source: .policy),
    sensitivity: .internalLevel, retention: .auditRetention(days: 365))
  try await engine.append(auditDraft)
  let factDraft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.name", statement: "AURA",
    evidenceReferences: ["README.md"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  try await engine.append(factDraft)

  await #expect(throws: AuraError.self) {
    try await engine.inspect(memoryClass: .auditSecurity)
  }

  let bundle = try await engine.export()
  #expect(bundle.records.count == 1)
  #expect(bundle.records.first?.memoryClass == .projectFact)
}

// MARK: - Provenance graph

@Test
func memoryEngineAppendCreatesProvenanceNode() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.theme", statement: "dark mode",
    evidenceReferences: ["turn-theme-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let record) = try await engine.append(draft) else {
    Issue.record("expected recorded")
    return
  }

  let subgraph = try await engine.provenance(for: record.id)
  #expect(subgraph.nodes.count == 1)
  #expect(subgraph.nodes.first?.recordID == record.id)
  #expect(subgraph.nodes.first?.kind == .preference)
  #expect(subgraph.nodes.first?.authority == .userStated)
}

@Test
func memoryEngineSupersessionCreatesProvenanceEdge() async throws {
  let engine = try await makeEngine()
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.theme", statement: "light mode",
    evidenceReferences: ["turn-theme-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let firstRecord) = try await engine.append(first) else {
    Issue.record("expected recorded")
    return
  }
  let firstSubgraph = try await engine.provenance(for: firstRecord.id)
  let firstNodeID = firstSubgraph.rootNodeID!

  let correction = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.theme", statement: "dark mode",
    evidenceReferences: ["turn-theme-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite, supersedes: firstRecord.id)
  guard case .recorded(let secondRecord) = try await engine.append(correction) else {
    Issue.record("expected recorded")
    return
  }
  let secondSubgraph = try await engine.provenance(for: secondRecord.id)
  let secondNodeID = secondSubgraph.rootNodeID!

  let subgraph = try await engine.provenance(for: secondRecord.id)
  let supersedingEdges = subgraph.edges.filter { $0.kind == .supersedes }
  #expect(supersedingEdges.count == 1)
  #expect(supersedingEdges.first?.sourceID == secondNodeID)
  #expect(supersedingEdges.first?.targetID == firstNodeID)
}

@Test
func memoryEngineEvidenceReferenceCreatesEvidenceForEdge() async throws {
  let engine = try await makeEngine()
  let evidenceDraft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "evidence.swiftVersion", statement: "Swift 6.4",
    evidenceReferences: ["Package.swift"], provenance: .observed(source: .user),
    sensitivity: .internalLevel, retention: .indefinite)
  guard case .recorded(let evidenceRecord) = try await engine.append(evidenceDraft) else {
    Issue.record("expected recorded")
    return
  }
  let evidenceSubgraph = try await engine.provenance(for: evidenceRecord.id)
  let evidenceNodeID = evidenceSubgraph.rootNodeID!

  let derivedDraft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.language", statement: "Swift",
    evidenceReferences: [evidenceRecord.id.uuidString], provenance: .systemDerived(source: .memory),
    sensitivity: .internalLevel, retention: .indefinite)
  guard case .recorded(let derivedRecord) = try await engine.append(derivedDraft) else {
    Issue.record("expected recorded")
    return
  }
  let derivedSubgraph = try await engine.provenance(for: derivedRecord.id)
  let derivedNodeID = derivedSubgraph.rootNodeID!

  let subgraph = try await engine.provenance(for: derivedRecord.id)
  let evidenceEdges = subgraph.edges.filter { $0.kind == ProvenanceEdgeKind.evidenceFor }
  #expect(evidenceEdges.count == 1)
  #expect(evidenceEdges.first?.sourceID == evidenceNodeID)
  #expect(evidenceEdges.first?.targetID == derivedNodeID)
}

@Test
func memoryEngineContradictionCreatesConflictsWithEdge() async throws {
  let engine = try await makeEngine()
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.theme", statement: "light mode",
    evidenceReferences: ["turn-theme-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let firstRecord) = try await engine.append(first) else {
    Issue.record("expected recorded")
    return
  }
  let firstSubgraph = try await engine.provenance(for: firstRecord.id)
  let firstNodeID = firstSubgraph.rootNodeID!

  let second = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.theme", statement: "dark mode",
    evidenceReferences: ["turn-theme-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recordedWithConflict(let secondRecord, _) = try await engine.append(second) else {
    Issue.record("expected recordedWithConflict")
    return
  }
  let secondSubgraph = try await engine.provenance(for: secondRecord.id)
  let secondNodeID = secondSubgraph.rootNodeID!

  let subgraph = try await engine.provenance(for: secondRecord.id)
  let conflictEdges = subgraph.edges.filter { $0.kind == .conflictsWith }
  #expect(conflictEdges.count == 1)
  #expect(conflictEdges.first?.sourceID == secondNodeID)
  #expect(conflictEdges.first?.targetID == firstNodeID)
}

@Test
func memoryEngineAnnotateAddsNodeAndEdges() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .taskState, subject: "task.build", statement: "building now",
    evidenceReferences: ["turn-task-1"], provenance: .systemDerived(source: .user),
    sensitivity: .internalLevel, retention: .indefinite)
  guard case .recorded(let record) = try await engine.append(draft) else {
    Issue.record("expected recorded")
    return
  }

  let evidenceRecord = try await engine.append(
    MemoryRecordDraft(
      memoryClass: .projectFact, subject: "tool.xcodebuild.exitCode", statement: "0",
      evidenceReferences: ["xcodebuild.log"], provenance: .observed(source: .automation),
      sensitivity: .internalLevel, retention: .indefinite))
  guard case .recorded(let evidenceMemoryRecord) = evidenceRecord else {
    Issue.record("expected recorded")
    return
  }
  let evidenceSubgraph = try await engine.provenance(for: evidenceMemoryRecord.id)
  let evidenceNodeID = evidenceSubgraph.rootNodeID!

  let decisionNode = try await engine.annotate(
    recordID: record.id,
    nodeKind: .decision,
    label: "task build succeeded",
    authority: .derivedTool,
    confidence: 0.95,
    outgoingEdges: [(.evidenceFor, evidenceNodeID)])
  let decisionNodeID = decisionNode.id

  let subgraph = try await engine.provenance(forNodeID: decisionNodeID)
  let nodes = subgraph.nodes.filter { $0.kind == .decision }
  #expect(nodes.count == 1)
  let evidenceEdges = subgraph.edges.filter { $0.kind == .evidenceFor }
  #expect(evidenceEdges.count == 1)
  #expect(evidenceEdges.first?.sourceID == decisionNodeID)
  #expect(evidenceEdges.first?.targetID == evidenceNodeID)
}

@Test
func memoryEngineActiveBeliefsRespectAuthorityTieBreaker() async throws {
  let engine = try await makeEngine()
  let inferred = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.timezone", statement: "US/Pacific",
    evidenceReferences: [], provenance: .inferred(basis: "timestamps"), sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let inferredRecord) = try await engine.append(inferred) else {
    Issue.record("expected recorded")
    return
  }

  try await Task.sleep(nanoseconds: 2_000_000)

  let userStated = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.timezone", statement: "US/Eastern",
    evidenceReferences: ["turn-tz-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite, supersedes: inferredRecord.id)
  guard case .recorded(let userRecord) = try await engine.append(userStated) else {
    Issue.record("expected recorded")
    return
  }

  let beliefs = try await engine.activeBeliefs(
    memoryClass: .userPreference, subject: "user.timezone")
  #expect(beliefs.count == 1)
  #expect(beliefs.first?.activeRecordID == userRecord.id)
  #expect(beliefs.first?.statement == "US/Eastern")
  #expect(beliefs.first?.authority == .userStated)
  #expect(beliefs.first?.conflictingRecordIDs.isEmpty == true)
  #expect(beliefs.first?.supersededRecordIDs.contains(inferredRecord.id) == true)
}

@Test
func memoryEngineActiveBeliefsExcludeShadowedRecords() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.theme", statement: "dark mode",
    evidenceReferences: ["turn-theme-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let record) = try await engine.append(draft) else {
    Issue.record("expected recorded")
    return
  }

  _ = try await engine.deleteRecord(id: record.id, reason: "user requested deletion")

  let beliefs = try await engine.activeBeliefs(
    memoryClass: .userPreference, subject: "user.theme")
  #expect(beliefs.isEmpty)
}

@Test
func memoryEngineExportWithProvenanceIncludesSubgraphs() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.language", statement: "Swift",
    evidenceReferences: ["Package.swift"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  try await engine.append(draft)

  let export = try await engine.exportWithProvenance()
  #expect(export.recordsWithProvenance.count == 1)
  #expect(export.recordsWithProvenance.first?.subgraph.nodes.count == 1)
}
