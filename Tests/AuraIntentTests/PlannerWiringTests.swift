import AuraAutomation
import AuraCore
import AuraPolicy
import AuraShell
import AuraStore
import AuraTasks
import Foundation
import Testing

@testable import AuraIntent

/// SP-006 closeout follow-up: `CapabilityPlanner` used to be constructed only
/// in tests, so "only a manifest-validated step ever becomes a `PlanStep`" was
/// a test-only property and no production path built a plan. These tests pin
/// the wiring that closed that gap — the planner as the mandatory seam in
/// `ToolRouter.route`, and `ToolRouter.routePlan` as a real multi-step
/// executor running each step through the same policy → adapter path.
@Suite("Planner wiring (production path)")
struct PlannerWiringTests {
  private struct Harness {
    let router: ToolRouter
    let registry: CapabilityRegistry
    let sessionID: UUID
    let events: EventRecorder
  }

  /// Records what the router emits, so a test can assert on the trace rather
  /// than on the return value alone.
  private actor EventRecorder {
    private(set) var planFingerprints: [String] = []
    private(set) var blockedReasons: [String] = []
    private(set) var invokedToolIDs: [String] = []

    func subscribe(to bus: AuraEventBus) async {
      await bus.subscribe(IntentPlanGeneratedEvent.self) { [weak self] envelope in
        await self?.recordPlan(envelope.payload.planFingerprint)
      }
      await bus.subscribe(IntentBlockedEvent.self) { [weak self] envelope in
        await self?.recordBlocked(envelope.payload.reason)
      }
      await bus.subscribe(ToolInvokedEvent.self) { [weak self] envelope in
        await self?.recordInvoked(envelope.payload.toolID)
      }
    }

    private func recordPlan(_ fingerprint: String) { planFingerprints.append(fingerprint) }
    private func recordBlocked(_ reason: String) { blockedReasons.append(reason) }
    private func recordInvoked(_ toolID: String) { invokedToolIDs.append(toolID) }
  }

  private func makeHarness() async throws -> Harness {
    let bus = AuraEventBus(logger: AuraLogger(subsystem: "AuraIntentTests", category: "planner"))
    let recorder = EventRecorder()
    await recorder.subscribe(to: bus)
    let policyEngine = try await makeTestPolicyEngine(
      eventBus: bus,
      allowByDefaultTiers: [.observation, .reversible, .mutation, .destructive],
      grantConfirmationNoneFor: [.fileOpen, .fileReveal, .urlOpen, .appActivate])
    let spy = ApplicationControllerSpy()
    let automation = makeAutomation(spy: spy, eventBus: bus)
    let shell = AuraShell(configuration: ShellConfiguration())
    let store = try await makeTestStore()
    let taskEngine = await AuraTaskEngine(store: store, eventBus: bus)
    let (agentRunner, sessionID) = makeAgentBackendTaskRunner(
      policyEngine: policyEngine, eventBus: bus)
    let registry = CapabilityRegistry()
    await InitialCapabilitySet.registerAll(in: registry)
    let router = ToolRouter(
      policyEngine: policyEngine, automation: automation, shell: shell, taskEngine: taskEngine,
      agentTaskRunner: agentRunner, capabilityRegistry: registry,
      confirmationPresenter: IntentAlwaysDenyConfirmationPresenter(), eventBus: bus,
      configuration: IntentEngineConfiguration())
    return Harness(router: router, registry: registry, sessionID: sessionID, events: recorder)
  }

  private func makeContext(sessionID: UUID) -> TurnContext {
    TurnContext(
      sessionID: sessionID, correlationID: UUID(), causationID: UUID(),
      activationSource: .text, actor: .user, authority: .userUtterance,
      sensitivity: .sensitive)
  }

  private func intent(kind: IntentKind, slots: [IntentSlot]) -> TypedIntent {
    TypedIntent(
      turnCorrelationID: UUID(), kind: kind,
      semanticCategory: ToolRouter.semanticCategory(for: kind),
      rawUtterance: "", normalizedUtterance: "", slots: slots,
      classificationConfidence: 0.9, isAmbiguous: false, dialogueAct: .execute)
  }

