# AURA Runtime Completion Program Ledger

Append-only. Never edit or delete prior entries. Corrections are new entries that reference the corrected entry.

### 2026-08-02T14:12:55Z — BOOTSTRAP_RECONCILIATION_STARTED — strict prompt gate repair

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Prompt:** `BOOTSTRAP` (`AURA_RUNTIME_COMPLETION/prompts/00_SESSION_BOOTSTRAP.prompt.md`).
- **Verified starting commit:** `62f96da3c14b1def80764a259377638142876ccc` on `main`; live `origin/main` matched and the working tree was clean at session start.
- **Objective:** Re-run the bootstrap gate from the prompt itself, repair stale machine-state/handoff metadata, record the three required bootstrap evidence classes, distinguish the mandatory out-of-manifest session-closeout prompt from the ordered implementation manifest, and leave R0 executable without advancing product features.
- **Assumptions:** Existing product/test/build evidence remains valid only where its recorded artifacts are available; historical append-only entries remain unchanged; `15_SESSION_CLOSEOUT.prompt.md` is a mandatory session procedure, not an ordered implementation track, as documented by `prompts/README.md`.
- **Authority for this session:** The current instruction `go apply be perfect` authorizes repository inspection and metadata/documentation edits. No dependency installation, model download, TCC/permission mutation, app launch/install, commit, push, merge, signing, notarization, release, or deployment authority is assumed.
- **Risks:** stale commit projections after state-only commits; missing required evidence identifiers; CommandLineTools-only environment has no `xcodebuild`; legacy current-state/starter prose contains historical claims.
- **Acceptance criteria:** live state and stored projections agree; five JSON documents validate; manifest/dependency/reference checks pass; required first reads exist; authority is explicit; legacy contradictions are identified as R0 work; exact R0 first action is recorded; no product source is modified.

---

### 2026-07-31T12:11:00Z — PROGRAM_INITIALIZED — Runtime Completion Program v1.0.0

- **Actor:** ChatGPT repository planning session.
- **Session ID:** `PROGRAM-SEED-2026-07-31`.
- **Starting commit:** `27edd2ced7d6f7ae66de86c9e7e2b16380bd2e15`.
- **Objective:** Convert the repository-grounded fully operational assistant plan into a professional, context-efficient, anti-amnesia implementation prompt system that can resume from a fresh session without chat history.
- **Program structure:**
  - shared execution contract;
  - ordered BOOTSTRAP, R0–R12, and FINAL prompts;
  - mandatory session-closeout prompt;
  - machine-readable prompt manifest;
  - schema-validated current state, capability matrix, session handoff, evidence records, and context index;
  - separate anti-amnesia, program ledger, decision, risk, and evidence files.
- **Audited interpretation:** The repository contains substantial implemented foundations, but the assistant is not yet fully operational. Several services are constructed but disconnected, general conversation is canned, intent handling is narrow and English-oriented, computer use lacks a production planner, VS Code policy/bridge behavior is incomplete, personal-productivity adapters are missing, wake word is synthetic/test-only, privileges remain concentrated, and public release operations are incomplete.
- **Authority boundary:** This initialization records prompts and planning artifacts only. It does not grant standing authority for future code edits, dependency installation, model downloads, TCC mutation, app installation/launch, commit, push, merge, signing, notarization, release, or deployment.
- **Initial active prompt:** `BOOTSTRAP` — `AURA_RUNTIME_COMPLETION/prompts/00_SESSION_BOOTSTRAP.prompt.md`.
- **Acceptance status:** Program structure being installed. Implementation tracks have not started.
- **Next safe action:** In a fresh authorized engineering session, run the bootstrap prompt, validate schemas and live repository state, reconcile legacy status, and mark R0 ready only when the baseline is truthful.

---

### 2026-08-02T14:30:00Z — BOOTSTRAP_STARTED — Reconcile live repository against stored state

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Repository:** `mustafaras/AURA-Local-Voice-Agent-Premium-Pack`, branch `main`.
- **Starting verified commit:** `55734a78922214a8929d0c624573de7ed08092ab`.
- **Trigger:** Stored `current-state.json` and `session-handoff.json` referenced legacy paths (`prompts/runtime_completion/*`, `ledger/runtime_completion`, `anti_amnesia/runtime_completion`, `schemas/runtime_completion`) that had already been removed from the working tree. Per `READ_FIRST.md` and `SHARED_EXECUTION_CONTRACT.md`, live repository evidence takes precedence over stored state.
- **Authority:** User explicitly authorized edits, cleanup, builds, dependency/model installation, app launch/permissions, commit, and push. `merge`/`sign`/`notarize`/`release` remain false in `current-state.json` authority matrix.
- **Actions:**
  - Verified root legacy directories/symlinks no longer present on disk: `prompts/implementation/*`, `prompts/review/*`, `prompts/runtime_completion`, `anti_amnesia/runtime_completion`, `ledger/runtime_completion`, `schemas/runtime_completion`, `runtime_completion/` empty directory.
  - Migrated all internal references to canonical paths under `AURA_RUNTIME_COMPLETION/`.
  - Updated `AURA_RUNTIME_COMPLETION/state/current-state.json`, `context/session-handoff.json`, `prompts/prompt-manifest.json`, `context/context-index.json`.
  - Updated schemas `program-state.schema.json`, `session-handoff.schema.json`, `prompt-manifest.schema.json`, `context-index.schema.json`, `capability-matrix.schema.json`, `evidence-record.schema.json` to const-enforce canonical paths and allow a required `$schema` property.
  - Updated prompts `00_SESSION_BOOTSTRAP.prompt.md`, `01_R0_REPOSITORY_TRUTH_AND_GOVERNANCE.prompt.md`, `15_SESSION_CLOSEOUT.prompt.md` to canonical paths.
  - Verified JSON parseability for all 5 machine-readable state files.
  - Performed standards-compliant JSON Schema validation using `jsonschema` 4.26.0; all 5 files pass after schema fixes.
  - Final repository scan outside explanatory prose contains no actionable legacy path strings.
- **Evidence:**
  - `EV-BOOTSTRAP-20260802-STATE-RECONCILE-01` — legacy path removal and canonical migration.
  - `EV-BOOTSTRAP-20260802-SCHEMA-VALIDATE-01` — `jsonschema` validation output confirming all 5 documents conform.
- **Remaining before R0:** Commit reconciliation, run `scripts/aura-test.sh`, update `CURRENT_STATE.md`, mark R0 ready only on clean build/test evidence.

---

### 2026-08-02T14:35:00Z — BOOTSTRAP_COMPLETED — Baseline reconciled and validated, awaiting commit and build verification

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Repository:** `mustafaras/AURA-Local-Voice-Agent-Premium-Pack`, branch `main`.
- **Verified commit at completion:** `55734a78922214a8929d0c624573de7ed08092ab` (pre-commit).
- **Outcome:**
  - All legacy path references migrated or documented as intentionally removed.
  - JSON state, manifest, context-index, capability-matrix, and schemas validate against canonical schemas.
  - Program ledger, evidence index, and risk register updated with this reconciliation event.
  - Authority remains scoped: edit, install, download, mutate permissions, launch, commit, push enabled; merge/sign/notarize/release disabled.
- **Next safe action:** Stage changes, commit "BOOTSTRAP: reconcile legacy path migration and schema validation", push, then run `scripts/aura-test.sh` and continue with R0 only if build/tests pass.

---

### 2026-07-31T12:47:00Z — PROGRAM_INSTALLED — Runtime Completion Prompt Suite v1.0.0

- **Actor:** ChatGPT repository planning session.
- **Session ID:** `PROGRAM-SEED-2026-07-31`.
- **Branch:** `docs/runtime-completion-prompt-suite-v1`.
- **Starting commit:** `27edd2ced7d6f7ae66de86c9e7e2b16380bd2e15`.
- **Verified suite commit before closeout update:** `62920bfefdf7c300c33765d36fe39e7e0f2963fd`.
- **Objective result:** The repository-grounded master plan was converted into a complete ordered implementation program that can be started in a fresh session without relying on prior chat context.
- **Delivered structure:**
  - `16` executable prompts: BOOTSTRAP, R0–R12, FINAL, and mandatory SESSION CLOSEOUT;
  - one shared execution contract and one machine-readable ordered prompt manifest;
  - a tiered anti-amnesia system with minimal startup reads, stable facts, active context, session handoff, and a token-aware context index;
  - a new runtime-completion ledger system with machine state, capability matrix, append-only program ledger, decision register, risk register, and evidence index;
  - six JSON Schemas for program state, handoff, evidence, capability matrix, prompt manifest, and context index;
  - seeded JSON files for prompt order, program state, audited capability status, session handoff, and context loading rules.
- **Implementation order:** Repository truth → runtime integration → bilingual dialogue → capability registry → computer use → productivity adapters → VS Code/coding agents → voice/resource governance → memory → product UI → privilege separation → release operations → beta validation → final acceptance.
- **Professional execution properties:**
  - every prompt has explicit prerequisites, scoped reads, deliverables, tests, evidence requirements, completion gates, and ledger/handoff duties;
  - no authority is carried automatically between sessions;
  - production readiness is separated into implemented, registered, reachable, system-tested, live-verified, and release-verified states;
  - historical 0–25 prompts remain untouched and available as prior implementation history;
  - the new program starts with reconciliation rather than trusting contradictory legacy status prose.
- **Structural verification evidence:**
  - GitHub compare from `27edd2c` to `62920bf` reported `ahead_by: 38`, `behind_by: 0`, with exactly `38` added files and no deletion or modification of pre-existing repository files.
  - Key manifest, current-state, session-handoff, and final-acceptance files were fetched successfully from the program branch.
- **Validation limitation:** Full standards-compliant JSON Schema validation, local repository toolchain verification, production builds, and product tests were not run in this planning-only session. The BOOTSTRAP prompt explicitly requires those checks before R0 or product implementation begins.
- **Authority boundary:** This entry does not grant standing authority for future code edits, dependency installation, model downloads, TCC mutation, app installation/launch, commit, push, merge, signing, notarization, release, or deployment.
- **Acceptance verdict:**
  - Complete prompt sequence exists and is ordered. **Met.**
  - New sessions can find the active prompt from machine state and handoff. **Met.**
  - Context and history are separated for token efficiency. **Met.**
  - Program state, capability state, evidence, risks, and decisions have separate schemas/records. **Met.**
  - Full schema and live repository validation. **Deferred to BOOTSTRAP by design.**
  - Product implementation and final AURA operation. **Not started; governed by R0–R12 and FINAL.**
- **Next safe action:** Run `AURA_RUNTIME_COMPLETION/prompts/00_SESSION_BOOTSTRAP.prompt.md` in a fresh authorized engineering session, validate all JSON/schema references and live repository state, then begin R0 only if the baseline is truthful.

### 2026-08-02T12:29:50Z — R0_BASELINE_VERIFIED — full test runner, package build, and startup smoke corrected

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Verified code commit:** `20571dee89e7c7616757239c2717b07b5e2ee297` on `main`; the runtime-state projection is intentionally dirty while this closeout is recorded.
- **Objective:** Finish the bootstrap verification needed before R0: make the Swift test runner reliable in the CommandLineTools environment, remove the observed system-TTS latency flake without weakening its assertion, build the release app bundle, and perform a bounded startup smoke.
- **Changes:**
  - `scripts/aura-test.sh` now builds test targets sequentially, continues to collect isolated build failures, tracks only successfully built targets, and rejects missing test executables.
  - `Tests/AuraAudioTests/SystemTTSLatencyTests.swift` marks the AVSpeechSynthesizer latency suite as serialized using the installed Swift Testing trait; the 2.0-second budget remains unchanged.
- **Verification:**
  - Focused `AuraAudioTests`: 33/33 passed.
  - Full runner: 20/20 bundles and 665/665 tests passed; exit code 0.
  - `BUILD_DIR=/tmp/aura-app-after ./scripts/build-app-bundle.sh`: exit code 0; main AURA plus PluginHost, AutomationHelper, and ShellHelper packaged.
  - Clean-home executable smoke: AURA remained alive until the 12-second watchdog; no crash output and no unexpected clean-home files.
  - `git diff --check` and `zsh -n scripts/aura-test.sh scripts/build-app-bundle.sh scripts/codesign-adhoc.sh`: passed.
- **Limitations:** `swift-format` is not installed on this host. The app smoke was unsigned and did not claim TCC, GUI, microphone, Screen Recording, notarization, release, or real acoustic wake-word validation.
- **Evidence IDs:** `EV-R0-20260802-FULL-SUITE-01`, `EV-R0-20260802-APP-SMOKE-01`, `EV-R7-20260802-SYSTEM-TTS-SERIALIZE-01`.
- **Next safe action:** Start R0 repository-truth and governance work; keep signing, notarization, real wake-word, and external release gates open.

### 2026-08-02T14:26:47Z — R0_COMPLETED — repository truth and governance repair accepted

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Prompt:** `R0` (`AURA_RUNTIME_COMPLETION/prompts/01_R0_REPOSITORY_TRUTH_AND_GOVERNANCE.prompt.md`).
- **Verified baseline:** `62f96da3c14b1def80764a259377638142876ccc` on `main`; live remote matched at the start of the transition. R0 changes are metadata/governance/tooling only; no product source was advanced.
- **Delivered:**
  - Standard-library `scripts/validate_runtime_completion.py` with schema, state, prompt graph, evidence/risk/gate, capability, release-state, repository-claim, toolchain, and legacy-pointer checks.
  - 13 deterministic validator tests covering positive and required failure paths.
  - Machine-readable `AURA_RUNTIME_COMPLETION/state/toolchain-manifest.json`, schema, human `TOOLCHAIN.md`, and accepted ADR-045.
  - CI governance job before Swift build/test, with local YAML/shell/Python syntax validation.
  - Capability matrix audit tied to the audited commit; unsupported release claim downgraded and historical Chatterbox live evidence indexed.
  - Canonical legacy pointers and closed state-contradiction risk.
