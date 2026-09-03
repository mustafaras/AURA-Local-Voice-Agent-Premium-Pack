# AURA Second-Pass Prompt Program

This is the human-facing index for the one-gap-at-a-time second pass. The
machine source is
`AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_MANIFEST.json`; the
gap source is `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`.

## Non-negotiable transition rule

Run exactly one `SP-*` prompt at a time. Do not open the next prompt until the
current prompt has:

1. resolved its named gap objectively;
2. answered its cognitive completion questions;
3. produced the required evidence;
4. updated all synchronized state/ledger/context files;
5. passed `scripts/validate_second_pass_program.py`.

If the prompt cannot prove its root cause or postcondition, leave it
`in_progress`/`blocked` and repeat it. “Nearly done,” “tests pass,” or “the
next prompt can finish it” is not a valid transition.

## Context-engineering topology

| Layer | Canonical file | Responsibility |
|---|---|---|
| Gap truth | `SECOND_PASS_OPEN_GAPS.md` | What is missing and why it remains open |
| Execution order | `second-pass/SECOND_PASS_PROMPT_MANIFEST.json` | One linear dependency chain |
| Active machine state | `second-pass/SECOND_PASS_STATE.json` | Which prompt may run now |
| Prompt contract | `second-pass/SECOND_PASS_PROMPT_CONTRACT.md` | Completion and transition invariants |
| Context read order | `context/SECOND_PASS_READ_FIRST.md` | Tiered anti-amnesia loading |
| Focused ledger | `second-pass/SECOND_PASS_LEDGER.md` | Append-only cognitive resolution records |
| Program ledger | `state/PROGRAM_LEDGER.md` | Historical phase evidence |
| Project ledger | `ledger/PROJECT_LEDGER.md` | Project-level delivery history |
| Evidence/risk | `state/EVIDENCE_INDEX.md`, `state/RISK_REGISTER.md` | Proof and residual risk |

## Chain

The 34 prompts are deliberately small. R4–R8 could be parallelized by a
human team, but this chain is linear so a single agent cannot hide an
unresolved dependency behind parallel progress.

| Sequence | Prompt | Focus |
|---:|---|---|
| 000 | SP-000 | Baseline and synchronization lock |
| 001 | SP-001 | R1 live trace and confirmation residual |
| 002 | SP-002 | R2 microphone/TCC Push-to-Talk |
| 003 | SP-003 | R2 seven live bilingual scenarios |
| 004 | SP-004 | R3 filesystem/URL adapters |
| 005 | SP-005 | R3 NLU/UI reachability and planner wiring |
| 006 | SP-006 | R3 live capability scenarios |
| 007 | SP-007 | R4 live planner in approved apps |
| 008 | SP-008 | R4 adversarial safety and emergency stop |
| 009 | SP-009 | R5 extension packaging/authentication |
| 010 | SP-010 | R5 provider/account composition and UI |
| 011 | SP-011 | R5 live read/mutation/revocation acceptance |
| 012 | SP-012 | R6 authenticated extension bridge |
| 013 | SP-013 | R6 backend and durable task lifecycle |
| 014 | SP-014 | R6 user-present coding acceptance |
| 015 | SP-015 | R7 wake-word decision/evaluation |
| 016 | SP-016 | R7 STT quality and voice recovery |
| 017 | SP-017 | R7 TTS/resource soak and ADR-042 |
| 018 | SP-018 | R8 production reference wiring |
| 019 | SP-019 | R8 live memory controls/conflicts/restart |
| 020 | SP-020 | R8 remote boundary and ADR-043 |
| 021 | SP-021 | R9 accessibility and localization |
| 022 | SP-022 | R9 controls/onboarding/recovery |
| 023 | SP-023 | R10 IPC and privilege separation |
| 024 | SP-024 | R10 network/OAuth/injection enforcement |
| 025 | SP-025 | R10 plugin trust/incident/review/ADR-044 |
| 026 | SP-026 | R11 toolchain/reproducibility/CI |
| 027 | SP-027 | R11 signing/notarization/clean machine |
| 028 | SP-028 | R11 updater/lifecycle/recovery/migration |
| 029 | SP-029 | R12 cohort/consent/telemetry |
| 030 | SP-030 | R12 local-only deterministic validation and scope decision |
| 031 | SP-031 | R12 RC package and ADR-047 |
| 032 | SP-032 | FINAL acceptance and cleanup |
| 033 | SP-033 | Final closeout reconciliation |

The closeout procedure is also required after every prompt attempt; SP-033 is
the explicit chain-end audit, not permission to skip intermediate closeouts.

The machine validator is `scripts/validate_second_pass_program.py`; run it
before claiming any transition or handoff.
