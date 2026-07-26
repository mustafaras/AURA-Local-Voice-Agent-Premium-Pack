import Foundation

// MARK: - Semantic intent classification
//
// Every computer-use action step is required to declare *why* it is being
// taken, from a fixed, closed vocabulary — never inferred from free-form
// model text. `riskTier` is a pure function of this enum, so the capability
// (and therefore the policy tier) a step is evaluated under can never be
// spoofed or under-reported by a caller.

/// The semantic purpose of one computer-use action step, matching the
/// normative computer-use safety vocabulary
/// (`docs/subsystems/10_COMPUTER_USE.md`): "Never send, publish, purchase,
/// delete, deploy, or accept legal terms without explicit confirmation."
public enum ComputerUseSemanticIntent: String, Codable, Sendable, Equatable, CaseIterable {
  /// Read-only observation with no side effect (e.g. reading a value).
  case observe
  /// Non-destructive UI navigation (e.g. clicking a link or tab).
  case navigate
  /// Toggling a checkbox/switch/button that does not leave the app or send data.
  case toggleControl
  /// Typing into a field without submitting it.
  case fillField
  /// Submitting a form or confirming a dialog that is not itself one of the
  /// named hard-confirm categories below.
  case submit
  /// Sending a message, email, or similar communication.
  case send
  /// Publishing content.
  case publish
  /// Making a purchase or financial transaction.
  case purchase
  /// Deleting data.
  case delete
  /// Deploying or releasing software/configuration.
  case deploy
  /// Accepting legal terms, licenses, or similar agreements.
  case acceptLegalTerms
  /// Entering or changing a credential, or otherwise authenticating.
  case authenticateOrChangeCredential

  /// Pure, deterministic mapping from semantic intent to policy risk tier —
  /// mirrors `Capability`'s own tiering so every computer-use step is
  /// evaluated at a tier consistent with the rest of the policy engine.
  public var riskTier: PermissionRiskTier {
    switch self {
    case .observe:
      return .observation
    case .navigate, .toggleControl:
      return .reversible
    case .fillField, .submit:
      return .mutation
    case .send, .publish, .purchase, .delete, .deploy, .acceptLegalTerms,
      .authenticateOrChangeCredential:
      return .destructive
    }
  }

  /// The exact set named by the normative spec as never executable without
  /// explicit confirmation. Fixed and non-configurable: no `Grant`, however
  /// permissively configured, can cause a step with one of these intents to
  /// execute on a bare `.allow` decision — see
  /// `ComputerUseControlLoop`'s mandatory-confirmation gate.
  public static let mandatoryConfirmationIntents: Set<ComputerUseSemanticIntent> = [
    .send, .publish, .purchase, .delete, .deploy, .acceptLegalTerms,
    .authenticateOrChangeCredential,
  ]

  /// Whether this intent must never execute on a bare `.allow` decision.
  public var requiresMandatoryConfirmation: Bool {
    Self.mandatoryConfirmationIntents.contains(self)
  }
}

// MARK: - UI anchoring

/// Describes where a computer-use action step should act, preferring
/// Accessibility text/ID anchors over raw screen coordinates per the
/// normative reliability rule ("Prefer accessibility identifiers and text
/// anchors over absolute coordinates").
///
/// An anchor may carry both an accessibility hint and a coordinate fallback;
/// resolution always attempts the accessibility hint first and only falls
/// back to the coordinate when accessibility resolution fails or no hint was
/// supplied at all.
public struct UIAnchor: Codable, Sendable, Equatable {
  public let accessibilityRole: String?
  public let accessibilityTitle: String?
  public let accessibilityIdentifier: String?
  /// Window-relative, normalized `[0, 1]` fallback coordinate, matching the
  /// same convention as `CaptureRegion`/`RecognizedTextRegion`.
  public let fallbackNormalizedX: Double?
  public let fallbackNormalizedY: Double?

  public init(
    accessibilityRole: String? = nil,
    accessibilityTitle: String? = nil,
    accessibilityIdentifier: String? = nil,
    fallbackNormalizedX: Double? = nil,
    fallbackNormalizedY: Double? = nil
  ) {
    self.accessibilityRole = accessibilityRole
    self.accessibilityTitle = accessibilityTitle
    self.accessibilityIdentifier = accessibilityIdentifier
    self.fallbackNormalizedX = fallbackNormalizedX
    self.fallbackNormalizedY = fallbackNormalizedY
  }

  /// Whether any accessibility hint was supplied at all.
  public var hasAccessibilityHint: Bool {
    accessibilityRole != nil || accessibilityTitle != nil || accessibilityIdentifier != nil
  }

  /// Whether a coordinate fallback was supplied at all.
  public var hasCoordinateFallback: Bool {
    fallbackNormalizedX != nil && fallbackNormalizedY != nil
  }

  /// Whether any coordinate fallback supplied is within `[0, 1]` on both
  /// axes. `true` when no coordinate was supplied at all — absence is not
  /// itself an out-of-bounds coordinate.
  public var coordinateFallbackInBounds: Bool {
    guard let x = fallbackNormalizedX, let y = fallbackNormalizedY else { return true }
    return (0...1).contains(x) && (0...1).contains(y)
  }

  /// An anchor is valid only if it supplies an accessibility hint, a
  /// bounds-valid coordinate fallback, or both. An anchor with neither, or
  /// with an out-of-bounds coordinate, is rejected outright — never
  /// silently clamped.
  public var isValid: Bool {
    guard coordinateFallbackInBounds else { return false }
    return hasAccessibilityHint || hasCoordinateFallback
  }
}

// MARK: - Action steps

