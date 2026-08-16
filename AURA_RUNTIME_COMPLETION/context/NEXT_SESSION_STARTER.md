# AURA Next Session Starter — SP-006 is next, pending and unopened

> Written: 2026-08-16 · Re-verified at live
> `HEAD == origin/main == 1c7d5691215e490b3f19e4df3f74d92c0529f1ac`.
> Worktree clean. Never copy a commit out of this header; run
> `git rev-parse HEAD` at session start.
>
> Authoritative state is
> `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json` and
> `AURA_RUNTIME_COMPLETION/context/session-handoff.json`.

## User-granted authority for the next session (2026-08-16)

The user stated **"tümüne açık yetki veriyorum"** (explicit full authority) for
the SP-006 session and asked that SP-006 run in a **new session** using this
starter. In scope for that session:

- Build and **launch the AURA app** locally (ad-hoc sign allowed per
  `scripts/build-app-bundle.sh` + `scripts/codesign-adhoc.sh` precedent from
  SP-002 under `EV-SP-002-20260815-PTT-MOCK-14`).
- **TCC interactions** (observe/allow Accessibility, Automation prompts).
- **Real filesystem/URL opens in a sandbox** (`/tmp/aura-sp006-*` only; nothing
  outside the sandbox).
- **Live local model inference** via the already-installed local Ollama model
  (`gemma4:latest`); cloud inference stays off (`allowCloudModels == false`).
- **Commit / push / merge** the SP-006 result to `main` (feature branch +
  no-ff merge, same pattern as SP-004 `09df409` and SP-005 `75b42ae`).

Not in scope (never authorized without a fresh explicit grant): dependency
installs, model downloads, provider accounts, telemetry, beta enrollment,
Developer-ID signing/notarization, release, deployment.

## Where the program actually stands

| | |
|---|---|
| Completed | `SP-000`, `SP-001`, `SP-002`, `SP-003`, `SP-004`, `SP-005` |
| Next eligible | **`SP-006`** — pending and **unopened** |
| Blocked | none |
| `OPEN-04` | **closed** by SP-004 (adapters) + SP-005 (NLU/reachability). SP-006 still carries `gap_ids: OPEN-04` and owns its last bullet: the **seven-scenario live completion demonstration**. |

Re-verified at `1c7d569` on 2026-08-16: **21 bundles / 870 tests / 0 failed**,
second-pass/runtime/hygiene/supply-chain validators exit 0, 38/38 governance
tests pass. Recheck these rather than trusting the numbers.

## What SP-006 must do (from the prompt's procedure)

Prompt: `AURA_RUNTIME_COMPLETION/prompts/second_pass/SP-006_R3_LIVE_CAPABILITY_SCENARIOS.prompt.md`.
Mission: run the R3 seven-scenario demonstration end to end — prove registry,
planner, policy, verification, and unavailable-capability behavior on the live
path. The seven scenarios (prompt procedure step 1):

1. observation,
2. reversible app/file/URL action,
3. confirmed mutation,
4. two-step safe plan,
5. unavailable capability (must stay visibly unavailable),
6. malformed model-plan rejection,
7. capability-health inspection.

Per scenario capture: plan fingerprint, policy decision, confirmation, adapter
result, verification, UI evidence (procedure step 2). Also test cancellation,
partial failure, rollback/compensation declaration, and no unauthorized
delivery (step 3). **Do not mark R3 complete if any capability is only
direct-call reachable or only simulated** (step 4).

Completion gate: *"The seven direct/live scenarios pass with typed evidence and
no registry bypass; otherwise keep R3 open."*

### What already exists (built by SP-004/SP-005 — do not rebuild)

- Four `.ready` capabilities (`filesystem.open_file`, `filesystem.open_folder`,
  `filesystem.reveal`, `url.open`) with real adapters
  (`AuraAutomation.FileSystemURLOpener`) and truthful manifests.
