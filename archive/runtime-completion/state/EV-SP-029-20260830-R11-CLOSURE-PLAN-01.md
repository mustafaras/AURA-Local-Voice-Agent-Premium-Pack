# EV-SP-029-20260830-R11-CLOSURE-PLAN-01

**Evidence ID:** EV-SP-029-20260830-R11-CLOSURE-PLAN-01
**Track:** SP-029 / R12 / OPEN-13 (planning the R11 → SP-030 dependency for R12)
**Type:** Process/plan — R11 closure plan produced under owner option-A grant
**Commit:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` (`main`; `HEAD == origin/main == 37805cb0`; working tree dirty with uncommitted SP-028/SP-029 source + control-plane projections)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6, Git 2.54.0
**Session:** AURA-SP-029-BETA-CONTRACT-20260829
**Authority:** The release owner chose option A ("a go be perfect and premium") for R11 closure planning. This produces a decision-ready plan and records the honest dispositions; it does not fabricate R11 completion, an RC, external signing, or beta-readiness advancement.

## What was produced

A decision-ready R11 closure plan at `AURA_RUNTIME_COMPLETION/context/R11_CLOSURE_PLAN.md` that:

- Maps every remaining R11 gate into three honest dispositions:
  - **Locally closable** with owner-authorized launch/install/test (launch-at-login live, sleep/wake/crash live, safe mode/support-bundle live, migration on a populated profile).
  - **External/Apple-prerequisite** (Developer ID signing, notarization, stapling, external clean-machine, signed update transport) — genuinely unavailable, cannot be fabricated, and by SP-027's local-only scope decision are out of scope for AURA.
  - **Owner-decision** (ADR-046 local-only acceptance; keep artifact `development_unverified`; keep `beta-readiness.json` blocked).
- Records a **stale-authority drift**: `current-state.json` `authority` is edit/test/state-only (reset during SP-029's blocked phase) while `SECOND_PASS_STATE.json` shows launch/commit/push/merge true; the owner grants since then have not been propagated. This must be reconciled before exercising any R11 local gate.
- Specifies the recommended sequence (authority reconcile → local gates → ADR-046 local-only acceptance → keep beta blocked → open SP-030 under its own authority) and honesty guardrails.

## Honest dispositions (no fabrication)

- **Not claimed:** R11 `completed`; Developer ID/notarization/clean-machine evidence; a signed/notarized RC artifact; any relabel of `development_unverified`; `beta-readiness.json` advancing past `blocked`.
- **Owner-decision prepared:** ADR-046 may be advanced to `Accepted` **with an explicit local-only scope limitation** once the local updater/rollback/recovery/safe-mode/reset contract is accepted for local operation — the SP-028 deterministic + adversarial tests evidence the local contract; a real external signed update/transport remains out of scope by SP-027.
- **Next gate owned by SP-030:** SLOs/scenarios/incidents/sign-offs. SP-030 live measurement still requires `telemetry_or_beta: true`, which only the owner can grant.

## Evidence

- `AURA_RUNTIME_COMPLETION/context/R11_CLOSURE_PLAN.md` (the plan).

## Falsifiers

- Any claim that R11 is `completed`, that Developer ID/notarization/clean-machine evidence exists, that an RC artifact is approved, or that `beta-readiness.json` left `blocked` would falsify this record — none of those occurred and none is claimed.
- SP-029 remains `completed`; `beta-readiness.json` stays `blocked` (R12 not RC-ready).

## Next action

Reconcile the stale-authority drift in the control-plane projections, then, under owner authorization, close the locally-closable R11 gates in a user-present session and advance ADR-046 under the explicit local-only scope. Keep `beta-readiness.json` blocked. Open SP-030 only under its own authority and with `telemetry_or_beta` granted.
