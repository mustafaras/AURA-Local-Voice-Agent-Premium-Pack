import AuraCore
import Foundation

/// Outcome of one step inside a `Plan` executed by `ToolRouter.routePlan`.
public enum PlanStepOutcome: Sendable, Equatable {
  case executed(summary: String)
  case blocked(reason: String)
  case failed(reason: String)
  /// Never attempted, because a step it declared a dependency on did not
  /// execute. Recorded rather than silently dropped so a partial run stays
  /// legible: the caller can see exactly where the plan stopped and why.
  case skipped(reason: String)

  public var isExecuted: Bool {
    if case .executed = self { return true }
    return false
  }
}

/// Result of executing a whole `Plan`.
///
/// A plan is *not* a transaction. Steps that already ran keep their effects —
/// `filesystem.open_file` cannot be un-opened — so this report states what
/// actually happened per step and carries each step's declared
/// `rollbackStrategy` verbatim from its manifest. It never claims to have
/// undone anything.
public struct PlanExecutionReport: Sendable, Equatable {
  public let planID: UUID
  public let planFingerprint: String
  public let stepOutcomes: [PlanStepOutcome]
  /// Per-step `rollbackStrategy` copied from the manifest, index-aligned with
  /// `stepOutcomes`.
  public let declaredRollbackStrategies: [String]

  public var succeeded: Bool { stepOutcomes.allSatisfy { $0.isExecuted } }

  public var executedStepCount: Int { stepOutcomes.filter { $0.isExecuted }.count }

  public init(
    planID: UUID, planFingerprint: String, stepOutcomes: [PlanStepOutcome],
    declaredRollbackStrategies: [String]
  ) {
    self.planID = planID
    self.planFingerprint = planFingerprint
    self.stepOutcomes = stepOutcomes
    self.declaredRollbackStrategies = declaredRollbackStrategies
  }
}

extension PlanValidationFailure {
  /// Reason string for the `IntentBlockedEvent` emitted when the planner
  /// refuses a step, and the description callers outside this module surface
  /// when a whole plan is rejected.
  public var blockedReason: String {
    switch self {
    case .unknownCapability(let id, let version): return "unknownCapability:\(id)@\(version)"
    case .capabilityUnavailable(let id, _): return "capabilityUnavailable:\(id)"
    case .missingRequiredArgument(let id, let name): return "missingArgument:\(id).\(name)"
    case .planTooLarge(let count, let max): return "planTooLarge:\(count)>\(max)"
    case .dependencyCycle: return "dependencyCycle"
    case .invalidDependencyIndex(let step, let dependsOn):
      return "invalidDependency:\(step)->\(dependsOn)"
    }
  }

  /// How a planner refusal surfaces to the conversation. An unavailable
  /// capability is a policy-shaped refusal the user should hear as such; the
  /// rest are malformed requests.
  var executionOutcome: IntentExecutionOutcome {
    switch self {
    case .capabilityUnavailable(let id, let reason):
      return .blockedByPolicy(reason: "\(id) is unavailable: \(reason)")
    case .missingRequiredArgument(_, let name):
      return .failed(reason: "missing \(name) slot")
    default:
      return .failed(reason: blockedReason)
    }
  }
}

extension ToolRouter {
  /// Slot values a capability's plan step is built from. Keys are
  /// `IntentSlotName` values so `planStepIntent` can map them back.
  static func planArguments(for intent: TypedIntent) -> [String: String] {
    var arguments: [String: String] = [:]
    for name in [
      IntentSlotName.bundleIdentifier, IntentSlotName.executable, IntentSlotName.arguments,
      IntentSlotName.backend, IntentSlotName.objective, IntentSlotName.filePath,
      IntentSlotName.folderPath, IntentSlotName.url,
    ] {
      if let value = intent.slotValue(name), !value.isEmpty {
        arguments[name] = value
      }
    }
    return arguments
  }

  /// The slots a kind cannot execute without. Deliberately narrow: only slots
  /// whose absence already causes a handler to fail are listed, so the planner
  /// refuses earlier for the same reason rather than inventing a stricter
  /// contract than the handlers enforce.
  static func requiredArgumentNames(for kind: IntentKind) -> [String] {
    switch kind {
    case .appActivate, .appTerminate: return [IntentSlotName.bundleIdentifier]
    case .shellExecute: return [IntentSlotName.executable]
    case .urlOpen: return [IntentSlotName.url]
    case .fileReveal: return [IntentSlotName.filePath]
    // `.fileOpen` accepts either a file or a folder slot and dispatches on
    // whichever is present, so neither is individually required.
    case .fileOpen, .converse, .codingAgentRun, .unknown: return []
    }
  }

