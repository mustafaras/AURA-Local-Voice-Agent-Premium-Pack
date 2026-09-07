import AuraCore
import Foundation

/// The grants AURA seeds into a fresh `PolicyEngine` at construction.
///
/// Extracted from `AuraKernel.seedDefaultGrants` so the production default
/// policy posture is unit-testable from outside the executable app target:
/// `AURA` is an `executableTarget`, so no test bundle can import it, and a
/// test-local copy of the grant list would silently drift from production.
///
/// SP-006 finding: the four filesystem/URL capabilities delivered by
/// SP-004/SP-005 (`.fileOpen`, `.fileReveal`, `.urlOpen`, all `.reversible`
/// tier) previously had **no** seeded grant. The production
/// `PolicyConfiguration` denies `.reversible` by default, so every live
/// `filesystem.open_file` / `filesystem.open_folder` / `filesystem.reveal` /
/// `url.open` request — by NLU or by direct `AuraKernel` call — was denied
/// before reaching the adapter, despite the capabilities being registered
/// `.ready`. The manifests for these capabilities declare
/// `confirmationRule: "reversible tier default (no mandatory confirmation)"`,
/// so the matching posture is a `.none`-confirmation grant, exactly the
/// pattern `.appActivate` (also `.reversible`) already uses. Policy remains
/// the gate: a grant only removes the deny-by-default wall; the adapter's
/// `OpenTargetValidator` refuse-before-effect rules and the registry's
/// availability state still apply to every request.
///
/// SP-006 closeout follow-up (`RISK-SP-006-DEFAULT-GRANT-BREADTH`): those
/// grants were first written with `patterns: [.any]`, which meant the policy
/// layer did not narrow the targets at all — and the production adapter was
/// simultaneously built with `OpenTargetValidator`'s default
/// `approvedRoots: []` ("no root restriction"), so *neither* layer confined a
/// path. The filesystem grants are now scoped to `DeclaredFileRoots.all` via
/// `.directory(_:recursive:)`, one grant per root because `patternsSatisfied`
/// requires *every* pattern in a grant to match while `matchingGrant` accepts
/// the first grant that does — so alternatives must be separate grants, not
/// separate patterns on one grant. `url.open` is scoped by
/// `.urlScheme(allowed:)` to the same list the adapter enforces.
public enum DefaultPolicyGrants {
  /// Marker stamped on every seeded grant's `purpose`.
  ///
  /// Seeding used to append: `issueGrant` de-duplicates by `id`, and `Grant`
  /// mints a fresh `UUID` per construction, so every launch added a *new* copy
  /// of the whole default set. A live run found 895 persisted grants on a
  /// developer machine, 30 of them pre-scoping `.any` grants for the
  /// filesystem/URL capabilities. Because `matchingGrant` returns the *first*
  /// grant that matches, those legacy broad grants kept authorizing paths the
  /// scoped grants were meant to refuse — the scoping was effective only on a
  /// store that had never run the old build. `PolicyEngine
  /// .reconcileSeededGrants(_:marker:)` uses this marker to replace the seeded
  /// set instead of appending to it, and to prune the legacy shape.
  public static let seedPurpose = "aura.default-seed"

