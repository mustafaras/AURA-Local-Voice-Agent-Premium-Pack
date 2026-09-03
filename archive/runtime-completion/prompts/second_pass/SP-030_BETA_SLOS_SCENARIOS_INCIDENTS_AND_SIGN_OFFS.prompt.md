---
id: SP-030
sequence: 30
track: R12
gap_ids: OPEN-13
depends_on: SP-029
next_prompt: SP-031
state: pending
---

# SP-030 — Local-Only Deterministic Validation and Scope Decision

## Mission

Close the local-only deterministic validation scope for reliability, safety,
accessibility, privacy, security, and false-success controls without claiming
live beta or production readiness. The live-beta interpretation is explicitly
deferred under ADR-051 because the release owner does not want live testing.

## Read before acting

- `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md`
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md`
- `R12 prompt`
- `beta readiness record`
- `performance budgets`
- `acceptance scenarios`
- `incident response`
- `independent review checklist`
- `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md` sections OPEN-13

## Hard boundaries

- Work only on OPEN-13; do not absorb the next prompt's objective.
- Do not infer completion from a type, fake, local contract, historical ledger line, or model assertion.
- Do not run live user-present testing, access the microphone, mutate TCC,
  contact providers, enroll beta users, enable telemetry, sign, release,
  deploy, commit, push, or merge unless separately authorized. Deterministic
  and synthetic results must retain their measurement class and may never be
  relabeled as live-beta evidence.
- Preserve raw audio, screenshots, secrets, tokens, private account data, and unredacted model output out of ledgers and context files.

## Procedure

1. Run the prompt-relevant deterministic lifecycle, integration, STT, safety,
   and state-contract tests; record exact commands, counts, environment, and
   limitations.
2. Run the approved synthetic Speech path only when it is already authorized;
   if the OS authorization boundary blocks it, record the blocked result without
   requesting or changing permission.
3. Reconcile the existing beta-readiness record without promoting any
   non-live result: live SLOs remain `not_measured`, live scenario execution
   remains absent, and `incident_review` remains `not_run`.
4. Preserve the existing sign-off and local launch-at-login evidence, record
   the deferred live-beta/R11 limitations, and keep the overall R12 readiness
   blocked.

## Cognitive completion gate

Before changing this prompt to `completed`, answer all of these in `SECOND_PASS_LEDGER.md` and the two program ledgers:

- What exact symptom or missing postcondition was observed?
- What mechanism and root cause explain it? Which agent/context layer was involved, if any?
- What direct deterministic change or scope-acceptance procedure resolved the
  local-only objective?
- Which evidence ID and evidence class prove the result?
- What observation would falsify the conclusion?
- What live-beta, R11, or incident residual remains, and why is it explicitly
  outside this local-only scope?
- Why must beta readiness and SP-031 remain blocked even after this scoped
  completion?

## Required records

- Evidence ID prefix: `EV-SP-030`; include timestamp, branch/commit, command or procedure, environment, result, artifact path/hash, scope, and limitations.
- Update the named gap in `SECOND_PASS_OPEN_GAPS.md` without deleting historical wording.
- Update `EVIDENCE_INDEX.md`, `RISK_REGISTER.md`, `SECOND_PASS_LEDGER.md`, `PROGRAM_LEDGER.md`, `PROJECT_LEDGER.md`, second-pass state, first-pass state references, and session handoff as required by the control contract.
- Run `python3 scripts/validate_second_pass_program.py` and the prompt-relevant tests.
- Run `15_SESSION_CLOSEOUT.prompt.md` after this attempt, even if blocked.

## Completion gate

The local-only scope is complete when the deterministic validation suites and
state validators pass, the userless/synthetic attempt is recorded with
provenance and limitations, the five existing R12 sign-offs remain valid, and
ADR-051 is recorded. No live-beta claim may be made: `ptt_ack`,
`stt_partial`, live dialogue latency, live R11 transitions, live scenario
execution, and incident review remain explicitly deferred.
`beta-readiness.json` must remain `blocked`, and SP-031 may open only for its
bounded local-only package-preparation scope under ADR-052; no release approval
or beta claim follows from this prompt.

## Stop condition

If any local-only evidence, authority, cognitive answer, postcondition, scope
decision, or validator result is missing, keep SP-030 `in_progress` or
`blocked`. A scoped completion does not authorize live beta, release, or
production claims. SP-031 may be opened under ADR-052 for local-only package
preparation, but do not proceed to SP-032 or any approval claim without its own
scope, evidence, and decision gates.