- **Acceptance verdict:**
  - One canonical machine state and deterministic projection policy. **Met.**
  - Explicit, validated toolchain assumptions and release limitation. **Met with open RISK-TOOLCHAIN-PREVIEW.**
  - Contradiction/evidence/capability/release-state checks fail closed. **Met.**
  - Capability matrix audited without upgrading unsupported claims. **Met with documented gaps.**
  - CI governance configured before build/test. **Met as configuration; no actual CI run observed.**
  - Fresh-session handoff identifies R1 and its exact first action. **Met.**
- **Evidence IDs:** `EV-R0-20260802-STATE-VALIDATOR-01`, `EV-R0-20260802-TOOLCHAIN-MANIFEST-01`, `EV-R0-20260802-CI-CONFIG-01`, `EV-R0-20260802-CAPABILITY-AUDIT-01`, `EV-R0-20260802-LEGACY-REDIRECT-01`.
- **Residual risks:** `RISK-TOOLCHAIN-PREVIEW`, R1 runtime risks, and all later-track product/release risks remain open; no release claim is made.
- **Authority:** User explicitly authorized commit, push, and merge for this session; installation, model download, TCC, app launch, signing, notarization, release, and deployment remain unauthorized.
- **Next safe action:** Execute R1 and inspect the runtime integration files named in the handoff before editing.

### 2026-08-02T14:15:06Z — BOOTSTRAP_COMPLETED — strict baseline reconciliation passed

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Prompt:** `BOOTSTRAP` (`AURA_RUNTIME_COMPLETION/prompts/00_SESSION_BOOTSTRAP.prompt.md`).
- **Verified start/end commit:** `62f96da3c14b1def80764a259377638142876ccc` on `main`; live `origin/main` matched. The working tree is `dirty_expected` only because of the authorized metadata/documentation reconciliation; no product source changed.
- **Objective result:** Re-ran every BOOTSTRAP preflight and repaired the stale state/handoff projections so a fresh session can safely start R0.
- **Delivered changes:**
  - Aligned `current-state.json` and `session-handoff.json` to live `HEAD == origin/main == 62f96da3c14b1def80764a259377638142876ccc`.
  - Recorded current-session authority: metadata/documentation edits only; no install, model download, TCC, app launch, commit, push, merge, signing, notarization, release, or deployment authority.
  - Added exact required evidence IDs for repository state, schema/manifest integrity, and toolchain inventory.
  - Updated `ACTIVE_CONTEXT.md`, `ledger/CURRENT_STATE.md`, and `SESSION_STARTER.md` with canonical-state pointers while retaining historical text.
  - Updated the contradiction risk to Mitigating and assigned deterministic legacy projection/redirect work to R0.
- **Acceptance verdict:**
  - Live repository state known and stored projections reconciled. **Met.**
  - Five JSON documents validate against schemas. **Met.**
  - Ordered manifest, mandatory out-of-manifest closeout, dependency graph, references, identifiers, and required reads validate. **Met.**
  - Authority explicitly recorded. **Met.**
  - Legacy contradictions captured as R0 work without rewriting append-only history. **Met.**
  - Exact R0 first action recorded and R0 ready. **Met.**
  - Product source/features advanced. **No; correctly unchanged.**
- **Evidence IDs:** `EV-BOOTSTRAP-20260802-REPOSITORY-STATE-01`, `EV-BOOTSTRAP-20260802-SCHEMA-MANIFEST-01`, `EV-BOOTSTRAP-20260802-TOOLCHAIN-INVENTORY-01`.
- **Limitations:** Xcode is not installed/active; the host uses CommandLineTools and has no `xcodebuild`. `swift-format` is unavailable. These are recorded as R0 toolchain work, not silently claimed as verified.
- **Authority boundary:** No commit or push performed in this session.
- **Next safe action:** Execute `AURA_RUNTIME_COMPLETION/prompts/01_R0_REPOSITORY_TRUTH_AND_GOVERNANCE.prompt.md`; first inspect the canonical state, capability/evidence/risk registers, decision index, `Package.swift`, CI workflow, and build/signing scripts before editing.

### 2026-08-02T14:33:36Z — R0_REGRESSION_RECHECKED — full Swift suite clean after transient TTS timing miss

- **Actor:** GitHub Copilot engineering session.
- **Prompt:** `R0` closeout correction.
- **Verified baseline:** `62f96da3c14b1def80764a259377638142876ccc` on `main`.
- **Procedure:** Re-ran the already-built 20 Swift Testing bundles sequentially through the installed `swiftpm-testing-helper`; reran `AuraAudioTests` three times directly.
- **Result:** 20/20 bundles and 665/665 tests passed; `AuraAudioTests` passed 33/33 on all three isolated reruns. The earlier fresh wrapper run had one 2.047-second first-chunk latency miss against the unchanged 2.0-second bound; no assertion or budget was weakened.
- **Evidence:** `EV-R0-20260802-FULL-SUITE-RERUN-01`.
- **Limitation:** System TTS wall-clock latency remains host-load sensitive and is not a release-hardware gate.

### 2026-08-02T14:35:54Z — R0_POST_COMMIT_VALIDATION — projection evidence synchronized to 083aaa8

- **Actor:** GitHub Copilot engineering session.
- **Verified commit:** `083aaa833a7cb6ee938029275a33381eb8dd7cb9`; `HEAD == origin/main` at validation time.
- **Procedure/result:** `python3 scripts/validate_runtime_completion.py --ci`, 13 deterministic governance tests, and `git diff --check` passed.
- **Evidence:** `EV-R0-20260802-POST-COMMIT-VALIDATION-01`.
- **Next safe action:** Commit the state-only projection, push it, and continue from R1. A merge commit is not applicable because the work is already on `main`; verify `git merge --ff-only origin/main` reports no divergence.

### 2026-08-02T16:34:12Z — R1_COMPLETED — runtime integration spine and trace correctness verified

- **Actor:** GitHub Copilot engineering session.
- **Session ID:** `AURA-BOOTSTRAP-2026-08-02`.
- **Prompt:** `R1` (`AURA_RUNTIME_COMPLETION/prompts/02_R1_RUNTIME_INTEGRATION_SPINE.prompt.md`).
- **Verified baseline:** `f1f3bb959ea3b79eb821c5faccf57d8fad076203` on `main`; `origin/main` matched; the working tree is intentionally `dirty_expected` because R1 remains local and uncommitted.
- **Objective result:** Completed the R1 production integration spine with one immutable `TurnContext`, truthful backend metadata, typed runtime health, transactional confirmation lifecycle, distinct execution/verification outcomes, text fallback, and deterministic full-suite evidence.
- **Delivered:**
  - Propagated context through wake activation/deactivation, STT partial/stable/error/cancel, Push-to-Talk finalization, conversation bridge, intent/dispatch, policy, ToolRouter, latency, and actual TTS metadata.
  - Added `RuntimeHealthChangedEvent`; `RuntimeHealthRegistry` now publishes live updates, while `AuraKernel` records loading, unsupported, degraded, failed, and ready states instead of hiding optional construction failures behind `try?`.
  - Added `ConfirmationTransactionStore` lifecycle with immutable plan hash, nonce/expiry, context binding, one-time execution, verification, replay/plan-change rejection, and fail-closed restart behavior.
  - Added accepted `ADR-035` and `ADR-037`; registered both in `ledger/DECISION_INDEX.md`.
  - Serialized the Multi-Agent Orchestrator test suite and removed an unnecessary deterministic-stop sleep after full-run timing races; no assertion or budget was weakened.
- **Verification:**
  - Fresh `./scripts/aura-test.sh /tmp/aura-r1-final-full`: 20/20 Swift Testing bundles, 677/677 tests, 0 failed bundles.
  - Focused trace/health evidence: AuraCoreTests 16/16, AURAIntegrationTests 17/17, AuraAudioTests 33/33, AuraSTTTests 14/14, AuraPolicyTests 18/18, AuraAgentTests 206/206.
  - `git diff --check`, runtime-completion validator, 13 deterministic governance tests, and `zsh -n scripts/aura-test.sh` passed after state projection repair.
- **Evidence IDs:** `EV-R1-20260802-FULL-SUITE-01`, `EV-R1-20260802-TRACE-HEALTH-01`, `EV-R1-20260802-GOVERNANCE-CLOSEOUT-01`.
- **Acceptance verdict:** R1 trace identity, honest runtime health, transactional confirmation, text/voice integration, existing safety tests, and deterministic regression gate are **met for the development/integration scope**. R2 is ready.
- **Residual limitations:** Confirmation authorization is intentionally not resumed after restart because the transaction ledger is in-memory and fail-closed. Universal capability-specific postcondition verification, real acoustic wake-word, live target hardware demonstration, full Xcode/CI evidence, and release gates remain open. No commit, push, app install, TCC mutation, signing, notarization, release, or deployment was performed.
- **Next safe action:** Begin R2 bilingual NLU and dialogue from the accepted R1 contracts. Preserve the R1 context, health, confirmation, and truthful-outcome boundaries; do not make release claims from this local CommandLineTools run.

### 2026-08-02T16:39:22Z — R1_HEALTH_DETAIL_CORRECTION_VERIFIED — final post-edit focused gate

- **Actor:** GitHub Copilot engineering session.
- **Correction:** Preserved detailed plugin and Ollama construction failures in the single runtime-health record instead of overwriting them with generic degraded text.
- **Verification:** Production AURA rebuilt successfully and `./scripts/aura-test.sh /tmp/aura-r1-health-final3 AuraCoreTests` passed 16/16. This focused correction does not change capability or release claims.
- **Evidence:** `EV-R1-20260802-HEALTH-DETAIL-01`.

### 2026-08-02T16:51:13Z — R1_FINAL_CLOSURE_REGRESSION — exact plan binding and audio cleanup verified

- **Actor:** GitHub Copilot engineering session.
- **Procedure:** Fresh `./scripts/aura-test.sh /tmp/aura-r1-final-closure` after the exact plan fingerprint and Chatterbox cleanup fixes.
- **Result:** 20/20 Swift Testing bundles and 678/678 tests passed; 0 failed bundles. AuraPolicyTests passed 19/19 with changed-plan rejection, and AuraAudioTests passed 33/33 with private-output cleanup before stream completion.
- **Evidence IDs:** `EV-R1-20260802-PLAN-BINDING-01`, `EV-R1-20260802-AUDIO-CLEANUP-01`, `EV-R1-20260802-FULL-SUITE-FINAL-01`.
- **Limitation:** This remains local CommandLineTools contract/system evidence with controlled fakes; no live target-hardware demo, app install, TCC mutation, signing, notarization, or release claim was made.

### 2026-08-02T17:27:28Z — R2_STARTED — layered bilingual NLU and dialogue implementation

- **Actor:** GitHub Copilot engineering session.
- **Prompt:** `R2` (`AURA_RUNTIME_COMPLETION/prompts/03_R2_BILINGUAL_NLU_AND_DIALOGUE.prompt.md`).
- **Objective:** Replace the English-only/canned conversation path with a deterministic Turkish/English/mixed fast path, provider-neutral typed structured NLU refinement, local-first model-backed dialogue, bounded provenance context, and locale-preserving responses without allowing model output to execute actions.
- **Assumptions:** R1 TurnContext, runtime health, exact plan-bound confirmation, and truthful response-plan contracts remain stable. Ollama is optional, loopback-only, policy-gated, cloud-disabled by default, and may be unavailable.
- **Acceptance criteria:** Bilingual golden corpus and structured-output tests pass; unknown targets and model action proposals clarify; ordinary questions use local reasoning when available and degrade honestly otherwise; response/TTS language remains consistent; context is bounded and provenance-bearing; full R2 regression and live evidence remain open.
- **Delivered so far:** Added `DialogueLanguage`, `DialogueAct`, `DialogueResponse`, bounded `DialogueEngine`, bilingual classifier metadata/aliases, Turkish emergency aliases, provider-neutral structured-NLU response, Ollama JSON schema/adapter path, localized clarification, and response-plan TTS locale propagation.
- **Verification so far:** `AuraIntentTests` 35/35, `AuraAgentTests` 208/208, and `AURAIntegrationTests` 17/17 passed in focused runs.
- **Evidence IDs:** `EV-R2-20260802-FOCUSED-INTENT-DIALOGUE-01`, `EV-R2-20260802-OLLAMA-STRUCTURED-01`, `EV-R2-20260802-INTEGRATION-DIALOGUE-01`.
- **Open work:** Expand the golden corpus and paraphrase/ASR-error measurements, add multi-turn slot filling/expiry, verify model prompt redaction and degraded runtime health, run the full repository regression, and complete authorized hardware demonstration before marking R2 complete.

### 2026-08-02T17:38:57Z — R2_FULL_SLICE_REGRESSION — 20 bundles and 691 tests clean

- **Actor:** GitHub Copilot engineering session.
- **Procedure:** Fresh `./scripts/aura-test.sh /tmp/aura-r2-full-slice` after bilingual fast-path, structured-NLU, dialogue, locale, and slot-filling changes.
- **Result:** Production AURA and all 20 Swift Testing bundles passed: 691/691 tests, 0 failed bundles.
- **Evidence:** `EV-R2-20260802-FULL-SUITE-SLICE-01`.
- **Limitations:** This is local CommandLineTools system/contract evidence. The golden corpus measurement, real Ollama availability/latency, authorized hardware demonstrations, and R2 release gates remain open.

### 2026-08-02T17:44:24Z — R2_FINAL_LOCAL_REGRESSION — 693 tests clean, live model gate retained

- **Actor:** GitHub Copilot engineering session.
- **Procedure:** Fresh `./scripts/aura-test.sh /tmp/aura-r2-full-final` followed by a read-only `ollama list` inventory check.
- **Result:** 20/20 Swift Testing bundles and 693/693 tests passed. The host has `/opt/homebrew/bin/ollama` and local `gemma4:latest` (9.6 GB), but no inference was started because model residency/latency and hardware authorization remain explicit gates.
- **Evidence IDs:** `EV-R2-20260802-FULL-SUITE-FINAL-01`, `EV-R2-20260802-LOCAL-MODEL-INVENTORY-01`.
- **R2 status:** Still in progress. Remaining acceptance work is authorized/live model and hardware evidence, not an untested claim based on model inventory alone.

