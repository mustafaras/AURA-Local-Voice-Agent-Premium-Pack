import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

@testable import AuraIntent

/// SP-010: dialogue reachability for the four read-first capabilities.
///
/// These tests answer three questions the completion gate asks. Can a spoken
/// request in either language reach the right capability? Does a capability
/// that is not connected refuse *before* an adapter is touched? And can
/// anything private reach an event payload?

// MARK: - Fixtures

private let syntheticToken = "sk-abcdefghijklmnopqrstuvwxyz012345"
private let privateAddress = "person@example.com"

/// A reader that records its calls, so "the adapter was never reached" is an
/// assertion about behavior rather than about an outcome string.
private actor ReaderSpy {
  private(set) var calls: [String] = []
  func record(_ name: String) { calls.append(name) }
}

private struct ProductivityReaderFake: ProductivityReading {
  let spy: ReaderSpy
  let result: Result<ProductivityReadResult, ProductivityReadFailure>

  init(
    spy: ReaderSpy,
    result: Result<ProductivityReadResult, ProductivityReadFailure> = .success(
      ProductivityReadResult(
        capabilityID: InitialCapabilitySet.mailRead.id, itemCount: 2,
        summary: "2 message(s) matched: “Quarterly plan”.",
        sourceFingerprint: "ac-0123456789ab"))
  ) {
    self.spy = spy
    self.result = result
  }

  func readActiveBrowserTab(
    profileID: String?
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    await spy.record("browser")
    return result
  }

  func searchMail(
    accountID: String?, query: String, limit: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    await spy.record("mail:\(query)")
    return result
  }

  func summarizeMailThread(
    accountID: String?, query: String
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    await spy.record("mail-thread:\(query)")
    return result
  }

  func readCalendarAgenda(
    dayRange: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    await spy.record("calendar:\(dayRange)")
    return result
  }

  func readCalendarFreeWindows(
    dayRange: Int, minimumMinutes: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    await spy.record("calendar-free:\(dayRange):\(minimumMinutes)")
    return result
  }

  func lookupContacts(
    query: String, limit: Int
  ) async -> Result<ProductivityReadResult, ProductivityReadFailure> {
    await spy.record("contacts:\(query)")
    return result
  }
}

private final class EventRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var _resultSummaries: [String] = []
  private var _blockedReasons: [String] = []
  private var _invokedTools: [String] = []

  var resultSummaries: [String] { lock.withLock { _resultSummaries } }
  var blockedReasons: [String] { lock.withLock { _blockedReasons } }
  var invokedTools: [String] { lock.withLock { _invokedTools } }

  func subscribe(to bus: AuraEventBus) async {
    await bus.subscribe(ToolResultEvent.self) { [self] envelope in
      lock.withLock { _resultSummaries.append(envelope.payload.summary) }
    }
    await bus.subscribe(IntentBlockedEvent.self) { [self] envelope in
      lock.withLock { _blockedReasons.append(envelope.payload.reason) }
    }
    await bus.subscribe(ToolInvokedEvent.self) { [self] envelope in
      lock.withLock { _invokedTools.append(envelope.payload.toolID) }
    }
  }
}

private struct ProductivityHarness {
  let router: ToolRouter
  let registry: CapabilityRegistry
  let recorder: EventRecorder
  let spy: ReaderSpy
  let sessionID: UUID
}

