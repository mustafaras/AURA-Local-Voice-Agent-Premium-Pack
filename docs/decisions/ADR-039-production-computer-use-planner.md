# ADR-039 — Production Computer-Use Planner and Approved-Application Beta Boundary

- Status: Accepted
- Date: 2026-08-07
- Owners: GitHub Copilot engineering session
- Supersedes: —
- Superseded by: —

## Context

R4 (`05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md`) requires turning the existing screen-context, Accessibility/CGEvent executor, emergency stop, and bounded control loop (ADR-019) into a **production user capability** with: a production observation contract, a real typed planner emitting only the closed `ComputerUsePlan` schema, an approved-target beta allowlist, resumable confirmation, postcondition verification, and live beta evidence.

ADR-019 already delivered the loop's safety spine: a bounded Observe → Plan → Policy → Act → Verify loop; `ComputerUseSemanticIntent`/`ComputerUsePlan`/`ComputerUseActionStep` closed types; `EmergencyStopController` enforced at both the loop and the executor layer; Accessibility-first anchoring with bounded coordinate fallback; secure-field non-interaction; unexpected-modal halting; mandatory-confirmation blocking; no-progress detection. What R4 adds is the **productization** layer: a real planner conformer (not just `ScriptedPlanner` test fakes), an approved-application boundary so computer use "must not become a universal shortcut around missing adapters," resumable confirmation that survives a state change, and semantic postcondition verification beyond a bare hash diff.

`RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` (R4, High/Critical, Open) captures exactly this: "Real action executor exists without a production typed planner/user route."

## Decision

1. **A production observation contract extends `ScreenObservation` without replacing it.** `ComputerUseObservation` wraps a `ScreenObservation` and adds the planner-relevant structured fields the prompt's "Observation contract" section names that `ScreenObservation` does not already carry: a bounded Accessibility-tree summary (roles/labels/identifiers/values/states/actions — captured only from the approved target application's AX tree, capped by a traversal bound), semantic control candidates, secure-field and sensitive-app state, modal state, a structural/content hash, capture/redaction provenance, and a freshness deadline. It deliberately **never retains the raw frame** (`rawImageRetained` stays false by default), matching `ScreenObservation`'s zero-retention-by-default posture. The `ComputerUseControlLoop` Observe phase produces a `ComputerUseObservation` from a `ScreenObservation`; the planner consumes only `ComputerUseObservation`.

