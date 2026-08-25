import AuraContext
import AuraCore
import AuraMemory
import AuraStore
import Foundation
import Testing

@testable import AuraIntent

private struct ClarificationFixtureClassifier: UtteranceClassifying {
  func classify(normalized: String, raw: String) -> ClassificationResult {
    if normalized.hasPrefix("open /repo/") {
      let path = String(normalized.dropFirst("open ".count))
      return ClassificationResult(
        kind: .fileOpen, semanticCategory: .fileOpen,
        slots: [IntentSlot(name: IntentSlotName.filePath, value: path)],
        confidence: 0.95, dialogueAct: .execute)
    }
    if normalized.hasPrefix("delete the file") {
      return ClassificationResult(
        kind: .shellExecute, semanticCategory: .shellDestructive, confidence: 0.95,
        dialogueAct: .execute)
    }
    return ClassificationResult(kind: .converse, semanticCategory: .converse, confidence: 0.95)
  }
}

/// Manually advanced clock. `clarificationExpirySeconds` (60) is far below
/// `referenceCandidateMaxAgeSeconds` (900), so time can pass the expiry
/// without aging the candidates out — which is what isolates the expiry
/// behaviour from ordinary candidate staleness.
private final class TestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Date

  init(_ value: Date) { self.value = value }

  var current: Date {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func advance(by interval: TimeInterval) {
    lock.lock()
    value += interval
    lock.unlock()
  }
}

private func makeClarificationEngine(clock: TestClock) async throws -> IntentEngine {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraIntentTests", category: "reference-clarification"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let context = ContextEngine(store: store, memory: memory, eventBus: bus)
  let builder = ContextBuilder(engine: context, memory: memory, eventBus: bus)
  return IntentEngine(
    classifier: ClarificationFixtureClassifier(), contextEngine: context,
    contextBuilder: builder, memoryEngine: memory,
    referenceContextProvider: { _ in
      ReferenceContextSnapshot(
        activeWorkspace: ActiveWorkspaceSnapshot(
          workspaceFolderPaths: ["/repo"], capturedAt: clock.current))
    },
    eventBus: bus, sessionID: UUID(), now: { clock.current })
}