private func makeProductivityHarness(
  reader: (any ProductivityReading)?,
  spy: ReaderSpy,
  readyCapabilities: [String] = []
) async throws -> ProductivityHarness {
  let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "sp010"))
  let recorder = EventRecorder()
  await recorder.subscribe(to: bus)
  let policyEngine = try await makeTestPolicyEngine(
    eventBus: bus, allowByDefaultTiers: [.observation, .reversible, .mutation, .destructive],
    grantConfirmationNoneFor: [])
  let automation = makeAutomation(spy: ApplicationControllerSpy(), eventBus: bus)
  let store = try await makeTestStore()
  let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
  let (agentRunner, sessionID) = makeAgentBackendTaskRunner(
    policyEngine: policyEngine, eventBus: bus)
  let registry = CapabilityRegistry()
  await InitialCapabilitySet.registerAll(in: registry)
  // The four read capabilities register disabled; a test that wants the ready
  // path has to say so, exactly as the composition root does after computing
  // real availability.
  for id in readyCapabilities {
    if let manifest = await registry.resolveLatest(id: id) {
      await registry.setAvailability(.ready, for: manifest.qualifiedID)
    }
  }
  let router = ToolRouter(
    policyEngine: policyEngine, automation: automation,
    shell: AuraShell(configuration: ShellConfiguration()), taskEngine: taskEngine,
    agentTaskRunner: agentRunner, capabilityRegistry: registry,
    confirmationPresenter: IntentAlwaysDenyConfirmationPresenter(), eventBus: bus,
    configuration: IntentEngineConfiguration(), productivityReader: reader)
  return ProductivityHarness(
    router: router, registry: registry, recorder: recorder, spy: spy, sessionID: sessionID)
}

private func makeReadIntent(
  kind: IntentKind,
  category: IntentSemanticCategory,
  slots: [IntentSlot] = []
) -> TypedIntent {
  TypedIntent(
    turnCorrelationID: UUID(), kind: kind, semanticCategory: category,
    rawUtterance: "", normalizedUtterance: "", slots: slots,
    classificationConfidence: 0.9, isAmbiguous: false, dialogueAct: .execute)
}

// MARK: - Classification

@Suite("SP-010 bilingual classification")
struct SP010ClassificationTests {
  @Test(
    "English and Turkish page-read utterances classify as browserRead",
    arguments: ["read this page", "summarize this page", "bu sayfayı oku", "açık sekmeyi oku"])
  func browserReadUtterances(utterance: String) {
    let result = RuleBasedUtteranceClassifier().classify(normalized: utterance, raw: utterance)
    #expect(result.kind == .browserRead)
    #expect(result.semanticCategory == .browserRead)
  }

  @Test("mail search carries the query as a slot, in both languages")
  func mailSearchCarriesQuery() {
    let english = RuleBasedUtteranceClassifier().classify(
      normalized: "search mail for quarterly plan", raw: "search mail for quarterly plan")
    #expect(english.kind == .mailRead)
    #expect(english.slots.first { $0.name == IntentSlotName.query }?.value == "quarterly plan")

    let turkish = RuleBasedUtteranceClassifier().classify(
      normalized: "postada ara üç aylık plan", raw: "postada ara üç aylık plan")
    #expect(turkish.kind == .mailRead)
    #expect(turkish.slots.first { $0.name == IntentSlotName.query }?.value == "üç aylık plan")
  }

  @Test("an explicit thread-summary utterance selects the thread read path")
  func mailThreadSummaryCarriesMode() {
    let result = RuleBasedUtteranceClassifier().classify(
      normalized: "summarize mail thread about aura fixture",
      raw: "summarize mail thread about aura fixture")
    #expect(result.kind == .mailRead)
    #expect(result.slots.first { $0.name == IntentSlotName.query }?.value == "aura fixture")
    #expect(result.slots.first { $0.name == IntentSlotName.threadSummary }?.value == "true")
  }

  @Test("an unread-mail check becomes a fixed provider query, not free text")
  func unreadCheckUsesFixedQuery() {
    let result = RuleBasedUtteranceClassifier().classify(
      normalized: "check my mail", raw: "check my mail")
    #expect(result.kind == .mailRead)
    #expect(result.slots.first { $0.name == IntentSlotName.query }?.value == "is:unread")
  }

  @Test("today and tomorrow resolve to different calendar ranges")
  func calendarRanges() {
    let today = RuleBasedUtteranceClassifier().classify(
      normalized: "what is on my calendar", raw: "what is on my calendar")
    #expect(today.kind == .calendarRead)
    #expect(today.slots.first { $0.name == IntentSlotName.dayRange }?.value == "1")

    let tomorrow = RuleBasedUtteranceClassifier().classify(
      normalized: "yarın ne var", raw: "yarın ne var")
    #expect(tomorrow.kind == .calendarRead)
    #expect(tomorrow.slots.first { $0.name == IntentSlotName.dayRange }?.value == "2")
  }

