# AURA Session Starter — R7 Active; R2/R3/R4/R5/R6 Open for Second Pass

> Conversation date: 8 August 2026
> Live HEAD: `daf062aefc8b2eaa516769fdf27e6fc816111002` — `docs(state): start R5 adapters and write new session starter for second-pass completion`
> Read `AGENTS.md`, `AURA_RUNTIME_COMPLETION/state/current-state.json`, `AURA_RUNTIME_COMPLETION/context/session-handoff.json`, and the newest `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` entry before changing files.

## Canonical State Notice — 2026-08-08

This starter is a **historical compatibility document**. Use
`AURA_RUNTIME_COMPLETION/state/current-state.json` and
`AURA_RUNTIME_COMPLETION/context/session-handoff.json` as the authoritative
state. Live `HEAD == origin/main == daf062aefc8b2eaa516769fdf27e6fc816111002`;
the active prompt is **R7**. R2/R3/R4/R5/R6 remain open and their second-pass
gates are recorded in `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`.
The historical phase and push claims below are not current state.

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
- **R5** `in_progress` — first typed read-first adapter slice implemented and
  tested, but Safari/provider packaging, composition/UI wiring, live accounts,
  mutation/send, and live acceptance remain open.
- **R6** `in_progress` — active first-pass prompt. The policy/bridge slice is
  verified under `EV-R6-20260808-POLICY-BRIDGE-01`; the current first-pass
  typed-route continuation is source/build verified under
  `EV-R6-20260808-TYPED-ROUTES-02`. Live
  extension packaging/provisioning, complete route acceptance, backend
  auth/model readiness, durable reviewable live flows, test-runner repair, and
  live acceptance remain open. ADR-041 remains Proposed.
- **R7** `in_progress` — exact-frame audio safety, truthful Push-to-Talk-only
  wake scope, local STT routing, bounded continuation, TTS
  interruption/timeout fallback, and bounded resource admission are under
  validation. Real wake-word/live bilingual microphone/recovery/soak/neural
  quality evidence and ADR-042 approval remain open.

## Second-pass completion plan (all remaining gates)

The user directed that all remaining incomplete gates be completed in a second
pass after the first pass. The canonical list is
`AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`; each live/account item
requires the user physically present or explicit authorization:

1. **R2 live-verification:** microphone/TCC voice demo
   (`EV-R2-20260804-LIVE-VOICE-DEMO-01`) and 7-scenario demo
   (`EV-R2-20260804-LIVE-7SCENARIO-01`).
2. **R3:** filesystem/URL adapters, NLU/UI reachability for 4 direct-call-only
   capabilities, planner wired into DialogueEngine/ToolRouter, 7-scenario live
   demo.
3. **R4:** live beta-app evidence in ≥3 approved apps, then mark
   `computerUse.run` `.liveValidated`.
4. **R5:** package and wire read-first adapters, authorized account/profile
   acceptance, injection/degraded tests, and separately gated mutation/send.
5. **R6:** retain the current first-pass open gates listed in
   `SECOND_PASS_OPEN_GAPS.md`; continue R6 now, and revisit these items from
   the beginning in the future second pass after the first pass is complete.
6. **R7:** retain the current first-pass open gates listed in
   `SECOND_PASS_OPEN_GAPS.md`; deliver R7, then stop for explicit user approval
   before R8.

After R7's own delivery, commit/push/merge it, record the exact evidence, and
stop for the user's explicit approval before transitioning to R8. Do not begin
R8 from an assumed approval.

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
   `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` entry plus
   `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`.
2. Continue **R7 (active prompt)** with focused voice routing/resource
   validation and truthful live-gate recording,
   live typed workspace/task/test/agent routes, backend onboarding, and durable
   reviewable coding flows; keep R2/R3/R4/R5 open.
3. State objective, assumptions, risks, and acceptance criteria in the task
   ledger before editing.
4. Do not commit, push, merge, release, deploy, or mutate TCC/application state
   unless explicitly authorized.
