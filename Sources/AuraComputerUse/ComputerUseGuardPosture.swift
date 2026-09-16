import AuraPolicy
import Foundation

/// Which of the computer-use control loop's structural guards are enforced
/// (ADR-064 §4, owner decision D-2 as resolved 2026-09-16).
///
/// Two named presets exist. `.structural` is the pre-PA-0 behaviour: every
/// guard enforced. `.ownerTrust` is the owner posture: none enforced — for
/// the single owner behind the macOS login, a session that stops itself on
/// "send", refuses to act next to a password field, or halts on a modal is
/// a second password, not a safety control. `production` picks between them
/// from `OwnerTrustPosture.isEnabled`, so the posture switch is the only
/// thing that decides; the kernel passes nothing and inherits it.
///
/// What is **not** here, by decision and by diff: the emergency stop
/// (checked unconditionally in the loop and the executor — the owner's
/// explicit exception), identity-change detection, invalid-anchor rejection,
/// the `maxIterations` ceiling, and the action rate limit. Those are bounds,
/// not prompts, and they hold under both presets.
///
/// Keeping the guards as a value rather than deleting them preserves the
/// mechanism for the disabled posture, for `actor: .plugin` callers, and for
/// the tests that prove each guard still refuses under `.structural`.
public struct ComputerUseGuardPosture: Sendable, Equatable {
  /// (A) Refuse to execute a step whose semantic intent is in
  /// `ComputerUseSemanticIntent.mandatoryConfirmationIntents` on a bare
  /// `.allow` decision (`.mandatoryConfirmationBlocked`).
  public var enforcesMandatoryConfirmation: Bool
  /// (B) Probe for a focused secure field before every step, in the loop
  /// and in the executor, and refuse on `.focused` or `.indeterminate`.
  public var refusesSecureFields: Bool
  /// (C) Probe for an unexpected modal dialog after every observation and
  /// terminate the session on one (or on an unreadable modal state).
  public var haltsOnUnexpectedModal: Bool
  /// (C) Terminate the session after `noProgressIterationThreshold`
  /// consecutive observations with an identical content hash.
  public var haltsOnNoProgress: Bool
  /// (C) Reject a plan with more than `maxStepsPerPlan` steps outright.
  public var enforcesMaxStepsPerPlan: Bool

  public init(
    enforcesMandatoryConfirmation: Bool,
    refusesSecureFields: Bool,
    haltsOnUnexpectedModal: Bool,
    haltsOnNoProgress: Bool,
    enforcesMaxStepsPerPlan: Bool
  ) {
    self.enforcesMandatoryConfirmation = enforcesMandatoryConfirmation
    self.refusesSecureFields = refusesSecureFields
    self.haltsOnUnexpectedModal = haltsOnUnexpectedModal
    self.haltsOnNoProgress = haltsOnNoProgress
    self.enforcesMaxStepsPerPlan = enforcesMaxStepsPerPlan
  }

  /// Every guard enforced — the ADR-019 / ADR-039 behaviour.
  public static let structural = ComputerUseGuardPosture(
    enforcesMandatoryConfirmation: true,
    refusesSecureFields: true,
    haltsOnUnexpectedModal: true,
    haltsOnNoProgress: true,
    enforcesMaxStepsPerPlan: true)

  /// No guard enforced — the ADR-064 owner posture (D-2).
  public static let ownerTrust = ComputerUseGuardPosture(
    enforcesMandatoryConfirmation: false,
    refusesSecureFields: false,
    haltsOnUnexpectedModal: false,
    haltsOnNoProgress: false,
    enforcesMaxStepsPerPlan: false)

  /// The posture the production kernel inherits. Derived, never hard-coded.
  public static var production: ComputerUseGuardPosture {
    OwnerTrustPosture.isEnabled ? .ownerTrust : .structural
  }
}