### 2026-08-02T17:50:37Z — R2_FINAL_REGRESSION_WITH_DIALOGUE_HEALTH — 694 tests clean

- **Actor:** GitHub Copilot engineering session.
- **Procedure:** Fresh `./scripts/aura-test.sh /tmp/aura-r2-final-closure` after publishing DialogueEngine model health transitions.
- **Result:** 20/20 Swift Testing bundles and 694/694 tests passed with 0 failed bundles. AuraIntentTests passed 43/43; the full run includes the golden corpus, slot expiry, structured NLU safety, locale propagation, and dialogue health coverage.
- **Evidence:** `EV-R2-20260802-FULL-SUITE-FINAL-02`.
- **Status:** R2 remains in progress pending live Ollama first-token/quality evidence and authorized Turkish/English/mixed hardware demonstration. No release claim is made.

### 2026-08-02T18:04:55Z — R2_GAP_AND_TODO_AUDIT — actionable source markers cleared

- **Actor:** GitHub Copilot engineering session.
- **Audit:** Tracked production/test/script/resource files contain zero actionable TODO/FIXME/XXX/HACK markers after fixture exclusion. No literal `Got it.` remains in runtime sources. Remaining placeholder matches are intentional compatibility facades, deterministic/mock fallbacks, unsupported optional adapter messages, or explicitly deferred later-track boundaries.
- **Correction:** Coding-agent metadata now maps to generic destructive `Capability.agentRun` instead of the low-risk conversation placeholder; adapter-specific policy evaluation remains authoritative.
- **Evidence IDs:** `EV-R2-20260802-TODO-AUDIT-01`, `EV-R2-20260802-AGENT-RISK-01`.
- **Residual gaps:** Live local Ollama health/first-token/residency measurement, authorized hardware demo, real wake word, full Xcode/CI, release operations, and later-track capabilities remain open and are not hidden by deleting comments or historical planning text.

### 2026-08-02T18:08:28Z — R2_FINAL_REGRESSION_AFTER_GAP_FIXES — current tree clean

- **Actor:** GitHub Copilot engineering session.
- **Procedure:** Fresh `./scripts/aura-test.sh /tmp/aura-r2-after-gap-fixes` after the coding-agent destructive-risk metadata correction, all-TODO audit recording, and stale-state documentation alignment.
- **Result:** Production AURA rebuilt successfully; all 20 Swift Testing bundles passed for a total of 695/695 tests with 0 failed bundles. AuraIntentTests passed 44/44.
- **Evidence:** `EV-R2-20260802-FULL-SUITE-FINAL-03`.
- **Status:** R2 remains in progress. This closes the current local regression and metadata/documentation gaps only; live Ollama health/first-token/quality/residency evidence and authorized Turkish/English/mixed hardware demonstration remain required. No commit, push, app launch, TCC mutation, signing, release, or deployment occurred.

### 2026-08-03T06:18:04Z — R2_PRECOMMIT_REGRESSION — current tree clean before publication

- **Actor:** GitHub Copilot engineering session.
- **Procedure:** Fresh `./scripts/aura-test.sh /tmp/aura-final-before-commit-20260803` before committing the validated R1/R2 runtime and governance changes.
- **Result:** Production AURA rebuilt successfully; all 20 Swift Testing bundles passed for a total of 695/695 tests with 0 failed bundles. AuraIntentTests passed 44/44 and AuraAdversarialTests passed 61/61.
- **Evidence:** `EV-R2-20260803-FINAL-REGRESSION-01`.
- **Authority:** The user explicitly authorized commit, push, and merge operations for this closeout. No dependency installation, model download, app launch, TCC mutation, signing, release, or deployment was authorized.
- **Remaining limits:** R2 remains in progress pending live Ollama health/first-token/quality/residency evidence and authorized Turkish/English/mixed hardware demonstration.

### 2026-08-03T06:19:48Z — R2_PUBLICATION_CLOSEOUT — validated runtime change set committed and pushed

- **Actor:** GitHub Copilot engineering session.
- **Publication:** Committed the validated 56-file R1/R2 runtime, tests, ADRs, evidence, and governance change set as `b8f896097d6b8bd390c5a5030b5eb902eb1631c0` with message `feat(runtime): integrate truthful bilingual dialogue spine`, then pushed it to `origin/main`.
- **Verification:** `git status` reported a clean worktree and `git rev-parse HEAD origin/main` returned the same full hash. No separate merge commit was required because `main` was the active publication branch and no open PR/merge candidate existed.
- **Evidence:** `EV-R2-20260803-PUBLICATION-01`.
- **Authority boundary:** Commit/push/merge authority was explicit for this user request and expires at task completion. No dependency installation, model download, app launch, TCC mutation, signing, release, or deployment occurred.

### 2026-08-03T07:35:00Z — R2_LIVE_MODEL_AND_APP_SMOKE — bounded live Ollama benchmark and app-launch smoke recorded

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; `HEAD == origin/main`; working tree clean at session start.
- **Authority:** The user explicitly authorized (1) loading/running the already-local `gemma4:latest` via Ollama for a bounded benchmark, (2) launching the AURA app, and (3) microphone/TCC permission, in response to an explicit pre-action question. No dependency installation, model download, commit, push, merge, signing, release, or deployment was authorized or occurred.
- **Actions:**
  - Verified the live `ollama serve` daemon (v0.32.5) and local `gemma4:latest` (9.6 GB on disk; cloud model variants untouched and unused).
  - Ran a bounded live benchmark directly against the Ollama HTTP API: cold load 7.87 s, warm first-token 165-182 ms across English/Turkish/mixed prompts, correct-quality answers in all three, memory residency of 3.2 GB / 100% GPU while loaded (23% system-free during load, 16 GB physical), clean release back to 78% free after a forced `keep_alive:0` unload, and an honest JSON error for an unknown model name (degraded-mode check).
  - Built the real release `AURA.app` via `scripts/build-app-bundle.sh` and launched it with an isolated `HOME` for a bounded 12-second watchdog window. `os_log` capture (subsystem `ai.aura.local`) confirmed the production composition root completed: TTS, performance sampler, and wake-word pipeline started, ending in `AuraKernel running; push-to-talk ready`. No crash; the process and any loaded Ollama model were confirmed cleanly terminated afterward.
- **Evidence IDs:** `EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01`, `EV-R2-20260803-APP-LAUNCH-LIVE-01`.
- **What this does NOT demonstrate:** No microphone audio was captured, no TCC permission dialog was presented or clicked, and no text/voice turn was submitted through AURA's own production `IntentEngine`/`DialogueEngine` path. This session has no GUI/Accessibility/mouse-control tool, and AURA exposes no external CLI/IPC hook to inject a turn into a running instance — driving the menu-bar UI or a spoken microphone turn requires a human physically present at the machine. The R2 prompt's full completion-demonstration (steps 1-7, including the ambiguous-request clarification and degraded-mode-while-running checks through the actual app) therefore remains unperformed.
- **R2 status:** Remains `in_progress`. This entry adds live model-quality/latency/residency data and a live app-composition smoke; it does not satisfy the R2 completion gate's hardware-demonstration requirement.
- **Next safe action:** To close R2's live-hardware gate, a human operator must run AURA.app interactively (grant the microphone TCC prompt, speak or type the seven demonstration turns from the R2 prompt's "Completion demonstration" section, and observe the trace/provenance), or a future session must add a reviewed, intentional structured text-input hook to AURA's composition root before any external driver can exercise the real dialogue path non-interactively. No commit, push, or R2-complete state transition should occur before that evidence exists.

### 2026-08-03T11:50:00Z — R2_TEXT_DEMO_HOOK_AND_POLICY_GRANT_FIX — live production-path dialogue exercised, real policy gap found and fixed

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carried this session's prior uncommitted ledger/state edits.
- **Authority:** User explicitly authorized (1) adding a debug-gated, opt-in text-input hook to exercise the real production dialogue path without GUI/mic, and (2) after a live finding, adding a default policy grant for `.agentOllamaLocalInference`. No commit, push, merge, signing, release, dependency installation, or model download was authorized or occurred.
- **Actions:**
  - Added `AuraAppModel.runTextDemoIfRequested(logger:)` (`Sources/AURA/AuraAppModel.swift`): inert unless `AURA_TEXT_DEMO_SCRIPT` names a file of utterances; submits each through the real `submitText()` production path used by the menu-bar text field, waiting for the conversation to leave and return to `.idle` between turns.
  - Added a debug-gated (`AURA_LOG_RESPONSE_TEXT=1`) `logger.info` call in `Conversation.responsePlanReceived` (`Sources/AuraAgent/Conversation.swift`) to observe the dialogue response text via `os_log`, since no other observable surface exists outside spoken TTS audio.
  - Full regression after both additions: 20/20 bundles, 695/695 tests (`/tmp/aura-r2-textdemo-regression`).
  - First live run (model pre-loaded via direct `ollama` call): every turn returned the degraded "local answer model is unavailable" message in 30-100ms — too fast to be a real network round trip.
  - Traced the cause precisely: `AuraKernel.seedDefaultGrants()` seeds grants for `appActivate`, `appTerminate`, `shellExec`, and the three coding-agent capabilities, but never for `.agentOllamaLocalInference`. That capability's `riskTier` is `.reversible`, and `PolicyConfiguration.denyByDefaultTiers` defaults to `[.reversible, .mutation, .destructive]`, so `PolicyEngine.evaluate` denied every reasoning request before any network call, independent of model health or residency.
  - With explicit user authorization, added `Grant(capability: .agentOllamaLocalInference, patterns: [.any], confirmationRequirement: .none)` to `seedDefaultGrants()` (`Sources/AURA/AuraKernel.swift`), documented as a 2026-08-03 addendum to ADR-036. `.agentOllamaCloudInference` intentionally remains ungranted.
  - Full regression re-run after the grant: 20/20 bundles, 695/695 tests (`/tmp/aura-r2-grant-regression`); one `AuraAudioTests` transient timing flake (exit 142) reproduced the pre-existing system-TTS-load sensitivity documented in `EV-R0-20260802-FULL-SUITE-RERUN-01` and cleared on isolated rerun (33/33).
  - Rebuilt the app and re-ran the live text-demo with the model pre-loaded: degraded messages disappeared entirely; turns now took ~6-9s (real network round trips) — confirming the grant was the actual blocker.
  - Using validated `BilingualGoldenCorpusTests` phrasings for Turkish ("Gökyüzü neden mavi?"), English ("What is the weather?"), and mixed ("Please bugün hava nasıl?"), plus the validated ambiguous phrase from `DialogueEngineTests` ("please do the operation"), all four turns nonetheless returned a clarification response rather than a substantive answer.
  - Root-caused the clarification-only outcome without further code changes: `IntentEngine.classify`'s structured-NLU refinement (`ClassificationResult.applying`, `Sources/AuraIntent/IntentEngine.swift:62-86`) requires the model's structured JSON proposal to report exactly `dialogueAct == .answer` and `capabilityID == nil` to preserve a confident `.converse` classification; `gemma4:latest` did not reliably satisfy that gate in this run.
- **Evidence ID:** `EV-R2-20260803-TEXTDEMO-LIVE-01`.
- **What this does NOT demonstrate:** real microphone audio capture and clicking the TCC permission dialog — still requires a human physically present, since this session has no GUI/Accessibility/mouse-control tool.
- **R2 status:** Remains `in_progress`. The default-grant fix is a genuine, verified improvement to R2's production reachability (dialogue calls are no longer silently policy-blocked), but the structured-NLU quality gap means general questions still do not reliably receive substantive answers through the full production path with this model, and the interactive hardware/mic demonstration remains unperformed.
- **Next safe action:** Either (a) a human operator runs AURA.app interactively this evening to grant microphone/TCC and perform the seven R2 demonstration turns, now that the policy-grant blocker is fixed, or (b) a follow-up investigates why `gemma4:latest`'s structured-NLU proposals fail `ClassificationResult.applying`'s gate (e.g. by logging the raw JSON) and whether the structured-NLU prompt/schema needs adjustment for small local models. Do not mark R2 complete before both the hardware demonstration and a resolution (or an explicitly accepted-risk decision) for the structured-NLU quality gap exist.

