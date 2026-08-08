# AURA Second-Pass Open Gaps

**Status:** Open tracking record; these items are intentionally not closed.
**Recorded:** 2026-08-08
**Authority:** `AURA_RUNTIME_COMPLETION/state/current-state.json`, the active prompt files, and the append-only program/project ledgers.

This document is the canonical handoff list for incomplete gates deferred to a
second implementation pass. An item may be marked complete only after its
own prompt gate, evidence requirement, and relevant live acceptance have
actually passed. Local unit or contract tests do not close a live gate.

## R2 — Bilingual NLU and Dialogue

Prompt: [`03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md`](prompts/03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md)

- Perform the user-present microphone/TCC Push-to-Talk verification and record
  `EV-R2-20260804-LIVE-VOICE-DEMO-01`.
- Perform the required seven-scenario Turkish/English/mixed-language live
  completion demonstration and record
  `EV-R2-20260804-LIVE-7SCENARIO-01`.
- Keep `RISK-STT-MIC-NOT-CAPTURING` open until hardware evidence passes and
  `RISK-ENGLISH-ONLY-INTENT` mitigating until the live scenario gate passes.
- Do not treat local model, text-demo, or unit/integration evidence as a
  substitute for the user-present hardware gate.

## R3 — Capability Registry and Typed Planner

Prompt: [`04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`](prompts/04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md)

- Build the remaining filesystem and URL adapters.
- Add NLU/UI reachability for the four capabilities that currently have only
  direct-call reachability.
- Wire the typed planner into `DialogueEngine`/`ToolRouter` for real
  multi-step natural-language plans.
- Run and record the required seven-scenario live completion demonstration.
- Preserve truthful registry state; unavailable capabilities remain disabled.

## R4 — Computer-Use Productization

Prompt: [`05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md`](prompts/05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md)

- Keep `computerUse.run` disabled until explicit live validation authorizes
  the approved applications.
- With the user physically present, run safe tasks in at least three approved
  beta applications with Accessibility and Screen Recording permissions.
- Capture live confirmation, emergency-stop, modal/secure-field/no-progress,
  and screen-content prompt-injection evidence.
- Verify semantic postconditions and ensure no push, merge, release, or deploy
  occurs without separate authority.
- Close `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` only after the live gate and
  its evidence bundle pass.

## R5 — Browser, Mail, Calendar, and Contacts Adapters

Prompt: [`06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`](prompts/06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md)

The deterministic first slice is recorded by
`EV-R5-20260808-READ-FIRST-ADAPTERS-01`, but R5 remains `in_progress`.

- Package and authenticate the Safari Web Extension/native messaging bridge;
  the current Swift bridge is a structured contract, not a live extension.
- Add real provider transports and explicitly authorized account/profile
  onboarding.
- Wire browser/mail/calendar/contacts through `AuraKernel`, Dialogue, and UI
  reachability while keeping the four manifests disabled until verified.
- Run live offline/degraded, permission, account ambiguity, revocation, and
  injection-acceptance tests with the user present where required.
- Keep compose/send, calendar/contact mutation, and any OAuth scope escalation
  behind separate immutable confirmation, least-privilege escalation, and
  post-action verification gates.
- Do not mark R5 complete based only on `AuraProductivityTests` or the full
  local Swift regression.

## R6 — VS Code and Coding-Agent Completion

Prompt: [`07_R6_VSCODE_AND_CODING_AGENTS.prompt.md`](prompts/07_R6_VSCODE_AND_CODING_AGENTS.prompt.md)

R6 is the active first-pass prompt. Its current implementation is recorded by
`EV-R6-20260808-POLICY-BRIDGE-01` and
`EV-R6-20260808-TYPED-ROUTES-02`; the items below are preserved for the future
second pass and do not close the active first-pass R6 gate.

- Complete and provision the real authenticated VS Code extension transport;
  the current file bridge is a bounded local contract and has no live extension
  package or shared-secret onboarding evidence.
- Connect the typed workspace/editor/diagnostics/task/test/terminal routes to a
  real extension and verify disconnect, version mismatch, stale state, dirty
  buffers, and user confirmation behavior on the live path.
- Complete the coding-agent backend gate for exact interface/version,
  authentication, model availability, sandbox/approval, cancellation,
  network, workspace, cost/time/file budgets, and actionable disabled states.