2. **A deterministic, app-specific `ComputerUsePlanning` conformer is the first production planner.** `DeterministicComputerUsePlanner` maps a small set of known objectives (per approved application) to typed `ComputerUsePlan`s through an app-specific fixture table, and otherwise returns a `ComputerUsePlan` whose steps carry an explicit `.observe` intent or an empty plan with a clarification request. It emits **only** closed `ComputerUseActionStep`/`ComputerUsePlan` values — structurally incapable of producing raw model text as an action. It **stops and clarifies when the target is uncertain** (unknown objective, unknown app, or an observation whose `appBundleIdentifier` does not match the planner's configured app), matching the prompt's "Stop and clarify when the target is uncertain." A later model-backed conformer can sit behind the same `ComputerUsePlanning` boundary without changing the loop.

3. **A `ComputerUseBetaAllowlist` gates every production target.** The allowlist starts deliberately small (the prompt's suggested set: Finder, one browser, VS Code, Terminal, Notes, Calendar, read-only Mail). Each entry records an `appBundleIdentifier`, an app-specific fixture bundle identifier (`ComputerUseAppFixtures`), and a validation state. A target is `.disabled` (never reachable by a production planner) until its `appBundleIdentifier` is present **and** marked `liveValidated`. This makes "remains disabled for unvalidated apps" a structural property of the planner boundary, not a caller convention: `DeterministicComputerUsePlanner` refuses any target not on the allowlist, and `ComputerUseControlLoop` refuses to start a session whose target is not allowlisted.

4. **Resumable confirmation is a persisted, hash-bound checkpoint, not an in-memory flag.** `ComputerUseConfirmationStore` persists (a) the immutable plan fingerprint, (b) the observation's content/structural hash and identity, (c) the app/window identity and anchor, and (d) a nonce/expiry — the exact fields the prompt's "Confirmation checkpoint/resume" section enumerates. On resume it **recaptures and re-resolves** the target, and rejects execution if the app/window identity, modal state, anchor, content hash, or secure-field state changed in a way that invalidates the plan — mirroring ADR-037's fail-closed confirmation discipline applied to the computer-use path. It executes once and records evidence; a replay of the same checkpoint is rejected (one-time execution).

5. **Postcondition verification is semantic, not a bare hash diff.** `ComputerUseVerifier` evaluates a step's declared `expectedPostcondition` against the post-action observation using an app-specific semantic predicate (via `ComputerUseAppFixtures`), with the content-hash comparison available only as an additional signal — never sufficient on its own, matching the prompt's "Hash change alone is insufficient for success."

6. **Computer use is registered as a capability but remains off by default.** A `computerUse.run` capability (mutation tier, gated by the same `PolicyEngine.evaluate` every other capability uses) is registered; `DeterministicComputerUsePlanner`'s allowlist and the mandatory-confirmation gates keep it from acting on unapproved apps or unbounded objectives regardless of any grant.

## Alternatives considered

- **A model-backed planner as the first conformer.** Rejected for this pass — the local 8B model's structured-output sampling variance (`RISK-STRUCTURED-NLU-MODEL-QUALITY`) is a documented, accepted bounded risk; a deterministic first conformer keeps the "no raw model text becomes an action" guarantee structurally airtight while a model adapter (already integrated via `OllamaAdapter`) can be added behind the same `ComputerUsePlanning` boundary later without touching the loop.
- **Letting `ScreenObservation` itself carry the full accessibility tree.** Rejected — `ScreenObservation` is a redaction-safe, image-hash-focused record; embedding a deep AX tree would bloat it and risk leaking accessibility values. `ComputerUseObservation` composes over it, keeping the two concerns (capture/redaction vs. planner-relevant structure) separate.
- **A confirmation checkpoint that stores the full plan object.** Rejected — plans are immutable; the persistent identity is the plan's content fingerprint plus the observation hash, not a serialized mutable plan. This is the same immutable-fingerprint discipline ADR-038/ADR-037 use.
- **Allowing the allowlist to be empty-and-open (any app once Accessibility is trusted).** Rejected — that is exactly "a universal shortcut around missing adapters," which the R4 mission explicitly forbids. The allowlist is closed by default; only explicit live validation opens an entry.

## Security and privacy impact

- Computer use never becomes a universal shortcut: the beta allowlist and per-target validation state structurally gate every production session; unvalidated apps are unreachable.
- No raw model output ever becomes an executable action: the deterministic planner emits only closed `ComputerUseActionStep` values, and the `ComputerUsePlanning` boundary is unchanged from ADR-019.
- Confirmation resumes fail closed: a persisted checkpoint whose observation/identity/anchor/content changed is rejected rather than replayed; each checkpoint executes once.
- The observation contract never retains raw frames by default and adds capture/redaction provenance, so every planner-visible field is traceable to a redaction-safe capture.
- Emergency stop (ADR-019 decision 8/14) remains enforced at the loop and executor layers; the new planner and allowlist cannot bypass it.

## Operational impact

- `Sources/AuraComputerUse/` gains `ComputerUseObservation.swift`, `DeterministicComputerUsePlanner.swift`, `ComputerUseBetaAllowlist.swift`, `ComputerUseAppFixtures.swift`, `ComputerUseConfirmationStore.swift`, `ComputerUseVerifier.swift`.
- `Sources/AuraCore/` gains a `computerUse.run` capability static and any additive fields on `ActorID`/`AuraError` needed by the new types.
- `AuraComputerUseTests` gains deterministic unit tests for the new types; no live Accessibility/CGEvent hardware is exercised in the sandboxed environment (matching ADR-019's limitation).

## Migration

No breaking migration. The new types are additive; `ComputerUseControlLoop` keeps its existing public surface (the `ScreenObservation` → `ComputerUseObservation` composition is internal to the Observe phase). No new database schema.

## Validation evidence

- Deterministic unit tests for: `ComputerUseObservation` construction/redaction-safe provenance/freshness; `ComputerUseBetaAllowlist` open-only-after-live-validation and disabled-for-unvalidated-apps; `DeterministicComputerUsePlanner` known-objective → typed plan, unknown-objective → clarify, unknown/disabled app → refusal, never-emitting-raw-text (structural); `ComputerUseConfirmationStore` one-time execution, hash/identity/anchor/modal/secure-field change rejection, nonce/expiry; `ComputerUseVerifier` semantic postcondition pass/fail and hash-not-sufficient.
- Full repository regression (20/20 bundles) re-passed after the additions.

## Consequences

- **Positive:** Computer use has a production typed planner, an approved-application boundary, resumable hash-bound confirmation, semantic postcondition verification, and a redaction-safe observation contract — the deterministic core of R4's productization.
- **Negative:** Live beta-app evidence (running safe tasks in at least three approved apps on granted Accessibility/Screen-Recording hardware) and live confirmation/emergency-stop-through-the-real-app remain deferred to a user-present hardware session; the deterministic planner covers a curated fixture set, not arbitrary apps.
- **Risk:** `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` is materially mitigated (a real planner + allowlist now exist) but not closed — live beta evidence and a model-backed or broader planner route are still required before R4 completion.

## Related

- `05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md`
- `docs/decisions/ADR-019-computer-use-control-loop.md`
- `docs/decisions/ADR-018-screen-context-redaction.md`
- `docs/decisions/ADR-037-runtime-health-and-confirmation-transactions.md`
- `Sources/AuraComputerUse/`
- `Sources/AuraCore/ComputerUseTypes.swift`