  /// The category a plan-step intent carries. `TypedIntent` derives
  /// `riskTier` and `requiresMandatoryConfirmation` from this, so it must
  /// mirror what the classifier would have produced for the same kind — a
  /// step must never enter the router at a softer risk tier than an
  /// equivalent spoken request. `.shellExecute` maps to the non-destructive
  /// category deliberately: escalation to `.shellDestructive` is the router's
  /// own pattern check, not something a caller may pre-declare away.
  static func semanticCategory(for kind: IntentKind) -> IntentSemanticCategory {
    switch kind {
    case .converse: return .converse
    case .appActivate: return .appActivate
    case .appTerminate: return .appTerminate
    case .shellExecute: return .shellExecute
    case .codingAgentRun: return .codingAgentRun
    case .fileOpen: return .fileOpen
    case .fileReveal: return .fileReveal
    case .urlOpen: return .urlOpen
    case .unknown: return .unknown
    }
  }

  /// Inverse of `capabilityID(for:)` — the mapping a validated `PlanStep`
  /// needs to reach the same handlers a classified utterance reaches.
  static func intentKind(forCapabilityID id: String) -> IntentKind? {
    switch id {
    case InitialCapabilitySet.converse.id: return .converse
    case InitialCapabilitySet.appActivate.id: return .appActivate
    case InitialCapabilitySet.appTerminate.id: return .appTerminate
    case InitialCapabilitySet.shellExecuteTyped.id: return .shellExecute
    case InitialCapabilitySet.codingAgentRun.id: return .codingAgentRun
    case InitialCapabilitySet.filesystemOpenFile.id: return .fileOpen
    case InitialCapabilitySet.filesystemOpenFolder.id: return .fileOpen
    case InitialCapabilitySet.filesystemReveal.id: return .fileReveal
    case InitialCapabilitySet.urlOpen.id: return .urlOpen
    default: return nil
    }
  }

  /// Execute an already-validated `Plan`, step by step, through the exact same
  /// policy → confirmation → adapter path a single routed intent takes.
  ///
  /// Steps run in index order, which `CapabilityPlanner.buildPlan` guarantees
  /// is a valid topological order (it rejects any dependency that does not
  /// point strictly backward). A step whose dependency did not execute is
  /// skipped, not attempted — the plan degrades honestly instead of running a
  /// step whose precondition never materialized.
  public func routePlan(
    _ plan: Plan,
    context: TurnContext
  ) async -> PlanExecutionReport {
    var outcomes: [PlanStepOutcome] = []
    for (index, step) in plan.steps.enumerated() {
      let unmetDependency = step.dependsOnStepIndices.first { dependency in
        dependency >= outcomes.count || !outcomes[dependency].isExecuted
      }
      if let unmetDependency {
        outcomes.append(
          .skipped(
            reason: "step \(index) depends on step \(unmetDependency), which did not execute"))
        continue
      }
      guard let kind = Self.intentKind(forCapabilityID: step.capabilityID) else {
        outcomes.append(.failed(reason: "no intent route for capability \(step.capabilityID)"))
        continue
      }
      let intent = Self.planStepIntent(step, kind: kind, context: context)
      let executionContext = ToolExecutionContext(
        actor: context.actor,
        sessionID: context.sessionID,
        correlationID: context.correlationID,
        causationID: context.causationID)
      let outcome = await route(intent, executionContext: executionContext)
      outcomes.append(outcome.planStepOutcome)
    }
    return PlanExecutionReport(
      planID: plan.id,
      planFingerprint: plan.fingerprint,
      stepOutcomes: outcomes,
      declaredRollbackStrategies: plan.steps.map(\.rollbackStrategy))
  }

  /// Rebuild a `TypedIntent` from a validated step. The step's arguments were
  /// already checked against the manifest, so this only re-shapes them into
  /// the slots the handlers read.
  static func planStepIntent(
    _ step: PlanStep, kind: IntentKind, context: TurnContext
  ) -> TypedIntent {
    // `filesystem.open_folder` and `filesystem.open_file` share `.fileOpen`;
    // the handler dispatches on which slot is present, so a folder step must
    // carry `folderPath` even when the caller supplied the path as `filePath`.
    var arguments = step.validatedArguments
    if step.capabilityID == InitialCapabilitySet.filesystemOpenFolder.id,
      arguments[IntentSlotName.folderPath] == nil,
      let path = arguments[IntentSlotName.filePath]
    {
      arguments[IntentSlotName.folderPath] = path
      arguments.removeValue(forKey: IntentSlotName.filePath)
    }
    let slots = arguments.map { IntentSlot(name: $0.key, value: $0.value) }
    return TypedIntent(
      turnCorrelationID: context.correlationID,
      kind: kind,
      semanticCategory: Self.semanticCategory(for: kind),
      rawUtterance: "plan step \(step.qualifiedCapabilityID)",
      normalizedUtterance: "plan step \(step.qualifiedCapabilityID)",
      slots: slots,
      classificationConfidence: 1.0,
      isAmbiguous: false,
      turnContext: context)
  }
}

extension IntentExecutionOutcome {
  var planStepOutcome: PlanStepOutcome {
    switch self {
    case .executed(let summary, _): return .executed(summary: summary)
    case .acknowledgedAsync(let summary): return .executed(summary: summary)
    case .blockedByPolicy(let reason): return .blocked(reason: reason)
    case .blockedPendingConfirmationDenied: return .blocked(reason: "confirmationDenied")
    case .ambiguous(let question): return .failed(reason: question)
    case .failed(let reason): return .failed(reason: reason)
    }
  }
}
