import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

func makeTempStore() async throws -> AuraStore {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  return try await AuraStore(path: path)
}

func makeEngine() async throws -> MemoryEngine {
  let store = try await makeTempStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraMemoryTests", category: "engine"))
  return MemoryEngine(store: store, eventBus: bus)
}

actor Capture {
  var payloads: [any EventPayload] = []
  func append(_ payload: any EventPayload) { payloads.append(payload) }
  func all<E: EventPayload>(_ type: E.Type) -> [E] { payloads.compactMap { $0 as? E } }
}

// MARK: - Append and evidence rule

@Test
func memoryEngineAppendsFactWithEvidence() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.language", statement: "The project uses Swift",
    evidenceReferences: ["Package.swift"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)

  let outcome = try await engine.append(draft)
  guard case .recorded(let record) = outcome else {
    Issue.record("expected recorded, got \(outcome)")
    return
  }
  #expect(record.subject == "project.language")
  #expect(record.evidenceReferences == ["Package.swift"])
}

@Test
func memoryEngineRejectsFactWithoutEvidence() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.language", statement: "The project uses Swift",
    evidenceReferences: [], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)

  await #expect(throws: AuraError.self) {
    try await engine.append(draft)
  }
}

@Test
func memoryEngineAllowsInferenceWithoutEvidence() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.timezone", statement: "Likely US/Pacific",
    evidenceReferences: [], provenance: .inferred(basis: "recent message timestamps"),
    sensitivity: .internalLevel, retention: .indefinite)

  let outcome = try await engine.append(draft)
  guard case .recorded = outcome else {
    Issue.record("expected recorded, got \(outcome)")
    return
  }
}

@Test
func memoryEngineRejectsSecretEphemeralWithIndefiniteRetention() async throws {
  let engine = try await makeEngine()
  let draft = MemoryRecordDraft(
    memoryClass: .workingConversation, subject: "conversation.turn.1",
    statement: "user's home address", evidenceReferences: ["turn-1"], provenance: .userStated,
    sensitivity: .secret, retention: .indefinite)

  await #expect(throws: AuraError.self) {
    try await engine.append(draft)
  }
}

// MARK: - Contradiction detection

