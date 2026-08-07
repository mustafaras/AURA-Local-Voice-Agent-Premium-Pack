# AURA Session Starter — R5 Active; R2/R3/R4 Deferred for Second Pass

> Conversation date: 7 August 2026
> Last commit: `808cf64f1804fc9ba433ea5a85beedcdabeacdb2` — `docs(state): record R2 closeout, R3 status, and R4 productization progress`
> Read `AGENTS.md`, `AURA_RUNTIME_COMPLETION/state/current-state.json`, `AURA_RUNTIME_COMPLETION/context/session-handoff.json`, and the newest `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` entry before changing files.

## Canonical State Notice — 2026-08-07

This starter is a **historical compatibility document**. Use
`AURA_RUNTIME_COMPLETION/state/current-state.json` and
`AURA_RUNTIME_COMPLETION/context/session-handoff.json` as the authoritative
state. Live `HEAD == origin/main == 808cf64f1804fc9ba433ea5a85beedcdabeacdb2`;
the active prompt is **R5** and the next action is to author ADR-040 then build
read-first browser/mail/calendar/contacts adapters. The historical HEAD, phase,
and push claims below are not current state.

## Repository

- Path: `/Users/m_ras/Desktop/AURA-Local-Voice-Agent-Premium-Pack`
- Remote: `https://github.com/mustafaras/AURA-Local-Voice-Agent-Premium-Pack`
- Platform: macOS 27+ on Apple Silicon; Swift 6.4; CommandLineTools
- Test command: `./scripts/aura-test.sh /tmp/<unique-build-path> [bundle-filter]`
- Coverage gate: `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70 ./scripts/aura-test.sh /tmp/<unique-build-path>`
- Governance gate: `python3 scripts/validate_runtime_completion.py --ci`
- Do not use plain `swift test` in this environment.

## Current program state (authoritative)

- **R0** completed (repository truth/governance repair).
- **R1** completed (runtime integration spine and trace correctness).
- **R2** `in_progress` — bilingual NLU/dialogue implemented and system-tested
  (20/20 bundles) but **not formally closed**: `RISK-STT-MIC-NOT-CAPTURING`
  (Open) and `RISK-ENGLISH-ONLY-INTENT` (Mitigating) require live hardware
  evidence with the user physically present. `RISK-STRUCTURED-NLU-MODEL-QUALITY`
  sub-finding 3 accepted as bounded residual risk (2026-08-07).
- **R3** `in_progress` — capability registry/typed planner architectural core
  implemented and tested (ADR-038 accepted) but **not complete**: filesystem/URL
  adapters unbuilt, 4 direct-call-only capabilities lack NLU/UI reachability,
  planner not wired into DialogueEngine/ToolRouter, 7-scenario live demo pending.
- **R4** `in_progress` — computer-use productization deterministic core and
  registry/composition wiring implemented and tested (ADR-039 accepted,
  `computerUse.run` registered truthfully `.disabled`, `AuraKernel.computerUseRun`
  wired) but **not complete**: live beta-app evidence (≥3 approved apps) requires
  the user physically present.
- **R5** `in_progress` — browser/mail/calendar/contacts adapters, started by
  user-directed deviation while R2/R3/R4 remain open. **No adapters exist yet;
  ADR-040 must be authored first.**

## Second-pass completion plan (all remaining gates)

The user directed that all remaining incomplete gates be completed in a second
pass after the first pass. Each requires the user physically present or explicit
authorization for live/account actions:

1. **R2 live-verification:** microphone/TCC voice demo
   (`EV-R2-20260804-LIVE-VOICE-DEMO-01`) and 7-scenario demo
   (`EV-R2-20260804-LIVE-7SCENARIO-01`).
2. **R3:** filesystem/URL adapters, NLU/UI reachability for 4 direct-call-only
   capabilities, planner wired into DialogueEngine/ToolRouter, 7-scenario live
   demo.
3. **R4:** live beta-app evidence in ≥3 approved apps, then mark
   `computerUse.run` `.liveValidated`.
4. **R5:** author ADR-040, build read-first adapters, injection resistance,
   live acceptance with authorized test accounts.

## Verified historical handoff (Phases 0–25, prior program)

- `AuraAdversarialTests`: 61/61 passed; coverage gate 70.24% (≥70 ratchet).
- Chatterbox V3 model pinned and hash-verified; first offline neural Turkish WAV
  synthesized on CPU (MPS stalled); neural production speech remains fail-closed
  to Yelda until an owned/consented bounded female reference WAV is supplied.
- ADR-033 (adversarial safety) Accepted; ADR-034 (privilege separation) milestone
  1 complete.
- Boundaries to preserve: plugin code never loads in the AURA process; models
  propose typed intents/plans, policy authorizes, adapters execute, verification
  confirms, ledger records; `ContentProvenance.carryAuthority` is `true` only for
  `.systemPolicy`/`.userUtterance`.

## First safe action for the next session

1. Read `AGENTS.md`, `AURA_RUNTIME_COMPLETION/state/current-state.json`,
   `AURA_RUNTIME_COMPLETION/context/session-handoff.json`, and the newest
   `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` entry.
2. Choose the next work item:
   - **Option A — Begin R5 (active prompt):** author ADR-040
     (`docs/decisions/ADR-040-productivity-integrations-oauth.md`), then build
     read-first browser/mail/calendar/contacts adapters with least-privilege
     OAuth/Keychain, injection resistance, and offline/degraded behavior.
   - **Option B — Second-pass completion:** with the user physically present,
     close R2 live-verification, R3 remaining items, R4 live beta-app evidence,
     and R5 live acceptance.
3. State objective, assumptions, risks, and acceptance criteria in the task
   ledger before editing.
4. Do not commit, push, merge, release, deploy, or mutate TCC/application state
   unless explicitly authorized.