  // MARK: - The planner is on the production single-intent path

  @Test("routing a single intent emits a real plan fingerprint")
  func singleRouteProducesPlanFingerprint() async throws {
    let harness = try await makeHarness()
    _ = await harness.router.route(
      intent(
        kind: .appActivate,
        slots: [IntentSlot(name: IntentSlotName.bundleIdentifier, value: "com.apple.Safari")]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())
    let fingerprints = await harness.events.planFingerprints
    #expect(fingerprints.count == 1)
    // Empty would mean the event came from a path that never built a plan —
    // exactly the pre-fix state.
    #expect(!(fingerprints.first ?? "").isEmpty)
  }

  @Test("the planner refuses a missing required slot before any handler runs")
  func plannerRefusesMissingRequiredArgument() async throws {
    let harness = try await makeHarness()
    // `.urlOpen` requires the url slot. Without it the planner must refuse and
    // no tool may be invoked.
    let outcome = await harness.router.route(
      intent(kind: .urlOpen, slots: []),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())
    guard case .failed(let reason) = outcome else {
      Issue.record("expected .failed, got \(outcome)")
      return
    }
    #expect(reason.range(of: IntentSlotName.url) != nil)
    let blocked = await harness.events.blockedReasons
    #expect(blocked.contains { $0.hasPrefix("missingArgument:") })
    let invoked = await harness.events.invokedToolIDs
    #expect(invoked.isEmpty)
  }

  @Test("a disabled capability never reaches an adapter")
  func disabledCapabilityNeverInvoked() async throws {
    let harness = try await makeHarness()
    await harness.registry.setAvailability(
      .disabled(reason: "disabled for this test"),
      for: InitialCapabilitySet.urlOpen.qualifiedID)
    let outcome = await harness.router.route(
      intent(
        kind: .urlOpen,
        slots: [IntentSlot(name: IntentSlotName.url, value: "https://example.com")]),
      actor: .user, sessionID: harness.sessionID, correlationID: UUID(), causationID: UUID())
    switch outcome {
    case .failed, .blockedByPolicy: break
    default: Issue.record("expected a refusal, got \(outcome)")
    }
    let invoked = await harness.events.invokedToolIDs
    #expect(!invoked.contains(InitialCapabilitySet.urlOpen.id))
  }

  // MARK: - Multi-step execution

  @Test("routePlan executes a two-step dependent plan through policy and adapters")
  func twoStepPlanExecutes() async throws {
    let harness = try await makeHarness()
    let sandbox = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-plan-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: sandbox) }
    let note = sandbox.appendingPathComponent("note.txt")
    try "hello".write(to: note, atomically: true, encoding: .utf8)

    let planner = CapabilityPlanner(registry: harness.registry)
    let built = await planner.buildPlan(steps: [
      PlanStepRequest(
        capabilityID: InitialCapabilitySet.filesystemOpenFolder.id,
        arguments: [IntentSlotName.folderPath: sandbox.path],
        requiredArgumentNames: [IntentSlotName.folderPath],
        dependsOnStepIndices: []),
      PlanStepRequest(
        capabilityID: InitialCapabilitySet.filesystemReveal.id,
        arguments: [IntentSlotName.filePath: note.path],
        requiredArgumentNames: [IntentSlotName.filePath],
        dependsOnStepIndices: [0]),
    ])
    guard case .success(let plan) = built else {
      Issue.record("expected a valid plan, got \(built)")
      return
    }

