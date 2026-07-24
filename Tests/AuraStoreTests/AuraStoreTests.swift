import Foundation
import AuraCore
import AuraStore
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

        let rows = try await store.database.query(sql: "SELECT COUNT(*) AS count FROM events;", arguments: [])
        let count = (rows.first?["count"] as? SQLiteValue)?.integerValue ?? 0
        #expect(count == 1)
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

    private func temporaryDatabasePath() -> String {
        NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
    }

    private func cleanup(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