  @Test("contact lookup carries the name, in both languages")
  func contactLookup() {
    let english = RuleBasedUtteranceClassifier().classify(
      normalized: "find contact ada lovelace", raw: "find contact ada lovelace")
    #expect(english.kind == .contactsLookup)
    #expect(english.slots.first { $0.name == IntentSlotName.query }?.value == "ada lovelace")

    let turkish = RuleBasedUtteranceClassifier().classify(
      normalized: "kişi bul ada lovelace", raw: "kişi bul ada lovelace")
    #expect(turkish.kind == .contactsLookup)
  }

  /// The new patterns run before the file/URL and app classifiers, which is
  /// exactly where they could break existing behavior. These are the
  /// regressions that ordering would cause.
  @Test("the read patterns do not capture existing app, file, or URL commands")
  func orderingDoesNotRegressExistingIntents() {
    let classifier = RuleBasedUtteranceClassifier()
    #expect(classifier.classify(normalized: "open safari", raw: "open safari").kind == .appActivate)
    #expect(classifier.classify(normalized: "open mail", raw: "open mail").kind == .appActivate)
    #expect(
      classifier.classify(normalized: "show /Users/me/a.txt", raw: "show /Users/me/a.txt").kind
        == .fileReveal)
    #expect(
      classifier.classify(normalized: "go to https://example.com", raw: "go to https://example.com")
        .kind == .urlOpen)
  }
}

// MARK: - Risk and capability mapping

@Suite("SP-010 risk tier and capability mapping")
struct SP010RiskMappingTests {
  @Test("all four read categories are observation tier and need no confirmation")
  func readsAreObservation() {
    for category in [
      IntentSemanticCategory.browserRead, .mailRead, .calendarRead, .contactsLookup,
    ] {
      #expect(category.riskTier == .observation)
      #expect(!category.requiresMandatoryConfirmation)
    }
  }

  @Test("each read category maps to its own read capability and never to escalation")
  func capabilityMapping() {
    #expect(Capability.forIntent(.browserRead) == .browserRead)
    #expect(Capability.forIntent(.mailRead) == .mailRead)
    #expect(Capability.forIntent(.calendarRead) == .calendarRead)
    #expect(Capability.forIntent(.contactsLookup) == .contactsLookup)
    for category in IntentSemanticCategory.allCases {
      #expect(Capability.forIntent(category) != .oauthEscalate)
    }
  }

  @Test("mail and contact reads cannot be planned without a query")
  func queryIsRequired() {
    #expect(ToolRouter.requiredArgumentNames(for: .mailRead) == [IntentSlotName.query])
    #expect(ToolRouter.requiredArgumentNames(for: .contactsLookup) == [IntentSlotName.query])
    #expect(ToolRouter.requiredArgumentNames(for: .browserRead).isEmpty)
    #expect(ToolRouter.requiredArgumentNames(for: .calendarRead).isEmpty)
  }

  @Test("every read capability ID round-trips back to its intent kind")
  func capabilityIDsRoundTrip() {
    let pairs: [(IntentKind, String)] = [
      (.browserRead, InitialCapabilitySet.browserRead.id),
      (.mailRead, InitialCapabilitySet.mailRead.id),
      (.calendarRead, InitialCapabilitySet.calendarRead.id),
      (.contactsLookup, InitialCapabilitySet.contactsLookup.id),
    ]
    for (kind, id) in pairs {
      #expect(ToolRouter.intentKind(forCapabilityID: id) == kind)
      #expect(ToolRouter.semanticCategory(for: kind).riskTier == .observation)
    }
  }
}

// MARK: - Routing