    let report = await harness.router.routePlan(
      plan, context: makeContext(sessionID: harness.sessionID))
    #expect(report.stepOutcomes.count == 2)
    #expect(report.planFingerprint == plan.fingerprint)
    #expect(!report.planFingerprint.isEmpty)
    // Each step carries its manifest's declared rollback strategy verbatim.
    #expect(report.declaredRollbackStrategies.count == 2)
    #expect(report.declaredRollbackStrategies.allSatisfy { !$0.isEmpty })
  }

  @Test("a step whose dependency did not execute is skipped, not attempted")
  func failedDependencySkipsDependentStep() async throws {
    let harness = try await makeHarness()
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("aura-absent-\(UUID().uuidString)")
    let planner = CapabilityPlanner(registry: harness.registry)
    let built = await planner.buildPlan(steps: [
      // Step 0 targets a path that does not exist, so the adapter refuses it.
      PlanStepRequest(
        capabilityID: InitialCapabilitySet.filesystemOpenFile.id,
        arguments: [IntentSlotName.filePath: missing.path],
        requiredArgumentNames: [], dependsOnStepIndices: []),
      PlanStepRequest(
        capabilityID: InitialCapabilitySet.filesystemReveal.id,
        arguments: [IntentSlotName.filePath: missing.path],
        requiredArgumentNames: [IntentSlotName.filePath],
        dependsOnStepIndices: [0]),
    ])
    guard case .success(let plan) = built else {
      Issue.record("expected a valid plan, got \(built)")
      return
    }

    let report = await harness.router.routePlan(
      plan, context: makeContext(sessionID: harness.sessionID))
    #expect(report.stepOutcomes.count == 2)
    #expect(!report.succeeded)
    #expect(!report.stepOutcomes[0].isExecuted)
    guard case .skipped(let reason) = report.stepOutcomes[1] else {
      Issue.record("expected step 1 to be skipped, got \(report.stepOutcomes[1])")
      return
    }
    #expect(reason.range(of: "did not execute") != nil)
  }

  @Test("the planner rejects an unknown capability, so routePlan never sees it")
  func plannerRejectsUnknownCapability() async throws {
    let harness = try await makeHarness()
    let planner = CapabilityPlanner(registry: harness.registry)
    let built = await planner.buildPlan(steps: [
      PlanStepRequest(
        capabilityID: "time_machine.travel", arguments: [:],
        requiredArgumentNames: [], dependsOnStepIndices: [])
    ])
    guard case .failure(let failure) = built else {
      Issue.record("expected rejection of an unknown capability, got \(built)")
      return
    }
    #expect(failure.blockedReason.hasPrefix("unknownCapability:"))
  }

  @Test("a self-referencing dependency is rejected as a cycle")
  func plannerRejectsForwardDependency() async throws {
    let harness = try await makeHarness()
    let planner = CapabilityPlanner(registry: harness.registry)
    let built = await planner.buildPlan(steps: [
      PlanStepRequest(
        capabilityID: InitialCapabilitySet.appActivate.id,
        arguments: [IntentSlotName.bundleIdentifier: "com.apple.Safari"],
        requiredArgumentNames: [], dependsOnStepIndices: [0])
    ])
    guard case .failure(let failure) = built else {
      Issue.record("expected rejection, got \(built)")
      return
    }
    #expect(failure.blockedReason == "dependencyCycle")
  }

  // MARK: - Mapping integrity

  @Test("every routable intent kind round-trips through the capability mapping")
  func capabilityMappingRoundTrips() async throws {
    let harness = try await makeHarness()
    for kind in [
      IntentKind.converse, .appActivate, .appTerminate, .shellExecute, .codingAgentRun,
      .fileReveal, .urlOpen,
    ] {
      guard let id = await harness.router.capabilityID(for: kind) else {
        Issue.record("no capability id for \(kind)")
        continue
      }
      #expect(ToolRouter.intentKind(forCapabilityID: id) == kind)
    }
    // `.fileOpen` maps to open_file, and open_folder maps back to `.fileOpen`
    // too — the handler dispatches on which slot is present.
    #expect(
      ToolRouter.intentKind(forCapabilityID: InitialCapabilitySet.filesystemOpenFolder.id)
        == .fileOpen)
    #expect(
      ToolRouter.intentKind(forCapabilityID: InitialCapabilitySet.filesystemOpenFile.id)
        == .fileOpen)
  }
}
