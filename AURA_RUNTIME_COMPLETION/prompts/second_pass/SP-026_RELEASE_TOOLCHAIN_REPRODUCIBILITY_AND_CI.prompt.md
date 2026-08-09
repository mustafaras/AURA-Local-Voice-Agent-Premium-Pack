---
id: SP-026
sequence: 26
track: R11
gap_ids: OPEN-12
depends_on: SP-025
next_prompt: SP-027
state: pending
---

# SP-026 — Release Toolchain, Reproducibility, and CI

## Mission

Establish a reproducible, observed release pipeline before any signing or distribution action.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R11 prompt`
- `ADR-045`
- `TOOLCHAIN.md`
- `artifact builder/manifest validators`
- `CI workflow`
- `official Apple tool docs`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-12

## Hard boundaries

- Work only on OPEN-12; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not install, launch, mutate TCC, contact providers, enroll beta users, sign, release, deploy, commit, push, or merge unless this prompt's authority explicitly permits it.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Obtain or authorize full Xcode/SDK/toolchain pinning and record exact versions.
2. Build app, nested helpers, entitlements, plists, resources, symbols, SBOM, checksums, provenance, and update metadata reproducibly.
3. Run the actual CI workflow and inspect retained artifacts, signatures, manifests, and provenance; distinguish workflow configuration from run evidence.
4. Keep development_unverified artifacts clearly non-release.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct change or acceptance procedure resolved it?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What residual risk remains, and why is it outside this prompt?
- Why is SP-027 now safe to start?

## Required records

- Evidence ID prefix: `EV-SP-026`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

Reproducibility and observed CI evidence are independently inspectable and match the canonical commit.

## Stop condition

If any required evidence, authority, cognitive answer, postcondition, or validator result is missing, keep SP-026 `in_progress` or `blocked`, record the exact blocker, and do not proceed to SP-027.