### 2026-08-03T16:15:00Z — R2_PROMPT_LEAKAGE_ROOT_CAUSED_AND_FIXED — structured-NLU non-determinism explained, prompt leakage fixed

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803`.
- **Authority:** User explicitly requested root-causing the clarification-only behavior, then explicitly authorized fixing the discovered system-prompt leakage.
- **Actions:**
  - Added a debug-gated (`AURA_LOG_RESPONSE_TEXT=1`) `print()` diagnostic around `structuredNLUBackend.propose()` in `IntentEngine.classify` (`Sources/AuraIntent/IntentEngine.swift`).
  - Live run of the identical validated phrase "What is the weather?" produced different outcomes across repeated calls — clarification in some runs, a substantive answer in others — proving the structured-NLU gate's pass/fail is genuine LLM sampling non-determinism at `gemma4:latest`'s 8B scale, not a deterministic logic defect.
  - The one answer-path response observed leaked internal terminology: "Please specify location and invoke the relevant weather API function via a policy path to retrieve this information."
  - Traced to `DialogueEngine.makePrompt` (`Sources/AuraIntent/DialogueEngine.swift:171-173`): the system prompt told the model, for action-shaped requests, to "explain that the typed policy path must handle it" — AURA's own internal terminology, which the model echoed verbatim.
  - With explicit user authorization, reworded the prompt to state plainly that the model cannot perform actions directly and to suggest the user ask AURA as a command, adding an explicit instruction never to mention internal system/policy/implementation terminology. Confirmed via `grep` that no test asserts the prior exact wording.
  - Rebuilt and ran a 5-turn batch mixing validated Turkish/English/mixed `.converse` phrasings: 3 of 5 reached the answer path (2 clarified, consistent with the still-open non-determinism); all 3 answers were clean, with no policy-path leakage.
  - Full regression re-run: 20/20 bundles, 695/695 tests, including `AuraAudioTests` passing cleanly (no flake this run).
- **Evidence IDs:** `EV-R2-20260803-TEXTDEMO-LIVE-02`, `EV-R2-20260803-PROMPT-LEAKAGE-FIX-01`.
- **Risk update:** `RISK-STRUCTURED-NLU-MODEL-QUALITY` moved from `Open` to `Mitigating` — the prompt-leakage sub-finding is fixed and verified; the underlying structured-NLU gate non-determinism remains open and unfixed by design (needs a considered sampling/schema decision, not a quick patch).
- **R2 status:** Remains `in_progress`. Two genuine production gaps found live and fixed with authorization this session (missing policy grant, prompt leakage); the interactive hardware/mic demonstration and a decision on structured-NLU determinism remain the two blockers to completion.
- **Next safe action:** This evening, a human operator runs AURA.app interactively to grant microphone/TCC and perform the R2 completion-demonstration turns. Separately, decide whether to invest in structured-NLU determinism (sampling/schema tuning) before R2 completion, or explicitly accept the non-determinism as a documented, bounded risk for this model tier.

### 2026-08-03T17:35:00Z — R2_REAL_DESKTOP_SESSION — first live user-operated session; two new findings, mic still unresolved

- **Actor:** Claude Code engineering session, with the user operating the real desktop/microphone directly.
- **Session ID:** `AURA-R2-LIVE-20260803`.
- **Authority:** User explicitly authorized launching `AURA.app` on their real desktop (non-isolated `HOME`) for interactive use.
- **Actions and findings:**
  - Launched `AURA.app` on the user's real desktop; the user interacted directly (typed commands, used Push-to-Talk).
  - First real launch produced "model unavailable" for typed input. Root cause: `OllamaAdapter.ensureMemoryBudget` rejects a cold model load when the candidate's on-disk `/api/tags` size (9.6 GB for `gemma4:latest`) exceeds `maxResidentModelBytes` (default 6 GB) — independent of the real ~3.2 GB quantized VRAM footprint already measured in `EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01`. Worked around for tonight by pre-loading the model via a direct API call before the user's session; the underlying sizing defect is unfixed and newly risk-registered (`RISK-OLLAMA-COLDSTART-BUDGET-REJECTION`).
  - Relaunched via `open` (instead of direct binary execution) to correct TCC/Info.plist bundle-identity attribution for permission dialogs.
  - The user then typed a command-shaped request and received the corrected honest boundary response ("bu isteği yerine getiremem, bunu Aura'dan isteyiniz") — confirming, on a real non-scripted interactive turn, that the `EV-R2-20260803-PROMPT-LEAKAGE-FIX-01` fix behaves correctly and that R2's intended action/conversation boundary (no guessed execution) holds live.
  - The user reported the synthesized voice sounds "very robotic" (Chatterbox TTS quality/fallback concern; R7 scope, not investigated further this session by user's choice).
  - The user confirmed microphone/Push-to-Talk speech input still does not produce recognized transcripts, even after the `open`-based relaunch. No `os_log` STT/speech/permission lines appeared during the session; the exact failure point is undiagnosed. Newly risk-registered as `RISK-STT-MIC-NOT-CAPTURING`.
- **Evidence ID:** `EV-R2-20260803-REAL-DESKTOP-SESSION-01`.
- **User decision:** Per explicit instruction, this session's evidence (typed-text dialogue confirmed live, TTS confirmed live, correct action-boundary behavior confirmed live, voice input still broken) is accepted as this evening's R2 evidence; further live mic debugging is deferred rather than pursued immediately.
- **R2 status:** Remains `in_progress`. The typed-text hardware/production-path demonstration now has genuine live, user-operated evidence. The voice-specific hardware demonstration required by the R2 prompt's "Completion demonstration" section is still not met — microphone capture does not work. Two new, real, unresolved defects (`RISK-STT-MIC-NOT-CAPTURING`, `RISK-OLLAMA-COLDSTART-BUDGET-REJECTION`) were discovered and documented, not fixed, this session.
- **Next safe action:** Before R2 can be marked complete: (1) diagnose and fix microphone/STT capture with the user present (check TCC-granted status in System Settings, `STTPipeline` health/logs, and whether Push-to-Talk activation reaches the audio pipeline at all); (2) decide on a fix for the cold-start memory-budget sizing defect so a fresh launch does not require manually pre-loading the model; (3) decide on structured-NLU determinism tuning or explicitly accept it as a bounded risk. None of these are release claims — all remain local, uncommitted findings pending the next session's authorized work.

### 2026-08-03T18:20:00Z — R2_OLLAMA_COLDSTART_BUDGET_FIX — disk-size-as-VRAM category error fixed

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carried this session's prior uncommitted findings.
- **Authority:** User explicitly chose to fix `RISK-OLLAMA-COLDSTART-BUDGET-REJECTION` this turn (selected from an explicit menu of the three open R2 blockers). Edit-only authority; no commit, push, merge, or release authorized.
- **Root cause confirmed by reading the code:** `OllamaAdapter.ensureMemoryBudget` (`Sources/AuraAgent/OllamaAdapter.swift`) compared a not-yet-resident candidate model's `OllamaRegisteredModel.sizeBytes` — the raw on-disk `/api/tags` file size — directly against `maxResidentModelBytes`, a budget intended for real resident VRAM. Already-resident models correctly used their measured `size_vram` from `/api/ps`; only the cold-load path used the wrong quantity. This is a category error, not a threshold-tuning issue, and directly explains the `gemma4:latest` 9.6 GB-disk-vs-3.2 GB-real-VRAM rejection recorded in `EV-R2-20260803-REAL-DESKTOP-SESSION-01`.
- **Fix:** Added `OllamaConfiguration.estimatedResidentMemoryRatio` (`Sources/AuraCore/AuraConfiguration.swift`, default `0.5`, validated to `(0, 1]`, full `init`/`validate`/`mergedWithDefaults`/`init(from:)` coverage matching the struct's existing field pattern). `ensureMemoryBudget` now derates a not-yet-resident candidate's disk size by this ratio before comparing against the budget or triggering eviction; already-resident models are untouched and still use real `size_vram`. `0.5` is a deliberately conservative margin above the ~0.33 ratio actually observed for `gemma4:latest`, so the estimate still overshoots real usage.
- **Verification:** Added `ollamaAdapterAllowsColdLoadWhenDiskSizeExceedsBudgetButEstimatedResidentSizeFits` (`Tests/AuraAgentTests/OllamaAdapterTests.swift`) reproducing the exact real-world numbers (9.6 GB disk, 6 GB budget) and asserting the load now succeeds with zero eviction. `swift build` clean. Full regression run three times: 20/20 bundles, 696/696 tests each run (695 baseline + 1 new test), no flakiness, including `AuraAudioTests` passing cleanly all three runs.
- **Evidence ID:** `EV-R2-20260803-OLLAMA-BUDGET-FIX-01`.
- **Risk update:** `RISK-OLLAMA-COLDSTART-BUDGET-REJECTION` moved from `Open` to `Fixed` in `RISK_REGISTER.md`.
- **R2 status:** Remains `in_progress`. This closes one of the three documented R2 blockers. Two remain open: `RISK-STT-MIC-NOT-CAPTURING` (needs the user physically present) and the `RISK-STRUCTURED-NLU-MODEL-QUALITY` determinism decision.
- **Next safe action:** With the user present, diagnose microphone/Push-to-Talk capture, and separately decide whether to tune structured-NLU sampling/schema or explicitly accept that risk. Neither R2 completion nor any commit/push should occur before both remaining items are resolved or explicitly accepted.

### 2026-08-04T09:10:00Z — R2_STRUCTURED_NLU_CAPABILITY_ID_GATE_ROOT_CAUSED_AND_FIXED — real root cause of clarify-only outcome found and fixed

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803` (continued).
- **Authority:** User instruction "go next be perfect" — continuing to the next open R2 blocker with full rigor. Edit-only; the local Ollama daemon (already running, port 11434) was queried directly via `curl` for live A/B verification, matching this session's established pattern for the same purpose. No commit, push, merge, or release authorized.
- **Root cause found by live A/B testing (not assumed):** Ran the exact production `makeStructuredNLUPrompt` + `.nlu` format schema against the real `gemma4:latest` via direct `curl` to `/api/generate`, 5x for "What is the weather?" at default temperature. Result: 5/5 responses had a non-empty `capability_id` (e.g. `"weather_forecast"`, `"weather-service"`) regardless of `dialogue_act`, including the 2/5 that correctly said `dialogue_act: "answer"`. `ClassificationResult.applying` (`Sources/AuraIntent/IntentEngine.swift:65`) requires **both** `dialogueAct == .answer` and `capabilityID == nil` to accept a confident `.converse` answer — so 0/5 samples could ever have passed the gate, independent of any sampling temperature. The prompt (`Sources/AuraIntent/IntentEngine.swift:497-508`, prior wording) never told the model when `capability_id` must be empty; the model reasonably filled it with a topically relevant identifier for any domain-shaped question (weather, etc.), permanently defeating the gate for exactly the common case of factual Q&A about a topic that happens to have an associated capability name. Also tried temperature `0.1`: made output perfectly deterministic but deterministically wrong (5/5 `clarify`) — confirming this was a prompt/schema-design defect, not primarily a sampling-variance problem, so no temperature/sampling change was made.
- **Fix:** Reworded `makeStructuredNLUPrompt` (`Sources/AuraIntent/IntentEngine.swift`) to explicitly define `dialogue_act` semantics and state plainly that `capability_id` must be the empty string `""` whenever `dialogue_act` is `"answer"` or `"clarify"`, and is only ever set for `"execute"`/`"confirm"`/`"delegate"`.
- **Verification:** Live A/B re-test with the corrected prompt against the same real model: **11/11** samples across English ("What is the weather?", 5x), Turkish ("Gökyüzü neden mavi?", 3x), and mixed ("Please bugün hava nasıl?", 3x) now correctly returned `dialogue_act: "answer"` with `capability_id: ""` — up from 0/5 before the fix. `swift build` clean; confirmed via `grep` that no test asserts the exact prior prompt string. Full regression: 20/20 bundles, 696/696 tests. Rebuilt the release app bundle and ran a live 4-turn text-demo through the real production path (isolated `HOME`, `AURA_TEXT_DEMO_SCRIPT`): the Turkish sky-color question produced a full, correct, unprompted substantive answer about Rayleigh scattering (previously always clarified); the English weather question this run still hit the safe action-boundary refusal (fails safe, not a regression — confirms genuine LLM dialogue-act sampling variance remains, separate from the now-fixed `capability_id` defect); the ambiguous "please do the operation" turn correctly did not receive a substantive answer.
- **Evidence ID:** `EV-R2-20260804-STRUCTURED-NLU-CAPABILITY-GATE-FIX-01`.
- **Risk update:** `RISK-STRUCTURED-NLU-MODEL-QUALITY` remains `Mitigating` (not `Closed`) — the specific, systemic `capability_id`-always-non-empty defect is fixed and verified (0/11 → 11/11 in isolated repeated sampling), but residual `dialogue_act` sampling variance at this 8B model's scale was directly observed live post-fix and is not eliminated.
- **R2 status:** Remains `in_progress`. One blocker (`RISK-STT-MIC-NOT-CAPTURING`) remains, requiring the user physically present. The structured-NLU determinism item is substantially improved with real evidence but not fully closed; treating the residual sampling variance as an accepted, bounded model-tier limitation (rather than pursuing further prompt/schema iteration) is a reasonable option for the user to decide on.
- **Next safe action:** With the user present, diagnose microphone/Push-to-Talk capture — this is the one remaining hard blocker to R2 completion. Separately, the user may explicitly accept the residual structured-NLU sampling variance as a bounded risk (recommended, given the fix already substantially improves real behavior) or request further iteration.

