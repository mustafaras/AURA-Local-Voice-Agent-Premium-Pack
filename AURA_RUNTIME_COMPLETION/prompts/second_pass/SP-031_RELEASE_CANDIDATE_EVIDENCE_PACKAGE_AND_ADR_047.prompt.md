---
id: SP-031
sequence: 31
track: R12
gap_ids: OPEN-13
depends_on: SP-030
next_prompt: SP-032
state: pending
---

# SP-031 — Local-Only RC Evidence Package Preparation and ADR-047

## Mission

Open and assemble one provenance-bound local-only `development_unverified`
RC evidence package and prepare the ADR-047 decision record without inventing
beta, production, or release approval. This prompt may advance the local-only
package work after SP-030, but it must not manufacture the live evidence that
SP-030 deliberately deferred.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R12 prompt`
- `artifact hashes/SBOM/manifests`
- `CI/coverage/adversarial logs`
- `beta report`
- `sign-offs`
- `ADR-047 decision record`
- `docs/decisions/ADR-052-sp031-local-only-rc-package-scope.md`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-13

## Hard boundaries

- Work only on OPEN-13; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not run live beta tests, capture microphone audio, mutate TCC, contact
  providers, enroll beta users, enable telemetry, sign/notarize, publish,
  release, deploy, commit, push, or merge unless separately authorized. Bind
  only local `development_unverified` artifacts and non-live evidence, and
  preserve each evidence class and limitation.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Bind the exact local source commit and existing `development_unverified`
   artifact, hashes, SBOM/dependency/model manifests, deterministic CI/test/
   coverage/adversarial results, and known artifact limitations.
2. Attach the local-only SLO/scenario limitations, deferred live-beta/R11/
   incident gates, open/accepted risks, capability exclusions, five sign-offs,
   and rollback/kill-switch plan without promoting non-live evidence.
3. Draft the local-only ADR-047 decision record and identify the explicit
   owner decision still required for any package approval. Do not infer that
   opening this prompt is approval.
4. If package evidence, cognitive answers, or the required decision is absent,
   keep SP-031 `in_progress` or `blocked`; do not advance to SP-032.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-032 safe or not safe to start after this local-only package attempt?

## Required records

- Evidence ID prefix: `EV-SP-031`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

The local-only package may complete only when it is reproducible,
recoverable, independently reviewed for its declared scope, and explicitly
approved for local-only use with ADR-047 evidence. A `development_unverified`
artifact is never a signed/notarized or external-release artifact;
`beta-readiness.json` and `release_candidate` remain blocked unless their own
direct authority and evidence gates are separately satisfied.

## Stop condition

If any required package evidence, authority, cognitive answer, postcondition,
or validator result is missing, keep SP-031 `in_progress` or `blocked`, record
the exact blocker, and do not proceed to SP-032. Do not turn the local-only
package preparation into a beta, production, or release claim.
