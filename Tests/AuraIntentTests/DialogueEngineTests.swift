import AuraAgent
import AuraCore
import AuraIntent
import Foundation
import Testing

private final class MutableDateBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date

  init(_ value: Date) {
    self.value = value
  }

  func now() -> Date {
    lock.withLock { value }
  }

  func advance(by interval: TimeInterval) {
    lock.withLock { value.addTimeInterval(interval) }
  }
}

private struct DialogueBackendStub: DialogueReasoningBackend {
  let result: Result<OllamaCapabilityResult, AuraError>

  func reason(
    prompt: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async throws(AuraError) -> OllamaCapabilityResult {
    switch result {
    case .success(let value): return value
    case .failure(let error): throw error
    }
  }
}

private struct StructuredNLUBackendStub: StructuredNLUBackend {
  let response: StructuredNLUResponse

  func propose(
    prompt: String,
    actor: ActorID,
    sessionID: UUID,
    correlationID: UUID,
    causationID: UUID
  ) async throws(AuraError) -> StructuredNLUResponse {
    response
  }
}

private func dialogueIntent(
  language: DialogueLanguage = .english,
  utterance: String = "Why is the sky blue?"
) -> TypedIntent {
  TypedIntent(
    turnCorrelationID: UUID(),
    kind: .converse,
    semanticCategory: .converse,
    rawUtterance: utterance,
    normalizedUtterance: utterance.lowercased(),
    classificationConfidence: 0.9,
    isAmbiguous: false,
    language: language,
    dialogueAct: .answer)
}

@Test
func dialogueEngineUsesLocalReasoningBackendAndKeepsProvenance() async {
  let engine = DialogueEngine(
    reasoningBackend: DialogueBackendStub(
      result: .success(
        OllamaCapabilityResult(
          text: "Rayleigh scattering explains it.", model: "local:latest", degraded: false))))
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let contextItem = DialogueContextItem(
    sourceID: "utterance", summary: "current question", confidence: 1, authority: "userStated")
  let response = await engine.respond(
    to: dialogueIntent(),
    context: context,
    contextItems: [contextItem])

  #expect(response.text == "Rayleigh scattering explains it.")
  #expect(response.modelID == "local:latest")
  #expect(response.degraded == false)
  #expect(response.sourceIDs == ["utterance"])
}

@Test
func dialogueEngineReportsHonestTurkishDegradationWithoutBackend() async {
  let engine = DialogueEngine()
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let response = await engine.respond(
    to: dialogueIntent(language: .turkish, utterance: "Gökyüzü neden mavi?"), context: context)

  #expect(response.degraded)
  #expect(response.modelID == nil)
  #expect(response.text.contains("Yerel"))
}

@Test
func dialogueEngineReportsHonestDegradationWhenBackendFails() async {
  let engine = DialogueEngine(
    reasoningBackend: DialogueBackendStub(
      result: .failure(AuraError.ollamaError("daemon unavailable"))))
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let response = await engine.respond(
    to: dialogueIntent(language: .english), context: context)

  #expect(response.degraded)
  #expect(response.modelID == nil)
  #expect(response.text.contains("unavailable"))
}

@Test
func dialogueEnginePublishesDegradedRuntimeHealthWithoutBackend() async {
  let registry = RuntimeHealthRegistry()
  let engine = DialogueEngine(runtimeHealthRegistry: registry)
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  _ = await engine.respond(to: dialogueIntent(), context: context)

  #expect(await registry.health(for: "dialogue")?.status == .degraded)
}

@Test
func dialogueEngineBoundsResponseAndPromptData() async {
  let longText = String(repeating: "answer ", count: 2_000)
  let engine = DialogueEngine(
    reasoningBackend: DialogueBackendStub(
      result: .success(OllamaCapabilityResult(text: longText, model: "local", degraded: false))),
    configuration: DialogueEngineConfiguration(
      maxPromptCharacters: 1_000, maxResponseCharacters: 256))
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let response = await engine.respond(
    to: dialogueIntent(utterance: String(repeating: "question ", count: 500)), context: context)

  #expect(response.text.count <= 256)
}

@Test
func structuredModelActionProposalCannotBecomeExecutableIntent() async {
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraIntentTests", category: "structured-nlu"))
  let engine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    structuredNLUBackend: StructuredNLUBackendStub(
      response: StructuredNLUResponse(
        dialogueAct: "execute",
        language: "english",
        capabilityID: "shell.execute",
        confidence: "0.99",
        ambiguityReason: "")),
    eventBus: bus,
    sessionID: UUID())
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let intent = await engine.classify(
    TurnCompletedEvent(
      text: "please do the operation",
      confidence: 1,
      isFinal: true,
      requiresPolicyReview: true,
      turnContext: context),
    context: context)

  #expect(intent.kind == .unknown)
  #expect(intent.isAmbiguous)
  #expect(intent.dialogueAct == .clarify)
  #expect(intent.slots.isEmpty)
}

@Test
func intentEngineFillsAnUnknownApplicationOnTheNextTurn() async {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "slot-fill"))
  let engine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    configuration: IntentEngineConfiguration(clarificationExpirySeconds: 60),
    eventBus: bus,
    sessionID: UUID(),
    now: { Date(timeIntervalSince1970: 100) })
  let firstContext = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let first = await engine.classify(
    TurnCompletedEvent(
      text: "open an unknown application",
      confidence: 1,
      isFinal: true,
      turnContext: firstContext),
    context: firstContext)
  #expect(first.isAmbiguous)
  #expect(first.kind == .unknown)

  let secondContext = TurnContext(
    sessionID: firstContext.sessionID,
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  let second = await engine.classify(
    TurnCompletedEvent(
      text: "Safari",
      confidence: 1,
      isFinal: true,
      turnContext: secondContext),
    context: secondContext)

  #expect(second.kind == .appActivate)
  #expect(second.dialogueAct == .execute)
  #expect(second.slotValue(IntentSlotName.bundleIdentifier) == "com.apple.Safari")
}

@Test
func intentEngineExpiresClarificationBeforeAcceptingAStandaloneTarget() async {
  let dateBox = MutableDateBox(Date(timeIntervalSince1970: 100))
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "slot-expiry"))
  let engine = IntentEngine(
    classifier: RuleBasedUtteranceClassifier(),
    configuration: IntentEngineConfiguration(clarificationExpirySeconds: 10),
    eventBus: bus,
    sessionID: UUID(),
    now: { dateBox.now() })
  let context = TurnContext(
    sessionID: UUID(),
    activationSource: .text,
    actor: .user,
    authority: .userUtterance,
    sensitivity: .sensitive)
  _ = await engine.classify(
    TurnCompletedEvent(
      text: "open an unknown application",
      confidence: 1,
      isFinal: true,
      turnContext: context),
    context: context)
  dateBox.advance(by: 11)

  let followUp = await engine.classify(
    TurnCompletedEvent(
      text: "Safari",
      confidence: 1,
      isFinal: true,
      turnContext: context),
    context: context)

  #expect(followUp.kind == .converse)
  #expect(followUp.kind != .appActivate)
}

@Test
func codingAgentIntentPreservesDestructiveRiskMetadata() {
  #expect(Capability.forIntent(.codingAgentRun) == .agentRun)
  #expect(Capability.forIntent(.codingAgentRun).riskTier == .destructive)
  #expect(InitialCapabilitySet.codingAgentRun.requiredCapability == .agentRun)
}