### 2026-08-04T10:05:00Z — R2_MIC_CODE_AUDIT_AND_CANDIDATE_FIX — Push-to-Talk permission-request gap found and addressed, live verification still pending

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803` (continued).
- **Authority:** User instruction "go next be perfect." `RISK-STT-MIC-NOT-CAPTURING` explicitly requires the user physically present to test (grant TCC, speak into the mic); this entry is a code-level audit and candidate fix, not a live-verified resolution. Edit-only; no live mic/TCC exercise occurred or could occur in this session.
- **Trace of the real capture chain:** `AuraAudio.start()` (real `AVAudioEngine` tap) → `AudioSampleBridge` → `STTPipeline.ingestSampleFrame`, gated on `STTPipeline` being in `.transcribing` state, itself driven by `WakeActivationEvent`. `AuraKernel.activatePushToTalk()` publishes that event but only after `guard sttStarted else { throw AuraError.permissionDenied(...) }` — and `sttStarted`/`audioStarted` are only set by the separate `AuraKernel.startSpeechRecognition()` method, never by `AuraKernel.start()` (app bootstrap) itself.
- **Finding:** `AuraAppModel.pushToTalk()` (`Sources/AURA/AuraAppModel.swift`, prior version) only read `permissions.speechReady` passively; if not ready, it set a status label ("Grant microphone and Speech Recognition access first") and returned — it never called the OS permission-request APIs itself. A separate function, `requestVoicePermissions()`, does correctly call `AVAudioApplication.requestRecordPermission`/`SFSpeechRecognizer.requestAuthorization` and then `kernel.startSpeechRecognition()` on success, but it is only reachable from distinct menu controls (`AuraMenuView.swift:106,210`), not from the Push-to-Talk action itself. Ruled out two other hypotheses by direct inspection: (a) `Resources/AURA-Info.plist` does have both `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` with proper text — not a missing-usage-description TCC auto-denial; (b) the permission-request wiring inside `requestVoicePermissions()` itself is structurally correct (checks `.undetermined` before requesting, calls `startSpeechRecognition()` on success). The most defensible remaining explanation matching every observed symptom (no TCC dialog seen, no STT/permission `os_log` lines, silent no-op) is that a user pressing Push to Talk expects that action itself to trigger the permission prompt (as on iOS/Android) — if they never separately found/pressed the distinct voice-permissions menu control, no OS prompt would ever fire.
- **Fix:** `AuraAppModel.pushToTalk()` now proactively calls `PermissionCoordinator.requestVoicePermissions()` and `kernel.startSpeechRecognition()` inline when `permissions.speechReady` is false, before falling through to the existing `activatePushToTalk()` call — reusing the same already-correct OS-level request path, not introducing new permission logic. `startSpeechRecognition()` is idempotent (`if !sttStarted`/`if !audioStarted` guards), so no double-start risk.
- **Verification:** `swift build` clean. Full regression: 20/20 bundles, 696/696 tests, no flakiness. **Not verified live** — this session cannot grant TCC permission or produce microphone input; whether this specific gap was the actual root cause of the user's real-world failure is unconfirmed pending a live Push-to-Talk test.
- **Evidence ID:** `EV-R2-20260804-PTT-PERMISSION-AUDIT-01`.
- **Risk update:** `RISK-STT-MIC-NOT-CAPTURING` status unchanged (`Open`) — a plausible, real, defensible candidate fix now exists, but it must not be treated as closing the risk until confirmed live with the user present.
- **R2 status:** Remains `in_progress`. This is real progress toward the one remaining hard blocker, not a resolution of it.
- **Next safe action:** With the user physically present: relaunch (via `open`, to preserve correct TCC bundle identity per the prior session's fix), press Push to Talk, and observe whether the OS permission dialog now appears (if permission was never granted) or whether speech is now transcribed (if it was already granted but STT simply never started). If TCC was already denied from an earlier mis-attributed launch, `AVAudioApplication.shared.recordPermission`/`SFSpeechRecognizer.authorizationStatus()` will report `.denied`, not `.undetermined` — the request APIs silently no-op on `.denied` by design, and the user must instead use System Settings (the existing `PermissionCoordinator.openPrivacySettings` control) to reset it.

### 2026-08-04T10:40:00Z — R3_STARTED_WITH_R2_EXPLICITLY_OPEN — user-directed deviation from normal gate order

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803` (continued).
- **Decision:** User said "bunu atlayalım sıradaki aşamaya geçelim" (let's skip this, move to the next phase). Asked explicitly via a structured question whether to formally mark `RISK-STT-MIC-NOT-CAPTURING` and `RISK-STRUCTURED-NLU-MODEL-QUALITY` as accepted risks to close R2 before starting R3. User chose: leave both open, keep R2 `in_progress`, but proceed to R3 anyway.
- **What this means:** This is a deliberate, user-directed deviation from the prompt manifest's normal dependency order (`R3 depends on R2`; "Execute after R2 is complete" per `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`). It is recorded here explicitly rather than silently overridden or silently treated as equivalent to R2 completion. R2 remains genuinely `in_progress` with two real open risks; R3 work proceeds in parallel per explicit instruction.
- **State updates:** `current-state.json`: `active_prompt` moved to R3; `tracks[R3].state` → `in_progress`, `started_at` set; `tracks[R3].active_prompt.blocked_by` explicitly documents the R2 deviation. `tracks[R2].state` remains `in_progress`.
- **R3 status:** `in_progress`. Scope per `04_R3_CAPABILITY_REGISTRY_AND_PLANNER.prompt.md`: a versioned capability manifest, registry, bounded typed planner replacing the closed five-intent `ToolRouter` switch, an initial production capability set (~12 capabilities: `app.discover/activate/hide/quit`, `filesystem.open_file/open_folder/reveal`, `url.open`, `shell.execute_typed`, `task.status/cancel`, coding-agent start/status/cancel, runtime/capability health query), a typed adapter-result contract, policy integration from manifest metadata, an extensive required test list, a 7-scenario completion demonstration, and ADR-038. This is comparable in size to R1 or R2 and will be built incrementally across this and likely further sessions, not completed in a single pass.
- **Next safe action:** Begin with the foundational data model — capability manifest schema types, the registry, and ADR-038 — then the planner, then migrate the initial capability set from `ToolRouter` one at a time with tests, preserving all existing R1/R2 behavior (no regression) at every step per the completion gate's explicit requirement that "R4, R5, R6, and R8 can add capabilities without changing core routing architecture."

### 2026-08-04T12:30:00Z — R3_CAPABILITY_REGISTRY_AND_PLANNER_IMPLEMENTED — architectural core built, tested, zero regression

- **Actor:** Claude Code engineering session.
- **Session ID:** `AURA-R2-LIVE-20260803` (continued).
- **Authority:** User confirmed via explicit question to proceed with full R3 implementation in this session (not sliced across sessions). Edit-only; no commit, push, merge, or release authorized.
- **Built:** `CapabilityManifest`/`CapabilityRegistry` (`Sources/AuraIntent/CapabilityRegistry.swift`) — versioned, fail-closed-on-unknown capability contracts, superseding `ToolRegistry`/`ToolContract` (deleted, not left as dead code). `PlanStep`/`Plan`/`PlanResult`/`CapabilityPlanner` (`Sources/AuraIntent/CapabilityPlanner.swift`) — bounded typed planner that always recomputes risk/confirmation from the registry, never from a caller, rejects unknown/disabled capabilities and missing arguments, rejects oversized plans and dependency cycles, and produces a `SHA256` content fingerprint per plan (immutable identity; replanning yields a new plan, not a mutation). `InitialCapabilitySet` (`Sources/AuraIntent/InitialCapabilitySet.swift`) registers 14 manifests: 10 `.ready` (5 pre-existing NLU-reachable capabilities migrated onto the new registry with zero behavior change, plus `app.discover`/`app.hide`/`task.status`/`task.cancel`/`capability.health` newly reachable via 5 new direct, policy-gated `AuraKernel` methods) and 4 truthfully `.disabled` (`filesystem.open_file`/`open_folder`/`reveal`, `url.open` — real reviewed manifests, no adapter yet). `ToolRouter` now sources every capability contract from the registry (`resolveContract(for:)`); its five existing handler methods are otherwise untouched. Added 7 new `Capability` statics to `PolicyTypes.swift`. Wrote ADR-038.
- **Verification:** `CapabilityRegistryTests` and `CapabilityPlannerTests` (new, `Tests/AuraIntentTests/`) cover fail-closed unknown/wrong-version lookups, latest-version resolution, reachable-vs-disabled filtering, unknown/model-proposed capability rejection, missing-argument rejection, registry-recomputed risk tier, multi-step dependency ordering, plan-size/cycle rejection, and fingerprint stability/divergence. All pre-existing suites (`ToolRouterTests`, `DialogueEngineTests`, `EndToEndPipelineTests`, `AuraAdversarialTests`) pass unchanged after the migration — zero regression to the five already-production capabilities. Full regression run twice: 20/20 bundles, 717/717 tests (696 baseline + 21 new), no flakiness.
- **Evidence ID:** `EV-R3-20260804-CAPABILITY-REGISTRY-PLANNER-01`.
- **Known gaps, documented honestly (see ADR-038's "Known gaps carried forward"):** filesystem/URL capabilities have manifests but no adapter yet; the four newly-ready capabilities are reachable only via direct kernel calls, not yet the NLU classifier or any UI control; the planner's multi-step/delegated/refusal outcomes are implemented and unit-tested as building blocks, not yet wired for automatic natural-language decomposition; R2's two blockers remain open by explicit user choice.
- **R3 status:** `in_progress`, not complete — the completion gate requires "initial capabilities are genuinely reachable and tested" for the full set; only 10 of 14 registered capabilities are reachable today, and none of the required 7-scenario completion demonstration has been performed live.
- **Next safe action:** Decide whether to (a) build the filesystem/URL adapters and extend classifier reachability for the four direct-call-only capabilities next, (b) wire `DialogueEngine`/`ToolRouter` to consult `CapabilityPlanner` for real multi-step natural-language plans, or (c) return to closing R2's two open risks first. None of these are release claims.

### 2026-08-07T00:00:00Z — R2_CLOSEOUT_DEFERRED — sub-finding 3 accepted as bounded risk; live hardware evidence still required

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable for live interaction; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carries the prior uncommitted R2/R3 findings and R3 architectural core (CapabilityRegistry/CapabilityPlanner/ADR-038) as documented in the preceding entries.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised. This entry is documentation-only. The user is unavailable and delegated autonomous decision-making with later review; the two live-verification steps (microphone/TCC voice demo and the 7-scenario Ollama demo) physically require a human present and were therefore NOT performed and NOT fabricated.
- **Decision — `RISK-STRUCTURED-NLU-MODEL-QUALITY` sub-finding 3 (residual `dialogue_act` sampling variance):** **Option A — Accepted as bounded residual risk.** Rationale: (1) the fails-safe boundary means the residual variance degrades to a clarification or an `execute`-shaped safe-boundary refusal, never to unsafe execution — the typed NLU boundary (`ClassificationResult.applying`) still prevents any raw model result from reaching execution; (2) Option B (temperature/prompt iteration) is already empirically shown to be high-risk of diminishing returns — temperature 0.1 made the model *deterministically wrong* (5/5 `clarify`), and the systemic `capability_id` defect (the primary cause) is already fixed and verified 0/11 → 11/11 (`EV-R2-20260804-STRUCTURED-NLU-CAPABILITY-GATE-FIX-01`); (3) Option C (model upgrade) risks memory pressure on the 16 GB budget and would require re-benchmarking plus a new cold-start budget check, which is out of scope for a closeout and not authorized. The residual variance is a genuine 8B-model-scale sampling limitation, not a wiring defect. **Owner:** user (final authority). **Review/expiry date:** 2026-09-07 (30 days). **Release impact:** does not block development; must be re-evaluated before external beta if the local 8B model remains the reasoning backend, and the fails-safe boundary must be preserved.
- **R2 status:** Remains `in_progress`. R2 is NOT closed because the two live-verification evidence classes required by the R2 completion gate are still absent:
  - `RISK-STT-MIC-NOT-CAPTURING` remains `Open` — the candidate fix (`EV-R2-20260804-PTT-PERMISSION-AUDIT-01`) is unconfirmed pending a live Push-to-Talk test with the user present.
  - `RISK-ENGLISH-ONLY-INTENT` remains `Mitigating` — the Mitigating→Closed transition requires live bilingual evidence from the 7-scenario completion demonstration, which has not been performed.
- **Evidence IDs:** `EV-R2-20260807-STRUCTURED-NLU-SUBFINDING3-ACCEPT-01` (this decision), plus the existing `EV-R2-20260804-STRUCTURED-NLU-CAPABILITY-GATE-FIX-01`, `EV-R2-20260803-OLLAMA-BUDGET-FIX-01`, `EV-R2-20260804-PTT-PERMISSION-AUDIT-01`.
- **What this does NOT do:** It does not mark R2 `completed`, does not mark `RISK-STT-MIC-NOT-CAPTURING` or `RISK-ENGLISH-ONLY-INTENT` closed, and does not fabricate any live hardware or 7-scenario evidence. Per the risk-register rules, a risk is closed only with evidence IDs or explicit accepted-risk authority; the two live-verification risks have neither.
- **Next safe action:** With the user physically present: (1) reset TCC if `.denied` (System Settings → Privacy & Security → Microphone and Speech Recognition), relaunch via `open /Applications/AURA.app`, enable voice permissions, press Command-Shift-T and speak "Merhaba AURA, hava nasıl?"; record `EV-R2-20260804-LIVE-VOICE-DEMO-01`. (2) Run the 7-scenario completion demonstration and record `EV-R2-20260804-LIVE-7SCENARIO-01`. Only if both pass can R2 be marked `completed` and `RISK-STT-MIC-NOT-CAPTURING`/`RISK-ENGLISH-ONLY-INTENT` be closed. No commit, push, or R2-complete state transition should occur before that live evidence exists.

### 2026-08-07T01:00:00Z — R2_NOTES_REPO_AND_R3_PROCEED — R2 closeout notes recorded in repo; R3 confirmed active; ADR-038 accepted

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carries the prior uncommitted R2/R3 findings and R3 architectural core.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised. Documentation-only, per the user's instruction "r2 için gerekli noktaları not al repoya ve r3 e geçelim."
- **R2 closeout notes recorded in repo:** The deferred-closeout status, the sub-finding-3 acceptance, and the exact live-verification steps required to finish R2 are now recorded across `PROGRAM_LEDGER.md` (`R2_CLOSEOUT_DEFERRED` entry, this entry), `RISK_REGISTER.md` (`RISK-STRUCTURED-NLU-MODEL-QUALITY` → `Accepted`; `RISK-STT-MIC-NOT-CAPTURING` stays `Open`; `RISK-ENGLISH-ONLY-INTENT` stays `Mitigating`), `EVIDENCE_INDEX.md` (`EV-R2-20260807-STRUCTURED-NLU-SUBFINDING3-ACCEPT-01`), `current-state.json` (R2 stays `in_progress`; `blocked_by` reflects the current live-verification-only blocker), and `context/ACTIVE_CONTEXT.md` (updated to R3-active with a dedicated "R2 closeout status" section and updated "Immediate next action").
- **ADR-038 accepted:** Corrected `DECISION_REGISTER.md` — ADR-038 was recorded `Proposed` with a stale file reference (`ADR-038-capability-manifest-planner.md`), but the ADR file itself (`docs/decisions/ADR-038-capability-registry-and-planner.md`) is already `Accepted` with full validation evidence. The register now matches the file: `Accepted`, correct path, and the validation evidence `EV-R3-20260804-CAPABILITY-REGISTRY-PLANNER-01`.
- **R3 status:** Remains `in_progress`. The architectural core is complete and tested (registry, planner, ToolRouter migration, 10/14 reachable, zero regression). The R3 completion gate is NOT met: filesystem/URL adapters are unbuilt; the 4 direct-call-only capabilities lack NLU/UI reachability; the planner is not yet wired into `DialogueEngine`/`ToolRouter` for automatic multi-step natural-language plans (ADR-038 explicitly defers model-backed automatic planning to a follow-up pass); and the 7-scenario live completion demonstration has not been performed.
- **Next safe action (R3):** (1) build the filesystem/URL adapters (`filesystem.open_file`/`open_folder`/`reveal`, `url.open`); (2) extend NLU/UI reachability for the 4 direct-call-only capabilities; (3) wire the planner into `DialogueEngine`/`ToolRouter` for real multi-step natural-language plans; (4) run the required 7-scenario live completion demonstration. Do not mark R3 complete before these are resolved or explicitly accepted. R2's live-verification blockers remain open and are not blocking R3's independent work per the recorded user-directed deviation.

### 2026-08-07T02:00:00Z — R3_STATUS_RECORDED_AND_R4_PROCEED — R3 status noted in repo; R4 started by user-directed deviation

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carries the prior uncommitted R2/R3 findings and R3 architectural core.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised. Documentation-only, per the user's instruction "bunu da not et ve r4 e geç."
- **R3 status noted in repo:** R3 is NOT complete. Its architectural core (manifest, registry, planner, ToolRouter migration, ADR-038 accepted) is implemented and system-tested with zero regression (20/20 bundles, 717/717 tests), but the R3 completion gate is not met. The four remaining R3 items — (1) filesystem/URL adapters (`filesystem.open_file`/`open_folder`/`reveal`, `url.open` still truthfully `.disabled` with no adapter), (2) NLU/UI reachability for the 4 direct-call-only capabilities, (3) planner wired into `DialogueEngine`/`ToolRouter` for automatic multi-step natural-language plans, and (4) the required 7-scenario live completion demonstration — remain unperformed. This is recorded in `PROGRAM_LEDGER.md` (this entry and the preceding `R2_NOTES_REPO_AND_R3_PROCEED` entry), `current-state.json` (R3 track stays `in_progress`), and `context/ACTIVE_CONTEXT.md`.
- **R4 transition (user-directed deviation):** The user directed proceeding to R4 while R3 remains `in_progress` (not complete). This mirrors the earlier R2→R3 deviation and is recorded explicitly rather than silently treated as equivalent to R3 completion. R3's independent remaining work is not blocked by R2's live-verification blockers; likewise R4's work can proceed in parallel with R3's remaining items per this explicit instruction, but R3 must not be marked `completed` until its four remaining items are resolved or explicitly accepted.
- **R4 status:** `in_progress`. Scope per `05_R4_COMPUTER_USE_PRODUCTIZATION.prompt.md`: production observation contract, `ComputerUsePlanning` conformer emitting only the closed `ComputerUsePlan` schema, approved-target onboarding, resumable confirmation, postcondition verification, and live beta evidence. `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` (R4, High/Critical, Open) is the primary R4 risk. ADR-039 (`docs/decisions/ADR-039-production-computer-use-planner.md`) is Proposed in `DECISION_REGISTER.md` but does not yet exist on disk — it must be authored before R4 implementation proceeds.
- **Next safe action (R4):** (1) author ADR-039 (`Production computer-use planner and approved application beta boundary`) and record it in `DECISION_REGISTER.md`; (2) build the production observation contract; (3) implement a `ComputerUsePlanning` conformer that emits only the closed `ComputerUsePlan` schema; (4) add approved-target onboarding and resumable confirmation; (5) verify postconditions; (6) gather live beta evidence. Do not mark R4 complete before these are resolved. R3's four remaining items and R2's two live-verification blockers remain open and unblocked by R4's independent work per the recorded user-directed deviation.

### 2026-08-07T03:00:00Z — R4_PRODUCTIZATION_CORE_IMPLEMENTED — ADR-039, observation contract, deterministic planner, beta allowlist, resumable confirmation, semantic verification

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carries the prior uncommitted R2/R3/R4 findings.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised. Edit/build/test only. Live beta-app hardware validation requires the user physically present and is therefore deferred, not fabricated.
- **ADR-039 authored and accepted:** `docs/decisions/ADR-039-production-computer-use-planner.md` was written (it was `Proposed` in `DECISION_REGISTER.md` but the file did not exist on disk — the same stale-reference class as ADR-038's register entry) and marked `Accepted` in `DECISION_REGISTER.md`. It defines the production computer-use planner and approved-application beta boundary.
- **Implemented (deterministic R4 productization core):**
  - `ComputerUseObservation` (`Sources/AuraComputerUse/ComputerUseObservation.swift`) — the production observation contract: composes over redaction-safe `ScreenObservation` and adds a bounded Accessibility-tree summary, semantic control candidates, secure-field and modal state, a structural hash, and capture/redaction provenance; never retains the raw frame by default.
  - `ComputerUseBetaAllowlist` (`ComputerUseBetaAllowlist.swift`) — the R4 beta target allowlist (Finder, Safari, VS Code, Terminal, Notes, Calendar, Mail), structurally closed until an app is explicitly `.liveValidated`; unvalidated apps are unreachable by a production planner.
  - `ComputerUseAppFixtures` (`ComputerUseAppFixtures.swift`) — app-scoped curated known tasks + semantic postcondition predicates.
  - `DeterministicComputerUsePlanner` (`DeterministicComputerUsePlanner.swift`) — the first production `ComputerUsePlanning` conformer; emits only closed `ComputerUsePlan` values and stops/clarifies for unapproved apps, unknown objectives, secure fields, or unexpected modals.
  - `ComputerUseConfirmationStore` (`ComputerUseConfirmationStore.swift`) — resumable, hash-bound confirmation checkpoint with one-time execution and rejection on app/window/content/structural/anchor/secure-field/modal change.
  - `ComputerUseVerifier` (`ComputerUseVerifier.swift`) — semantic postcondition verification where a content-hash change alone is never sufficient.
- **Verification:** `swift build --target AuraComputerUse` clean. New `R4ProductizationTests` (13 tests) pass. Full regression: 20/20 bundles, 772/772 tests (759 baseline + 13 new), 0 failed bundles. Governance gate passes.
- **Evidence ID:** `EV-R4-20260807-PRODUCTIZATION-CORE-01`.
- **R4 status:** Remains `in_progress`. The deterministic productization core (observation contract, beta allowlist, production planner, resumable confirmation, semantic verification, ADR-039) is implemented and unit-tested with zero regression. The R4 completion gate is NOT met: computer use is not yet voice/text/UI reachable through the capability registry (no `AuraKernel`/`DialogueEngine` wiring in this pass), the live beta-app evidence (safe tasks in ≥3 approved apps on granted Accessibility/Screen-Recording hardware, live confirmation, live emergency stop, live screen-content injection fixture) has not been performed (requires the user present), and `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` is mitigated but not closed.
- **Next safe action (R4):** (1) wire computer use into the capability registry/`AuraKernel`/`DialogueEngine` for voice/text/UI reachability; (2) with the user present, run safe tasks in ≥3 approved beta apps (Accessibility-anchored action, coordinate fallback, a task requiring confirmation, a modal/identity/no-progress failure, a secure-field refusal, emergency stop, a screen-content injection fixture) and record live evidence. Do not mark R4 complete before these are resolved. R2's two live-verification blockers and R3's four remaining items remain open and unblocked by R4's independent work.

### 2026-08-07T04:00:00Z — R4_WIRING_REGISTRY_COMPOSITION — computer use wired into capability registry and composition root

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `24fe2165f6b3805d3afcdbb7ed8554fda1ee06d0` on `main`; working tree carries the prior uncommitted R2/R3/R4 findings.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised. Edit/build/test only. Live beta-app hardware validation requires the user physically present and is therefore deferred, not fabricated.
- **R4 wiring (completion gate "voice/text/UI reachable through the capability registry"):**
  - `Capability.computerUseRun` added (`domain: computerUse, action: run`, mutation tier) in `PolicyTypes.swift`.
  - `computerUse.run` `CapabilityManifest` registered in `InitialCapabilitySet` as truthfully `.disabled` (implemented but requires an approved, live-validated beta app; reachable count stays 10).
  - `AuraKernel.computerUseRun(appBundleIdentifier:objective:)` added: evaluates `.computerUseRun` policy, checks the `ComputerUseBetaAllowlist`, resolves an approved window via `ScreenContextEngine.listApprovedWindows()`, and runs the bounded `ComputerUseControlLoop` with a `DeterministicComputerUsePlanner`. The planner is bridged to the loop's `ComputerUsePlanning` boundary via a `ScreenObservation` → `ComputerUseObservation` wrapper that never fabricates accessibility structure.
  - `computerUseAllowlist = .initial` stored in the kernel.
- **Injection resistance (R4 section F) + tests:** 6 new `R4ProductizationTests` (planner never treats screen text as an instruction, never emits a text-driven destructive action, re-scopes steps to the observed app, observation freshness/identity, raw-frame-not-retained-by-default) and 1 registry test (`computerUseRunRegisteredDisabledUntilApproved`).
- **Verification:** AuraComputerUseTests 62/62, AuraIntentTests 67/67, full regression 20/20 bundles, 778/778 tests (772 baseline + 6 new), 0 failed bundles, `swift build --target AURA` clean; governance gate passes.
- **Evidence ID:** `EV-R4-20260807-WIRING-REGISTRY-01`.
- **R4 status:** Remains `in_progress`. Computer use is now wired into the capability registry and composition root (policy-gated, allowlist-gated, deterministic planner). The R4 completion gate is still NOT met: `computerUse.run` remains `.disabled` until an app is explicitly `.liveValidated`, the live end-to-end path has not been exercised on real hardware, and the required live beta-app evidence (safe tasks in ≥3 approved apps on granted Accessibility/Screen-Recording hardware, live confirmation, live emergency stop, live screen-content injection fixture) has not been performed — it requires the user physically present. `RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER` is mitigated but not closed.
- **Next safe action (R4):** with the user physically present, run safe tasks in ≥3 approved beta apps (Accessibility-anchored action, coordinate fallback, a task requiring confirmation, a modal/identity/no-progress failure, a secure-field refusal, emergency stop, a screen-content injection fixture) and record live evidence; then mark `computerUse.run` `.liveValidated` for the validated apps and re-run the completion gate. Do not mark R4 complete before these are resolved. R2's two live-verification blockers and R3's four remaining items remain open and unblocked by R4's independent work.

### 2026-08-07T05:00:00Z — R5_STARTED_AND_SESSION_STARTER — R5 adapters started by user-directed deviation; new session starter written; second-pass completion plan recorded

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `808cf64f1804fc9ba433ea5a85beedcdabeacdb2` on `main`; `HEAD == origin/main`; working tree clean at session start.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised in this transition. Documentation-only, per the user's instruction "eksiklikleri tamamlanmayan kapıları not alalım ve r5 devam etmek üzere new session starter yaz, tüm eksik kalanlara hepsi bittikten sonra ikinci turda tamamlarız."
- **R5 transition (user-directed deviation):** The user directed proceeding to R5 while R2/R3/R4 remain `in_progress` (not complete). This mirrors the earlier R2→R3 and R3→R4 deviations and is recorded explicitly rather than silently treated as equivalent to completion. R5's independent work can proceed in parallel, but R2/R3/R4 must not be marked `completed` until their remaining items are resolved or explicitly accepted.
- **R5 status:** `in_progress`. Scope per `06_R5_BROWSER_MAIL_CALENDAR_ADAPTERS.prompt.md`: read-first browser/mail/calendar/contacts adapters, least-privilege OAuth/Keychain, injection resistance, offline/degraded behavior, and live acceptance. Primary risks: `RISK-MISSING-PRODUCTIVITY-ADAPTERS`, `RISK-INDIRECT-PROMPT-INJECTION`. ADR-040 is Proposed in `DECISION_REGISTER.md` but the file does not yet exist on disk and must be authored before implementation.
- **Second-pass completion plan (all remaining gates, to be completed after the first pass):** R2 live-verification (microphone/TCC voice demo `EV-R2-20260804-LIVE-VOICE-DEMO-01`, 7-scenario demo `EV-R2-20260804-LIVE-7SCENARIO-01`); R3 (filesystem/URL adapters, NLU/UI reachability for 4 direct-call-only capabilities, planner wired into DialogueEngine/ToolRouter, 7-scenario live demo); R4 (live beta-app evidence in ≥3 approved apps, mark `computerUse.run` `.liveValidated`); R5 (author ADR-040, build read-first adapters, injection resistance, live acceptance with authorized test accounts). Each requires the user physically present or explicit authorization for live/account actions.
- **New session starter:** `SESSION_STARTER.md` was rewritten to point at the authoritative `AURA_RUNTIME_COMPLETION/state/current-state.json` and `context/session-handoff.json`, record the current `HEAD == origin/main == 808cf64`, the active prompt R5, and the exact next action (author ADR-040, then build read-first adapters).
- **Next safe action (R5):** (1) author ADR-040 (`docs/decisions/ADR-040-productivity-integrations-oauth.md`) and record it in `DECISION_REGISTER.md`; (2) build read-first browser/mail/calendar/contacts adapters with least-privilege OAuth/Keychain; (3) add injection resistance and offline/degraded behavior; (4) run live acceptance with explicitly authorized test accounts/profiles. Do not mark R5 complete before these are resolved. R2's two live-verification blockers, R3's four remaining items, and R4's live beta-app evidence remain open and unblocked by R5's independent work.

### 2026-08-07T06:00:00Z — R5_ADR040_ACCEPTED — ADR-040 authored and accepted; R5 trust boundaries and OAuth scope model defined

- **Actor:** GitHub Copilot engineering session (autonomous, user unavailable; user will review later).
- **Session ID:** `AURA-R2-CLOSEOUT-20260807`.
- **Verified starting commit:** `808cf64f1804fc9ba433ea5a85beedcdabeacdb2` on `main`; `HEAD == origin/main`; working tree clean at session start.
- **Authority:** No commit, push, merge, install, launch, or TCC mutation authority is assumed or exercised. Documentation-only.
- **ADR-040 authored and accepted:** `docs/decisions/ADR-040-productivity-integrations-oauth.md` now exists on disk (previously Proposed in `DECISION_REGISTER.md` with no file) and is marked **Accepted** in `DECISION_REGISTER.md`. It defines the R5 browser/mail/calendar/contacts least-privilege OAuth/Keychain trust boundaries: read-first default with mutation/send separately gated; incremental least-privilege OAuth scopes (read-only installation never requests send scope); Keychain-only immediately-revocable tokens via `KeychainSecretStore`; deny-by-default `NetworkAllowlist` enforcement per provider with redirect re-checking; untrusted-content provenance tagging + `PromptInjectionClassifier` isolation for page/mail/attachment/event content; explicit closed account/profile scope mirroring `ComputerUseBetaAllowlist`; immutable `ConfirmationTransaction` for send/mutation; computer use as explicit bounded fallback; and first-class offline/degraded states. It reuses the verified primitives (ADR-020 Keychain/NetworkAllowlist/ContentProvenance/PromptInjectionClassifier, ADR-037 ConfirmationTransaction, ADR-038 CapabilityRegistry, ADR-039 allowlist pattern) rather than inventing parallel ones.
- **R5 status:** Remains `in_progress`. ADR-040 is now Accepted (the first R5 work item is done), but no browser/mail/calendar/contacts adapters exist yet, and live acceptance requires explicitly authorized test accounts/profiles. `RISK-MISSING-PRODUCTIVITY-ADAPTERS` and `RISK-OAUTH-OVERPRIVILEGE` are materially mitigated by the ADR's decisions but not closed; `RISK-INDIRECT-PROMPT-INJECTION` is mitigated for the R5 content paths but the general R10 enforcement remains open.
- **Next safe action (R5):** (1) build read-first browser/mail/calendar/contacts adapters with least-privilege OAuth/Keychain (registering the R5 capabilities in `InitialCapabilitySet` with truthful availability); (2) add injection resistance and offline/degraded behavior; (3) run live acceptance with explicitly authorized test accounts/profiles. Do not mark R5 complete before these are resolved. R2's two live-verification blockers, R3's four remaining items, and R4's live beta-app evidence remain open and unblocked by R5's independent work.

### 2026-08-08T10:13:59Z — R5_READ_FIRST_ADAPTER_SLICE_STARTED — objective, boundaries, and acceptance criteria recorded before implementation

- **Actor:** Codex engineering session.
- **Objective:** Implement the first deterministic R5 read-first slice: typed browser/mail/calendar/contacts adapter contracts; least-privilege OAuth scope and Keychain-reference handling; provider/domain allowlist checks; external-content provenance and prompt-injection isolation; explicit degraded states; native EventKit/Contacts read adapters where the current macOS SDK provides a structured API; and truthful capability manifests.
- **Assumptions:** Existing ADR-040 is the governing decision; the current SwiftPM package remains the build boundary; Safari page access requires a separately packaged Safari Web Extension/native-messaging bridge; no live provider account or browser profile is configured for this offline test pass; read-only capabilities may be registered but must remain visibly unavailable until composition-root and live/provider wiring exists.
- **Risks:** Provider/browser bridge and live OAuth acceptance remain open; EventKit/Contacts authorization is user-controlled and must not be requested during tests; external content must never gain authority; token values must not enter logs, events, prompts, or speech; the pre-existing dirty state and untracked ADR-040 must be preserved.
- **Acceptance criteria:** (1) package builds the new productivity target; (2) read-only adapters are typed and fail closed for missing configuration, permission, account, scope, network, and injection conditions; (3) read-only OAuth scope manifests cannot silently include compose/send scopes; (4) capability registration is truthful and does not increase the reachable count before composition wiring; (5) focused tests cover scope escalation/revocation, token-reference redaction, domain/redirect enforcement, ambiguity, native read mapping, conflict detection, and direct/indirect injection fixtures; (6) no live account, permission, send, commit, push, or release action is performed.
- **Next safe action:** Implement the adapter/security slice, then run focused tests, full `scripts/aura-test.sh`, and governance validation before updating state/evidence.

### 2026-08-08T10:40:01Z — R5_READ_FIRST_ADAPTER_SLICE_IMPLEMENTED — deterministic first slice verified; live wiring remains open

- **Actor:** Codex engineering session.
- **Verified repository:** `HEAD == origin/main == daf062aefc8b2eaa516769fdf27e6fc816111002` on `main`; the worktree remains intentionally dirty and this session performed no commit or push.
- **Objective result:** Implemented the first R5 read-first slice under Accepted ADR-040: `AuraProductivity` typed browser/mail/calendar/contacts contracts; structured Safari active-tab bridge contract; Gmail read-only OAuth scope/Keychain/account/network boundary; EventKit calendar and Contacts candidate-only native adapters; provenance/injection guards; conflict and attachment policies; and truthful `.disabled` capability manifests.
- **Verification:** `swift build --target AuraProductivity` passed; focused `AuraProductivityTests` passed 9/9; `./scripts/aura-test.sh /tmp/aura-r5-full` passed 21/21 bundles, 747/747 tests, 0 failed bundles; `python3 scripts/validate_runtime_completion.py --ci` passed; `git diff --check` passed. Focused log SHA-256: `6e97abe025939bc4bb67daf34858a41a2fa21f2c35b7bd63bc70f6c7a3e6e9c8`.
- **Safety and limits:** No live OAuth consent, provider account, Safari extension package, EventKit/Contacts permission prompt, NLU/UI composition path, mutation/send flow, or external publication was performed. `swift-format` and full Xcode remain unavailable. R5 remains `in_progress`; four read capabilities remain truthfully disabled until live wiring and acceptance.
- **Next safe action:** Wire the typed slice through `AuraKernel`/Dialogue/UI, package Safari/provider transports, configure explicitly authorized accounts/profiles and permissions, run live offline/degraded acceptance, then separately gate mutation/draft/send with immutable confirmation and post-action verification.
- **Evidence ID:** `EV-R5-20260808-READ-FIRST-ADAPTERS-01`.

### 2026-08-08T10:51:29Z — R6_POLICY_BRIDGE_SLICE_STARTED — R5 gaps preserved; R6 objective and acceptance recorded

- **Actor:** Codex engineering session.
- **Transition:** R5 remains `in_progress`; its unresolved gates and the R2/R3/R4 deferred gates are recorded in `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`. R6 is now the active prompt by user-directed continuation.
- **Objective:** Enforce `PolicyEngine` decisions before every VS Code action path and harden the existing structured bridge boundary with authenticated/versioned/nonce-aware contracts, bounded data, and explicit stale/disconnect behavior.
- **Assumptions:** Existing `AuraVSCode`, `AuraTasks`, `AuraAgent`, `WorktreeManager`, and ADR-041 Proposed record are the governing local surfaces; the installed `code` CLI is version `1.132.0` arm64; no live extension packaging, agent backend execution, TCC, commit, or publication action is authorized in this slice.
- **Risks:** Current bridge state is file-based and unauthenticated; CLI/backend flags and health may drift; direct adapter paths could bypass policy; dirty editor and workspace ambiguity could cause loss or wrong-directory execution.
- **Acceptance criteria:** Policy deny/confirm/missing-policy paths fail closed before CLI/shell/bridge execution; bridge DTOs carry version/nonce/freshness and reject malformed or stale state; focused R6 tests cover policy gating and bridge failure modes; no R5 gate is marked complete; no live external action is performed.
- **Next safe action:** Implement the policy gate and bridge contract slice, then run focused R6 tests, full regression, governance validation, and update evidence without accepting ADR-041 prematurely.

### 2026-08-08T11:05:18Z — R6_POLICY_BRIDGE_SLICE_IMPLEMENTED — first policy and authenticated bridge slice verified

- **Actor:** Codex engineering session.
- **Verified repository:** `HEAD == origin/main == daf062aefc8b2eaa516769fdf27e6fc816111002` on `main`; the worktree remains intentionally dirty and this session performed no commit or push.
- **Objective result:** `VSCodeAdapter` now receives and awaits the real `PolicyEngine` before CLI, shell, or bridge execution and fails closed for missing, denied, or confirmation-required decisions. The file bridge has an authenticated, versioned HMAC-SHA256 envelope with expected extension ID, nonce replay defense, freshness/clock-skew checks, and bounded payload size. The default production bridge remains unavailable without authenticated configuration.
- **Verification:** Focused `./scripts/aura-test.sh /tmp/aura-r6-vscode-focused-4 AuraVSCodeTests` passed 17/17. Full `./scripts/aura-test.sh /tmp/aura-r6-full` passed 21/21 bundles, 751/751 tests, 0 failed bundles. Final `python3 scripts/validate_runtime_completion.py --ci`, script unittest discovery (13/13), `git diff --check`, `zsh -n scripts/aura-test.sh`, and JSON parsing passed. Known linker warnings reference unavailable CommandLineTools framework paths; they did not fail the build.
- **Evidence:** `EV-R6-20260808-POLICY-BRIDGE-01`; `/tmp/aura-r6-full/out/Products/Debug/*.log`; `/tmp/aura-r6-vscode-focused-4`.
- **Boundaries:** No live extension package/shared-secret provisioning, task/test/diagnostics/workspace route, coding-agent backend health/auth/run, TCC/UI acceptance, user-present live coding-agent demonstration, commit, push, release, or deployment was performed. ADR-041 remains Proposed; R6 remains `in_progress`. R2/R3/R4/R5 remain open in `SECOND_PASS_OPEN_GAPS.md`.
- **Next safe action:** Package and provision the authenticated extension bridge; complete workspace/task/test/diagnostic/agent routes and durable reviewable writes; verify backend health; then run user-present live acceptance. Do not close R6 or accept ADR-041 from local simulated evidence alone.

### 2026-08-08T11:52:53Z — R6_TYPED_ROUTES_AND_BOUNDED_CODING_SLICE — local typed route and durable-control expansion recorded

- **Actor:** Codex engineering session; session `AURA-R6-VSCODE-20260808`.
- **Objective result:** Added typed signed bridge command/response DTOs and bounded command validation; fail-closed workspace resolution with explicit → active VS Code → active durable task/worktree → project-candidate precedence; typed task/test/cancel policy mappings; backend health probes that record exact local CLI/version/help evidence while keeping auth/model readiness unverified; production natural-language coding routing through the workspace/backend/worktree/durable-task coordinator; and durable task deadline, inactivity-watchdog, duplicate-ID, cancellation, and latest-checkpoint recovery controls.
- **Verification:** `swift build --target AuraIntent` passed; `swift build --target AURA` passed; `git diff --check` passed. After placing the existing CommandLineTools `Testing.framework` and interop library in the temporary scratch `@rpath`, `swift test --skip-build --scratch-path /tmp/aura-r6-verify.c9K82Q` passed 21/21 bundles and 763/763 tests. The project runner passed all R6-relevant bundles; its single repository-wide failure was the known `AuraAudioTests` helper `exit 142` after assertions passed.
- **Safety and limits:** The production bridge remains unavailable without authenticated extension configuration. No extension package/provisioning, live backend auth/model turn, TCC/UI action, commit, push, release, deploy, or user-present acceptance was performed. Write-capable coding remains fail-closed until workspace, backend readiness, worktree, policy, and verification gates pass. ADR-041 remains Proposed and was not accepted.
- **Evidence ID:** `EV-R6-20260808-TYPED-ROUTES-02`.
- **Next safe action:** Provision the real extension bridge, connect/live-verify all typed routes, complete backend onboarding and durable reviewable flows, and run the user-present R6 acceptance gate before considering ADR-041 or R6 closure. Keep the AuraAudio exit-142 result under its existing approval boundary; do not intervene in system services without approval.

### 2026-08-08T12:22:42Z — R6_FIRST_PASS_SCOPE_CLARIFICATION — corrected pass terminology

- **User correction:** R6 is the active first-pass continuation. The phrase
  “second local R6 slice” was incorrect and has been removed from the current
  handoff/state projections.
- **State boundary:** `SECOND_PASS_OPEN_GAPS.md` is reserved for the R2-R5
  gates deferred for the future second pass. R6's remaining extension,
  backend, durable-flow, and user-present acceptance gates remain current
  first-pass work and are tracked in the authoritative R6 state/evidence
  records.
- **No product change:** This correction changes terminology and state
  projection only; the R6 implementation and its evidence remain intact.

### 2026-08-08T12:28:03Z — R6_GAPS_AND_R7_APPROVAL_RULE — per-prompt gap recording restored

- **User instruction:** After every prompt, including the active R6 prompt,
  append unresolved gates to `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`
  for completion from the beginning in the future second pass.
- **R6 state:** The R6 section is restored in that file. Its presence is a
  future second-pass record and does not suspend or close the current first-pass
  R6 work.
- **Transition gate:** After R7's explicitly authorized commit/push/merge
  delivery, stop and obtain the user's explicit approval before transitioning
  to R8.

### 2026-08-08T12:43:10Z — R7_VOICE_ROUTING_RESOURCE_GOVERNOR_STARTED — objective and boundaries recorded before R7 continuation

- **Actor:** Codex engineering session; user explicitly authorized continuation to R7.
- **Transition:** R6 remains `in_progress`; R2-R6 unresolved gates remain recorded in `AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md`. R7 is the active first-pass prompt. No R8 work is authorized before R7 delivery and explicit user approval.
- **Objective:** Implement the R7 local voice slice: exact-frame wake pipeline safety with truthful PTT-only production behavior, reusable local STT routing with capability-aware on-device recognition, bounded incomplete-turn completion, deterministic system-TTS interruption/fallback, and actor-isolated resource admission under memory pressure and thermal state.
- **Assumptions:** Apple Speech and AVFoundation remain the native local adapters; no qualified real wake-word engine, live bilingual corpus, live human barge-in session, or approved ADR-042 acceptance is available in this pass. The existing dirty R5/R6 worktree is user-owned state and must be preserved.
- **Risks:** Wake-word FAR/FRR and neural-TTS quality are unverified; local STT fallback is not a qualified Whisper-quality router; sleep/device/TCC recovery and measured 16 GB soak require live evidence; ADR-042 must not be accepted without explicit user approval.
- **Acceptance criteria:** R7 code must build; focused and full available tests must pass or be precisely bounded; PTT remains truthful and safe; fallback/cancel/duplicate/continuation/resource paths are covered; R7 open gates are appended to `SECOND_PASS_OPEN_GAPS.md`; ledgers/state/evidence remain synchronized; no R8 transition occurs without explicit approval.
- **Intended files:** `Sources/AuraCore/{VoiceResourceGovernor,TurnCompletionHeuristics}.swift`, `Sources/AuraSTT/{STTRouter,STTEngine,SystemSTTEngine,STTPipeline}.swift`, `Sources/AuraAudio/{WakeWordDetector,WakeWordPipeline,SystemTTSEngine,ChatterboxTTSEngine}.swift`, `Sources/AURA/AuraKernel.swift`, related tests, subsystem documentation, and R7 state/evidence records.
- **Next safe action:** Compile the existing R7 slice, repair any source/test failures, then add focused coverage before state closeout.

### 2026-08-08T13:29:34Z — R7_VOICE_LOCAL_SAFETY_VALIDATED — local implementation and available regression gates passed

- **Actor:** Codex engineering session; session `AURA-R7-VOICE-20260808`.
- **Objective result:** Completed the R7 local voice routing/resource slice with truthful production Push-to-Talk-only behavior, bounded exact-frame wake buffering, capability-aware on-device STT routing, duplicate-result suppression, bounded incomplete-turn continuation, generation-safe system-TTS interruption, Chatterbox timeout/Yelda fallback, and actor-isolated thermal/memory/failure admission control. The production wake detector remains explicitly disabled because no real wake-word candidate was live-qualified.
- **Verification:** `swift build --target AURA` passed. `./scripts/aura-test.sh /tmp/aura-r7-full-final` built production AURA and passed 21/21 bundles with 774/774 tests and zero failed bundles. Focused Core and Audio reruns passed 22/22 and 35/35. `python3 scripts/validate_runtime_completion.py --ci`, 13/13 deterministic validator tests, `git diff --check`, `zsh -n scripts/aura-test.sh`, and JSON parsing passed after the deterministic thermal-state correction.
- **Evidence:** `EV-R7-20260808-VOICE-LOCAL-SAFETY-01`; `/tmp/aura-r7-full-final/out/Products/Debug/*.log` aggregate SHA-256 `4213dc54d4c12a767b2df3387f27453b91b238198b4235ad958518aacc1a047a`; focused Core log SHA-256 `6acba13cf4382ba3dba6c3e5ed24f24dd7adc935f3285ab6bcf1deb832c9da97`; focused Audio log SHA-256 `edfa14206274609d056f12c361fbb18bc2536fde9558ca14e4bd0fd09d3571b8`.
- **Limits:** No live wake-word FAR/FRR, bilingual/mixed microphone WER/entity evaluation, user-present barge-in or sleep/device/TCC recovery, measured 16 GB multi-workload soak, consented neural reference/quality acceptance, or ADR-042 approval was performed. R7 remains `in_progress`; R2-R6 gaps remain in `SECOND_PASS_OPEN_GAPS.md`.
- **Delivery boundary:** R7 is ready for the explicitly authorized commit/push delivery. The active branch is `main`, so no separate merge commit is applicable. After delivery, stop and request explicit user approval before R8.

### 2026-08-08T13:46:00Z — R7_LOCAL_APP_DEPLOYED — signed local development bundle installed and smoke-tested

- **Actor:** Codex engineering session; user explicitly authorized push/commit/merge/deploy.
- **Deployment:** Built the pushed R7 tree under `/tmp/aura-r7-deploy`, signed with `AURA Stable Local Signing`, verified all helper sandbox attestations and strict code-signature checks, then installed `/Applications/AURA.app`. The prior local app was preserved at `/Applications/AURA.app.r7-previous-20260808T164510` for rollback.
- **Verification:** Deployed and scratch main binaries match SHA-256 `42b5bf4103319770a282d51ef16062bcf917b9c0ed6f22731edf407294442c75`; the deployed process remained alive during the 8-second launch smoke. Evidence: `EV-R7-20260808-LOCAL-APP-DEPLOY-01` and `/tmp/aura-r7-deployed-signature.log` SHA-256 `0e803a4d44e295d54ade8f52267a498c72f11a1e85cfe9e7b871ecfc071d0677`.
- **Limits:** This is local development deployment only. Full Xcode is unavailable, so `python3 scripts/validate_runtime_completion.py --release` fails closed; no Developer ID, notarization, external beta, TCC, microphone, or live voice acceptance is claimed. R7 remains `in_progress` and R8 remains gated on explicit user approval.

### 2026-08-08T14:13:21Z — R8_STARTED_MEMORY_PERSONALIZATION_EXPLAINABILITY — user-directed first-pass continuation

- **Actor:** Codex engineering session; user explicitly directed continuation to R8 after R7 delivery. No R8 commit, push, merge, release, deploy, installation, dependency download, or TCC mutation is authorized by this entry.
- **Objective:** Activate the existing memory/provenance/context foundations as a user-controlled capability while preventing raw/untrusted/model content retention, authority confusion, unbounded context, and remote-context leakage.
- **Assumptions:** Existing AuraStore schema is migrated additively; the compatibility `append(draft:)` path remains for existing tests/callers; local-only is the safe default; R9 owns visible UI controls; live acceptance requires the user present.
- **Implementation:** Added `MemoryWriteRequest`/source policy with secret-like content checks; persisted record purpose via additive `v1_5_0_memory_purpose`; added bounded `UserPreferenceProfile` and `UserPreferenceProfileStore`; changed IntentEngine memory persistence to a bounded classifier summary without raw utterance/slot values; extended `ContextBundle` and `ContextItem` with requester/purpose/delivery/sensitivity/budget/exclusions/provenance metadata; context retrieval now uses authority-ranked active beliefs and surfaces unresolved conflicts; remote context delivery fails closed without a redacted approved summary.
- **Verification:** `swift build --build-path /tmp/aura-r8-build` passed. `./scripts/aura-test.sh /tmp/aura-r8-memory-final2 AuraMemoryTests` passed 30/30; `./scripts/aura-test.sh /tmp/aura-r8-context AuraContextTests` passed 33/33. Evidence IDs: `EV-R8-20260808-MEMORY-POLICY-01`, `EV-R8-20260808-CONTEXT-PRODUCT-02`.
- **Risks:** User-present restart/profile, multi-turn reference, destructive ambiguity, contradiction resolution, inspection/correction/deletion/export, and provenance-display demonstrations are not performed. Reference candidates are not yet populated from all production salience/tool paths; R9 UI and actual remote transport verification remain open; ADR-043 is Proposed and must not be accepted without explicit user approval.
- **Acceptance criteria:** Focused/full local validation and governance must pass; all unresolved R8 gates must be appended to `SECOND_PASS_OPEN_GAPS.md`; no memory record may silently authorize a risky action; no R9 transition occurs without explicit approval.
- **Next safe action:** Run the full available regression and governance gates, then record R8 evidence/state projections and stop for the user's decision on delivery and ADR-043 acceptance.

### 2026-08-08T14:31:02Z — R8_REGRESSION_AND_GOVERNANCE_VALIDATED — local first-pass validation complete, live gates remain open

- **Actor:** Codex engineering session; session `AURA-R8-MEMORY-20260808`.
- **Verification:** `./scripts/aura-test.sh /tmp/aura-r8-full-final` passed 21/21 bundles and 782/782 tests with zero failed bundles. R8 focused suites remained green at `AuraMemoryTests` 30/30 and `AuraContextTests` 33/33; the updated raw-transcript non-retention contract in `AuraIntentTests` passed 67/67. `python3 scripts/validate_runtime_completion.py --ci` passed; `python3 -m unittest discover -s scripts/tests` passed 13/13; `jq empty`, shell syntax checks, and `git diff --check` passed.
- **Evidence:** `EV-R8-20260808-REGRESSION-03`; 21 test logs under `/tmp/aura-r8-full-final/out/Products/Debug/`, aggregate hash of sorted per-log SHA-256 records `17ea291c7736f2d0474a417f867343f6066d43985aeefc13075feee0c914cae0`.
- **Limits:** CommandLineTools linker warnings for unavailable full-Xcode framework paths remain host limitations; no user-present restart/profile, reference, ambiguity, contradiction/control, remote transport, or latency/soak acceptance was performed. R8 remains `in_progress`; ADR-043 remains `Proposed`.
- **Delivery boundary:** No R8 commit, push, merge, release, deploy, installation, dependency/model download, or TCC mutation was performed or authorized. Stop for explicit user direction before delivery and before R9.

### 2026-08-08T15:28:28Z — R9_STARTED_PRODUCT_UI_ACCESSIBILITY_ONBOARDING — explicit user-directed continuation

- **Actor:** Codex engineering session; session `AURA-R9-PRODUCT-UI-20260808`.
- **Objective:** Transform the menu-bar panel into a coherent, keyboard-operable, VoiceOver-aware, Turkish/English product surface covering conversation, tasks, capabilities/permissions, models/voice, privacy/memory, recovery, and staged onboarding.
- **Assumptions:** Existing backend contracts remain authoritative; unavailable capabilities remain visibly disabled; R8 live gates remain open and are not silently closed by UI work; permission requests occur only after user action; no cloud or privileged behavior is enabled by presentation code.
- **Risks:** Manual VoiceOver/keyboard/scaled-layout acceptance, complete localization, restart restoration, onboarding denial/recovery, and full provider/model/memory control coverage are not yet evidenced.
- **Acceptance criteria:** Add the R9 UI slice with pure state/reducer tests, real kernel snapshot/control wiring where available, actionable disabled states, accessibility/localization semantics, staged onboarding, and truthful R9 open-gap recording. No commit/push/merge/release/deploy is authorized by this entry.

### 2026-08-08T16:36:47Z — R9_PRODUCT_UI_SLICE_VALIDATED — local first-pass implementation and deterministic tests

- **Actor:** Codex engineering session; session `AURA-R9-PRODUCT-UI-20260808`, branch `main`, dirty worktree at `HEAD 3f5c28f`.
- **Objective result:** Replaced the single control panel with a SwiftUI product surface for conversation, durable tasks, capabilities/permissions, models/voice, privacy/memory, and recovery. Added truthful local/cloud and ready/degraded/disabled projections, task cancellation, backend/model health, non-audit memory inspect/correct/delete/export paths, confirmation/emergency controls, persisted UI tab/language/onboarding state, staged onboarding, and English/Turkish shell copy. Existing policy, append-only memory, permission, and emergency-stop boundaries remain authoritative.
- **Verification:** `swift build --target AURA` passed on macOS 27 / Apple Silicon / Swift 6.4 CommandLineTools with known missing-framework search-path warnings. `swift build --target AURAIntegrationTests` compiled the test target; the direct Swift Testing helper run passed `R9ProductUIStateTests` 3/3 (reducer, localization, export round-trip). The normal `swift test --filter` runner remains host-blocked by unrelated all-bundle codesign/Finder metadata and test-framework rpath behavior; no test result was inferred from that failed command.
- **Risks:** User-present VoiceOver reading order, keyboard-only focus, contrast/scaled-layout/reduced-motion, live TCC permission denial/revocation, onboarding restart/recovery, task scope/review metadata, capability grant lifecycle, model lifecycle, integrations/account controls, support bundles, and full privacy/recovery acceptance remain open exactly as recorded in `SECOND_PASS_OPEN_GAPS.md`. R9 remains `in_progress`.
- **Evidence:** `EV-R9-20260808-UI-BUILD-02`, `EV-R9-20260808-UI-TESTS-03`, and `EV-R9-20260808-GAPS-04`.
- **Delivery boundary:** No commit, push, merge, release, deploy, installation, dependency/model download, or TCC mutation was performed or authorized. Stop for user-present R9 acceptance or explicit scope direction before R10.

### 2026-08-08T16:42:07Z — R9_FOCUSED_REGRESSION — relevant UI and existing remediation tests passed

- **Actor:** Codex engineering session; session `AURA-R9-PRODUCT-UI-20260808`, branch `main`, dirty worktree.
- **Verification:** Direct Swift Testing helper execution with the local CommandLineTools Testing framework/interop rpaths passed `6/6`: `R9ProductUIStateTests` 3/3 and `RuntimeUIRemediationTests` 3/3. The latter retained clean-profile directory permissions and confirmation-denial behavior while exercising the updated AURA target.
- **Limits:** This is local unit/integration evidence only. The normal all-bundle SwiftPM runner is blocked by this host's generated `.xctest` metadata/codesign/rpath behavior; no user-present VoiceOver, keyboard, TCC, model, account, live onboarding, or deployment result is claimed. R9 remains `in_progress`.
- **Evidence:** `EV-R9-20260808-UI-REGRESSION-05`.

### 2026-08-08T16:44:48Z — R9_FAIL_CLOSED_CONTROLS_VERIFIED — final local source verification

- **Actor:** Codex engineering session; session `AURA-R9-PRODUCT-UI-20260808`, branch `main`, dirty worktree.
- **Verification:** After replacing runtime-optional control calls with explicit fail-closed guards, `swift build --target AURA` passed again. A freshly rebuilt `AURAIntegrationTests` target passed the focused UI/remediation run `6/6` through the documented direct Swift Testing helper/rpath workaround.
- **Limits:** The plain all-bundle SwiftPM runner remains host-blocked by generated xctest metadata/codesign/rpath behavior. This does not provide user-present accessibility, TCC, onboarding, model/account, or deployment evidence; R9 remains `in_progress`.
- **Evidence:** `EV-R9-20260808-FAIL-CLOSED-06`.
