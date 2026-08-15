import AuraCore
import AuraStore
import Foundation
import Testing

struct AuraStoreTests {

  @Test func storeOpensAndMigrates() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let entries = try await store.entries()
    #expect(entries.isEmpty)
  }

  @Test func storeAppendsLedgerEntry() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let entry = ProjectLedgerEntry(
      taskID: "TEST-001",
      title: "Test entry",
      actor: "test",
      objective: "Verify persistence",
      startingState: "empty"
    )
    try await store.append(entry)

    let entries = try await store.entries()
    #expect(entries.count == 1)
    #expect(entries.first?.taskID == "TEST-001")
  }

  @Test func storePersistsEvent() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let envelope = EventEnvelope(
      correlationID: UUID(),
      causationID: UUID(),
      actor: .audio,
      sensitivity: .sensitive,
      payload: LifecycleEvent(state: "captured", reason: "vad")
    )
    try await store.persistEvent(envelope)

    let rows = try await store.database.query(
      sql: "SELECT COUNT(*) AS count FROM events;", arguments: [])
    let count = (rows.first?["count"] as? SQLiteValue)?.integerValue ?? 0
    #expect(count == 1)
  }

  @Test func storePersistsOnlyRedactedTraceColumns() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let requestID = UUID()
    let record = RedactedTraceRecord(
      correlationID: UUID(),
      causationID: UUID(),
      phase: "tool",
      eventType: "tool.result",
      requestID: requestID,
      actionIdentifier: "app.terminate",
      outcome: "verified")
    try await store.appendTrace(record)

    let rows = try await store.database.query(
      sql: "SELECT * FROM redacted_trace_records;", arguments: [])
    #expect(rows.count == 1)
    #expect(rows.first?["request_id"]?.textValue == requestID.uuidString)
    #expect(rows.first?["action_identifier"]?.textValue == "app.terminate")
    #expect(rows.first?["outcome"]?.textValue == "verified")
    #expect(rows.first?["payload_json"] == nil)
  }

  @Test func entriesRespectsSinceAndLimit() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let now = Date()
    let old = ProjectLedgerEntry(
      timestamp: Date(timeIntervalSince1970: 0),
      taskID: "OLD",
      title: "Old",
      actor: "test",
      objective: "",
      startingState: ""
    )
    let recent = ProjectLedgerEntry(
      timestamp: now,
      taskID: "RECENT",
      title: "Recent",
      actor: "test",
      objective: "",
      startingState: ""
    )
    try await store.append(old)
    try await store.append(recent)

    let filtered = try await store.entries(since: now.addingTimeInterval(-1), limit: 10)
    #expect(filtered.count == 1)
    #expect(filtered.first?.taskID == "RECENT")
  }

  @Test func storeAppendsAndQueriesMemoryRecord() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let record = MemoryRecord(
      memoryClass: .projectFact,
      subject: "project.name",
      statement: "AURA",
      evidenceReferences: ["README.md"],
      provenance: .userStated,
      confidence: 1.0,
      sensitivity: .internalLevel,
      retention: .indefinite
    )
    try await store.appendMemoryRecord(record)

    let all = try await store.memoryRecords(matching: .all)
    #expect(all.count == 1)
    #expect(all.first?.id == record.id)
    #expect(all.first?.statement == "AURA")
    #expect(all.first?.evidenceReferences == ["README.md"])
    #expect(all.first?.provenance == .userStated)
    #expect(all.first?.retention == .indefinite)
  }

  @Test func storeMemoryRecordsExcludesSupersededByDefault() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let original = MemoryRecord(
      memoryClass: .projectFact, subject: "project.buildTool", statement: "Make",
      evidenceReferences: ["doc-1"], provenance: .userStated, confidence: 1.0,
      sensitivity: .internalLevel, retention: .indefinite)
    try await store.appendMemoryRecord(original)
    let correction = MemoryRecord(
      memoryClass: .projectFact, subject: "project.buildTool", statement: "SwiftPM",
      evidenceReferences: ["doc-2"], provenance: .userStated, confidence: 1.0,
      sensitivity: .internalLevel, retention: .indefinite, supersedes: original.id)
    try await store.appendMemoryRecord(correction)

    let active = try await store.memoryRecords(matching: MemoryQuery(includeSuperseded: false))
    #expect(active.count == 1)
    #expect(active.first?.statement == "SwiftPM")

    let all = try await store.memoryRecords(matching: .all)
    #expect(all.count == 2)
  }

  @Test func storeDeleteMemoryRecordRemovesRow() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let record = MemoryRecord(
      memoryClass: .userPreference, subject: "user.favoriteColor", statement: "blue",
      evidenceReferences: ["turn-1"], provenance: .userStated, confidence: 1.0,
      sensitivity: .sensitive, retention: .indefinite)
    try await store.appendMemoryRecord(record)
    try await store.deleteMemoryRecord(id: record.id)

    let all = try await store.memoryRecords(matching: .all)
    #expect(all.isEmpty)
  }

  @Test func storeAppendsAndUpdatesMemoryConflictResolution() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let conflict = MemoryConflict(
      memoryClass: .userPreference, subject: "user.favoriteColor", existingRecordID: UUID(),
      newRecordID: UUID())
    try await store.appendMemoryConflict(conflict)

    let unresolved = try await store.memoryConflicts(unresolvedOnly: true)
    #expect(unresolved.count == 1)

    try await store.setMemoryConflictResolution(id: conflict.id, resolution: .supersededExisting)
    let resolved = try await store.memoryConflicts(unresolvedOnly: true)
    #expect(resolved.isEmpty)
    let all = try await store.memoryConflicts()
    #expect(all.first?.resolution == .supersededExisting)
  }

  @Test func storeAppendsImmutablePluginAuditHistory() async throws {
    let path = temporaryDatabasePath()
    defer { cleanup(path: path) }

    let store = try await AuraStore(path: path)
    let correlationID = UUID()
    let record = PluginAuditRecord(
      pluginID: "com.example.plugin",
      version: "1.0.0",
      action: "install",
      actor: .user,
      outcome: "success",
      correlationID: correlationID)
    try await store.appendPluginAudit(record)

    let records = try await store.pluginAuditRecords(pluginID: "com.example.plugin")
    #expect(records.count == 1)
    #expect(records.first?.id == record.id)
    #expect(records.first?.action == record.action)
    #expect(records.first?.outcome == record.outcome)
    #expect(
      abs((records.first?.timestamp ?? .distantPast).timeIntervalSince(record.timestamp)) < 0.001)
    #expect(records.first?.correlationID == correlationID)
  }

  private func temporaryDatabasePath() -> String {
    NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  }

  private func cleanup(path: String) {
    try? FileManager.default.removeItem(atPath: path)
  }
}