  /// Grants whose capability has no path/URL target to narrow, or where a
  /// mandatory confirmation is the control rather than a pattern.
  private static let unscoped: [Grant] = [
    Grant(
      capability: .appActivate, patterns: [.any], confirmationRequirement: .none,
      purpose: seedPurpose),
    Grant(
      capability: .appTerminate, patterns: [.any],
      confirmationRequirement: .forRiskTier(.mutation), purpose: seedPurpose),
    Grant(
      capability: .shellExec, patterns: [.any], confirmationRequirement: .always,
      purpose: seedPurpose),
    Grant(
      capability: .agentCodexRun, patterns: [.any], confirmationRequirement: .always,
      purpose: seedPurpose),
    Grant(
      capability: .agentClaudeRun, patterns: [.any], confirmationRequirement: .always,
      purpose: seedPurpose),
    Grant(
      capability: .agentCopilotRun, patterns: [.any], confirmationRequirement: .always,
      purpose: seedPurpose),
    // Local Ollama is reversible and has no side effects. The policy adapter
    // only maps a model to this grant when its /api/tags entry is local.
    Grant(
      capability: .agentOllamaLocalInference, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    // SP-022: the Task Center lifecycle controls. Each is `.reversible` tier,
    // and production `PolicyConfiguration` denies `.reversible` by default, so
    // without these grants the Task Center's cancel/pause/resume/retry buttons
    // would be policy-denied before ever reaching `AuraTaskEngine` — the same
    // silent-gap the SP-006 filesystem/URL grants fixed. `task.status` and
    // `task.list` are `.observation` and allow by default already.
    //
    // ADR-055: `task.delete` (`.destructive` tier) is granted without a
    // confirmation challenge — the owner directed that the destructive
    // surface be freely reachable in the local build. Deleting a durable
    // task's persisted state is still irreversible; the decision to accept
    // that risk locally is recorded in ADR-055, not relabeled as a policy
    // default.
    Grant(
      capability: .taskCancel, patterns: [.any], confirmationRequirement: .none,
      purpose: seedPurpose),
    Grant(
      capability: .taskPause, patterns: [.any], confirmationRequirement: .none,
      purpose: seedPurpose),
    Grant(
      capability: .taskResume, patterns: [.any], confirmationRequirement: .none,
      purpose: seedPurpose),
    Grant(
      capability: .taskRetry, patterns: [.any], confirmationRequirement: .none,
      purpose: seedPurpose),
    // ADR-055: `task.delete` joins the seed set — see the ADR-055 comment
    // above for the owner-instructed local risk acceptance.
    Grant(
      capability: .taskDelete, patterns: [.any], confirmationRequirement: .none,
      purpose: seedPurpose),
    // SP-030 (`EV-SP-030-20260831-R11-POLICY-BLOCK-01`): launch at login. This
    // is the SP-006 finding at the top of this file, recurring one track later
    // — a capability registered and implemented, but denied before reaching
    // its implementation because nothing seeded a grant. `.mutation` tier is
    // deny-by-default in production `PolicyConfiguration`, so the Settings
    // toggle failed with "No matching grant and tier mutation is denied by
    // default" and `SMAppService` was never reached.
    //
    // `.forRiskTier(.mutation)` rather than `.none`, matching `.appTerminate`
    // above: this writes a persistent, system-level login item, so the user
    // confirms the effect rather than the grant silently standing in for their
    // intent. It resolves to a confirmation for this capability, which is why
    // `evaluateDirectCapability` had to learn to present one.
    //
    // The other eight denied lifecycle capabilities — safe mode, reset,
    // rollback, uninstall, factory reset, update check/stage/approve — stayed
    // deny-by-default from SP-030 until ADR-055: they are `.destructive` or
    // `.network` tier, and the seed set deliberately refused to open a
    // destructive surface by default. ADR-055 (2026-09-07) records the
    // owner's explicit decision to change exactly that for this local,
    // non-distributed build ("Onaysız tam serbest"): the destructive
    // lifecycle tier is granted with NO confirmation challenge. This is an
    // owner-instructed local risk acceptance, not a policy default — an
    // external-distribution build must not inherit it.
    Grant(
      capability: .lifecycleLaunchAtLogin, patterns: [.any],
      confirmationRequirement: .forRiskTier(.mutation), purpose: seedPurpose),
    Grant(
      capability: .lifecycleCheckUpdate, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleApproveUpdate, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleStageUpdate, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleRollback, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleSafeMode, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleReset, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleUninstall, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    Grant(
      capability: .lifecycleFactoryReset, patterns: [.any],
      confirmationRequirement: .none, purpose: seedPurpose),
    // ADR-055: computer use joins the seed set at the same confirmation
    // requirement `.appActivate`/`.appTerminate` carry — a mutation-tier
    // confirmation on mutation actions, none on observation. The allowlist
    // gate itself (ADR-055 open mode) is structural; this grant is the
    // policy-engine gate.
    Grant(
      capability: .computerUseRun, patterns: [.any],
      confirmationRequirement: .forRiskTier(.mutation), purpose: seedPurpose),
    // ADR-055: Ollama cloud inference ("Etkinleştir"). The prompt is proxied
    // to Ollama's hosted backend, so this grant always requires the
    // confirmation challenge — matching `.agentCodexRun`/`.agentClaudeRun`/
    // `.agentCopilotRun` above, the other third-party-bound capabilities.
    Grant(
      capability: .agentOllamaCloudInference, patterns: [.any],
      confirmationRequirement: .always, purpose: seedPurpose),
  ]

  /// The filesystem capabilities SP-004/SP-005 delivered, confined to the
  /// declared roots. One grant per (capability, root) pair: a grant matches
  /// only when *all* of its patterns match, so listing several roots inside a
  /// single grant would demand a path be under every root at once — which no
  /// path can be.
  private static let fileRootGrants: [Grant] = DeclaredFileRoots.all.flatMap { root in
    [Capability.fileOpen, .fileReveal].map { capability in
      Grant(
        capability: capability,
        patterns: [.directory(root, recursive: true)],
        confirmationRequirement: .none,
        purpose: seedPurpose)
    }
  }

  /// `url.open`, scoped to the schemes the adapter will actually hand to
  /// LaunchServices. A `file:`, `ftp:`, or scheme-less target now fails to
  /// match any grant and is denied before the adapter is consulted.
  private static let urlGrant = Grant(
    capability: .urlOpen,
    patterns: [.urlScheme(allowed: DeclaredFileRoots.allowedURLSchemes)],
    confirmationRequirement: .none,
    purpose: seedPurpose)

  public static let all: [Grant] = unscoped + fileRootGrants + [urlGrant]

  /// Capabilities the seeded set governs. `reconcileSeededGrants` prunes the
  /// legacy unmarked `.any` grants for exactly these, and nothing else.
  public static var seededCapabilities: Set<Capability> { Set(all.map(\.capability)) }
}