/// Drive the engine to the point where "the file" is genuinely ambiguous
/// between `/repo/alpha.txt` and `/repo/beta.txt`.
private func makeAmbiguity(_ engine: IntentEngine) async throws {
  for path in ["open /repo/alpha.txt", "open /repo/beta.txt"] {
    _ = await engine.classify(
      TurnCompletedEvent(text: path, confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
  }
  let intent = await engine.classify(
    TurnCompletedEvent(text: "delete the file", confidence: 1, isFinal: true),
    correlationID: UUID(), causationID: UUID())
  #expect(intent.isAmbiguous)
  let result = try #require(await engine.inspectLastContext())
  guard case .ambiguous(let candidates) = result.referenceResolution else {
    Issue.record("fixture did not produce ambiguity: \(result.referenceResolution)")
    return
  }
  #expect(candidates.count == 2)
}

@Suite("SP-019 multi-turn reference clarification")
struct SP019ReferenceClarificationTests {
  @Test("naming one of the offered candidates resolves the reference next turn")
  func answerResolvesTheReference() async throws {
    let clock = TestClock(Date())
    let engine = try await makeClarificationEngine(clock: clock)
    try await makeAmbiguity(engine)

    let answered = await engine.classify(
      TurnCompletedEvent(text: "delete the file alpha", confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
    let result = try #require(await engine.inspectLastContext())

    guard case .resolved(let candidate) = result.referenceResolution else {
      Issue.record("expected the answer to resolve, got \(result.referenceResolution)")
      return
    }
    #expect(candidate.description == "file: /repo/alpha.txt")
    #expect(!answered.isAmbiguous)
  }

  @Test("an answer naming nothing offered leaves the question standing")
  func unrelatedAnswerStaysAmbiguous() async throws {
    let clock = TestClock(Date())
    let engine = try await makeClarificationEngine(clock: clock)
    try await makeAmbiguity(engine)

    _ = await engine.classify(
      TurnCompletedEvent(text: "delete the file gamma", confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
    let result = try #require(await engine.inspectLastContext())

    guard case .ambiguous = result.referenceResolution else {
      Issue.record("expected the reference to stay ambiguous, got \(result.referenceResolution)")
      return
    }
  }

  @Test("an answer that fits both candidates is not treated as a confirmation")
  func sharedTokenAnswerStaysAmbiguous() async throws {
    let clock = TestClock(Date())
    let engine = try await makeClarificationEngine(clock: clock)
    try await makeAmbiguity(engine)

    // "txt" belongs to both candidates, so it identifies neither.
    _ = await engine.classify(
      TurnCompletedEvent(text: "delete the file txt", confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
    let result = try #require(await engine.inspectLastContext())

    guard case .ambiguous = result.referenceResolution else {
      Issue.record("a shared token must not confirm a target: \(result.referenceResolution)")
      return
    }
  }

  @Test("a stale question is not answered by a much later turn")
  func expiredClarificationIsDiscarded() async throws {
    let clock = TestClock(Date())
    let engine = try await makeClarificationEngine(clock: clock)
    try await makeAmbiguity(engine)

    // Past `clarificationExpirySeconds`, but well inside the candidates'
    // 900-second freshness window: the question, not the candidates, is stale.
    clock.advance(by: 120)
    _ = await engine.classify(
      TurnCompletedEvent(text: "delete the file alpha", confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
    let result = try #require(await engine.inspectLastContext())

    if case .resolved = result.referenceResolution {
      Issue.record("an expired question must not be answered by a later turn")
    }
  }

  @Test("distinctive tokens exclude anything two candidates share")
  func distinctiveTokensDropSharedWords() {
    let alpha = ReferenceCandidate(
      sourceID: .recentFile(path: "/repo/alpha.txt"), description: "file: /repo/alpha.txt",
      authority: .userStated, confidence: 1, observedAt: Date(), hasDirectEvidence: true,
      scopeMatch: true, entityKind: .file)
    let beta = ReferenceCandidate(
      sourceID: .recentFile(path: "/repo/beta.txt"), description: "file: /repo/beta.txt",
      authority: .userStated, confidence: 1, observedAt: Date(), hasDirectEvidence: true,
      scopeMatch: true, entityKind: .file)

    let distinctive = IntentEngine.distinctiveTokens(among: [alpha, beta])

    #expect(distinctive[alpha.id] == ["alpha"])
    #expect(distinctive[beta.id] == ["beta"])
  }
}

// MARK: - Production classifier reachability

/// The suite above proves the clarification round trip with a fixture
/// classifier. That is exactly how the pre-existing reference tests were
/// written — and it hid the fact that the *production* rule-based classifier
/// could never emit an intent carrying an unresolved reference, so none of this
/// machinery was reachable in the shipped app. These tests use the real
/// `RuleBasedUtteranceClassifier`.
private func makeProductionEngine(clock: TestClock) async throws -> IntentEngine {
  let path = NSTemporaryDirectory().appending(UUID().uuidString).appending(".db")
  let store = try await AuraStore(path: path)
  let bus = AuraEventBus(
    logger: AuraLogger(subsystem: "AuraIntentTests", category: "reference-production"))
  let memory = MemoryEngine(store: store, eventBus: bus)
  let context = ContextEngine(store: store, memory: memory, eventBus: bus)
  let builder = ContextBuilder(engine: context, memory: memory, eventBus: bus)
  return IntentEngine(
    classifier: RuleBasedUtteranceClassifier(), contextEngine: context,
    contextBuilder: builder, memoryEngine: memory,
    referenceContextProvider: { _ in
      ReferenceContextSnapshot(
        activeWorkspace: ActiveWorkspaceSnapshot(
          workspaceFolderPaths: ["/workspace"], capturedAt: clock.current))
    },
    eventBus: bus, sessionID: UUID(), now: { clock.current })
}

@Suite("SP-019 reference resolution is reachable through the production classifier")
struct SP019ProductionReferenceReachabilityTests {
  @Test("an open-prefixed reference becomes a fileOpen with its target left open")
  func referenceBecomesFileOpenWithoutSlot() {
    let result = RuleBasedUtteranceClassifier().classify(
      normalized: "open the file", raw: "open the file")

    #expect(result.kind == .fileOpen)
    #expect(result.slots.isEmpty)
    // Must clear the confidence gate (0.6) or it is forced back to `.unknown`.
    #expect(result.confidence > 0.6)
  }

  @Test("a reference to an application resolves against applications, not files")
  func applicationReferenceBecomesAppActivate() {
    let result = RuleBasedUtteranceClassifier().classify(
      normalized: "open the app", raw: "open the app")

    #expect(result.kind == .appActivate)
    #expect(result.slots.isEmpty)
  }

  @Test(
    "explicit targets are unchanged",
    arguments: [
      ("open /workspace/a.txt", IntentKind.fileOpen),
      ("open safari", IntentKind.appActivate),
    ])
  func explicitTargetsAreUnaffected(utterance: String, expected: IntentKind) {
    let result = RuleBasedUtteranceClassifier().classify(
      normalized: utterance, raw: utterance)

    #expect(result.kind == expected)
    #expect(!result.slots.isEmpty)
  }

  @Test("the real classifier drives a full ambiguity-then-answer round trip")
  func productionRoundTripResolves() async throws {
    let clock = TestClock(Date())
    let engine = try await makeProductionEngine(clock: clock)

    for path in ["open /workspace/alpha.txt", "open /workspace/beta.txt"] {
      _ = await engine.classify(
        TurnCompletedEvent(text: path, confidence: 1, isFinal: true),
        correlationID: UUID(), causationID: UUID())
    }

    // "the file" is genuinely ambiguous between the two.
    let ambiguous = await engine.classify(
      TurnCompletedEvent(text: "open the file", confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
    let ambiguousResult = try #require(await engine.inspectLastContext())
    #expect(ambiguous.isAmbiguous)
    guard case .ambiguous(let candidates) = ambiguousResult.referenceResolution else {
      Issue.record("expected ambiguity, got \(ambiguousResult.referenceResolution)")
      return
    }
    #expect(candidates.count == 2)

    // The user answers, naming one of the two offered candidates.
    let answered = await engine.classify(
      TurnCompletedEvent(text: "open the file alpha", confidence: 1, isFinal: true),
      correlationID: UUID(), causationID: UUID())
    let answeredResult = try #require(await engine.inspectLastContext())

    guard case .resolved(let candidate) = answeredResult.referenceResolution else {
      Issue.record("expected resolution, got \(answeredResult.referenceResolution)")
      return
    }
    #expect(candidate.description == "file: /workspace/alpha.txt")
    #expect(!answered.isAmbiguous)
    // The resolved target is bound into the typed slot the tool router reads.
    #expect(answered.slotValue(IntentSlotName.filePath) == "/workspace/alpha.txt")
  }
}
