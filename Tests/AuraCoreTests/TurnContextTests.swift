import AuraCore
import Foundation
import Testing

struct TurnContextTests {
  @Test func advancingPreservesTraceAndAuthorityMetadata() {
    let sessionID = UUID()
    let turnID = UUID()
    let correlationID = UUID()
    let context = TurnContext(
      sessionID: sessionID,
      turnID: turnID,
      correlationID: correlationID,
      causationID: UUID(),
      activationSource: .pushToTalk,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive,
      language: "tr-TR",
      timingOrigin: 42,
      backendIDs: TurnBackendIDs(stt: "native-speech"))

    let nextCausationID = UUID()
    let advanced = context.advancing(
      causationID: nextCausationID,
      backendIDs: TurnBackendIDs(stt: "native-speech", tts: "system", tool: "automation.appActivate"))

    #expect(advanced.sessionID == sessionID)
    #expect(advanced.turnID == turnID)
    #expect(advanced.correlationID == correlationID)
    #expect(advanced.causationID == nextCausationID)
    #expect(advanced.authority == .userUtterance)
    #expect(advanced.sensitivity == .sensitive)
    #expect(advanced.backendIDs.tool == "automation.appActivate")
  }

  @Test func envelopeUsesContextCorrelationAndCausation() {
    let context = TurnContext(
      sessionID: UUID(),
      activationSource: .text,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .sensitive)
    let envelope = context.envelope(payload: LifecycleEvent(state: "thinking"))

    #expect(envelope.correlationID == context.correlationID)
    #expect(envelope.causationID == context.causationID)
    #expect(envelope.actor == .user)
    #expect(envelope.sensitivity == .sensitive)
  }

  @Test func contextRoundTripsThroughCodable() throws {
    let context = TurnContext(
      sessionID: UUID(),
      activationSource: .wakeWord,
      actor: .user,
      authority: .userUtterance,
      sensitivity: .internalLevel,
      language: "en-US",
      timingOrigin: 123.5,
      backendIDs: TurnBackendIDs(stt: "native-speech", tts: "system"))
    let data = try JSONEncoder().encode(context)
    let decoded = try JSONDecoder().decode(TurnContext.self, from: data)

    #expect(decoded == context)
  }
}
