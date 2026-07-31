# Start Here — AURA Runtime Completion

This is the only recommended entry point for a new implementation session.

## 1. Minimal startup read set

Read in this exact order:

1. `../AGENTS.md`
2. `prompts/SHARED_EXECUTION_CONTRACT.md`
3. `state/current-state.json`
4. `context/session-handoff.json`
5. `context/READ_FIRST.md`
6. the active prompt specified by `state/current-state.json`

Do not load the full master plan, all source code, all tests, or the historical project ledger at startup. Load additional context only when the active prompt or `context/context-index.json` requires it.

## 2. First executable prompt

The seeded active prompt is:

```text
AURA_RUNTIME_COMPLETION/prompts/00_SESSION_BOOTSTRAP.prompt.md
```

The bootstrap prompt must reconcile live repository state, authority, toolchain, JSON/Schema validity, prompt dependencies, capability status, and legacy contradictions before R0 begins.

## 3. Authoritative execution order

The ordered program is defined by:

```text
AURA_RUNTIME_COMPLETION/prompts/prompt-manifest.json
```

Execution order:

1. BOOTSTRAP
2. R0 — Repository truth and governance
3. R1 — Runtime integration spine
4. R2 — Bilingual NLU and dialogue
5. R3 — Capability registry and typed planner
6. R4 — Computer-use productization
7. R5 — Browser, mail, calendar, and contacts
8. R6 — VS Code and coding agents
9. R7 — Wake word, STT/TTS, and resource governance
10. R8 — Memory, personalization, and explainability
11. R9 — Product UI and accessibility
12. R10 — Security and privilege separation
13. R11 — Release engineering and operations
14. R12 — Beta validation and release candidate
15. FINAL — Acceptance and cleanup

Run `prompts/15_SESSION_CLOSEOUT.prompt.md` at the end of every session, including interrupted or blocked sessions.

## 4. State discipline

- `state/current-state.json` is the compact machine source of truth.
- `context/session-handoff.json` is the compact next-session handoff.
- `state/PROGRAM_LEDGER.md` is append-only history.
- `state/EVIDENCE_INDEX.md` records concise evidence references.
- `state/RISK_REGISTER.md` and `state/DECISION_REGISTER.md` remain separate from the handoff.
- `context/KNOWN_FACTS.md` contains only stable verified facts.
- `context/ACTIVE_CONTEXT.md` contains only concise current human-readable context.

## 5. Authority boundary

No implementation, dependency installation, model download, permission/TCC mutation, app installation/launch, commit, push, merge, signing, notarization, release, or deployment authority persists automatically across sessions. Record only the authority explicitly granted in the current session.

## 6. Truthfulness boundary

Code existence does not prove operation. Distinguish:

- implemented;
- runtime-registered;
- user-reachable;
- system-tested;
- live-verified;
- release-verified.

Execution does not equal verified completion. Never report success without postcondition evidence.
