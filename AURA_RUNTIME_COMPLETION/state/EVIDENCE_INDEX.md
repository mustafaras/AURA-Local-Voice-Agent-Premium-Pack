# AURA Runtime Completion Evidence Index

Each evidence item must conform conceptually to `AURA_RUNTIME_COMPLETION/schemas/evidence-record.schema.json`. Keep entries concise; store bulky logs/artifacts separately and reference path plus hash.

## Evidence ID format

`EV-<TRACK>-<YYYYMMDD>-<SHORT-NAME>-<NN>`

Examples:

- `EV-R1-20260802-TRACE-COMPLETENESS-01`
- `EV-R7-20260812-WAKE-FAR-FRR-01`
- `EV-R11-20260901-NOTARIZED-CLEAN-INSTALL-01`

## Index

| Evidence ID | Track | Type | Commit | Verdict | Summary | Artifact / log | Limitations |
|---|---:|---|---|---|---|---|---|
| EV-BOOTSTRAP-20260802-STATE-RECONCILE-01 | BOOTSTRAP | Contract/process | `55734a7` | Passed | Removed legacy prompt dirs/symlinks (`prompts/implementation/*`, `prompts/review/*`, `prompts/runtime_completion`, `anti_amnesia/runtime_completion`, `ledger/runtime_completion`, `schemas/runtime_completion`, empty `runtime_completion/`). Migrated all internal state, manifest, context-index, and schema references to canonical `AURA_RUNTIME_COMPLETION/` paths. | `git status`, `grep` scan, multi-file edits, `AURA_RUNTIME_COMPLETION/state/current-state.json` | Before user-owned deletions were committed; commit provides immutable evidence in next entry. |
| EV-BOOTSTRAP-20260802-SCHEMA-VALIDATE-01 | BOOTSTRAP | Contract | `55734a7` (pre-commit) | Passed | Validated `state/current-state.json`, `context/session-handoff.json`, `prompts/prompt-manifest.json`, `context/context-index.json`, `state/capability-matrix.json` against `jsonschema` 4.26.0 using updated canonical schemas. | `.venv/bin/python3 .venv_validate.py` output; `.venv/` created under repo root for validator | Temporary validation script removed after execution; artifacts are session-only. Rerun validator if evidence needs reproduction. |
| EV-R0-20260802-FULL-SUITE-01 | R0 | System/contract | `20571de` | Passed | Corrected runner built targets sequentially and executed all 20 Swift Testing bundles: 665 tests passed, 0 failed bundles. `AuraAudioTests` passed 33/33 after serializing its system-TTS latency suite. | `/tmp/aura-full-after-audio.log` (SHA-256 `b16046bcf0dedb4455e73ac573956a4c25e313e2fd893061c0cd215b68e68a9c`); `/tmp/aura-full-after-audio/out/Products/Debug/*.log` | CommandLineTools Swift 6.4 on macOS 27 Apple Silicon; system audio tests use live AVSpeechSynthesizer and are bounded wall-clock checks. |
| EV-R0-20260802-APP-SMOKE-01 | R0 | System | `20571de` | Passed | Release `AURA.app` bundle and three helpers built successfully. Unsigned main executable launched from a workspace-local bundle with isolated `HOME` and remained alive for the 12-second watchdog window without crash output. | `/tmp/aura-app-build.log` (SHA-256 `a15694149869357a1dcfdd34eaa0112036909c45bd547d918f71eb801c06e615`); `/tmp/aura-runtime-launch.log` (SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`) | Startup smoke only; no signing, notarization, TCC mutation, GUI interaction, microphone, screen, or real voice turn was claimed. |
| EV-R7-20260802-SYSTEM-TTS-SERIALIZE-01 | R7 | Contract/system | `20571de` | Passed | Repeated the previously flaky `AuraAudioTests` bundle three times; all runs passed, then the serialized suite passed in the focused and full runner executions. The 2.0-second assertion was preserved. | `/tmp/aura-full-after-audio/out/Products/Debug/AuraAudioTests.log` | First failing run measured 2.074 s under concurrent system TTS load; repeated isolated runs measured 0.687–0.995 s. This reduces test flakiness but is not a real-device latency release gate. |

## Required metadata per new entry

- timestamp;
- session ID;
- exact commit and branch;
- command or manual procedure;
- OS/SDK/tool/model versions;
- exit code or objective result;
- pass/fail/blocked/inconclusive verdict;
- artifact/log path and integrity hash where applicable;
- gates supported;
- limitations, including whether fakes or simulated services were used.

## Evidence quality classes

1. **Unit/static:** proves isolated logic only.
2. **Contract:** proves schema/protocol behavior against recorded or controlled interfaces.
3. **Integration simulated:** proves production composition with fake external/system boundaries.
4. **System:** proves signed production components on a controlled machine.
5. **Live hardware:** proves real microphone/screen/app/model/service behavior.
6. **Release:** proves clean installation, signing/notarization, update, recovery, or external distribution.

Never use a lower evidence class to claim a higher operational state in `capability-matrix.json`.
