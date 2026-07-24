import Foundation
import AuraCore
import Testing

struct AuraCoreTests {

    @Test func eventEnvelopeRoundTrip() async throws {
        let payload = LifecycleEvent(state: "started", reason: "bootstrap")
        let envelope = EventEnvelope(
            id: UUID(),
            correlationID: UUID(),
            causationID: UUID(),
            actor: .system,
            sensitivity: .internalLevel,
            payload: payload
        )

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(EventEnvelope<LifecycleEvent>.self, from: data)

        #expect(decoded == envelope)
        #expect(decoded.schemaVersion == auraEnvelopeSchemaVersion)
    }

    @Test func eventEnvelopeChildInheritsCausality() async throws {
        let correlation = UUID()
        let parent = EventEnvelope(
            id: UUID(),
            correlationID: correlation,
            causationID: UUID(),
            actor: .user,
            sensitivity: .publicLevel,
            payload: LifecycleEvent(state: "parent")
        )

        let child = parent.child(payload: LifecycleEvent(state: "child"))
        #expect(child.correlationID == correlation)
        #expect(child.causationID == parent.id)
    }

    @Test func eventEnvelopeSchemaValidationRejectsUnsupportedVersion() async throws {
        let envelope = EventEnvelope(
            schemaVersion: "0.0.1",
            correlationID: UUID(),
            causationID: UUID(),
            actor: .system,
            sensitivity: .internalLevel,
            payload: LifecycleEvent(state: "bad")
        )

        #expect(throws: AuraError.self) {
            try envelope.validateSchema()
        }
    }

    @Test func configurationDefaultsValidate() async throws {
        let config = AuraConfiguration.default
        try config.validate()
        #expect(config.audio.sampleRate == 16_000)
        #expect(config.privacy.ambientAudioRetentionSeconds == 0)
    }

    @Test func configurationLoadingMergesDefaults() async throws {
        let json = """
        {
            "audio": {
                "sampleRate": 48000
            }
        }
        """.data(using: .utf8)!

        let config = try AuraConfiguration.load(from: json)
        #expect(config.audio.sampleRate == 48_000)
        #expect(config.audio.frameLength == 512) // default preserved
    }

    @Test func configurationValidationRejectsInvalidLogLevel() async throws {
        let config = AuraConfiguration(
            log: LoggingConfiguration(minimumLevel: "verbose", destination: "stderr")
        )
        #expect(throws: AuraError.self) {
            try config.validate()
        }
    }

    @Test func loggerRespectsMinimumLevel() async {
        let logger = AuraLogger(subsystem: "test", category: "test", minimumLevel: .warning)
        // Logging is side-effect-only through os.Logger; we verify the actor is reachable.
        await logger.info("should be suppressed")
        await logger.warning("should be emitted")
    }
}
