import AuraAgent
import AuraAudio
import AuraCore
import Foundation
import Testing

struct TextTurnTests {
  @Test func typedTurnEntersThinkingAndEmitsContext() async throws {
    let bus = AuraEventBus(logger: AuraLogger(subsystem: "AURA", category: "TextTurnTests"))
    let context = TurnContext(
      sessionID: UUID(),
      activationSource: .text,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive,
      language: "en-US")
    let captured = AtomicBox<[EventEnvelope<TurnCompletedEvent>]>([])
    await bus.subscribe(TurnCompletedEvent.self) { envelope in
      await captured.withValue { $0 + [envelope] }
    }
    let conversation = Conversation(
      configuration: ConversationConfiguration(),
      ttsConfiguration: TTSConfiguration(),
      ttsEngine: MockTTSEngine(),
      eventBus: bus,
      logger: AuraLogger(subsystem: "AURA", category: "TextTurnTests"),
      sessionID: context.sessionID)

    await conversation.submitTextTurn("open Safari", context: context)
    try await Task.sleep(nanoseconds: 20_000_000)

    #expect(await conversation.state == .thinking)
    let events = await captured.value
    #expect(events.count == 1)
    #expect(events.first?.correlationID == context.correlationID)
    #expect(events.first?.payload.turnContext?.turnID == context.turnID)
    #expect(events.first?.payload.text == "open Safari")
  }
}
