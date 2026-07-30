# ADR-033 — Adversarial Safety and Red-Team Harness

- Status: Draft
- Date: 2026-07-29
- Owners: Codex
- Supersedes: —
- Superseded by: —

## Context

Phase 25 of the AURA implementation roadmap requires an adversarial safety
harness and red-team evaluation suite. The existing security primitives
(`PromptInjectionClassifier`, `PolicyEngine`, `ToolRouter`, `ReferenceResolver`,
`PluginVerifier`, `ConfigurationEngine`) are individually tested, but there is
no consolidated, deterministic, failure-as-blocker suite that exercises every
externally-influenced input path documented in `docs/security/30_THREAT_MODEL.md`
as a single adversarial surface. The goal is to make red-team findings
repeatable, version-controlled, and CI-blocking, while keeping the harness itself
out of the runtime authority path.

## Decision

1. **A new test target, `AuraAdversarialTests`**, contains all Phase 25
   adversarial evals. It depends on the production modules it exercises
   (`AuraSecurity`, `AuraPolicy`, `AuraIntent`, `AuraMemory`, `AuraContext`,
   `AuraAgent`, `AuraPlugins`, `AuraConfig`) and reuses their deterministic
   public interfaces as adversarial seams. It does not introduce a new runtime
   authority, coordinator, or policy bypass.

2. **Eval taxonomy is structured by attack family and test subject**, not by
   subsystem alone. Each eval names the attacker goal, the production seam
   exercised, the controlled input, and the expected deterministic outcome.
   Families:
   - prompt/indirect injection against `PromptInjectionClassifier`;
   - jailbreak and role-hijack against `ContentProvenance` + classifier;
   - tool-call spoofing against `ToolRouter` + `TypedIntent` schema;
   - policy bypass against `PolicyEngine` grants/confirmation binding;
   - memory poisoning against `ReferenceResolver` + `MemoryEngine`;
   - context-target confusion against `ContextEngine`/`ReferenceResolver`;
   - structured-output abuse against `TypedIntent` argument validation;
   - capability-boundary violation against `Capability`/`PermissionRiskTier`
     typed boundaries;
   - hallucination/confabulation of authority against provenance and grant
     persistence;
   - supply-chain tampering against `PluginVerifier` and package-signature
     checks.

3. **All blocking evals are deterministic and local.** No eval required to pass
   the CI gate may depend on a remote service, a stochastic model score, or a
   human judgment. Optional model-backed probes may be added for exploratory
   research but are explicitly marked non-blocking.

4. **Authority boundary is enforced by type, not by test assertion alone.**
   `ContentProvenance.carriesAuthority == false` for every non-user/non-system
   source means the harness does not need to "simulate" a model being tricked;
   it can assert that the provenance enum itself prevents authority transfer,
   and that the classifier/policy/intent seams reject or gate the input
   accordingly.

5. **Failure-as-blocker CI wiring.** `scripts/aura-test.sh` already treats any
   non-zero bundle exit or any Swift Testing failure as a non-zero overall
   result. The new target is added to the default build/run loop; no special
   "allowed failure" path is introduced.

6. **Independent review schedule and incident response are first-class
   deliverables.** `docs/operations/SECURITY_REVIEW_SCHEDULE.md` defines
   cadence, scope, reviewer independence, and evidence retention.
   `docs/operations/ADVERSARIAL_INCIDENT_RESPONSE.md` defines how a red-team
   finding is triaged, fixed, regression-tested, and recorded in the append-only
   ledger. The residual-risk registry in `Sources/AuraCore/ResidualRiskRegistry.swift`
   references these documents.

## Alternatives considered

- **A separate `AuraAdversarial` library target with production code.**
  Rejected — the harness is pure evaluation; nothing in it should run at
  product runtime.
- **Model-based adversarial scoring for the CI gate.** Rejected — stochastic
  verdicts are not reproducible and would weaken the "failure as blocker"
  guarantee. Deterministic rules and typed boundaries are the gate.
- **Adding adversarial cases to each existing test target only.** Rejected —
  cross-cutting adversarial reasoning is easier to maintain and review in one
  place, and a dedicated target makes the Phase 25 scope explicit in the test
  runner and coverage report.
- **Creating a new policy surface to "authorize" red-team actions.** Rejected —
  the harness subjects existing components to adversarial inputs; it does not
  need its own policy path, and adding one would risk introducing new authority.

## Security and privacy impact

- The harness does not introduce new runtime authority, secrets, network paths,
  or data collection. All evals run against in-memory or temporary-directory
  test doubles.
- By making red-team cases version-controlled and CI-blocking, the project
  turns tackearlier security knowledge into durable regression tests.
- Supply-chain evals will surface the current local-only signing reality rather
  than pretending a notarized chain exists; findings are documented, not
  bypassed.

## Operational impact

- `Package.swift` gains one `AuraAdversarialTests` test target.
- `scripts/aura-test.sh` includes the new bundle in its default loop.
- Two new operational documents are added to `docs/operations/`.
- `ledger/DECISION_INDEX.md` is updated when the ADR is accepted.

## Migration

No runtime migration. Existing security and policy tests remain unchanged.
The new target may reuse existing test helpers/fakes where they are already
public/internal to the module; any new shared test seam is added to the test
file itself, not to production code.

## Validation evidence

- `AuraAdversarialTests` will contain deterministic evals with explicit expected
  outcomes.
- The full repository coverage gate must pass with the new target included and
  line coverage ≥ 70%.
- Independent review of the harness design is part of the acceptance gate.

## Consequences

- Positive: adversarial safety becomes a repeatable, CI-enforced engineering
  practice rather than an ad-hoc manual review.
- Positive: future phases can add a new attack family as a test file plus a
  ledger entry, following the established taxonomy.
- Limitation: the harness can only test the seams that already exist; it cannot
  find integration gaps in components that are not yet wired to a real caller
  (e.g. classifier → screen OCR normalizer). Such gaps remain tracked in
  `docs/security/30_THREAT_MODEL.md` residual-risk sections.
- Next safe action: implement the `AuraAdversarialTests` scaffold and the first
  eval cases, then run the full coverage gate.
