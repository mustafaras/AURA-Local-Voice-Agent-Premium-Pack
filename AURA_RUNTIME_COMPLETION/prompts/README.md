# AURA Runtime Completion Prompt Program

> **Program version:** 1.0.0  
> **Status:** Execution-ready  
> **Primary plan:** `docs/roadmap/AURA_FULLY_OPERATIONAL_ASSISTANT_MASTER_PLAN.md`  
> **Prompt manifest:** `prompts/runtime_completion/prompt-manifest.json`  
> **Machine state:** `ledger/runtime_completion/current-state.json`  
> **Session handoff:** `anti_amnesia/runtime_completion/session-handoff.json`

## Purpose

This directory converts the master recovery and delivery plan into an ordered set of professional implementation prompts. Each prompt is designed to be executable in a fresh coding-agent session without relying on chat history.

The program exists because AURA already contains many substantial subsystems, but they are not yet connected into one truthful, bilingual, user-operable assistant. The prompts therefore prioritize integration, verification, product usability, privilege separation, and release quality rather than adding disconnected modules.

## Authoritative execution order

Run the prompts strictly in the order declared by `prompt-manifest.json`:

1. `00_SESSION_BOOTSTRAP.prompt.md`
2. `01_R0_REPOSITORY_TRUTH_AND_GOVERNANCE.prompt.md`
3. `02_R1_RUNTIME_INTEGRATION_SPINE.prompt.md`
4. `03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md`
5. `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`
6. `05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md`
7. `06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`
8. `07_R6_VSCODE_AND_CODING_AGENTS.prompt.md`
9. `08_R7_VOICE_WAKE_STT_TTS_RESOURCE_GOVERNOR.prompt.md`
10. `09_R8_MEMORY_PERSONALIZATION_EXPLAINABILITY.prompt.md`
11. `10_R9_PRODUCT_UI_AND_ACCESSIBILITY.prompt.md`
12. `11_R10_SECURITY_PRIVILEGE_SEPARATION.prompt.md`
13. `12_R11_RELEASE_ENGINEERING_AND_OPERATIONS.prompt.md`
14. `13_R12_BETA_VALIDATION_AND_RC.prompt.md`
15. `14_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md`

Use `15_SESSION_CLOSEOUT.prompt.md` at the end of every work session, including interrupted or partially completed sessions.

## Fresh-session start

A new agent session must read only the following files initially:

1. `AGENTS.md`
2. `prompts/runtime_completion/SHARED_EXECUTION_CONTRACT.md`
3. `ledger/runtime_completion/current-state.json`
4. `anti_amnesia/runtime_completion/session-handoff.json`
5. `anti_amnesia/runtime_completion/READ_FIRST.md`
6. the active prompt named by `current-state.json`

The agent should load the full master plan, ADRs, source files, tests, and historical ledger entries only when the active prompt requires them. This prevents context waste and reduces stale-state contamination.

## Anti-amnesia design

The program separates four kinds of information:

- **Stable context:** `anti_amnesia/runtime_completion/KNOWN_FACTS.md`
- **Current compact context:** `anti_amnesia/runtime_completion/ACTIVE_CONTEXT.md`
- **Machine-readable handoff:** `anti_amnesia/runtime_completion/session-handoff.json`
- **Historical evidence:** `ledger/runtime_completion/PROGRAM_LEDGER.md`

Do not turn the handoff file into a historical diary. It must remain short and atomically replaceable. Historical details belong in the append-only ledger or evidence index.

## Source-of-truth hierarchy

When files disagree, use this order:

1. live repository and command evidence;
2. accepted ADRs and security policy;
3. `ledger/runtime_completion/current-state.json` after validation;
4. newest append-only runtime-completion ledger entry;
5. current session handoff;
6. the master plan;
7. older roadmap, prompt, or prose claims.

Never treat a prior “complete” statement as proof that a live runtime path works.

## State transitions

A prompt can move from `pending` to `in_progress` only after its preflight gate passes. It can move to `completed` only when:

- all mandatory deliverables exist;
- required tests have run and passed;
- live gates are explicitly distinguished from deterministic tests;
- evidence is recorded;
- residual risks are recorded;
- the next prompt is unblocked;
- state and handoff files are updated atomically.

Allowed prompt states are defined by `schemas/runtime_completion/program-state.schema.json`.

## Commit and release authority

These prompts do not grant authority to commit, push, merge, install, mutate TCC permissions, notarize, publish, deploy, or release. The active session must derive those permissions from the user’s explicit instruction and record the authority in `current-state.json` and the session ledger entry.

## End condition

The program is complete only when `14_FINAL_ACCEPTANCE_AND_CLEANUP.prompt.md` passes every release and product gate. At that point AURA must be a clean, installable, bilingual macOS assistant with:

- truthful multi-turn conversation;
- typed capability planning;
- policy-controlled execution and verification;
- practical desktop, browser, mail, calendar, and coding workflows;
- safe computer use;
- durable context and user-controlled memory;
- visible health and privacy controls;
- signed, notarized, updateable distribution;
- clean-install, recovery, accessibility, security, and beta evidence.