- NLU reachability: `RuleBasedUtteranceClassifier.classifyFileOrURLCommand` →
  `IntentKind.fileOpen/.fileReveal/.urlOpen` → `ToolRouter` → registry →
  `PolicyEngine` → adapter. `CapabilityPlanner` validates plans.
- SP-002's launch/TCC harness precedent (`EV-SP-002-20260815-PTT-MOCK-14`):
  build → ad-hoc sign → `open` → Accessibility-driven UI interaction. Reuse
  that procedure; the user is speech-disabled, so drive scenarios through the
  **text input / UI**, not microphone.

### Open residual risks to keep in view (none block SP-006)

`RISK-SP-004-TOCTOU-RACE`, `RISK-SP-004-HANDLER-COMPROMISE` (R10 scope);
`RISK-SP-003-LIVE-VOICE-RESIDUAL`, `RISK-STT-MIC-NOT-CAPTURING` (voice track);
`RISK-SP-003-MODEL-LATENCY` (19.8–36.1 s model turns — plan for it in live
runs); `RISK-INJECTION-COVERAGE-NON-DIALOGUE`.

## First actions in the next session

1. Read Tier 0 per `AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md`
   (10 files).
2. Read the SP-006 prompt in full, then Tier 1: the first-pass R3 prompt,
   capability manifest/health UI surfaces, the live trace contract
   (ADR-035/ADR-037), and `SECOND_PASS_OPEN_GAPS.md` OPEN-04.
3. Confirm authority (this document is the recorded grant; re-confirm with the
   user at session start).
4. Plan the seven scenarios concretely — which sandbox files/URLs, which UI
   path, which evidence artifact per scenario — then execute one scenario at a
   time, recording `EV-SP-006-*` evidence as you go.
5. Closeout: mandatory `15_SESSION_CLOSEOUT.prompt.md` even if blocked;
   update all projections; run `python3 scripts/validate_second_pass_program.py`.

## Traps carried forward (do not relearn)

- Prompt frontmatter `state: pending` appears on **every** SP prompt, including
  completed ones — the validator enforces it. Truth is in
  `SECOND_PASS_STATE.json.completed_prompts`.
- `active_prompt`/`active_state: SP-006/completed` convention means "SP-006 is
  next, SP-005 just closed" — not "SP-006 is done".
- `validate_second_pass_program.py` rejects `--ci`; the other three validators
  require it.
- Handoff JSON is schema-strict: `risks` (not `risk_ids`),
  `required_first_reads` (not `mandatory_first_read`), `tests` entries are
  objects `{name, result, evidence_id}`, `last_verified_commit` must be a full
  40-char hash, `evidence_ids` must exist in `EVIDENCE_INDEX.md`.
- `EVIDENCE_INDEX.md` rows are appended after the last existing row; never in
  table syntax at the end of a paragraph (that corruption happened once).
- `capability-matrix.json.repository_commit`, `current-state.json
  .verified_head/remote_head`, and `session-handoff.json.last_verified_commit`
  must be aligned to the same commit **in the same commit** — updating them in
  separate commits creates a chasing-HEAD loop.
- Test counts: 21 bundles / 870 tests at `1c7d569`. Any different total means a
  bundle was skipped or a test silently dropped — investigate before trusting.
- **Never use plain `swift test`.** Use
  `./scripts/aura-test.sh /tmp/<unique-path> [bundle-filter]` and capture full
  output to a file — piping through `tail` has already hidden a real failure.
- **iCloud breaks code signing**: the repo lives under an iCloud-synced
  Desktop. Copy the bundle outside the synced tree and `xattr -cr` before
  signing.
- **The installed app is not what you build**: `/Applications/AURA.app` is a
  separate copy; check its mtime before claiming the user sees current code.
- **TCC is per executable**; a grant to `AURA.app` does not extend to the
  SwiftPM test helper.
- Evidence artifacts live in `AURA_RUNTIME_COMPLETION/state/`, never `/tmp`.
- Ledgers are append-only; corrections are new entries, historical wording
  preserved.