@Test
func memoryEngineDetectsContradictionForSameKeyDifferentStatement() async throws {
  let engine = try await makeEngine()
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "blue",
    evidenceReferences: ["turn-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  let outcome1 = try await engine.append(first)
  guard case .recorded(let firstRecord) = outcome1 else {
    Issue.record("expected recorded")
    return
  }

  let second = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "green",
    evidenceReferences: ["turn-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  let outcome2 = try await engine.append(second)

  guard case .recordedWithConflict(let secondRecord, let conflict) = outcome2 else {
    Issue.record("expected recordedWithConflict, got \(outcome2)")
    return
  }
  #expect(conflict.existingRecordID == firstRecord.id)
  #expect(conflict.newRecordID == secondRecord.id)

  let conflicts = try await engine.conflicts(subject: "user.favoriteColor")
  #expect(conflicts.count == 1)
}

@Test
func memoryEngineSupersessionSkipsConflictDetection() async throws {
  let engine = try await makeEngine()
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "blue",
    evidenceReferences: ["turn-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let firstRecord) = try await engine.append(first) else {
    Issue.record("expected recorded")
    return
  }

  let correction = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "green",
    evidenceReferences: ["turn-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite, supersedes: firstRecord.id)
  let outcome = try await engine.append(correction)

  guard case .recorded = outcome else {
    Issue.record("expected recorded (no conflict) for explicit supersession, got \(outcome)")
    return
  }
  let conflicts = try await engine.conflicts(subject: "user.favoriteColor")
  #expect(conflicts.isEmpty)
}

@Test
func memoryEngineResolveConflictPersistsResolution() async throws {
  let engine = try await makeEngine()
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "blue",
    evidenceReferences: ["turn-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  try await engine.append(first)
  let second = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "green",
    evidenceReferences: ["turn-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recordedWithConflict(_, let conflict) = try await engine.append(second) else {
    Issue.record("expected conflict")
    return
  }

  try await engine.resolveConflict(
    id: conflict.id, resolution: .keptExisting(reason: "user confirmed blue"))

  let conflicts = try await engine.conflicts(subject: "user.favoriteColor")
  #expect(conflicts.count == 1)
  if case .keptExisting(let reason) = conflicts.first?.resolution {
    #expect(reason == "user confirmed blue")
  } else {
    Issue.record(
      "expected keptExisting resolution, got \(String(describing: conflicts.first?.resolution))")
  }
}

// MARK: - Current-state projection

@Test
func memoryEngineCurrentStateReturnsLatestNonSupersededRecord() async throws {
  let engine = try await makeEngine()
  let firstRecordDraft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.testFramework", statement: "XCTest",
    evidenceReferences: ["doc-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let firstRecord) = try await engine.append(firstRecordDraft) else {
    Issue.record("expected recorded")
    return
  }
  let secondRecordDraft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.testFramework", statement: "swift-testing",
    evidenceReferences: ["doc-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite, supersedes: firstRecord.id)
  guard case .recorded(let secondRecord) = try await engine.append(secondRecordDraft) else {
    Issue.record("expected recorded")
    return
  }

  let current = try await engine.currentState(
    memoryClass: .projectFact, subject: "project.testFramework")
  #expect(current.count == 1)
  #expect(current.first?.id == secondRecord.id)
  #expect(current.first?.statement == "swift-testing")

  let superseding = try await engine.supersedingRecord(of: firstRecord.id)
  #expect(superseding?.id == secondRecord.id)
  let noSupersedingForLatest = try await engine.supersedingRecord(of: secondRecord.id)
  #expect(noSupersedingForLatest == nil)
}

@Test
func memoryEngineCurrentStateMostRecentWinsOnUnresolvedConflict() async throws {
  let engine = try await makeEngine()
  let first = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "blue",
    evidenceReferences: ["turn-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  try await engine.append(first)
  // Ensure createdAt ordering is unambiguous.
  try await Task.sleep(nanoseconds: 2_000_000)
  let second = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.favoriteColor", statement: "green",
    evidenceReferences: ["turn-2"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  try await engine.append(second)

  let current = try await engine.currentState(
    memoryClass: .userPreference, subject: "user.favoriteColor")
  #expect(current.count == 1)
  #expect(current.first?.statement == "green")
}

// MARK: - Correction

@Test
func memoryEngineCorrectAppendsSupersedingRecordAndEmitsEvent() async throws {
  let store = try await makeTempStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraMemoryTests", category: "correct"))
  let engine = MemoryEngine(store: store, eventBus: bus)
  let capture = Capture()
  await bus.subscribe(MemoryCorrectedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let draft = MemoryRecordDraft(
    memoryClass: .projectFact, subject: "project.buildTool", statement: "Make",
    evidenceReferences: ["doc-1"], provenance: .userStated, sensitivity: .internalLevel,
    retention: .indefinite)
  guard case .recorded(let original) = try await engine.append(draft) else {
    Issue.record("expected recorded")
    return
  }

  let corrected = try await engine.correct(
    recordID: original.id, newStatement: "SwiftPM", reason: "was factually wrong",
    evidenceReferences: ["Package.swift"])

  #expect(corrected.statement == "SwiftPM")
  #expect(corrected.supersedes == original.id)

  let events = await capture.all(MemoryCorrectedEvent.self)
  #expect(events.count == 1)
  #expect(events.first?.previousRecordID == original.id)
  #expect(events.first?.newRecordID == corrected.id)

  // The original record is untouched, not mutated or removed.
  let all = try await engine.inspect(memoryClass: .projectFact, subject: "project.buildTool")
  #expect(all.contains { $0.id == original.id && $0.statement == "Make" })
}

@Test
func memoryEngineCorrectRejectsAuditRecords() async throws {
  let engine = try await makeEngine()
  let auditDraft = MemoryRecordDraft(
    memoryClass: .auditSecurity, subject: "policy.denyRule.created", statement: "denied shellExec",
    evidenceReferences: ["audit-event-1"], provenance: .systemDerived(source: .policy),
    sensitivity: .internalLevel, retention: .auditRetention(days: 365))
  guard case .recorded(let record) = try await engine.append(auditDraft) else {
    Issue.record("expected recorded")
    return
  }

  await #expect(throws: AuraError.self) {
    try await engine.correct(recordID: record.id, newStatement: "tampered", reason: "malicious")
  }
}

// MARK: - Deletion

@Test
func memoryEngineDeleteRemovesRecordAndEmitsContentFreeAuditEvent() async throws {
  let store = try await makeTempStore()
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraMemoryTests", category: "delete"))
  let engine = MemoryEngine(store: store, eventBus: bus)
  let capture = Capture()
  await bus.subscribe(MemoryDeletedEvent.self) { envelope in
    await capture.append(envelope.payload)
  }

  let draft = MemoryRecordDraft(
    memoryClass: .userPreference, subject: "user.dietaryRestriction", statement: "vegetarian",
    evidenceReferences: ["turn-9"], provenance: .userStated, sensitivity: .sensitive,
    retention: .indefinite)
  guard case .recorded(let record) = try await engine.append(draft) else {
    Issue.record("expected recorded")
    return
  }

  let receipt = try await engine.deleteRecord(id: record.id, reason: "user requested deletion")
  #expect(receipt.recordID == record.id)

  let remaining = try await engine.inspect(
    memoryClass: .userPreference, subject: "user.dietaryRestriction")
  #expect(remaining.isEmpty)

  let events = await capture.all(MemoryDeletedEvent.self)
  #expect(events.count == 1)
  #expect(events.first?.recordID == record.id)

  let shadowed = try await store.shadowedRecordIDs()
  #expect(shadowed.contains(record.id))
}

@Test
func memoryEngineDeleteRejectsAuditRecords() async throws {
  let engine = try await makeEngine()
  let auditDraft = MemoryRecordDraft(
    memoryClass: .auditSecurity, subject: "policy.denyRule.created", statement: "denied shellExec",
    evidenceReferences: ["audit-event-1"], provenance: .systemDerived(source: .policy),
    sensitivity: .internalLevel, retention: .auditRetention(days: 365))
  guard case .recorded(let record) = try await engine.append(auditDraft) else {
    Issue.record("expected recorded")
    return
  }

  await #expect(throws: AuraError.self) {
    try await engine.deleteRecord(id: record.id, reason: "trying to erase audit trail")
  }
}

// MARK: - Retention enforcement
