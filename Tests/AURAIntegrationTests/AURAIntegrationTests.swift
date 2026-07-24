import AuraCore
import AuraStore
import AURA
import Foundation
import Testing

struct AURAIntegrationTests {

    @Test func executableBootstrapsStore() async throws {
        let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let store = try await AuraStore(path: path)
        let entry = ProjectLedgerEntry(
            taskID: "INT-001",
            title: "Integration smoke test",
            actor: "test",
            objective: "Verify AuraStore + AuraCore wiring",
            startingState: "fresh database"
        )
        try await store.append(entry)

        let entries = try await store.entries()
        #expect(entries.count == 1)
    }

    @Test func eventBusSubscriptionAndPersistence() async throws {
        let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let store = try await AuraStore(path: path)
        let logger = AuraLogger(subsystem: "test", category: "integration", minimumLevel: .warning)
        let bus = AuraEventBus(logger: logger)

        let received = AtomicBox<[EventEnvelope<LifecycleEvent>]>([])
        await bus.subscribe(LifecycleEvent.self) { envelope in
            await received.withValue { current in current + [envelope] }
        }

        let envelope = EventEnvelope(
            correlationID: UUID(),
            causationID: UUID(),
            actor: .system,
            sensitivity: .internalLevel,
            payload: LifecycleEvent(state: "integration", reason: "test")
        )

        await bus.emit(envelope)
        try await store.persistEvent(envelope)

        let captured = await received.value
        #expect(captured.count == 1)
        #expect(captured.first?.payload == envelope.payload)

        let rows = try await store.database.query(sql: "SELECT COUNT(*) AS count FROM events;", arguments: [])
        let count = (rows.first?["count"] as? SQLiteValue)?.integerValue ?? 0
        #expect(count == 1)
    }
}
