# AURA Session Starter — FINAL Active/Blocked; R2/R3/R4/R5/R6/R7/R8/R9/R10/R11/R12 Open

> Conversation date: 9 August 2026
> Live HEAD: `ee95b7c2e5caba9f77debf3c57e0873feb45ebf9` — `docs(delivery): record governance merge and deployment boundary`
> Read `AGENTS.md`, `AURA_RUNTIME_COMPLETION/state/current-state.json`, `AURA_RUNTIME_COMPLETION/context/session-handoff.json`, and the newest `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md` entry before changing files.

## Canonical State Notice — 2026-08-09

This starter is a **historical compatibility document**. Use
`AURA_RUNTIME_COMPLETION/state/current-state.json` and
`AURA_RUNTIME_COMPLETION/context/session-handoff.json` as the authoritative
state. Live `HEAD == origin/main == ee95b7c2e5caba9f77debf3c57e0873feb45ebf9`;
the active prompt is **FINAL**. R2/R3/R4/R5/R6/R7/R8/R9/R10/R11/R12 remain open and their second-pass
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
- **R8** `in_progress` — purpose-aware memory writes, bounded restart-safe
  preference profiles, authority-ranked context, contradiction visibility,
  provenance/budget/exclusion metadata, and local-only/remote fail-closed
  delivery are implemented; the full available regression passed 21/21 bundles
  and 782/782 tests, and governance passed. Live product demonstrations,
  production reference wiring, R9 UI, remote transport evidence, and ADR-043
  acceptance remain open.
- **R9** `in_progress` — product UI sections, truthful task/capability/model/
  privacy/recovery projections, staged onboarding, emergency/confirmation
  controls, persisted English/Turkish shell state, and deterministic UI-state
  tests are implemented locally. User-present VoiceOver/keyboard/manual layout,
  denial/revocation/restart, full control lifecycle, and live acceptance remain
  open; evidence: `EV-R9-20260808-UI-BUILD-02`,
  `EV-R9-20260808-UI-TESTS-03`, `EV-R9-20260808-GAPS-04`, and authorized
  delivery `EV-R9-20260809-DELIVERY-07`.
- **R10** `in_progress` — first-pass helper-envelope, covered network/Ollama,
  and OAuth/Keychain boundary slice delivered as merge
  `e1ecf82e2650823ddf4e4b553c0d8dda58e74911`, with evidence
  `EV-R10-20260809-BOUNDARY-SLICE-01` and `EV-R10-20260809-DELIVERY-02`.
  R10 is not complete: peer-authenticated IPC, real helper execution, universal
  network/provider/DNS enforcement, OAuth transport/revocation, injection,
  plugin trust, operations, and independent review remain open.
- **R11** `in_progress` — deterministic `development_unverified` artifact,
  reproducible ZIP, bundle inventory/SBOM, checksum-bound manifest, and
  fail-closed release-status validation are implemented under
  `EV-R11-20260809-ARTIFACT-MANIFEST-01`. Developer ID/notarization,
  clean-machine Gatekeeper, signed updater, launch-at-login, recovery,
  migration, uninstall, and observed post-change release CI remain open. The
  CI workflow now requests bounded retention of the same development artifact;
  its configuration is not run evidence.
- **R12** `in_progress` by explicit user transition request, but blocked by the
  incomplete R11 release gates. No beta cohort, telemetry, SLO, incident,
  independent sign-off, or release-candidate evidence exists; no beta or
  release readiness claim is made.
- **FINAL** `in_progress`/blocked by the incomplete R12 gate. The edit-only
  acceptance audit and blocked maintainer handoff are recorded under
  `EV-FINAL-20260809-CLOSEOUT-BLOCKED-01`; FINAL cannot mark the program
  release-candidate verified or released.

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
   `SECOND_PASS_OPEN_GAPS.md`; revisit these items from the beginning in the
   future second pass after the first pass is complete.
6. **R7:** retain the current first-pass open gates listed in
   `SECOND_PASS_OPEN_GAPS.md`; deliver R7, then stop for explicit user approval
   before R8 (already explicitly approved for this first-pass continuation).
7. **R8:** retain the current first-pass open gates listed in
   `SECOND_PASS_OPEN_GAPS.md`; complete local integration and validation, then
   R9 was then started by explicit user approval; its live gates remain open.
8. **R9:** retain the unresolved first-pass gates in
   `SECOND_PASS_OPEN_GAPS.md`; R9 was delivered but not formally closed.
9. **R10:** retain the unresolved security gates in
   `SECOND_PASS_OPEN_GAPS.md`; its first-pass slice was delivered.
10. **R11:** retain the unresolved release/operations gates in
   `SECOND_PASS_OPEN_GAPS.md`; no release or deployment claim is made.
11. **R12:** retain the unresolved beta/SLO/incident/sign-off/RC gates in
   `SECOND_PASS_OPEN_GAPS.md`; no beta or release-candidate claim is made.
12. **FINAL:** retain the unresolved acceptance/cleanup/operational-handoff
   gates in `SECOND_PASS_OPEN_GAPS.md`; no completion or release claim is made.

FINAL is active by explicit user request despite the R12 dependency blocker. Do
not infer beta enrollment, telemetry, commit/push/release/deploy authority from
this transition.

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
2. Continue **R11** by obtaining separately authorized full-Xcode, signing,
   clean-machine, updater, recovery, migration, uninstall, and observed-CI
   evidence; keep R2/R3/R4/R5/R6/R7/R8/R9/R10/R11 open where gates remain
   unresolved.
3. State objective, assumptions, risks, and acceptance criteria in the task
   ledger before editing.
4. Do not release, deploy, sign, mutate TCC/application state, install
   dependencies/models, or access secrets unless explicitly authorized.
