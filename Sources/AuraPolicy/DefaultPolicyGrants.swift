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
