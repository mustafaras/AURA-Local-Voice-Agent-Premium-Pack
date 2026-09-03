# AURA Runtime Completion Ledger

This directory is the evidence and governance record for the Runtime Completion Program.

## Files

- `current-state.json` — compact, schema-validated, atomically replaceable machine state.
- `capability-matrix.json` — audited implementation/runtime/user-path/verification status by capability.
- `PROGRAM_LEDGER.md` — append-only program and session history.
- `DECISION_REGISTER.md` — decision/ADR queue and accepted-decision index for this program.
- `RISK_REGISTER.md` — active, mitigated, accepted, and closed program risks.
- `EVIDENCE_INDEX.md` — concise index of automated, live, manual, external, build, and release evidence.

## Rules

1. Never edit or delete historical entries in `PROGRAM_LEDGER.md`; append corrections.
2. Replace `current-state.json` atomically and validate it before commit.
3. Capability status must reflect production wiring and user reachability, not merely source existence.
4. Evidence IDs are immutable.
5. Risks are closed only with evidence or explicit accepted-risk authority.
6. Decisions that materially alter architecture, security, privacy, data schema, toolchain, platform baseline, or release behavior require an ADR.
7. Detailed logs and artifacts are referenced by path/hash, not pasted into Markdown.
8. Legacy `ledger/CURRENT_STATE.md` and `ledger/PROJECT_LEDGER.md` remain historical sources; this directory is the new runtime-completion program record.
