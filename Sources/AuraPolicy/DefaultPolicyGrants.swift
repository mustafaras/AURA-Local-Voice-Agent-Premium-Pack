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
public enum DefaultPolicyGrants {
  public static let all: [Grant] = [
    Grant(capability: .appActivate, patterns: [.any], confirmationRequirement: .none),
    Grant(
      capability: .appTerminate, patterns: [.any],
      confirmationRequirement: .forRiskTier(.mutation)),
    Grant(capability: .shellExec, patterns: [.any], confirmationRequirement: .always),
    Grant(capability: .agentCodexRun, patterns: [.any], confirmationRequirement: .always),
    Grant(capability: .agentClaudeRun, patterns: [.any], confirmationRequirement: .always),
    Grant(capability: .agentCopilotRun, patterns: [.any], confirmationRequirement: .always),
    // Local Ollama is reversible and has no side effects. The policy adapter
    // only maps a model to this grant when its /api/tags entry is local.
    Grant(
      capability: .agentOllamaLocalInference, patterns: [.any],
      confirmationRequirement: .none),
    // SP-006: the SP-004/SP-005 filesystem/URL capabilities. `.reversible`
    // tier, no mandatory confirmation per their manifests, adapter validates
    // every target before any side effect.
    Grant(capability: .fileOpen, patterns: [.any], confirmationRequirement: .none),
    Grant(capability: .fileReveal, patterns: [.any], confirmationRequirement: .none),
    Grant(capability: .urlOpen, patterns: [.any], confirmationRequirement: .none),
  ]
}