/// One atomic input action a resolved `UIAnchor` may receive.
public enum ComputerUseActionKind: Codable, Sendable, Equatable {
  case click
  case doubleClick
  case rightClick
  case typeText(String)
  case keyPress(key: String, modifiers: [String])
  case scroll(deltaX: Double, deltaY: Double)
  case wait(seconds: Double)
}

/// One bounded, typed, closed-vocabulary action step. This is the *only*
/// boundary type the control loop's Act phase ever executes — a
/// `ComputerUsePlanning` conformer must translate whatever free-form model
/// output it consumes into values of this type before the loop can act on
/// them, so raw model text structurally never becomes an executable action.
public struct ComputerUseActionStep: Codable, Sendable, Equatable, Identifiable {
  public let id: UUID
  public let kind: ComputerUseActionKind
  public let anchor: UIAnchor
  public let semanticIntent: ComputerUseSemanticIntent
  /// Bundle identifier this step is expected to act within. Must equal the
  /// control loop session's approved target; a mismatch halts the loop
  /// rather than silently redirecting input to a different application.
  public let targetAppBundleIdentifier: String
  /// Free-text rationale carried only for audit/logging — never parsed or
  /// interpreted. Execution is driven exclusively by `kind`/`anchor`/
  /// `semanticIntent`.
  public let rationale: String

  public init(
    id: UUID = UUID(),
    kind: ComputerUseActionKind,
    anchor: UIAnchor,
    semanticIntent: ComputerUseSemanticIntent,
    targetAppBundleIdentifier: String,
    rationale: String = ""
  ) {
    self.id = id
    self.kind = kind
    self.anchor = anchor
    self.semanticIntent = semanticIntent
    self.targetAppBundleIdentifier = targetAppBundleIdentifier
    self.rationale = rationale
  }
}

/// A bounded, short atomic sequence of action steps proposed for one control
/// loop iteration — "generate one bounded action or a short atomic
/// sequence."
public struct ComputerUsePlan: Sendable, Equatable {
  public let steps: [ComputerUseActionStep]

  public init(steps: [ComputerUseActionStep] = []) {
    self.steps = steps
  }

  /// An empty plan signals the planner considers the objective complete —
  /// the loop's normal, non-error termination condition.
  public var isEmpty: Bool { steps.isEmpty }
}

// MARK: - Session target

/// The single approved window/application a `ComputerUseControlLoop` session
/// is bound to. Every observation and action step is validated against this
/// target; an identity change away from it halts the loop rather than
/// silently following focus.
public struct ComputerUseSessionTarget: Sendable, Equatable {
  public let windowID: Int
  public let appBundleIdentifier: String
  public let appName: String?

  public init(windowID: Int, appBundleIdentifier: String, appName: String? = nil) {
    self.windowID = windowID
    self.appBundleIdentifier = appBundleIdentifier
    self.appName = appName
  }
}

// MARK: - Emergency stop

/// The channel an emergency stop was triggered from. All three are
/// first-class and equally authoritative — none is a privileged or
/// higher-latency path than another.
public enum EmergencyStopSource: String, Codable, Sendable, Equatable, CaseIterable {
  case ui
  case voice
  case keyboard
}

// MARK: - Step block reasons

/// Why one action step within a plan was not executed.
public enum ComputerUseStepBlockReason: String, Codable, Sendable, Equatable {
  case emergencyStop
  case identityMismatch
  case invalidAnchor
  case secureFieldFocused
  case policyDenied
  case mandatoryConfirmationRequired
  case rateLimited
  case executionFailed
}

// MARK: - Loop outcome

/// Terminal result of one `ComputerUseControlLoop.run` call. The loop always
/// terminates in a bounded number of iterations and every non-`completed`
/// case is a distinct, auditable stop reason rather than an unbounded retry.
public enum ComputerUseLoopOutcome: Sendable, Equatable {
  /// The planner returned an empty plan — objective considered complete.
  case completed(iterations: Int)
  /// No observable progress across `noProgressIterationThreshold`
  /// consecutive iterations.
  case noProgress(iterations: Int)
  /// The configured maximum iteration count was reached.
  case iterationBudgetExhausted(iterations: Int)
  /// Emergency stop was active at a checkpoint.
  case emergencyStopped(iterations: Int)
  /// An unexpected modal or security dialog appeared.
  case unexpectedModalDialog(iterations: Int)
  /// The observed window/application no longer matches the approved target.
  case identityChanged(iterations: Int)
  /// A step's policy evaluation returned `.confirm`; the loop halts and
  /// surfaces the challenge for an external caller (UI/voice) to resolve.
  case confirmationRequired(challenge: PolicyConfirmationChallenge, iterations: Int)
  /// A step whose intent requires mandatory confirmation reached a bare
  /// `.allow` decision (e.g. via an overly permissive grant) — blocked
  /// unconditionally rather than trusting the grant.
  case mandatoryConfirmationBlocked(intent: ComputerUseSemanticIntent, iterations: Int)
  /// The planner proposed a plan violating a structural bound (too many
  /// steps, an invalid anchor) — rejected outright, not silently truncated.
  case invalidPlan(reason: String, iterations: Int)
  /// Observation, execution, or planner failure prevented continuation.
  case failed(reason: String, iterations: Int)
}

// MARK: - Planning boundary

/// Translates whatever free-form suggestion a real planner (e.g. a
/// model-backed adapter, added in a later phase) produces into a typed,
/// bounded `ComputerUsePlan`. This protocol is the structural boundary that
/// makes "no raw model output becomes an executable action" true by
/// construction: `ComputerUseControlLoop` never sees or evaluates anything
/// but `ComputerUsePlan` values.
public protocol ComputerUsePlanning: Sendable {
  func propose(
    observation: ScreenObservation,
    objective: String,
    previousSteps: [ComputerUseActionStep]
  ) async -> ComputerUsePlan
}