@Suite("SP-010 routing and fail-closed behavior")
struct SP010RoutingTests {
  @Test("a disconnected capability refuses before the adapter is reached")
  func disabledCapabilityNeverReachesAdapter() async throws {
    let spy = ReaderSpy()
    // No ready capabilities: the registry keeps the read manifests disabled,
    // exactly as it does before an account is onboarded.
    let harness = try await makeProductivityHarness(
      reader: ProductivityReaderFake(spy: spy), spy: spy)

    let outcome = await harness.router.route(
      makeReadIntent(
        kind: .mailRead, category: .mailRead,
        slots: [IntentSlot(name: IntentSlotName.query, value: "is:unread")]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .failed = outcome else {
      Issue.record("a disabled capability must not execute; got \(outcome)")
      return
    }
    #expect(await spy.calls.isEmpty)
    #expect(harness.recorder.invokedTools.isEmpty)
  }

  /// SP-011: the free-window slot must select a different adapter method on
  /// the *same* capability. If it were routed to a capability of its own the
  /// user would face a second authorization for data they had already
  /// approved; if the slot were ignored they would be handed an agenda when
  /// they asked when they were free.
  @Test("the free-window slot selects free windows without a second capability")
  func freeWindowSlotSelectsFreeWindowRead() async throws {
    let spy = ReaderSpy()
    let harness = try await makeProductivityHarness(
      reader: ProductivityReaderFake(spy: spy), spy: spy,
      readyCapabilities: [InitialCapabilitySet.calendarRead.id])

    _ = await harness.router.route(
      makeReadIntent(
        kind: .calendarRead, category: .calendarRead,
        slots: [
          IntentSlot(name: IntentSlotName.dayRange, value: "1"),
          IntentSlot(name: IntentSlotName.freeWindows, value: "true"),
        ]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    let calls = await spy.calls
    #expect(calls.contains { $0.hasPrefix("calendar-free:") })
    #expect(!calls.contains { $0.hasPrefix("calendar:") })
  }

  @Test("an agenda request without the slot still reads the agenda")
  func agendaRequestStillReadsAgenda() async throws {
    let spy = ReaderSpy()
    let harness = try await makeProductivityHarness(
      reader: ProductivityReaderFake(spy: spy), spy: spy,
      readyCapabilities: [InitialCapabilitySet.calendarRead.id])

    _ = await harness.router.route(
      makeReadIntent(
        kind: .calendarRead, category: .calendarRead,
        slots: [IntentSlot(name: IntentSlotName.dayRange, value: "1")]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    let calls = await spy.calls
    #expect(calls.contains { $0.hasPrefix("calendar:") })
    #expect(!calls.contains { $0.hasPrefix("calendar-free:") })
  }

  @Test("a ready capability with no wired reader refuses instead of answering empty")
  func missingReaderFailsClosed() async throws {
    let spy = ReaderSpy()
    let harness = try await makeProductivityHarness(
      reader: nil, spy: spy, readyCapabilities: [InitialCapabilitySet.calendarRead.id])

    let outcome = await harness.router.route(
      makeReadIntent(kind: .calendarRead, category: .calendarRead),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .blockedByPolicy(let reason) = outcome else {
      Issue.record("a missing reader must be refused, not answered; got \(outcome)")
      return
    }
    // The distinction that matters: "no integration" must never be reported
    // as "nothing is scheduled".
    #expect(!reason.lowercased().contains("nothing is scheduled"))
    #expect(harness.recorder.blockedReasons.contains { $0.contains("noProductivityReader") })
  }

  @Test("a connected capability executes and emits a redacted result event")
  func readyCapabilityExecutes() async throws {
    let spy = ReaderSpy()
    let harness = try await makeProductivityHarness(
      reader: ProductivityReaderFake(spy: spy), spy: spy,
      readyCapabilities: [InitialCapabilitySet.mailRead.id])

    let outcome = await harness.router.route(
      makeReadIntent(
        kind: .mailRead, category: .mailRead,
        slots: [
          IntentSlot(name: IntentSlotName.query, value: "quarterly"),
          IntentSlot(name: IntentSlotName.accountID, value: privateAddress),
        ]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .executed(let summary, _) = outcome else {
      Issue.record("expected execution, got \(outcome)")
      return
    }
    #expect(summary.contains("2 message(s)"))
    #expect(await spy.calls == ["mail:quarterly"])
    #expect(harness.recorder.invokedTools == [InitialCapabilitySet.mailRead.id])

    // The account was named in the request; it must not appear in the event
    // stream, only its fingerprint.
    let events = harness.recorder.resultSummaries.joined(separator: " | ")
    #expect(!events.contains(privateAddress))
    #expect(!events.contains(syntheticToken))
    #expect(events.contains("ac-0123456789ab"))
  }

  @Test("a thread-summary intent reaches only the typed thread reader")
  func threadSummaryUsesThreadReader() async throws {
    let spy = ReaderSpy()
    let harness = try await makeProductivityHarness(
      reader: ProductivityReaderFake(spy: spy), spy: spy,
      readyCapabilities: [InitialCapabilitySet.mailRead.id])

    let outcome = await harness.router.route(
      makeReadIntent(
        kind: .mailRead, category: .mailRead,
        slots: [
          IntentSlot(name: IntentSlotName.query, value: "aura fixture"),
          IntentSlot(name: IntentSlotName.threadSummary, value: "true"),
        ]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .executed = outcome else {
      Issue.record("expected thread summary execution, got \(outcome)")
      return
    }
    #expect(await spy.calls == ["mail-thread:aura fixture"])
  }

  @Test("account ambiguity becomes a question, and records no failed result")
  func ambiguityAsksRatherThanGuesses() async throws {
    let spy = ReaderSpy()
    let reader = ProductivityReaderFake(
      spy: spy,
      result: .failure(.ambiguous(question: "Which of your approved mail accounts?")))
    let harness = try await makeProductivityHarness(
      reader: reader, spy: spy, readyCapabilities: [InitialCapabilitySet.mailRead.id])

    let outcome = await harness.router.route(
      makeReadIntent(
        kind: .mailRead, category: .mailRead,
        slots: [IntentSlot(name: IntentSlotName.query, value: "is:unread")]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .ambiguous(let question) = outcome else {
      Issue.record("expected a clarifying question, got \(outcome)")
      return
    }
    #expect(question.contains("approved mail accounts"))
    #expect(harness.recorder.resultSummaries.isEmpty)
    #expect(harness.recorder.blockedReasons.contains { $0.contains("accountAmbiguous") })
  }

  @Test("a revoked credential surfaces as unavailable with its remediation")
  func revokedCredentialIsReportedAsUnavailable() async throws {
    let spy = ReaderSpy()
    let reader = ProductivityReaderFake(
      spy: spy,
      result: .failure(
        .unavailable(reason: "the stored credential is expired or revoked Reconnect it.")))
    let harness = try await makeProductivityHarness(
      reader: reader, spy: spy, readyCapabilities: [InitialCapabilitySet.mailRead.id])

    let outcome = await harness.router.route(
      makeReadIntent(
        kind: .mailRead, category: .mailRead,
        slots: [IntentSlot(name: IntentSlotName.query, value: "is:unread")]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .blockedByPolicy(let reason) = outcome else {
      Issue.record("expected a refusal, got \(outcome)")
      return
    }
    #expect(reason.contains("Reconnect"))
  }

  @Test("a mail read without a query is refused by the planner, not by the adapter")
  func missingQueryRefusedBeforeAdapter() async throws {
    let spy = ReaderSpy()
    let harness = try await makeProductivityHarness(
      reader: ProductivityReaderFake(spy: spy), spy: spy,
      readyCapabilities: [InitialCapabilitySet.mailRead.id])

    let outcome = await harness.router.route(
      makeReadIntent(kind: .mailRead, category: .mailRead),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())

    guard case .failed(let reason) = outcome else {
      Issue.record("expected a failure, got \(outcome)")
      return
    }
    #expect(reason.contains(IntentSlotName.query))
    #expect(await spy.calls.isEmpty)
  }
}
