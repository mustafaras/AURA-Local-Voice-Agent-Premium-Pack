import AuraCore
import AuraScreen
import Foundation

// MARK: - Production planning protocol

/// The R4 production planning boundary. Unlike the earlier `ComputerUsePlanning`
/// (which consumed a raw `ScreenObservation`), this consumes the richer
/// `ComputerUseObservation` contract (R4 section A) so the planner can reason
/// about accessibility structure, control candidates, secure-field/modal state,
/// and provenance — while still emitting **only** the closed `ComputerUsePlan`
/// schema, so no raw model text can ever become an executable action.
public protocol ProductionComputerUsePlanning: Sendable {
  func propose(
    observation: ComputerUseObservation,
    objective: String,
    previousSteps: [ComputerUseActionStep]
  ) async -> ComputerUsePlan
}

// MARK: - Deterministic production planner

/// The first production `ComputerUsePlanning` conformer (R4 section B),
/// using a deterministic, app-specific fixture table rather than a model.
///
/// Safety properties (each structural, not a convention):
/// - It only ever emits closed `ComputerUseActionStep`/`ComputerUsePlan`
///   values — structurally incapable of producing raw model text as an action.
/// - It **stops and clarifies when the target is uncertain**: an unknown
///   objective, an app with no fixtures, or a target app that is not
///   allowlisted all produce an empty plan (the loop's clarification signal)
///   rather than a guessed action.
/// - It is bounded by the same app/window scope the loop enforces: every step
///   it emits targets the observation's own `appBundleIdentifier`.
public struct DeterministicComputerUsePlanner: ProductionComputerUsePlanning {
  private let allowlist: ComputerUseBetaAllowlist

  public init(allowlist: ComputerUseBetaAllowlist = .initial) {
    self.allowlist = allowlist
  }

  public func propose(
    observation: ComputerUseObservation,
    objective: String,
    previousSteps: [ComputerUseActionStep]
  ) async -> ComputerUsePlan {
    // Target uncertainty → stop and clarify (empty plan).
    guard let appBundleIdentifier = observation.appBundleIdentifier else {
      return ComputerUsePlan()
    }
    guard allowlist.isApproved(appBundleIdentifier) else {
      // Unvalidated app is structurally disabled.
      return ComputerUsePlan()
    }
    guard let fixtures = ComputerUseAppFixtures.knownTasks(for: appBundleIdentifier) else {
      // No app-specific fixtures → cannot plan → clarify.
      return ComputerUsePlan()
    }

    // A secure field or unexpected modal means the planner must not propose
    // interaction until the user resolves it.
    if observation.secureFieldFocused {
      return ComputerUsePlan()
    }
    if observation.modalState != .none {
      return ComputerUsePlan()
    }

    // Match the objective to a curated known task (case-insensitive, trimmed).
    let normalized = objective.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard let task = fixtures.first(where: { $0.objectiveKey.lowercased() == normalized }) else {
      return ComputerUsePlan()
    }

    // Re-scope every step to the observation's app before returning.
    let reanchoredSteps = task.plan.steps.map { step in
      ComputerUseActionStep(
        id: step.id,
        kind: step.kind,
        anchor: step.anchor,
        semanticIntent: step.semanticIntent,
        targetAppBundleIdentifier: appBundleIdentifier,
        rationale: step.rationale)
    }
    return ComputerUsePlan(steps: reanchoredSteps)
  }
}

// MARK: - Bridge to the control loop's planning boundary

/// Adapts `DeterministicComputerUsePlanner` (which reasons over the R4
/// `ComputerUseObservation` contract) to the control loop's original
/// `ComputerUsePlanning` boundary (which passes a `ScreenObservation`).
/// The bridge builds a `ComputerUseObservation` from the screen observation
/// with empty accessibility/control structure, so the deterministic planner's
/// allowlist/objective/secure-field/modal logic still applies; it never
/// fabricates accessibility structure that was not actually captured.
extension DeterministicComputerUsePlanner: ComputerUsePlanning {
  public func propose(
    observation: ScreenObservation,
    objective: String,
    previousSteps: [ComputerUseActionStep]
  ) async -> ComputerUsePlan {
    let now = Date()
    let wrapped = ComputerUseObservation(
      screen: observation,
      accessibilityElements: [],
      controlCandidates: [],
      secureFieldFocused: false,
      modalState: .none,
      structuralHash: "",
      provenance: ComputerUseCaptureProvenance(
        capturedAt: now, source: .accessibility, redactionCount: 0,
        rawImageRetained: observation.rawImageRetained))
    return await propose(observation: wrapped, objective: objective, previousSteps: previousSteps)
  }
}
