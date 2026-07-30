# AURA Session Starter — Phases 0–25 Committed; Chatterbox Model Verified

> Conversation date: 30 July 2026
> Last commit: `14cb0bd` — `feat(security): ADR-034 milestone 1 — AuraAutomationHelper and AuraShellHelper sandboxed executables with IPC types, entitlements, and build/sign/verify script updates`
> Read `AGENTS.md`, `ledger/CURRENT_STATE.md`, and the newest `ledger/PROJECT_LEDGER.md` entry before changing files.

## Repository

- Path: `/Users/m_ras/Desktop/AURA-Local-Voice-Agent-Premium-Pack`
- Remote: `https://github.com/mustafaras/AURA-Local-Voice-Agent-Premium-Pack`
- Platform: macOS 27+ on Apple Silicon; Swift 6.4; CommandLineTools
- Test command: `./scripts/aura-test.sh /tmp/<unique-build-path> [bundle-filter]`
- Coverage gate: `AURA_ENABLE_COVERAGE=1 AURA_COVERAGE_MIN=70 ./scripts/aura-test.sh /tmp/<unique-build-path>`
- Do not use plain `swift test` in this environment.

## Current phase: Phases 0–25 committed and pushed; ADR-034 milestone 1 local; release gates and optional Phase 26 remain

- `HEAD == 14cb0bd`; `origin/main == a116332` (push failed with 403; see
  ledger). ADR-034 milestone 1 is committed locally only.
- Phase 24 (layered configuration governance) and Phase 25 (adversarial safety
  harness) are implemented, verified, committed, and pushed.
- ADR-034 (Accessibility/CLI privilege separation) is **In Progress**.
  Milestone 1 complete: `AuraAutomationHelper` and `AuraShellHelper` sandboxed
  helpers, shared `AuraCore` IPC types, entitlements, Info.plists, and updated
  build/sign/verify scripts. Milestone 2 (protocol boundary, in-process fallback,
  and `AuraKernel` selection) is the next safe action.
- The 20-phase implementation roadmap (`prompts/implementation/00_00` through
  `20_20_RELEASE`) is complete. The unified master prompt additionally
  defines optional phases 26–30; Phase 26 (Continuous Operation: telemetry,
  signed updates, field recovery, LTS) is the next optional implementation
  phase if the user authorizes it.
- `.vscode/launch.json` now includes launch configurations for
  `AuraPluginHost`, `AuraAutomationHelper`, and `AuraShellHelper` as part of
  ADR-034.

## Verified Phase 25 handoff

- `AuraAdversarialTests`: **61/61 tests passed**.
- `AuraAdversarialTests` added to the default `scripts/aura-test.sh` build/run
  loop.
- Coverage gate passed at **70.24%** line coverage (≥70% ratchet) on 2026-07-30.
- Deterministic prompt-injection classifier extended with a non-English
  instruction-override rule.
- New ops docs created and referenced from ADR-033 and
  `Sources/AuraCore/ResidualRiskRegistry.swift`:
  - `docs/operations/ADVERSARIAL_INCIDENT_RESPONSE.md`
  - `docs/operations/SECURITY_REVIEW_SCHEDULE.md`
- ADR-033 status: **Accepted**.

## Verified Phase 24 handoff

- Isolated `AuraConfig` / `AuraConfigTests` targets implemented.
- Five-layer configuration precedence with validation, rollback, and audit.
- Feature flags with owner, purpose, expiry, default, overrides, kill switch,
  and rollback plan.
- Opt-in, explainable local recommendations from latency, error, energy, and
  correction metrics; no raw telemetry leaves the device.
- Versioned configuration migrators reversible within a compatibility window.
- User-inspectable effective configuration, default diff, audit, and override
  revocation.
- `AuraConfigTests`: 17/17 passed.

## Boundaries to preserve

- Plugin code never loads in the AURA process.
- Every authority-bearing manifest field is signed; payload bytes are
  SHA-256-bound and rechecked before activation/execution.
- Plugin grants are scoped to the plugin actor, time-bounded, revocable, and
  never broaden empty permissions to `.any`.
- Only enabled plugins can cross the helper boundary.
- Quarantine revokes grants; uninstall removes runtime artifacts while
  append-only audit history remains.
- Marketplace sources and vendor keys are explicitly user-controlled and local.
- The v1 helper remains network-denied at the OS layer.
- Models do not execute actions; they propose typed intents or plans. The
  policy engine authorizes. Adapters execute. Verification confirms. The
  ledger records.
- ContentProvenance.carryAuthority is `true` only for `.systemPolicy` and
  `.userUtterance`; all other provenance is untrusted.

## Verified: Chatterbox V3 model

- Pinned snapshot from `ResembleAI/chatterbox` revision
  `5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18` downloaded into
  `~/Library/Application Support/AURA/chatterbox-model` (~3.5 GB, 6 files).
- `AURA_MODEL_MANIFEST.json` generated; all SHA-256 hashes verified.
- Files mode `0600`; directory mode `0700`.
- First offline neural Turkish WAV synthesized on CPU after MPS stalled at ~10%
  on this host session. WAV metadata: 24 kHz, mono, IEEE Float, 68,160 frames,
  ~8,268 ms synthesis time.

## Verified: Live neural-synthesis diagnostic benchmark

- First offline neural Turkish speech synthesized with the verified model.
- CPU fallback used after MPS sampling stalled at ~10% on this host session.
- Output: `/Users/m_ras/Library/Application Support/AURA/chatterbox-test-output/98578148-80db-4965-8402-7d0bf52762a1.wav`
- Format: RIFF WAVE, IEEE Float, mono, 24 kHz, 266 KB, 68,160 frames.
- Synthesis latency: ~8,268 ms for short text on CPU (Apple Silicon).
- Human listening and consented reference-voice gates are **deferred by user
  choice**; neural production speech remains fail-closed to Yelda until an
  owned/consented bounded female reference WAV is supplied.

## Open gates before any release claim

- ✅ Chatterbox V3 model download and hash-manifest generation.
- ✅ Live neural-synthesis diagnostic benchmark (CPU, short Turkish text).
- ⏸️ Owned/consented bounded female reference WAV and human listening test
  (deferred by user choice; no impersonation without consent).
- Screen Recording consent granted to the stable signing identity.
- Developer ID signing / notarization for third-party distribution.
- Public plugin vendor PKI / marketplace catalog.
- Real acoustic wake-word model.
- Main-process Accessibility/CLI privilege separation behind least-privilege
  helpers for OS-enforced network confinement.
- System TTS callback latency on the current host session (transient; retest if
  claiming latency budgets).

## First safe action for the next session

1. Read `AGENTS.md`, `ledger/CURRENT_STATE.md`, and the newest
   `ledger/PROJECT_LEDGER.md` entry.
2. Choose the next work item:
   - **Option A — Begin Phase 26 (Continuous Operation):** telemetry pipeline,
     signed delta updates, field diagnostics, recovery modes, LTS policy.
   - **Option B — Tackle a release gate:** Screen Recording consent, Developer
     ID signing/notarization, public plugin PKI, acoustic wake-word model, or
     main-process privilege separation.
   - **Option C — Close the deferred reference-audio/human-listening gate:**
     supply an owned/consented bounded female reference WAV and run a listened
     Turkish neural-TTS turn.
3. State objective, assumptions, risks, and acceptance criteria in the task
   ledger before editing.
4. Do not commit, push, merge, release, deploy, or mutate TCC/application state
   unless explicitly authorized.