- Exercise durable read-only, review-only, and write-capable flows with
  explicit workspace resolution, isolated worktrees, progress/checkpoints,
  cancellation, restart/resume, diff/test/evidence verification, and cleanup.
- Keep the repository-wide test gate honest: the clean scratch SwiftPM run
  passed 21/21 bundles and 763/763 tests after placing the existing
  CommandLineTools `Testing.framework` and interop library in the temporary
  scratch `@rpath`; the repository runner still reports `AuraAudioTests`
  helper `exit 142` after its assertions pass. Existing safety guidance
  requires approval before any system-service intervention. Do not convert
  that unrelated audio limitation into a false R6 product claim.
- Run the required user-present live acceptance, including no unauthorized
  commit/push/merge/release/deploy, before closing R6 or accepting ADR-041.

## R7 — Wake Word, STT/TTS Routing, and Resource Governor

Prompt: [`08_R7_VOICE_WAKE_STT_TTS_RESOURCE_GOVERNOR.prompt.md`](prompts/08_R7_VOICE_WAKE_STT_TTS_RESOURCE_GOVERNOR.prompt.md)

R7's first local implementation slice is being continued in the first pass;
the unresolved gates below are recorded for the future second pass as required
by the per-prompt workflow. The slice is not a substitute for live acceptance
or ADR-042 approval.

- A real licensed/local wake-word candidate has not been selected or qualified.
  Production remains explicitly Push-to-Talk-only through
  `DisabledWakeWordDetector`; the marker detector remains test-only. FAR/FRR,
  Turkish support, noise/distance, self-trigger, energy, debounce, privacy,
  model hash/license, and soak evidence remain open.
- Apple on-device Speech capability checks and the reusable STT router are
  implemented, but there is no live Turkish/English/mixed-language WER/entity
  corpus, qualified local Whisper/equivalent fallback, or user-present
  microphone/TCC acceptance. Locale fallback is fail-closed on engine start,
  not a silently quality-switching transcript rewrite.
- Bounded incomplete-turn continuation, duplicate-result suppression, and
  TTS interruption/cancellation paths are covered locally, but live barge-in,
  acoustic echo/self-transcription, headset/device switching, sleep/wake,
  interruption, permission revocation, and helper-crash recovery remain
  unverified on release hardware.
- Resource admission is integrated for STT and neural TTS with memory-pressure,
  thermal, budget, reservation, and circuit-breaker controls. NLU/reasoning,
  screen, and coding workloads are not yet admitted through the governor, and
  measured 16 GB resident-memory/thermal/energy/long-soak evidence is open.
- Neural TTS has a bounded helper timeout and system-Yelda fallback; CPU is
  the safe default and MPS is opt-in pending qualification. Consented
  reference-voice provenance, model/hash/license verification, first-audio
  latency, CPU quality/latency, cache safety, and human listening acceptance
  remain open. System-TTS-only release remains the truthful fallback scope.
- The required Turkish/English/mixed technical/noisy/far-field evaluation
  datasets and protocols, latency/WER/entity/turn-end/TTS/barge-in/resource
  measurements, and extended soak package are not yet recorded.
- ADR-042 remains `Proposed`; its full context/alternatives/consequences and
  explicit user acceptance are not recorded. Do not mark R7 complete or move
  to R8 based on simulated tests alone.

## Current first-pass workflow boundary

Continue R7 now as the active first-pass prompt. After each prompt, append that
prompt's unresolved gates to this file for the future second pass; do not treat
the presence of an entry here as permission to skip its current first-pass
work.

## Cross-cutting constraints for the second pass

- Preserve dirty worktree changes, frozen evidence, anonymization, and
  user-owned local files.
- No commit, push, merge, release, deploy, installation, dependency/model
  download, or TCC mutation is authorized by this tracking document.
- `swift-format` and full Xcode/release validation remain host/toolchain gaps;
  do not convert their absence into a false release claim.
- Every live evidence record must identify the exact command/path, result,
  hardware/account authority, and residual limitations.

## Prompt transition approval rule

- After R7 reaches its own completion gate, perform the explicitly requested
  commit/push/merge delivery and record the exact delivery evidence.
- Stop after that R7 delivery and request the user's explicit approval before
  transitioning to R8. Do not begin R8 from an assumed or implied approval.

## Reopening rule

When a second-pass item is completed, append evidence to the relevant ledger,
update the machine state and risk register, and retain the original open-gap
wording as historical context. Do not delete or rewrite this list to make a
gate appear complete.
