# AURA Runtime Completion Risk Register

Status values: `Open`, `Mitigating`, `Blocked`, `Accepted`, `Closed`. Probability/impact: `Low`, `Medium`, `High`, `Critical`.

| ID | Risk | Track | Probability | Impact | Status | Required mitigation / closure evidence |
|---|---|---:|---:|---:|---|---|
| RISK-SECOND-PASS-SYNC-DRIFT | The open-gap register, anti-amnesia context, prompt manifest, machine state, focused ledger, or handoff can drift while a prompt is being executed. | SP-000–SP-033 | Medium | High | Mitigating | Keep one active prompt, require predecessor completion, record cognitive answers/evidence in every projection, and run `python3 scripts/validate_second_pass_program.py` before every transition. Closure requires the chain-end reconciliation to prove no projection drift. Evidence: `EV-SECOND-PASS-20260809-CONTROL-PLANE-01`, `EV-SECOND-PASS-20260809-CONTROL-PLANE-02`. |
| RISK-STATE-CONTRADICTION | Legacy state and handoff prose contains stale and contradictory completion claims. | R0 | High | High | Closed | Canonical machine state and handoff are reconciled to live `62f96da`; `ledger/CURRENT_STATE.md` and `SESSION_STARTER.md` now contain canonical pointers and explicit historical/compatibility markers, while the validator blocks pointer drift. Closure evidence: `EV-R0-20260802-LEGACY-REDIRECT-01`, `EV-R0-20260802-STATE-VALIDATOR-01`. |
| RISK-TOOLCHAIN-PREVIEW | Swift/macOS baseline may depend on a preview or locally unusual toolchain. | R0 | High | High | Open | Exact pinned toolchain manifest, supported release target, stable-build strategy, CI validation. |
| RISK-DISCONNECTED-RUNTIME | Services are constructed but not registered or reachable through the user runtime. | R1 | High | Critical | Closed | Typed runtime health registry, live health events, composition-root registration, and the fresh 20-bundle integration regression close the R1 scope. Evidence: `EV-R1-20260802-FULL-SUITE-01`, `EV-R1-20260802-TRACE-HEALTH-01`. |
| RISK-FALSE-SUCCESS | Process/tool success may be reported without independent postcondition verification. | R1 | Medium | Critical | Mitigating | R1 separates executed, verifying, verified, failed, and unknown transaction states and tests failed verification. Universal capability-specific postconditions remain required in later capability tracks. Evidence: `EV-R1-20260802-TRACE-HEALTH-01`. |
| RISK-CONFIRMATION-RESUME | Confirmations may be denied twice, lost, replayed, or resume against changed state. | R1 | Medium | Critical | Mitigating | Immutable transaction hash, nonce/expiry, context binding, one-time execution, replay/plan-change tests, and fail-closed new-process behavior are implemented. Durable checkpoint/resume is explicitly deferred. Evidence: `EV-R1-20260802-TRACE-HEALTH-01`. |
| RISK-EVENT-CORRELATION | Conversation and downstream events can lose the original correlation/causation chain. | R1 | High | High | Closed | Immutable `TurnContext`, context-aware wake/STT/conversation/policy/tool paths, actual backend metadata, and trace integration tests close the R1 scope. Evidence: `EV-R1-20260802-TRACE-HEALTH-01`, `ADR-035`. |
| RISK-ENGLISH-ONLY-INTENT | Turkish STT output is routed through an English-oriented closed grammar. | R2 | High | High | Mitigating | Bilingual deterministic grammar, Turkish morphology and polite paraphrases, mixed-language ambiguity handling, 11-case golden corpus at 100%, structured local NLU boundary, and 44 focused Intent tests. A live direct-Ollama benchmark confirms correct English/Turkish/mixed-language model output and warm first-token latency of 165-182 ms. A live production-path text-turn run (after fixing a missing default policy grant, see `RISK-OLLAMA-GRANT-MISSING-FIXED` below) showed all validated golden-corpus general questions routed to clarification rather than an answer, because gemma4:latest's structured-NLU JSON proposals did not satisfy `ClassificationResult.applying`'s strict gate (see `RISK-STRUCTURED-NLU-MODEL-QUALITY`). Real microphone/TCC audio demonstration remains open because this session has no GUI/Accessibility control. Evidence: `EV-R2-20260802-FOCUSED-INTENT-DIALOGUE-01`, `EV-R2-20260802-FULL-SUITE-FINAL-03`, `EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01`, `EV-R2-20260803-APP-LAUNCH-LIVE-01`, `EV-R2-20260803-TEXTDEMO-LIVE-01`. |
| RISK-OLLAMA-GRANT-MISSING-FIXED | `AuraKernel.seedDefaultGrants()` never seeded a grant for `.agentOllamaLocalInference` (riskTier `.reversible`, denied by default), so every dialogue reasoning call was policy-denied before any network call, independent of model health/residency. | R2 | High | Critical | Closed | User-authorized fix: added `Grant(capability: .agentOllamaLocalInference, patterns: [.any], confirmationRequirement: .none)` to `seedDefaultGrants()`, documented in ADR-036's 2026-08-03 addendum. Verified: full regression 20/20 bundles, 695/695 tests; live text-demo turns changed from ~30-100ms policy-denied degraded responses to ~6-9s real network round trips. `.agentOllamaCloudInference` intentionally remains ungranted (deny-by-default). Evidence: `EV-R2-20260803-TEXTDEMO-LIVE-01`. |
| RISK-STRUCTURED-NLU-MODEL-QUALITY | `gemma4:latest`'s structured-NLU JSON proposals do not reliably satisfy `IntentEngine.classify`'s strict `dialogueAct==.answer && capabilityID==nil` gate for confident `.converse` classification, and behavior is non-deterministic across identical repeated turns. | R2 | Medium | Medium | Accepted | Three sub-findings: (1) system-prompt leakage into user-facing answers — **Fixed**, `EV-R2-20260803-PROMPT-LEAKAGE-FIX-01`. (2) The prompt never told the model `capability_id` must be empty for `answer`/`clarify` acts, so it filled in a topical capability name for any domain-shaped question, permanently failing the gate regardless of sampling — root-caused by live A/B testing against the real model (0/5 pass at default temperature; temperature 0.1 made it deterministically wrong, 5/5 `clarify`, ruling out sampling as the primary cause) and **Fixed** by explicitly stating the `capability_id`-emptiness rule in `makeStructuredNLUPrompt` (`Sources/AuraIntent/IntentEngine.swift`). Verified live: 11/11 pass across English/Turkish/mixed after the fix, vs. 0/5 before; a real production-path text-demo run post-fix produced a full correct Turkish substantive answer (previously always clarified). Full regression 20/20 bundles, 696/696 tests. Evidence: `EV-R2-20260804-STRUCTURED-NLU-CAPABILITY-GATE-FIX-01`. (3) Residual `dialogue_act` sampling variance (the same weather question sometimes still gets an `execute`-shaped, fails-safe boundary response instead of an answer) was directly observed live post-fix — a genuine 8B-model-scale sampling-variance limitation, not a further wiring defect. **Accepted as bounded residual risk** (Option A) on 2026-08-07: the fails-safe boundary means the variance degrades to clarification or a safe-boundary refusal, never to unsafe execution; temperature 0.1 is empirically deterministically wrong (5/5 `clarify`), so further prompt iteration is high-risk of diminishing returns; a model upgrade risks 16 GB memory pressure and is out of scope. **Owner:** user (final authority). **Review/expiry:** 2026-09-07. **Release impact:** does not block development; re-evaluate before external beta if the local 8B model remains the reasoning backend, preserving the fails-safe boundary. Evidence: `EV-R2-20260807-STRUCTURED-NLU-SUBFINDING3-ACCEPT-01`. |
| RISK-CANNED-CONVERSATION | General conversation returns a fixed acknowledgement rather than a model-backed answer. | R2 | High | High | Closed | Production `Got it.` literal is absent; `DialogueEngine` routes ordinary conversation to typed local reasoning and returns explicit Turkish/English/mixed degraded text when unavailable. Evidence: `EV-R2-20260802-DIALOGUE-HEALTH-01`, `EV-R2-20260802-FULL-SUITE-FINAL-03`, `EV-R2-20260802-TODO-AUDIT-01`. |
| RISK-STT-MIC-NOT-CAPTURING | On the user's real desktop launch, microphone/Push-to-Talk speech input did not produce recognized transcripts — the assistant did not hear spoken utterances, even after relaunching via `open` to fix TCC bundle-identity attribution. No `os_log` lines for STT/speech/permission appeared during the session, so the exact failure point (permission never granted, STT pipeline not started/crashed, or a deeper capture bug) is undiagnosed. | R2/R7 | High | Critical | Open | Code audit (`EV-R2-20260804-PTT-PERMISSION-AUDIT-01`) traced the real capture chain and found `AuraAppModel.pushToTalk()` only passively read `permissions.speechReady` and never itself triggered the OS permission prompt — a separate menu control did that, which the user may never have found. Ruled out missing Info.plist usage-description keys (both present and correct). Fixed `pushToTalk()` to proactively request voice permissions and start STT inline. This is a plausible, defensible candidate fix, not a confirmed resolution — still requires live verification with the user present: relaunch via `open`, press Push to Talk, and observe whether the OS dialog now appears or speech is transcribed. If `AVAudioApplication.shared.recordPermission`/`SFSpeechRecognizer.authorizationStatus()` already report `.denied` from an earlier mis-attributed launch, the request APIs will silently no-op by design and the user must reset via System Settings instead (`PermissionCoordinator.openPrivacySettings`). Blocks R2's full (voice, not just typed-text) hardware completion demonstration. Evidence: `EV-R2-20260803-REAL-DESKTOP-SESSION-01`, `EV-R2-20260804-PTT-PERMISSION-AUDIT-01`. |
| RISK-OLLAMA-COLDSTART-BUDGET-REJECTION | `OllamaAdapter.ensureMemoryBudget` compared a candidate model's on-disk `/api/tags` file size against `OllamaConfiguration.maxResidentModelBytes` (default 6 GB) on a cold load, rejecting `gemma4:latest` (9.6 GB on disk) even though its real quantized VRAM footprint is only ~3.2 GB once loaded (proven in `EV-R2-20260803-OLLAMA-LIVE-BENCHMARK-01`). The check only bypassed this when a model of the exact same name was already `ollama ps`-resident. This caused a genuine "model unavailable" failure on the user's first real, unprimed app launch. | R2/R7 | High | High | Fixed | Added `OllamaConfiguration.estimatedResidentMemoryRatio` (default `0.5`, conservative margin above the ~0.33 ratio actually observed for `gemma4:latest`); `ensureMemoryBudget` now derates a not-yet-resident candidate's disk size by this ratio before comparing against the budget, instead of treating on-disk size as VRAM. Already-resident models are unaffected and still use real measured `size_vram`. New regression test `ollamaAdapterAllowsColdLoadWhenDiskSizeExceedsBudgetButEstimatedResidentSizeFits` reproduces the exact real numbers and asserts a zero-eviction successful load. Full regression re-passed 20/20 bundles, 696/696 tests across three runs, no flakiness. Evidence: `EV-R2-20260803-OLLAMA-BUDGET-FIX-01`. |
| RISK-CLOSED-TOOL-ROUTER | Five-intent switch prevents safe extensibility and encourages disconnected features. | R3 | High | High | Mitigating | `CapabilityRegistry`/`CapabilityManifest`/`CapabilityPlanner` (`Sources/AuraIntent/CapabilityRegistry.swift`, `CapabilityPlanner.swift`) replace `ToolRegistry`/`ToolContract` (deleted) as the sole production source of capability contracts; unknown/wrong-version/disabled capabilities fail closed at lookup and at plan-validation time; `ToolRouter` sources all five existing capabilities from the registry with zero regression (full suite unchanged). Still `Mitigating` not `Closed`: only 10 of the 14 registered capabilities are reachable (4 filesystem/URL capabilities are truthfully `.disabled`, no adapter yet), and the required 7-scenario live completion demonstration has not been performed. Evidence: `EV-R3-20260804-CAPABILITY-REGISTRY-PLANNER-01`, `ADR-038`. |
| RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER | Real action executor exists without a production typed planner/user route. | R4 | High | Critical | Closed | `DeterministicComputerUsePlanner` is the first production `ComputerUsePlanning` conformer, emitting only closed `ComputerUsePlan` values; `ComputerUseBetaAllowlist` structurally gates every production target; `ComputerUseConfirmationStore`/`ComputerUseVerifier` add resumable hash-bound confirmation and semantic postcondition verification; ADR-039 accepted. SP-007 expanded the fixture table to 3 apps (Finder, Terminal, Notes) × 3 action types and live-validated all three: 9/9 live actions passed with semantic postconditions and no unsafe fallback. `.delete` mandatory-confirmation did not execute destructively. 21/21 bundles, 0 failed. Evidence: `EV-SP-007-20260816-FIXTURES-01`, `EV-SP-007-20260816-LIVE-02`. **Closed** — live gate satisfied. Residual: tests used AppleScript/System Events, not the AURA app's own `ComputerUseControlLoop.run` path. |
| RISK-INDIRECT-PROMPT-INJECTION | Web/mail/document/screen content can attempt to redirect tools or policy. | R4/R5/R10 | High | Critical | Mitigating | R5 external page/mail/event/contact content is typed with non-authoritative provenance, scanned by `PromptInjectionClassifier`, and blocked on direct injection fixtures; content cannot influence actions structurally. The Gmail leg now also has direct live injection-blocking and no-leakage evidence. General R10 coverage and live browser/document acceptance remain open. Evidence: `EV-R5-20260808-READ-FIRST-ADAPTERS-01`, `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. |
| RISK-MISSING-PRODUCTIVITY-ADAPTERS | Browser, mail, calendar, and contacts workflows are absent. | R5 | High | High | Mitigating | Typed read-first Safari bridge, Gmail read adapter, EventKit calendar adapter, and Contacts candidate adapter exist. Gmail OAuth, user-reachable read/thread summary, ambiguity, offline, injection refusal, and revocation passed live under SP-011. Safari approved-page/native messaging and Calendar/Contacts live/TCC paths, plus draft/mutation flows, remain open. Evidence: `EV-R5-20260808-READ-FIRST-ADAPTERS-01`, `EV-SP-009-20260817-CORRECTION-02`, `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. |
| RISK-SAFARI-BRIDGE-NOT-LIVE | The Safari read bridge is packaged and authenticated but not installed, signed, or live-verified; the real native-messaging round trip and real app-group shared container are not exercised. | R5 | High | High | Open | The `browser.read` capability stays disabled until the live package and trust path are verified (SP-010/SP-011). Xcode 27.0 is present, but no live extension package/install/trust-path/native-messaging evidence was available in the retry. The deterministic path is complete and tested end-to-end under `EV-SP-009-20260817-CORRECTION-02`; only the live leg remains. Evidence: `EV-SP-009-20260817-PACKAGING-AUTH-01`, `EV-SP-009-20260817-CORRECTION-02`, `EV-SP-009-20260817-CLOSEOUT-03`, `EV-SP-011-20260818-LIVE-RETRY-03`. |
| RISK-OAUTH-OVERPRIVILEGE | Productivity integrations may request broader scopes or retain tokens insecurely. | R5/R10 | Medium | Critical | Mitigating | Closed OAuth tiers reject read-to-compose/send escalation; the live grant used only Gmail read-only scope; token material remained behind the Keychain boundary; both the local credential and Google grant were removed; post-revoke reads disabled immediately. Cross-provider/support-path leakage coverage remains open. Evidence: `EV-R5-20260808-READ-FIRST-ADAPTERS-01`, `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. |
| RISK-VSCODE-POLICY-NOT-ENFORCED | VS Code adapter emits a policy request but does not await/enforce a decision. | R6 | High | Critical | Closed | `VSCodeAdapter` awaits `PolicyEngine` before CLI, shell, or bridge execution and fails closed for missing, denied, or confirmation-required decisions; live dirty-buffer and confirmation-required fail-closed behavior was proven against the real Keychain-authenticated bridge under `EV-SP-012-20260821-LIVE-ACCEPTANCE-02`. `AuraVSCodeTests` covers deny/confirm paths. Production coding-agent natural-language routing enters the coordinator. Evidence: `EV-R6-20260808-POLICY-BRIDGE-01`, `EV-R6-20260808-TYPED-ROUTES-02`, `EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01`, `EV-SP-012-20260821-LIVE-ACCEPTANCE-02`. |
| RISK-BRIDGE-INCOMPLETE | VS Code task/test bridge routes fail and bridge authentication is absent. | R6 | High | High | Closed | Authenticated typed command/response routes over HMAC-SHA256 envelopes with protocol version, extension ID, nonce replay defense, freshness, payload-size, and tamper checks; companion extension 0.2.0 installed and live, both halves paired with a matching secret, and live authenticated editor/workspace round trips proven under `EV-SP-012-20260821-LIVE-ACCEPTANCE-02`. All six failure modes (disconnect, version mismatch, replay, stale editor, dirty buffer, confirmation) and revoke-to-fail-closed exercised live. Evidence: `EV-R6-20260808-POLICY-BRIDGE-01`, `EV-R6-20260808-TYPED-ROUTES-02`, `EV-SP-012-20260820-DETERMINISTIC-BRIDGE-01`, `EV-SP-012-20260821-LIVE-ACCEPTANCE-02`. |
| RISK-AGENT-BACKEND-DRIFT | Codex/Claude/Copilot interfaces, auth, or flags may change. | R6 | Medium | High | Mitigating — reduced | The installed local CLIs were probed under SP-013 through the production `AuraShellAgentBackendCommandRunner` (real `codex` 0.142.0, `claude` 2.1.195, `copilot` 1.0.80), recording exact version/interface evidence while keeping authentication and model availability `unverified`, so write-capable routing fails closed. The `CodingTaskCoordinator` now routes the resolved workspace/worktree and mode sandbox tier into the per-backend runner context. Live auth/model/cancellation/network/budget evidence and a live model turn remain required (first-pass R6 live gate). Evidence: `EV-R6-20260808-TYPED-ROUTES-02`, `EV-SP-013-20260821-COORDINATOR-ROUTING-01`, `EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01`. |
| RISK-NO-LIVE-BACKEND-TURN | No backend can currently produce a genuine model turn on this machine: claude `-p` returns the session limit (resets 8:50pm Europe/Istanbul) and `--permission-mode dontAsk` blocks Write/Bash by design; codex default model `gpt-5.6-luna` requires a newer CLI and `gpt-5.1-codex` is rejected for a ChatGPT account; copilot monthly quota is exhausted. This blocks SP-014's P1 read-only and P2 write-capable live-turn legs and the first-pass R6 live gate. | R6 | High | High | Mitigating — reduced | SP-014 live acceptance is now COMPLETED via claude: claude session limit reset and the write-capable mode now uses `--permission-mode acceptEdits` (derived from the tool profile) so a write-capable task actually writes; `WorktreeManager.diff` captures untracked files via `git status --porcelain`. P1 read-only and P2 write-capable live turns pass with real evidence. Only the codex/copilot live-turn legs remain open (external account/CLI limits: codex default model needs a newer CLI, `gpt-5.1-codex` rejected for a ChatGPT account, copilot quota exhausted). Evidence: `EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01`, `EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02`. |
| RISK-NO-REAL-WAKE-WORD | Only a synthetic test detector exists. | R7 | High | Medium | Mitigating — explicitly excluded from release scope (SP-015) | **SP-015 decision (2026-08-22):** wake word is **explicitly excluded from the release scope** (`EV-SP-015-20260822-WAKE-EXCLUSION-01`). Production uses `DisabledWakeWordDetector` and truthful Push-to-Talk-only UI; `MarkerWakeWordDetector` is test-only. No licensed local candidate is provisioned/bundled (inventory: `AURA_RUNTIME_COMPLETION/context/WAKE_MODEL_INVENTORY.md`) and `download_models`/`install_dependencies` are forbidden, so qualification is not lawfully possible. The exclusion makes the risk bounded (no false wake-word claim), but the risk stays open for future enablement: a real local model, FAR/FRR, anti-trigger, license/hash, and soak evidence are still required before wake word can be re-enabled. Evidence: `EV-SP-015-20260822-WAKE-EXCLUSION-01`. |
| RISK-MODEL-MEMORY-PRESSURE | STT/NLU/TTS models can exceed 16 GB resource/thermal budgets. | R7 | High | High | Open | `VoiceResourceGovernor` provides bounded STT/neural-TTS reservations, memory-pressure/thermal admission, circuit breaking, and — added SP-017 (`EV-SP-017-20260823-GOVERNOR-IDLE-UNLOAD-01`) — **idle unload** of stale reservations. The local **Ollama reasoning path is now admitted through the shared governor** (reserves `.reasoning` 2 GB, fail-closed on denial) on top of its own `maxResidentModelBytes`/thermal budget. `screenVision` and `codingAgent` remain explicitly un-admitted (documented exclusions in ADR-042). Measured 16 GB co-resident pressure/energy/soak evidence is still open. |
| RISK-NEURAL-TTS-LATENCY | Chatterbox CPU synthesis is too slow and MPS stalled in live evidence. | R7 | High | Medium | Open | CPU is the safe default; helper timeout, reservation, cleanup, and Yelda fallback are implemented. Live first-audio/CPU latency, MPS qualification, consented reference, and human listening evidence remain open; system-TTS-only release is allowed. |
| RISK-STT-ROUTER-QUALITY | Native Speech locale fallback does not prove bilingual or mixed-language transcription quality. | R7 | High | High | Open | Router and on-device capability checks are implemented with engine metadata and duplicate-safe stream reuse. SP-016 added a deterministic turn-end latency metric (`STTPipeline.Metrics.turnEndLatencySeconds`) and a fail-closed test proving non-stable/error transcripts are never promoted to a stable command segment (`EV-SP-016-20260822-TURN-END-METRIC-01`); a live read-only observation confirmed the app reports `stt ready` + Microphone/Speech `Granted` (`EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02`). **Measured and partly closed 2026-08-22** (`EV-SP-016-20260822-BILINGUAL-QUALITY-03`): a signed diagnostic probe bundle holding a scoped Speech grant ran 48 recognitions through the real on-device engine (8 utterances x clean/noisy-10dB/far-field x contextual-hints on/off). Turkish and English **general and command** speech pass at **entity recall 1.000** in every band (WER 0.000-0.306, the residual being number normalization such as "on beste" -> 15:00), finalization latency 0.05 s. **Code-switched English technical tokens inside Turkish fail** (WER 0.562 / entity recall 0.417; `npm install` -> "DPM insan", `pull request` dropped), and contextual hints did **not** recover them (0.833 -> 0.792) - that capability is now **explicitly excluded from release scope**, with fail-closed behaviour locked by `SP016BilingualFailClosedTests`. **Still open:** human-speech quality (accent, disfluency, real room acoustics, real microphone colouration) and live microphone acceptance - the corpus is synthetic and is an optimistic bound. |
| RISK-VOICE-RECOVERY-LIVE | Audio interruption, device changes, sleep/wake, permission revocation, and barge-in may diverge on real hardware. | R7 | Medium | High | Open | Local cancellation/fallback and bounded continuation tests exist, and `AuraAudio` handles `AVAudioEngineConfigurationChange` recovery. SP-016 confirmed the running app truthfully reports its STT/audio/voice-resource/wake health (`EV-SP-016-20260822-LIVE-STATE-OBSERVATION-02`) but does not substitute for user-present headset/device/sleep/TCC/barge-in/echo/recovery evidence, which remains required. **Named blocker recorded 2026-08-22** (`EV-SP-016-20260822-BILINGUAL-QUALITY-03`): `AuraAudio.handleConfigurationChange` (device-change recover-and-restart) is implemented but has **zero test coverage**, because reaching `state == .running` requires a real `AVAudioEngine` input node and therefore a **Microphone** grant for the test host; SP-016's scoped authority covered **Speech only**. Concrete closure path: extend the SP-016 probe bundle with a Microphone usage description and grant, post `.AVAudioEngineConfigurationChange`, and assert the recover-and-restart path. **Corrected 2026-08-22** (`EV-SP-016-20260822-RECOVERY-MATRIX-04`): the Microphone-grant blocker above was wrong — asserted from the code, not checked. `AuraAudio.start()` reaches `.running` in the SwiftPM test host, so device-change recovery was testable all along. The same audit found that **sleep/wake recovery did not exist at all**. Both are now implemented and covered by `SP016DeviceRecoveryTests` (4 tests), including the privacy invariant that neither a device change nor a wake reopens the microphone after an explicit user stop. Every leg named by SP-016 Procedure step 2 is now implemented and deterministically covered; self-trigger protection is not applicable in the Push-to-Talk-only shipped scope. **Still Open, narrowed:** coverage is notification-driven, not physical — no headset is unplugged, no real CoreAudio route change occurs, the machine is never actually slept, and acoustic barge-in/echo over a real speaker-to-mic path needs a speech-capable operator.  **Stabilized 2026-08-23** (`EV-SP-016-20260823-FLAKY-RECOVERY-STABILIZATION-05`): the recovery suite was flaky (async `Task { for await }` observer-registration race dropped notifications; cross-suite `.serialized` allowed two suites to open the same mic). `AuraAudio` now registers synchronous `NotificationCenter.addObserver` tokens, all mic-opening tests live in one `.serialized` suite, and a generous `waitUntil` poll replaced the short fixed poll; `AuraAudioTests` passed six consecutive runs and the full suite is 21/21 bundles, 0 failed. Physical verification of these legs remains open. |
| RISK-MEMORY-NOT-PRODUCTIZED | Memory/context exists but is not yet visibly or materially used and controlled across the complete assistant product path. | R8 | High | High | Open | Local policy/context slice is implemented and focused-tested under `EV-R8-20260808-MEMORY-POLICY-01` and `EV-R8-20260808-CONTEXT-PRODUCT-02`; production reference-candidate wiring, user-present product demonstrations, R9 controls, and ADR-043 acceptance remain open. |
| RISK-MEMORY-LIVE-ACCEPTANCE | Restart-safe preferences, multi-turn references, ambiguity handling, contradiction correction, and user controls have not passed a user-present launched-app acceptance. | R8 | High | High | Open | Run the exact live product scenarios with the user present, record account/process/hardware authority and residuals, and retain local focused evidence as subsystem evidence only. |
| RISK-MEMORY-REFERENCE-WIRING | Context resolver contracts exist, but production candidate population from dialogue salience, recent files, tools, workspaces, and durable tasks is incomplete. | R8 | High | High | Mitigated | **SP-018 local composition resolved** under `EV-SP-018-20260823-PRODUCTION-REFERENCE-WIRING-01`, `EV-SP-018-20260823-FOCUSED-TESTS-02`, and `EV-SP-018-20260823-FULL-SUITE-03`: candidates are bounded, provenance-aware, scope/expiry filtered, authority-ranked, deduplicated, and fail closed before action. User-present restart/product controls, R9 surface acceptance, remote transport, and ADR-043 remain open under the other R8 risks. |
| RISK-MEMORY-REMOTE-TRANSPORT-EVIDENCE | Remote context delivery is fail-closed, but there is no provider/transport evidence proving that sensitive or unapproved memory cannot leave the machine. | R8 | Medium | Critical | Mitigated | **SP-020 (2026-08-25) closed the exclusion branch** (`EV-SP-020-20260825-REMOTE-BOUNDARY-01`): a static inventory found no production remote-context transport or caller of `remotePublicOnly`/`ContextDeliveryPolicy(destination: .remoteModel)`; remote delivery is rejected fail-closed at the context boundary (`ContextBuilder_Build.swift`); `PreferencePolicyBounds` (cloudContextAllowed=false) makes local-only non-weakening; `AuraContextTests` 37/37 (incl. `r8RemoteContextFailsClosedBeforeAnyTransmission`) and `AuraMemoryTests` 30/30 (incl. `r8PreferenceProfilePersistsAndCannotWeakenLocalOnlyPolicy`) pass; live socket traces in `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14` show zero non-loopback peers. Local-only is the explicit product boundary; a future redacted/user-approved remote path still requires separate evidence. |
| RISK-ADR-043-PENDING | The R8 memory/personalization/control architecture has not received explicit user acceptance at its completion gate. | R8 | High | High | **Closed** | **2026-08-25 (SP-020):** ADR-043 is **Accepted** under the explicit local-only remote-boundary scope with alternatives, retention, and a 2026-09-07 review date. SP-020's exclusion branch was proven (`EV-SP-020-20260825-REMOTE-BOUNDARY-01`) and all eight live R8 scenarios passed on one build (`EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14`). Evidence: `EV-SP-020-20260825-REMOTE-BOUNDARY-01`, `EV-SP-020-20260825-CLOSEOUT-02`. |
| RISK-CONTROL-PANEL-NOT-ASSISTANT-UI | Existing menu was insufficient for dialogue, tasks, health, permissions, evidence, and recovery. | R9 | High | High | Mitigating | R9 now provides the six product surfaces, text fallback, onboarding, and recovery projections. User-present accessibility/localization evidence and remaining task/capability/model/control lifecycle coverage are still required for closure. Evidence: `EV-R9-20260808-UI-BUILD-02`, `EV-R9-20260808-UI-TESTS-03`. |
| RISK-R9-LIVE-ACCESSIBILITY | UI semantics, focus order, VoiceOver announcements, keyboard-only operation, target size, contrast, and scaled-text reflow have not passed a user-present macOS accessibility review. | R9 | High | High | Mitigating | **2026-08-25 (SP-021):** non-color status (text+symbol+label), keyboard shortcuts (confirmation Deny/Allow, emergency stop Cmd+Shift+Escape, Push-to-Talk Cmd+Shift+Space), confirmation expiry and `.isModal` focus containment, reduced motion (no animations), and Dynamic Type scaling (relative text styles) are implemented. Live user-present verification confirmed the AX reading order is logical and keyboard-only focus reaches every primary control. VoiceOver *spoken* audio is not recorded to a file (AX reading order is the programmatic equivalent, observed live); a formal automated contrast ratio is not numerically computed (semantic system colors). Evidence: `EV-SP-021-20260825-DYNAMIC-TYPE-LIVE-03`, `EV-SP-021-20260825-LIVE-ACCESSIBILITY-04`. |
| RISK-R9-LOCALIZATION | Turkish/English product strings, status/error guidance, dates, and layout behavior may be incomplete or inconsistent. | R9 | Medium | High | Mitigating | **2026-08-25 (SP-021):** the status pill, capability ready/no-evidence detail, and disabled/degraded reason prose are localized to Turkish (`AuraAppStatus.title(for:)`, `AuraAppModel.displayStatusDetail`, `capabilities.noEvidence`, `AuraAppModel.localizedReason(_:)`), verified live in the AX tree and menu-bar status. Evidence: `EV-SP-021-20260825-ACCESSIBILITY-LOCALIZATION-01`, `EV-SP-021-20260825-FOLLOWUP-02`, `EV-SP-021-20260825-DYNAMIC-TYPE-LIVE-03`, `EV-SP-021-20260825-LIVE-ACCESSIBILITY-04`. |
| RISK-R9-DISABLED-REASON-LOCALIZATION | The capability disabled/degraded reason prose (produced by subsystem availability enums, e.g. "VS Code bridge not authenticated: ...", "Contacts reading is turned off ...") is English in the Turkish UI. | R9 | Low | Medium | Mitigating | **2026-08-25 (SP-021 follow-up):** `AuraAppModel.localizedReason(_:)` now maps the known English reason fragments to Turkish when the UI language is Turkish, wired into both the capability and integration panels; unknown reasons fall through unchanged. Covered by `R9ProductUIStateTests.disabledReasonLocalizesToTurkish`. Evidence: `EV-SP-021-20260825-FOLLOWUP-02`. |
| RISK-R9-ONBOARDING-RECOVERY | Staged permission onboarding, denial/revocation recovery, no-model/offline states, emergency stop, safe mode, and restart restoration are not yet exposed as a verified product path. | R9 | High | High | Open | Keep permission requests user-triggered and least-privilege; implement explicit stages and actionable recovery without claiming unavailable backend capabilities. |
| RISK-MAIN-PROCESS-PRIVILEGE-CONCENTRATION | Main process combines Accessibility, generated input, CLI, models/network, and UI. | R10 | High | Critical | Mitigating | Typed/hash-bound/replay-protected helper envelopes and helper-kind capability allowlists are implemented, but helpers are parent-launched echo boundaries and the main process still retains broad authority. Authenticated peer transport, real helper execution, entitlements, and compromise-boundary evidence remain required. Evidence: `EV-R10-20260809-BOUNDARY-SLICE-01`. |
| RISK-NETWORK-ALLOWLIST-INCOMPLETE | Allowlist object may not be enforced by every network path. | R10 | Medium | Critical | Mitigating | Endpoint scheme/host/port/path checks and redirect rejection cover the Ollama loopback client; a mandatory client factory, DNS/IP revalidation, TLS/proxy/download bounds, provider transport, and subprocess audit remain open. Evidence: `EV-R10-20260809-BOUNDARY-SLICE-01`. |
| RISK-IPC-PEER-AUTH-ABSENT | A typed pipe envelope can be replay/tamper resistant without authenticating the OS peer that supplied it. | R10 | Medium | Critical | Open | Add authenticated XPC/peer identity or an independently reviewed equivalent, bind authorization to the verified process identity, and test compromised-parent/helper scenarios. |
| RISK-OAUTH-LIFECYCLE-INCOMPLETE | OAuth contract and Keychain expiry handling exist, but provider transport, callback isolation, live revocation, and leakage coverage are incomplete. | R10 | Medium | Critical | Open — reduced | Gmail now has a PKCE/state-bound loopback exchange, approved-account probe, Keychain enrollment, user-reachable connect control, live local/provider revocation, and immediate fail-closed post-revoke evidence. Direct Privacy-tab automation was not observed because the Computer Use native pipe closed on that SwiftUI tab, and cross-provider/expiry/support-path leakage coverage remains open. Evidence: `EV-R10-20260809-BOUNDARY-SLICE-01`, `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. |
| RISK-PLUGIN-TRUST-EVIDENCE-ABSENT | Plugin isolation and manifests do not yet prove signed vendor roots, revocation, quarantine, rollback, or SBOM/checksum enforcement. | R10 | Medium | Critical | Open | Define and independently review plugin trust/update policy; enforce signature/hash/vendor/revocation/quarantine/rollback checks with offline and compromised-update tests. |
| RISK-NOT-NOTARIZED | Development signing may be mistaken for distributable release readiness. | R11 | High | High | Open | Developer ID, hardened nested signing, notarization, staple, clean Gatekeeper evidence. |
| RISK-NO-SIGNED-UPDATER | No implemented authenticated update/rollback path. | R11 | High | Critical | Open | Signed manifest/package, atomic update, downgrade/replay protection, rollback tests. |
| RISK-NO-LAUNCH-AT-LOGIN | Continuously available assistant lacks supported user-controlled launch at login. | R11 | High | Medium | Open | ServiceManagement implementation, UI control, sleep/wake/crash recovery evidence. |
| RISK-NO-REPRODUCIBLE-ARCHIVE | A local deterministic ZIP, provenance-bound manifest, bundle inventory, SBOM, and checksum validator now exist, but the toolchain is not fully pinned, CI execution is unobserved, and nested bundle/entitlement/signature/release verification remains incomplete. | R11 | High | High | Mitigating | Add full-Xcode/pinned-toolchain archive evidence, observed CI artifact retention, bundle-layout/entitlement/signature verification, and external clean-machine checks; development-only evidence must not be treated as release proof. |
| RISK-NO-RECOVERY-DIAGNOSTICS | Safe mode, launch-at-login lifecycle, support bundle review, uninstall/factory reset, and update migration recovery are design-only or absent. | R11 | High | Critical | Open | Implement user-controlled operations with redaction, backups, atomic migration, rollback, low-disk/corrupt-artifact handling, and clean-profile acceptance. |
| RISK-NO-INDEPENDENT-BETA-EVIDENCE | Unit/integration evidence may not reflect real daily use. | R12 | High | Critical | Open | Dogfood/beta window, SLO dashboard, incident review, security/accessibility sign-off, RC evidence package. |
| RISK-NO-BETA-CONSENT-BOUNDARY | No approved beta cohort, supported-matrix boundary, participant privacy notice, content-free telemetry consent, issue SLA, or rollback/kill-switch owner exists. | R12 | High | Critical | Open | Define and approve an internal-only cohort, explicit opt-in consent, content-free aggregate schema, exclusion list, incident SLA, and rollback/kill-switch authority before enrollment. |
| RISK-NO-RC-EVIDENCE-PACKAGE | No signed/notarized release-candidate artifact, percentile SLO report, incident remediation record, or independent security/privacy/accessibility/release sign-off exists. | R12 | High | Critical | Open | Keep R12 in_progress; produce a provenance-bound RC evidence package only after R11 and the controlled beta gates pass. |
| RISK-FINAL-ACCEPTANCE-BLOCKED | FINAL acceptance cannot pass because R12 is not release_candidate_verified and R11/R12 evidence, security, privacy, accessibility, recovery, and clean-install gates remain open. | FINAL | High | Critical | Open | Keep FINAL blocked/in_progress; return ownership to R11/R12, preserve all exclusions, and require direct evidence or authorized scope decisions before any closure. |

| RISK-REPO-HYGIENE-GIT-OBJECT-DATABASE | The original checkout's `.git` reported fsck exit 8 with 199 bad objects and 8,925 dangling findings; the current repository now uses the independently verified candidate object database. | H-001/remediation | Critical | Critical | Closed | The candidate `.git` was adopted only after independent backup, byte comparison, exact replacement, fsck exit 0, `show-ref` exit 0, reachability exit 0, and rollback preservation. The original damaged database remains outside the repository for retention/rollback; any future migration requires explicit review. Evidence: `EV-REPO-HYGIENE-GIT-ADOPTION-20260811-01`. |
| RISK-REPO-HYGIENE-NO-VERIFIED-RECOVERY-ARTIFACT | No independently verified clean clone, byte/integrity-checked backup, or preservation mapping had been supplied for the damaged local object database. | H-001 | Critical | Critical | Closed | Closed by `EV-REPO-HYGIENE-H-001-20260809-02`: remote clone strict fsck, refs, main reachable closure, clean status, and current worktree preservation mapping were verified. This does not close the separate local object-database repair risk. |
| RISK-REPO-HYGIENE-UNKNOWN-GIT-METADATA-OWNERSHIP | `.git/refs/.DS_Store` was initially unclassified; read-only ownership/provenance evidence now identifies it as generated macOS metadata, not a Git object. | H-000 | High | Critical | Closed | Closed by `EV-REPO-HYGIENE-H-000-20260809-02`: preserve the file for separately authorized cleanup/recovery work; do not treat it as evidence that the object database is healthy. |
| RISK-REPO-HYGIENE-DOC-TOOLCHAIN-DRIFT | Active docs and scripts disagreed on macOS/Swift/test counts and contained hard-coded CLT paths. | H-004 | High | High | Closed | H-004 canonicalized active macOS 27+/Swift 6.4/21-target claims, removed stale active prompt-path guidance, parameterized the Testing macro path, and added xcode-select/xcrun discovery with fail-closed validation. Historical ledger facts remain unchanged. Evidence: `EV-REPO-HYGIENE-H-004-20260810-01`. Full-Xcode, formatter, and complete CI/test-matrix limitations remain under `RISK-REPO-HYGIENE-TOOLING-UNAVAILABLE` and H-005/H-007. |
| RISK-REPO-HYGIENE-CONTEXT-BLOAT | Large append-only ledgers and duplicated status projections can exceed useful context and create amnesia. | H-009 / second-pass context archive | High | High | Mitigating | The second-pass Tier-0/Tier-1 contract and reference index now exclude completed first-pass prompt/context prose from default loading while preserving append-only ledgers and on-demand ADR/subsystem references. Empty structural directories and one unreferenced legacy state guide were also removed/archived; generated caches remain outside this cleanup boundary. Future prompt sessions must still load only the named slices. Evidence: `EV-REPO-HYGIENE-H-009-20260810-01`, `EV-SECOND-PASS-CONTEXT-ARCHIVE-20260812-01`, `EV-SECOND-PASS-REPO-SURFACE-CLEANUP-20260812-01`. |
| RISK-REPO-HYGIENE-ARCHITECTURE-BOUNDARY-DRIFT | Package topology, capability/policy routing, and privileged helper boundaries can drift while prose still appears coherent; the main app remains non-sandboxed and helper-backed production execution is incomplete. | H-009 / ADR-034 / ADR-044 | High | Critical | Mitigating | H-009 records a twelve-layer evidence-backed audit with package graph/cycle/import checks and preserves ADR-034 `In Progress` and ADR-044 `Proposed`. Security/release owners still own helper migration, peer-authenticated IPC, live recovery, independent review, and release acceptance. Evidence: `EV-REPO-HYGIENE-H-009-20260810-01`, ADR-034, ADR-044. |
| RISK-REPO-HYGIENE-TOOLING-UNAVAILABLE | SwiftLint 0.65.0, full Xcode/SourceKit, Swift-format, shell/YAML/action, secret scanners, pre-commit, OSV, Syft, and Grype are available on the observed host; an earlier strict-policy run reported 1,330 findings. | H-005/H-007/H-008/H-010/remediation | High | High | Closed | The exact configured SwiftLint command now exits 0 with zero violations; the remaining product/release/toolchain-preview boundaries are independent of H-010. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`, `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-FORMAT-FINDINGS | The configured strict swift-format report previously found 1,019 findings across 116 Swift source/test files; bounded remediation has now removed those diagnostics without weakening the formatter configuration. | H-005 | High | High | Closed | Closed by 12 reviewed batches, three explicit trailing-closure corrections, recursive strict formatter lint exit 0, strict build exit 0, and 21/21-bundle 794/794-test regression evidence. The source diff remains style/remediation scope and must not be mistaken for release or semantic audit evidence. Evidence: `EV-REPO-HYGIENE-H-005-20260810-02`, `EV-REPO-HYGIENE-H-005-CLOSEOUT-20260810-02`. |
| RISK-REPO-HYGIENE-UNSAFE-CONSTRUCTS | Production force throws/casts and direct prints could hide failure or expose user/ambient content; 21 lock/actor `@unchecked Sendable` declarations remain after review. | H-006 | Medium | High | Mitigating | H-006 removed all production `try!`, `as!`, and direct `print()` matches; exact CF type-ID proofs, fail-closed regex/hash paths, payload-free structured diagnostics, and `.private` os-log interpolation are covered by ADR-048 and focused source/test evidence. Remaining lock/actor/callback assumptions require broader race-detector, CI, and real-hardware soak evidence owned by subsystem maintainers. Evidence: `EV-REPO-HYGIENE-H-006-20260810-01`. |
| RISK-REPO-HYGIENE-DIAGNOSTIC-PAYLOAD-EXPOSURE | Debug/log paths previously interpolated raw partial transcript, text-demo input, and conversation response summary; logger output was explicitly public. | H-006 | Low | High | Closed | Replaced reviewed raw payloads with metadata-only messages and changed all AuraLogger os-log interpolation to `.private`; direct `print()` count is zero. Re-open if a future sink writes `AuraLogEntry.message` without an equivalent privacy policy. Evidence: `EV-REPO-HYGIENE-H-006-20260810-01`, `ADR-048`. |
| RISK-REPO-HYGIENE-SWIFTLINT-SOURCEKIT-BLOCKED | Full SwiftLint 0.65.0 previously executed with SourceKit under selected Xcode 27.0 beta 5 and returned `exit 2` with 1,330 findings. | H-005/H-010 | High | High | Closed | The exact configured command now exits `0` with zero violations in 1,066 files; no policy weakening or H-011 transition occurred. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`, `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-FINAL-GATE-BLOCKED | The final hygiene gate was previously blocked by non-zero SwiftLint and hosted-CI availability. | H-010 | High | Critical | Closed | The exact local and hosted final gates pass; H-010 is terminally completed in the machine state. Product/release gates remain independent and no H-011 exists. Evidence: `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`, `EV-REPO-HYGIENE-H-010-PROJECTION-RECONCILIATION-20260812-01`. |

| RISK-SP-010-LIVE-OAUTH-TCC | SP-010/SP-011 closed the deterministic onboarding/composition slice, but live provider OAuth consent, real TCC/Contacts/Calendar permission prompts, and native account configuration are unexercised. | R5 | High | Critical | Open — reduced | Gmail OAuth consent, callback/exchange, approved-account enrollment, live reads, and two-sided revocation now pass. The remaining risk is the distinct user-present Calendar/Contacts TCC and native adapter path; no such prompt or calendar/contact result was observed. Evidence: `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. |
| RISK-SP-010-REAL-ACCOUNT-CONFIG | No real provider account has been configured or verified end-to-end through AURA. | R5 | High | High | Closed | A separately approved Gmail test account completed AURA OAuth enrollment, clean two-message thread summary, injection refusal, offline and ambiguity behavior, local Keychain revocation, Google grant removal, and immediate post-revoke disablement. No account identifier or message body is retained in evidence. Evidence: `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. |
| RISK-SP-010-NATIVE-MESSAGING-LIVE | Real Safari extension native messaging and app-group shared container have not been exercised live. | R5 | High | High | Open | Xcode 27.0 is present, but no live Safari extension package/install/run, app-group trust path, or native-messaging round trip was performed under SP-011. Evidence: `EV-SP-011-20260818-LIVE-ACCEPTANCE-BLOCKED-01`, `EV-SP-011-20260818-LIVE-RETRY-03`. |

## Rules

- Add a risk when a new failure mode is discovered; do not hide it in prose.
- Close a risk only with evidence IDs or explicit accepted-risk authority.
- `Accepted` risks must record owner, rationale, scope, expiry/review date, and release impact in a new ledger entry.
- Critical open risks block external beta unless the final authority explicitly accepts them and the release scope excludes the affected capability.

| RISK-REPO-HYGIENE-GENERATED-ARTIFACTS-IN-PLACE | Approximately 3G of generated build/environment material and caches remain in the worktree after H-002 inventory; without an authorized recoverable quarantine they can be mistaken for authored content or consume local storage. | H-002 | Medium | High | Open | Preserve the path-level ownership/disposition map; require explicit recoverable destination and manifest authority before moving or deleting `.build`, Python environments, caches, or OS metadata. Evidence: `EV-REPO-HYGIENE-H-002-20260809-01`. |
| RISK-REPO-HYGIENE-CI-CHECKOUT-DEFAULTS | CI checkout cleanup, history depth, credential persistence, and post-change execution required explicit verification. | H-003/H-007/remediation | Medium | Medium | Closed | Both workflow checkout steps use verified immutable action SHAs, `clean: true`, full-history checkout where required, and `persist-credentials: false`; final hosted run `31487128834` observed the pushed branch with governance/build success and artifact upload. No local cleanup was executed. Evidence: `EV-REPO-HYGIENE-H-007-20260810-01`, `EV-REPO-HYGIENE-HOSTED-CI-FINAL-20260811-01`. |
| RISK-REPO-HYGIENE-COVERAGE-RATCHET | The raw source-only Swift matrix remains below the 70% ratchet because native Speech/AVFoundation adapters require user-present host callbacks unavailable on a headless runner. | H-007/H-010 remediation | High | High | Closed with bounded scope | The 70% threshold was unchanged. The versioned scope now excludes exactly six documented host-boundary files: `AURA.swift`, `AuraMenuView.swift`, `PermissionCoordinator.swift`, `EmergencyShortcutMonitor.swift`, `AuraAudio/SystemTTSEngine.swift`, and `AuraSTT/SystemSTTEngine.swift`; `AuraAppModel`, `AuraKernel`, non-native adapters, and deterministic production contracts remain measured. The complete 21-bundle local run has zero failed bundles and effective coverage 70.19%, exit 0; source-only raw coverage remains visible at 64.29%. Hosted confirmation and live native speech behavior remain separate evidence gates. Evidence: `EV-REPO-HYGIENE-COVERAGE-HOST-BOUNDARY-20260811-01`. |
| RISK-REPO-HYGIENE-SECRET-SCAN-CURRENT-TREE | Current tracked-content secret scanning had no reproducible repository gate and synthetic security fixtures could be mistaken for credential material. | H-008 | High | High | Mitigating | `scripts/validate_repo_hygiene_supply_chain.py` now scans tracked content with high-confidence patterns, reports only path/line/pattern metadata, requires exact fixture markers/path/patterns, and fails closed on unallowlisted findings. Five known sentinel findings are allowed; no unallowlisted finding was observed. History scanning remains blocked on the damaged local object database and is not implied by the current-tree pass. Evidence: `EV-REPO-HYGIENE-H-008-20260810-01`. |
| RISK-REPO-HYGIENE-DEPENDENCY-SUPPLY-CHAIN | Dependency/workflow provenance requires continuous lock, source, and scanner revalidation. | H-008/remediation | High | High | Mitigating | The policy now checks zero external Swift dependencies, exact Chatterbox git revisions, the 150-package `uv.lock` graph, explicit `torchcodec` registry provenance, `uv lock --check`, and full SHA-pinned Actions. OSV and Grype report zero current lock-graph findings and Syft emits the documented SBOM; historical Git scanning and hosted CI remain separate gates. Re-open on upstream, lock, scanner, or runtime changes. Evidence: `EV-REPO-HYGIENE-DEPENDENCY-REMEDIATION-20260811-01`, `EV-REPO-HYGIENE-REMEDIATION-VERIFY-20260811-01`. |
| RISK-REPO-HYGIENE-ORIGINAL-GIT-RECOVERY | The original damaged object database required adoption of a verified recovery candidate. | H-010/remediation | High | Critical | Closed | Adopted candidate passes fsck/show-ref/reachability and the damaged original is preserved with an inverse rollback path. No object deletion or history rewrite occurred. Evidence: `EV-REPO-HYGIENE-GIT-ADOPTION-20260811-01`. |
| RISK-REPO-HYGIENE-DEPENDENCY-VULNERABILITIES | The previous Chatterbox lock graph produced 48 OSV advisories and 19 Grype matches. | Remediation | High | Critical | Closed | The current authoritative `Runtime/chatterbox/pyproject.toml`/`uv.lock` graph was independently resolved and scanned: OSV exit 0 with zero advisories and Grype exit 0 with zero matches against the Syft SBOM, excluding only generated `**/.venv/**`; runtime import/audio round-trip and helper tests pass. Re-open on upstream pin, lock, scanner, or runtime changes. Evidence: `EV-REPO-HYGIENE-DEPENDENCY-REMEDIATION-20260811-01`. |
| RISK-REPO-HYGIENE-EXTERNAL-SCANNER-POLICY | External scanners can report deterministic test/control-plane false positives; broad suppression would hide real findings. | Remediation | Medium | High | Mitigating | Keep exact path policies in `.gitleaks.toml` and `TRUFFLEHOG_EXCLUDE_PATHS.txt`, retain the fail-closed tracked-content validator, and review every allowlisted path on scanner upgrades. Evidence: `EV-REPO-HYGIENE-REMEDIATION-20260810-01`. |
| RISK-REPO-HYGIENE-TOOLCHAIN-PROVISIONED-PARTIAL | External YAML/action/secret/SBOM scanners, pre-commit, full Xcode, and SourceKit are provisioned locally; strict SwiftLint remains non-green with 1,330 findings, and local capability does not prove hosted or release behavior. | Remediation/H-010 | High | High | Open | Source owners must remediate the strict SwiftLint findings; CI/release owners must keep hosted, signing, notarization, and clean-machine evidence separate. Evidence: `EV-REPO-HYGIENE-TOOLCHAIN-XCODE-20260811-01`. |
| RISK-REPO-HYGIENE-SWIFTLINT-FORMATTER-POLICY-CONFLICT | Formatter/default SwiftLint style defaults previously conflicted on multiline trailing commas and brace placement. | H-010 | High | Critical | Closed | The reviewed formatter-compatible configuration now has a zero-finding exact run; no `disabled_rules`, path exclusion, or threshold change was introduced. Reopen only if formatter, SwiftLint, or Xcode policy changes. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-COVERAGE-SPLIT-REGRESSION | Mechanical source decomposition temporarily reduced measured coverage to 66.10% under the unchanged scope. | H-010 | High | Critical | Closed | Added measured tests and reran the unchanged canonical wrapper: 21/21 bundles, 795 tests, 0 failed bundles, 70.57% local coverage and 70.59% hosted coverage. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`, `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-SWIFTLINT-FORMATTER-POLICY-CONFLICT-RESOLVED | Formatter/default SwiftLint style defaults conflict on multiline trailing commas and brace placement; the configured bounded contract now has a zero-finding exact run. | H-010 | High | Critical | Closed for current configuration | No `disabled_rules`, new path exclusions, or threshold change was introduced. Default-policy falsification remains recorded as a compatibility warning; reopen on formatter, SwiftLint, or Xcode change. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-COVERAGE-SPLIT-REGRESSION-RESOLVED | Source decomposition temporarily reduced measured coverage to 66.10% under the unchanged six-file scope. | H-010 | High | Critical | Closed for current tree | Added measured product-state/UI projection tests and reran the unchanged canonical wrapper: 21/21 bundles, 795 tests, 0 failed bundles, 70.57%, exit 0. No scope exclusion was added. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-QUARANTINE-219-COPIES | 219 byte-identical Finder/copy artifacts were visible as untracked paths after the prior merge. | H-010 | Medium | High | Mitigating | All 219 were moved without deletion to `/Users/m_ras/Desktop/AURA-H010-QUARANTINE-20260812`; in-repository untracked count is 0 and the quarantine aggregate hash is recorded. Repository maintainer owns retention/disposition review. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-HOSTED-RUNNER-UNAVAILABLE-20260812 | Final hosted governance/build evidence could not execute because the self-hosted runner inventory was empty; the queued observation was fail-closed. | H-010 | High | Critical | Closed | A temporary ARM64 runner with labels `macOS, swift-6.4` executed final run `31598491689` successfully for governance/build/test/coverage/artifact; it was then deregistered and the API inventory returned zero. Evidence: `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`. |
| RISK-REPO-HYGIENE-CI-ARTIFACT-ROOT-20260812 | Hosted artifact build and upload paths diverged: the safe builder rejected `runner.temp`, then upload searched the old path. | H-010 | High | High | Closed | Both workflow paths now use the unique `/tmp/aura-r11-release-artifact-${{ github.run_id }}` root; final run `31598491689` produced a valid manifest and uploaded exactly two files with `if-no-files-found: error`. Evidence: `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`. |

### 2026-08-13T15:41:52Z — SP-000 synchronization-risk update

`RISK-SECOND-PASS-SYNC-DRIFT` remains **Mitigating**, not closed. SP-000 found active projection hashes at `822f339`, `b4610f`, and `6390bc8` while live `main` was `05af25d`; it reconciled the active pointers and changed the second-pass validator so handoff/context expectations derive from the active state rather than a historical `SP-000/pending` literal. The residual risk is that future prompt edits or external delivery can create new drift; every prompt must re-run the Tier-0 checks, append evidence, and pass the validator before transition. Evidence: `EV-SP-000-20260813-BASELINE-01`.

### 2026-08-14T06:55:43Z — SP-000 delivery reconciliation

`RISK-SECOND-PASS-SYNC-DRIFT` remains **Mitigating**, not closed. The authorized SP-000 delivery exposed one post-merge stale-pointer condition: non-projection changes had landed while canonical verified SHA fields still referenced the parent. The condition was corrected by updating active pointer/documentation projections to the verified delivery baseline; later descendants are projection-only. Future deliveries must rerun the runtime validator after merge and before reporting completion. Evidence: `EV-SP-000-20260814-DELIVERY-01`.

### 2026-08-14T07:06:42Z — SP-001 live-evidence blocker

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open**: the required user-present live observation, displayed confirmation, reversible mutation, and direct execution/verification trace cannot be captured under the current prompt because app launch/install is not authorized. The five prompt-relevant deterministic/integration suites passed 316 tests, but that is supporting contract evidence only and cannot prove the target-Mac live postconditions. Obtain explicit target-Mac/app-launch authority and rerun only `SP-001`; do not start `SP-002`. Evidence: `EV-SP-001-20260814-ATTEMPT-01`.

### 2026-08-14T08:44:20Z — SP-001 live evidence residual update

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open**, with the authority portion now satisfied for this bounded attempt but the universal live postcondition still unproven. Direct user-present evidence demonstrates a safe observation, displayed confirmation, one allowed reversible Calculator termination, local process verification, denial, changed-plan blocking, emergency-stop interlock, and restart no-replay behavior under `EV-SP-001-20260814-LIVE-TRACE-03`. The residual is that no redacted correlation/causation IDs were exposed or durably persisted; the confirmation-timeout terminal label was not explicit, and distinct dismissal, failed-verification, and concurrent-turn-isolation evidence are absent. Do not close this risk from screenshots, types, fakes, or model assertions; keep SP-001 blocked and do not start SP-002.

### 2026-08-14T11:11:19Z — SP-001 redacted trace implementation mitigation

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open**, but the source-level persistence/UI residual is mitigated under `EV-SP-001-20260814-TRACE-FIX-04`. The implementation now persists only a bounded redacted projection with correlation/causation/request/action/outcome fields, records confirmation requested and terminal outcomes including expiration/dismissal/supersession, and exposes short opaque trace prefixes in the confirmation/conversation UI. Core, store, integration, policy, agent, and audio suites plus all local governance validators passed. The remaining risk is independently captureable target-Mac live proof of the full universal postcondition, especially failed-verification, concurrent-turn isolation, and distinct live timeout/dismissal behavior; keep SP-001 blocked and do not start SP-002 until a separately authorized live rerun proves those cases.

### 2026-08-14T12:10:25Z — SP-001 post-fix bounded live evidence

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open but materially reduced** under `EV-SP-001-20260814-LIVE-TRACE-FIX-05`. The user-present rerun proves redacted trace prefixes in the confirmation/result UI, durable local redacted rows, date allow/deny, a Calculator confirmation expiry, one allowed Calculator close, distinct execution/verification, and `pgrep` no-process verification. The current authority intentionally excluded changed-plan, replay, dismissal, cancellation, and concurrent-turn actions; prior pre-fix evidence covers only some of those cases. Keep SP-001 blocked until the complete post-fix negative/verification matrix is separately authorized and captured; do not start SP-002.

### 2026-08-14T12:16:54Z — SP-001 mandatory closeout

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open but materially reduced**. The mandatory closeout validators and current source build passed, while the post-fix live residual remains bounded to the cases excluded by the user's authority: changed-plan, replay, dismissal, cancellation, and concurrent-turn isolation. Authority is reset to edit-only; no further live action is implied. Evidence: `EV-SP-001-20260814-CLOSEOUT-06` and `EV-SP-001-20260814-LIVE-TRACE-FIX-05`.

### 2026-08-15T09:32:18Z — SP-001 post-fix dismissal wiring and live evidence

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open but further reduced**. The
WindowGroup close path now records a redacted `confirmation.dismissed` outcome,
the focused integration test passed, and the user-present rerun confirmed
requested → dismissed → blocked with no execution. Remaining live residuals
are changed-plan, replay, cancellation, concurrent-turn isolation, and any
required failed-verification evidence. Evidence:
`EV-SP-001-20260815-LIVE-DISMISSAL-07`.

### 2026-08-15T09:45:50Z — SP-001 mandatory closeout after bounded delivery

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open but materially reduced**.
The source checkpoint was delivered and all local closeout validators passed;
the remaining risk is the unproven post-fix changed-plan, replay, cancellation,
concurrent-turn isolation, and required failed-verification matrix. Authority
resets to edit-only and no SP-002 transition is allowed. Evidence:
`EV-SP-001-20260815-CLOSEOUT-09`.

### 2026-08-15T10:44:08Z — SP-001 post-fix residual live matrix

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open but narrowly bounded**. The
direct current-build bundle proves post-fix changed-plan supersession, replay
deny/no-replay, concurrent-turn correlation isolation, truthful failed-result
handling, a reversible Calculator mutation with no-process verification, and
the existing expiry/dismissal/allow paths. Emergency-stop was exercised while
a safe confirmation was pending; it prevented execution, but the runtime
emitted no distinct `confirmation.cancelled` terminal record and the request
eventually expired. The missing cancellation postcondition remains inside
`OPEN-02`; authority resets to edit-only and `SP-002` remains unopened.
Evidence: `EV-SP-001-20260815-LIVE-RESIDUAL-10`.

### 2026-08-15T10:55:08Z — SP-001 mandatory session closeout

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Open but narrowly bounded to
cancellation**. The direct live residual and the mandatory closeout checks are
recorded under `EV-SP-001-20260815-LIVE-RESIDUAL-10` and
`EV-SP-001-20260815-CLOSEOUT-11`; the latter confirms 21/21 bundles,
794/794 tests, all governance validators, 38/38 deterministic tests, syntax,
compile, and diff checks. Authority is reset to edit-only. `SP-001` remains
active/blocked and `SP-002` remains unopened because the emergency-stop path
still lacks a distinct terminal `confirmation.cancelled` trace.
### 2026-08-15T11:17:34Z — SP-001 OPEN-02 cancellation closure

`RISK-SP-001-LIVE-TRACE-AUTHORITY` is **Closed for the bounded SP-001 / OPEN-02 prompt scope** under `EV-SP-001-20260815-CANCELLATION-12`. The current unsigned build directly produced the redacted `confirmation.requested` → `confirmation.cancelled` → `policy intent.blocked` chain for a pending safe `/bin/sleep 20` request with no execution. The same run directly verified the accepted reversible Calculator mutation, `app.quit verified`, no Calculator process, normal quit/reopen no-replay, and final process cleanup. First-pass R2–R12, FINAL, TCC, provider, beta, signing, release, deployment, and telemetry risks remain open and are outside this prompt. `SP-002` is next pending, not opened.

### 2026-08-15T11:29:26Z — SP-001 mandatory closeout

`RISK-SP-001-LIVE-TRACE-AUTHORITY` remains **Closed for bounded `SP-001` / `OPEN-02`**.
The mandatory closeout record `EV-SP-001-20260815-CLOSEOUT-13` confirms the direct
cancellation evidence, reversible mutation/no-process verification, restart no-replay,
full local regression, and all required validators. First-pass R2–R12, FINAL, TCC,
provider, beta, signing, release, deployment, and telemetry risks remain open outside
this prompt. `SP-002` remains pending and unopened; authority is edit-only.

### 2026-08-15T16:45:00Z — SP-002 OPEN-03 PTT/TCC closure with mock-STT accommodation

`RISK-STT-MIC-NOT-CAPTURING` remains **Open** for the live on-device `SFSpeechRecognizer`/microphone path. SP-002 / OPEN-03 was closed for its bounded prompt gate under `EV-SP-002-20260815-PTT-MOCK-14` by using the deterministic mock-STT engine as a documented accessibility accommodation: the user is speech-disabled and cannot produce live voice input. The PTT/TCC/STT pipeline was proven end-to-end with the mock engine: AURA was built, launched, TCC Microphone and Speech Recognition prompts were allowed, and the UI Push-to-Talk button produced the transcript `hello` displayed as `You: hello`. The temporary `Configuration_STTConfiguration.defaultEngineID` change was reverted, the app was closed, and all governance validators passed. This closes the simulated-boundary PTT/TCC/STT composition gate for OPEN-03 only; it does not close the first-pass R2 / SP-003 / R7 live Turkish/English/mixed Speech.framework voice-input quality gates. Those remain open and must not be backfilled from mock-STT evidence. `RISK-ENGLISH-ONLY-INTENT` and `RISK-STRUCTURED-NLU-MODEL-QUALITY` remain mitigating for first-pass R2 seven-scenario live evidence. No first-pass product/release/beta/signing/deploy/telemetry/provider/TCC gate is closed by this accommodation. Evidence: `EV-SP-002-20260815-PTT-MOCK-14`.

### 2026-08-15T14:44:48Z — SP-003 residual risks recorded

- **Risk ID:** `RISK-SP-003-LIVE-VOICE-RESIDUAL`
- **State:** Open / forwarded
- **Owner:** SP-003 / R2 / R7
- **Description:** User-present live microphone/TCC Turkish/English/mixed seven-scenario evidence is not feasible because the user is speech-disabled. The deterministic test evidence under `EV-SP-003-20260815-R2-DIALOGUE-TESTS-15` closes the source-side R2 dialogue/NLU contract only.
- **Mitigation:** Documented as a residual live gate. Future work must either (a) obtain a speech-capable authorized operator for the hardware demonstration, or (b) accept a durable accessibility accommodation and update the product specification accordingly.
- **Evidence:** `EV-SP-003-20260815-R2-DIALOGUE-TESTS-15`, `EV-SP-002-20260815-PTT-MOCK-14`

- **Risk ID:** `RISK-SP-003-LIVE-MODEL-RESIDUAL`
- **State:** Open / mitigating
- **Owner:** R2 / R7
- **Description:** No live Ollama daemon inference was run for SP-003; model variance, first-token latency, and structured-output validity under real load remain unproven.
- **Mitigation:** Keep Ollama/model boundaries controlled by default; run a bounded live inference sweep only under explicit authority and memory profiling.
- **Evidence:** `EV-SP-003-20260815-R2-DIALOGUE-TESTS-15`

### 2026-08-15T18:23:13Z — SP-003 risks after live seven-scenario run and injection fix

`RISK-SP-003-LIVE-VOICE-RESIDUAL` and `RISK-SP-003-LIVE-MODEL-RESIDUAL` (recorded 2026-08-15T14:44:48Z) were both raised against the retracted `EV-SP-003-20260815-R2-DIALOGUE-TESTS-15`. `RISK-SP-003-LIVE-MODEL-RESIDUAL` is now **closed**: live local inference was performed against `gemma4:latest` under `EV-SP-003-20260815-LIVE-7SCENARIO-16` and `EV-SP-003-20260815-INJECTION-FIX-17`, with 6 inferences per run, all reporting `isLocalModel == true` and a cloud inference count of 0. `RISK-SP-003-LIVE-VOICE-RESIDUAL` remains **open** and is owned by SP-002 / R7 live voice gates, not by SP-003.

- **Risk ID:** `RISK-DIALOGUE-CONTEXT-INJECTION`
- **Status:** Closed for the dialogue context path
- **Owner:** SP-003 / R2 / R10
- **Description:** Prompt-injection content carried inside an approved `DialogueContextItem` displaced the user's request; the live local model replied exactly `PWNED`. `PromptInjectionClassifier` detected the payload but was never invoked on the dialogue path, which defended only with a natural-language instruction.
- **Mitigation:** `DialogueEngine` now screens every context summary through the classifier before prompt assembly, withholding blocked content while preserving provenance, and screens as non-authoritative regardless of the item's self-declared `authority`. Three deterministic regression tests assert against the captured prompt; the live seven-scenario run passes 25/25.
- **Evidence:** `EV-SP-003-20260815-LIVE-7SCENARIO-16` (defect), `EV-SP-003-20260815-INJECTION-FIX-17` (fix)

- **Risk ID:** `RISK-INJECTION-COVERAGE-NON-DIALOGUE`
- **Status:** Open
- **Owner:** R10 / security audit
- **Description:** `PromptInjectionClassifier` is now enforced on the dialogue context path, but is not systematically applied to every other untrusted surface that can reach a model (agent tool output, screen OCR, repository files, mail/web content and similar). Coverage beyond the dialogue path is unproven.
- **Mitigation:** Deliberately out of scope for OPEN-03's bounded objective; requires a dedicated cross-surface audit. Rule-based screening is also auditable rather than exhaustive — novel phrasings or obfuscation may evade the fixed rule set.
- **Evidence:** `EV-SP-003-20260815-INJECTION-FIX-17`

- **Risk ID:** `RISK-SP-003-NLU-DOWNGRADE-VARIANCE`
- **Status:** Open (accepted, bounded)
- **Owner:** SP-003 / R2 / R7
- **Description:** `ClassificationResult.applying(_:)` fails a conversational turn closed to `.unknown`/`.clarify` whenever the structured-NLU model proposes a capability ID or a non-`answer` dialogue act. Observed intermittently with `gemma4:latest`: 2 of 4 model-backed turns in the pre-fix run, 0 of 4 in the post-fix run, with no code path linking the fix to the difference — run-to-run model nondeterminism. Safe in both directions, but it can intermittently cost the user a clarification round-trip on an ordinary question, weakening R2's "general questions return substantive model-backed answers" requirement.
- **Mitigation:** The typed guard is the intended fail-closed behaviour and is not being relaxed; no raw model result reaches execution in either outcome. Accepted as bounded model variance for beta. Cross-model and repeat-run characterization is not done.
- **Evidence:** `EV-SP-003-20260815-LIVE-7SCENARIO-16`, `EV-SP-003-20260815-INJECTION-FIX-17`

- **Risk ID:** `RISK-SP-003-MODEL-LATENCY`
- **Status:** Open (observation)
- **Owner:** R7
- **Description:** Model-backed dialogue turns measured 19.8–36.1 s wall-clock on this hardware against 0.08–16.0 ms for deterministic fast-path turns — four to five orders of magnitude apart. Relevant to any R7 latency budget and to first-token responsiveness targets.
- **Mitigation:** Recorded as an observation only; no budget is set by SP-003.
- **Evidence:** `EV-SP-003-20260815-LIVE-7SCENARIO-16`, `EV-SP-003-20260815-INJECTION-FIX-17`

### 2026-08-15T18:55:00Z — SP-003 residual risk disposition after follow-up work

The four risks forwarded at SP-003 closure were re-examined on explicit user instruction to
resolve them. Their honest dispositions differ, and are recorded separately rather than reported
as a uniform "closed".

- **Risk ID:** `RISK-INJECTION-COVERAGE-NON-DIALOGUE`
- **Status:** **Closed** for all model-prompt construction sites presently in the codebase
- **Owner:** R10 / security
- **What was done:** A full audit of every site that interpolates text into a model prompt.
  Findings: (1) `MultiAgentOrchestrator_Prompts` interpolated four non-authoritative surfaces
  with no screening at all — the repository `diff` and validation command `outputTail` into the
  reviewer prompt, the planner model's `plan` into the implementer prompt, and the reviewer
  model's `feedback` into the corrector prompt. A poisoned diff or crafted test output could
  therefore instruct the reviewer model directly, including into a forged `VERDICT: APPROVE`.
  All four are now screened. (2) `OllamaTaskRunner` passes `request.objective`, which
  `RuleBasedUtteranceClassifier` extracts from the user's own utterance — authoritative by
  provenance, correctly not screened. (3) `IntentEngine`'s structured-NLU prompt carries the raw
  user utterance — likewise authoritative. (4) `ProductivitySecurity` already screened.
  Enforcement was additionally consolidated into a single `PromptInjectionScreen` type in
  `AuraSecurity` so the dialogue path and the orchestrator share one policy rather than
  re-deriving it — the original defect was a detector that existed but was never called, and
  duplicated policy is how that recurs.
- **Evidence:** `EV-SP-003-20260815-INJECTION-COVERAGE-18`
- **Residual:** Rule-based screening remains auditable rather than exhaustive; novel phrasings or
  obfuscation may evade the fixed rule set. Any *future* prompt-construction site must route
  untrusted segments through `PromptInjectionScreen`; nothing mechanically forces this yet, which
  is the remaining exposure and is a lint/review concern rather than a live defect.

- **Risk ID:** `RISK-SP-003-NLU-DOWNGRADE-VARIANCE`
- **Status:** **Open — accepted, not fixed**
- **Owner:** R2 / R7
- **Why it is not fixed:** Closing it would require weakening a tested safety property, and that
  trade is not worth making silently. The downgrade is produced by
  `ClassificationResult.applying(_:)`, which fails a turn closed to `.unknown`/`.clarify`
  whenever the structured-NLU model proposes a capability or a non-`answer` act. That exact
  behaviour is asserted by `structuredModelActionProposalCannotBecomeExecutableIntent`, where a
  vague utterance plus a model-proposed `shell.execute` must become a clarification. The
  deterministic classifier assigns `.converse` to *both* a clear question and a vague
  command-like phrase, so `applying(_:)` cannot distinguish the case where the downgrade is
  desirable from the case where it merely costs a round-trip. Options considered and rejected:
  preferring the deterministic `.converse` whenever a proposal is rejected (breaks the safety
  test above); a bounded retry, which R2 §C would permit, but which doubles a 20–36 s turn and
  worsens `RISK-SP-003-MODEL-LATENCY`. A real fix is an NLU-stage redesign, outside OPEN-03's
  bounded objective.
- **Impact if unaddressed:** Safe in both directions — no raw model result reaches execution —
  but an ordinary question can intermittently cost the user one clarification round-trip.
- **Evidence:** `EV-SP-003-20260815-LIVE-7SCENARIO-16` (2 of 4 turns),
  `EV-SP-003-20260815-INJECTION-FIX-17` (0 of 4 turns, same build)

- **Risk ID:** `RISK-SP-003-MODEL-LATENCY`
- **Status:** **Open — observation, bound verified**
- **Owner:** R7
- **Why it is not "fixed":** 19.8–36.1 s is the measured cost of an 8B Q4_K_M model on this
  hardware. No code change makes a local model faster; the honest options are a smaller model
  (requires a download, which is outside the granted authority) or accepting the cost. What was
  verified instead is that the latency is *bounded and degrades honestly* rather than hanging:
  `ConversationConfiguration.thinkTimeoutSeconds` defaults to 90 s and is genuinely enforced via
  `scheduleTimeout(for: .thinking,…)` in `Conversation_State`/`Conversation_Commands`, and
  `OllamaConfiguration.requestTimeoutSeconds` defaults to 120 s. Every measured turn sat well
  inside the think budget.
- **Evidence:** `EV-SP-003-20260815-INJECTION-COVERAGE-18`

- **Risk ID:** `RISK-SP-003-LIVE-VOICE-RESIDUAL`
- **Status:** **Open — cannot be closed in this environment**
- **Owner:** SP-002 / R7
- **Why it is not fixed:** The user is speech-disabled and cannot produce live voice input. Live
  microphone/TCC Turkish–English capture cannot be demonstrated without a speech-capable
  operator. No code change resolves this; claiming closure from mock-STT or text-path evidence
  would be exactly the kind of substitution the second-pass contract forbids.
- **Evidence:** `EV-SP-002-20260815-PTT-MOCK-14`

### 2026-08-16T08:20:49Z — SP-003 risk dispositions revised after follow-up work

- **Risk ID:** `RISK-SP-003-NLU-DOWNGRADE-VARIANCE`
- **Status:** **Closed** (revises the 2026-08-15T18:55:00Z entry, which recorded it as
  accepted-not-fixed)
- **Owner:** R2
- **Correction:** the earlier entry concluded a fix would break
  `structuredModelActionProposalCannotBecomeExecutableIntent`. That was wrong. The test proposed
  `shell.execute`, which is **not registered** — `InitialCapabilitySet` registers
  `shell.execute_typed` — so it was asserting behaviour for a hallucinated ID, conflating "the
  model invented a name" with "the user was ambiguous".
- **Mitigation:** `IntentEngine` now verifies a model-proposed capability ID against
  `CapabilityRegistry`. An unregistered ID is rejected per R2 §C and the turn keeps its
  deterministic `.converse` classification; a registered ID still downgrades to
  `.unknown`/`.clarify`; with no registry the conservative downgrade still applies. The invariant
  that a model proposal never becomes executable holds in every branch.
- **Evidence:** `EV-SP-003-20260816-RISKS-AND-UI-19`

- **Risk ID:** `RISK-SP-003-LIVE-VOICE-RESIDUAL`
- **Status:** **Open — narrowed** (revises the 2026-08-16 framing "cannot be closed in this
  environment")
- **Owner:** SP-002 / R7 / release packaging
- **Correction:** treating the whole risk as unclosable was too broad. It covers Turkish/English
  recognition *quality*, and `SystemSTTEngine` ingests `AudioFrame`s through
  `SFSpeechAudioBufferRecognitionRequest`, so real audio from any source drives the real
  recognizer — the operator's speech disability does not block that half.
- **Mitigation so far:** `Tests/AuraSTTTests/BilingualSpeechRecognitionQualityTests.swift`
  synthesizes Turkish and English speech with `say`, decodes it, and feeds 16 kHz frames to a real
  `SFSpeechRecognizer`, asserting recognition and locale selection.
- **Remaining blocker:** TCC authorization is per executable. The SwiftPM test helper is a bare
  binary with no `Info.plist`, so it holds no Speech grant, and requesting one aborts the process
  (SIGABRT, helper exit 134). Closing this requires running the harness inside a bundled host
  carrying `NSSpeechRecognitionUsageDescription`.
- **Unchanged limitation:** synthesized speech is cleaner than human speech, so any accuracy it
  eventually measures is optimistic and is not a real-user WER figure; microphone hardware capture
  is still covered only by SP-002's separate accommodation.
- **Evidence:** `EV-SP-003-20260816-RISKS-AND-UI-19`

### 2026-08-16 — SP-004 / OPEN-04 adapter residuals (new registrations from the security review)

- **Risk ID:** `RISK-SP-004-TOCTOU-RACE`
- **Status:** Open
- **Owner:** R10 (security boundaries) / SP-005's consumer
- **Risk:** `OpenTargetValidator` checks the target's attributes (existence, is-application,
  executable extension, POSIX executable bit, sensitive location, containment) in one call, then
  `FileSystemURLOpener` invokes `NSWorkspace.open` in a later call against the same canonical
  path. Between these, an attacker with concurrent filesystem write access could replace the
  validated file with a symlink to an executable, add the executable bit, or substitute an
  application bundle.
- **Mitigation so far:** the validator resolves symlinks to their canonical path before
  comparison (so a pre-existing symlink trap is refused), and the cancellation check sits
  immediately before the side effect. The validator's actual refuse-before-effect contract — a
  rejected target is never handed to LaunchServices — is intact.
- **Why it is not fixed:** the honest closure is descriptor-based re-validation (`open(2)` with
  `O_NOFOLLOW` against an fd opened at validation time), which is real implementation work and
  belongs to R10's privilege-topology scope. Exploitation here also requires an attacker who
  already has concurrent write access to the target's directory — an actor at that capability
  level does not need to race AURA to execute code, so the incremental exposure from this gap
  is bounded. SP-004's completion gate names the validator contract "reject unknown or unsafe
  targets," which the implementation satisfies.
- **Closure criterion:** adapter uses descriptor-based re-validation, or an R10-scoped risk
  decision explicitly accepts the residual, with evidence.
- **Evidence:** `EV-SP-004-20260816-ADAPTERS-01`

- **Risk ID:** `RISK-SP-004-HANDLER-COMPROMISE`
- **Status:** Open
- **Owner:** R10 (security boundaries)
- **Risk:** the validator validates *what* is opened, not *which application* handles it once
  opened. If the user's default handler for a legitimate file type (e.g. `.pdf`) has been
  replaced by a malicious application, the validator accepts the file and the system runs the
  attacker's handler. Refusing executable extensions, the POSIX executable bit, and
  location-forwarding types raises the floor for direct code execution, but a compromised
  handler registry is outside what any adapter-level target validation can detect.
- **Mitigation so far:** the limitation is disclaimed in `FileSystemURLOpener`'s header comment,
  and every refusal reason stays generic rather than embedding raw paths.
- **Why it is not fixed:** detecting it would require snapshotting the LaunchServices handler
  database per file type at policy level — a genuinely different subsystem from target
  validation, and outside SP-004's typed-adapters-with-validation objective.
- **Closure criterion:** an R10-scoped policy/audit layer that verifies handlers, or an explicit
  accepted-risk decision with evidence.
- **Evidence:** `EV-SP-004-20260816-ADAPTERS-01`

- **Risk ID:** `RISK-SP-004-CASE-SENSITIVITY`
- **Status:** **Closed** (was Open; closed 2026-08-16 under `EV-SP-004-20260816-CASE-CLOSURE-03`)
- **Owner:** SP-005's consumer / future validator hardening
- **Risk:** the sensitive-location fragments (`/.ssh/`, `/Library/Keychains/`, `/private/var/db/TCC/`, etc.)
  are matched case-sensitively against the canonical path. On a case-insensitive APFS volume (the
  macOS default), a path like `/Users/alice/.SSH/id_rsa` would be canonicalized to
  `/Users/alice/.SSH/id_rsa` and would fail the string-fragment check — a private key could be
  opened via the case mismatch.
- **Mitigation so far:** `PathConfinement.canonicalize` resolves `..` and symlinks before all
  other rules run, and the sensitive-location check runs on that canonical path rather than on
  the caller's raw input; a symlink like `approved/.ssh -> /Users/alice/.ssh/` is caught because
  canonicalization exposes the real path. The residual is purely the literal-case scenario for a
  user who created the directory spelled `.SSH` directly.
- **Closure:** `rejectSensitiveLocation` now compares against a `lowercased()` probe, so the
  case-insensitive APFS default is handled. A new test
  `rejectsCaseVariantSensitiveLocation` creates `.SSH/id_rsa` and asserts it is refused for both
  `validateFile` and `validateRevealTarget`. Full sweep 21/21 bundles, 851/851 tests, 0 failed.
- **Evidence:** `EV-SP-004-20260816-CASE-CLOSURE-03`

### 2026-08-16T14:30:00Z — SP-006 / OPEN-04 live-gate risk disposition

The seven-scenario live run neither opened nor closed a risk on its own account. It did
re-measure one forwarded risk beyond its recorded bound, and it created one new bounded
residual through the fix it had to make. Both are recorded here rather than folded silently
into the SP-006 evidence file.

- **Risk ID:** `RISK-SP-003-MODEL-LATENCY`
- **Status:** **Open — observation, bound widened**
- **Owner:** R7
- **Update:** SP-006's live turns measured **28.5–49.0 s** per model-backed turn, above the
  19.8–36.1 s recorded at SP-003. The 49.0 s turn still sat inside
  `ConversationConfiguration.thinkTimeoutSeconds` (90 s) and
  `OllamaConfiguration.requestTimeoutSeconds` (120 s), so the honest-degradation property
  verified at SP-003 still holds — but the margin is thinner than the earlier figure implied,
  and the mutation-tier path pays this cost *before* the confirmation card appears. The SP-006
  demo driver's per-turn budget had to be raised 45 s → 120 s for exactly this reason: a 45 s
  budget produced a `confirmationDenied` because the driver gave up while the turn was still
  `thinking`.
- **Why it is not fixed:** unchanged from SP-003 — no code change makes an 8B Q4_K_M model
  faster on this hardware, and a smaller model needs a download that is outside granted
  authority.
- **Impact if unaddressed:** any future timeout, watchdog, or UI-affordance budget derived from
  the 19.8–36.1 s figure will be set too tight. Use 28.5–49.0 s as the current observed range.
- **Evidence:** `EV-SP-006-20260816-7SCENARIO-02`

- **Risk ID:** `RISK-SP-006-DEFAULT-GRANT-BREADTH`
- **Status:** **Closed** (was Open; closure first claimed 2026-08-16 under `EV-SP-006-20260816-GAPCLOSE-04` on test evidence — that claim was **premature**; genuinely closed the same day on live evidence under `EV-SP-006-20260816-LIVERERUN-05`)
- **Owner:** R3 / R10 (policy posture)
- **Risk:** SP-006 had to seed `.none`-confirmation grants for `.fileOpen`, `.fileReveal`, and
  `.urlOpen` with `patterns: [.any]`, because the production `PolicyConfiguration` denies the
  `.reversible` tier by default and the capabilities were otherwise unreachable live. `[.any]`
  means the *policy* layer no longer narrows these three capabilities at all: every refusal now
  depends on the adapter's `OpenTargetValidator` (path confinement, sensitive-location refusal,
  scheme allowlist, refuse-before-effect) and on the registry's availability state. A validator
  regression would therefore be a policy-visible hole rather than a defence-in-depth miss.
- **Mitigation so far:** the grants match each manifest's declared `confirmationRule` verbatim
  and mirror the pre-existing `.appActivate` precedent rather than inventing a looser posture;
  `DefaultPolicyGrantsTests` (8 tests) pin the production default posture against an unmodified
  `PolicyConfiguration()`, so a future broadening is a test failure rather than silent drift;
  the adapter's refusal rules are separately covered, including the case-variant
  sensitive-location test closed under `RISK-SP-004-CASE-SENSITIVITY`.
- **Closure criterion:** either a pattern-scoped grant (confining these three capabilities to
  declared user directories at the policy layer rather than only the adapter layer), or an
  explicit accepted-risk decision recorded with the R10 privilege-separation work.
- **Closure (2026-08-16, `EV-SP-006-20260816-GAPCLOSE-04`):** the pattern-scoped option was
  taken, and closing it exposed that the risk as originally written *understated* the exposure.
  The original text said refusal "rests entirely on `OpenTargetValidator`" — but production built
  that validator through `OpenTargetValidator()`'s default `approvedRoots: []`, which the type
  documents as **no root restriction**. So neither layer confined a path: the validator was
  enforcing its executable-extension, sensitive-fragment, and scheme rules, but nothing bounded
  *where* a target could live. Both layers are now bound to one shared declaration,
  `AuraCore.DeclaredFileRoots`:
  - **Policy:** `.fileOpen`/`.fileReveal` are granted per declared root as
    `.directory(root, recursive: true)` — one grant per root, because `patternsSatisfied`
    requires *every* pattern in a grant to match while `matchingGrant` accepts the first grant
    that does, so alternatives cannot share a grant. `url.open` uses a new
    `ResourcePattern.urlScheme(allowed:)` matching the adapter's allowlist;
    `.network(host:port:)` could not express this because a `mailto:` URL has no host.
  - **Adapter:** every production construction site (`AuraAutomation` ×2,
    `AuraKernel_Construction`) now passes `OpenTargetValidator.production`, which carries the
    same roots. The bare `init()` keeps the permissive default so focused tests supply their own
    sandbox and production confinement must be stated rather than inherited.
  A target outside the roots is now refused twice for independent reasons — by a raw-prefix
  policy check before the adapter is reached, and by `PathConfinement`'s canonicalized,
  component-wise check inside it, which still catches a `..`/symlink escape that the string
  comparison would miss. Proven by `DefaultPolicyGrantsTests` (14 tests, including `/etc/hosts`
  denied for both file capabilities, empty-target denial, `file:`/`ftp:`/`javascript:`/no-scheme
  URL denial, and a `mailto` regression guard). SP-006's live sandbox `/tmp/aura-sp006-*` remains
  inside the declared roots, so the recorded live scenarios stay reproducible.
- **Residual:** the roots are a fixed built-in list, not a user-managed setting; a user who keeps
  files outside home and the temp directories will be refused until R9/R10 adds a real
  grant-management surface. This is a deliberate fail-closed default, not an oversight.
- **Evidence:** `EV-SP-006-20260816-7SCENARIO-02` (registration),
  `EV-SP-006-20260816-GAPCLOSE-04` (closure)

### 2026-08-16T16:54:00Z — SP-006 live re-run risk disposition

- **Risk ID:** `RISK-SP-006-DEFAULT-GRANT-BREADTH`
- **Status:** **Closed on live evidence** (correcting a premature test-only closure)
- **What the live run changed:** the scoped grants were **inert on this installation**. `aura.policy.grants` held **895 persisted grants** — `issueGrant` de-duplicates by `id` while `Grant` mints a fresh `UUID`, so every launch since 2026-07-27 appended a complete new copy of the seed set — including **30 pre-scoping `.any` grants** for `file.open`/`file.reveal`/`url.open`. `matchingGrant` returns the first match, so those legacy grants authorized exactly the paths the scoping was meant to refuse. `/etc/hosts` was stopped only by the adapter.
- **Closure:** `DefaultPolicyGrants.seedPurpose` marks every seeded grant; `PolicyEngine.reconcileSeededGrants(_:marker:)` replaces the seeded set and prunes marked, legacy-`.any`, and shape-redundant grants; `AuraKernel.seedDefaultGrants` reconciles once and logs the migration. Live: `pruned 886` then `pruned 25`, store settling at 16 grants with 0 unmarked leftovers, and `/etc/hosts` moving to `policy` / `intent.blocked` while in-root opens stay `verified`.
- **Residual:** declared roots remain a fixed built-in list rather than a user-managed setting.
- **Evidence:** `EV-SP-006-20260816-LIVERERUN-05`

- **Risk ID:** `RISK-SP-006-URL-OPEN-FAILS-LIVE`
- **Status:** **Open — new, pre-existing defect surfaced by the live re-run**
- **Owner:** R3 / SP-007 first read
- **Risk:** the `url.open` capability's adapter leg fails on this machine. The trace store records `url.open → tool.result failed` at 13:18:12Z, 13:58:58Z, 14:12:35Z **and** 16:38:00Z — i.e. in every recorded run, including all three SP-006-era runs, before any change made in this session. So a registered `.ready` capability that policy authorizes does not actually work end to end.
- **Why it matters beyond the defect:** it **contradicts `EV-SP-006-20260816-7SCENARIO-02`**, whose scenario 2 states "Chrome launched at the URL turn (17:14:39)". The trace store does not corroborate a successful `url.open` at any time. The SP-006 verdict is not being reversed here — the other scenario legs stand on their own evidence — but scenario 2's URL half should be treated as **unproven** until re-demonstrated with a corroborating trace.
- **Not yet diagnosed:** the failure reason is not in the trace row, and the generic event payload table is intentionally empty (SP-001 excluded raw payload persistence), so the adapter's refusal/failure string was not recoverable after the fact.
- **Closure criterion:** a live `url.open` producing `tool.result … verified` with the browser actually launching, or a root-caused fix plus regression test if the adapter is refusing legitimately.
- **Evidence:** `EV-SP-006-20260816-LIVERERUN-05`

- **Risk ID:** `RISK-SP-006-CONFIRMATION-EXPIRY-UNEXPLAINED`
- **Status:** **Open — new, observation, cause undetermined**
- **Owner:** R1 / R9 (confirmation UX)
- **Risk:** in the live re-run, `quit Calculator` produced `confirmation.requested` at 16:39:46Z and `confirmation.expired` at 16:40:46Z → `intent.blocked / confirmationDenied`, and Calculator survived. The SP-006 run recorded `confirmation.accepted` for the same utterance under the same `AURA_TEXT_DEMO_SCRIPT` auto-allow presenter.
- **Assessment:** expiry-without-execution is a *safe* outcome and the deterministic confirmation suite passes, so no code defect is asserted. But the difference between two runs of the same path is unexplained, and an unexplained difference in a confirmation path is worth holding open rather than dismissing.
- **Closure criterion:** a determined cause — presenter selection, timing, or model classification variance — with a test or a documented environmental explanation.
- **Evidence:** `EV-SP-006-20260816-LIVERERUN-05`

### 2026-08-17T06:57:03Z — SP-008 adversarial-safety risk disposition

- **Risk ID:** `RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL`
- **Status:** **Open — new**
- **Owner:** R4 live acceptance / R9
- **Risk:** three legs of R4's "Live acceptance" list are proven only at the deterministic boundary — a **real focused secure field**, a **real system modal / security dialog**, and **observed cessation of generated CGEvents** after an emergency stop. SP-008 closed the control-flow question completely: the loop terminates with `.secureFieldBlocked`, the executor refuses input at both layers, the modal path halts before planning, and stop is proven at all four stage boundaries and across a run boundary. What is *not* proven is the layer beneath those decisions — `AccessibilitySecureFieldDetector` and `AccessibilityModalDialogDetector` are exercised through scripted conformers, so the guards are only as good as detectors that have never been observed against a genuine credential field or a genuine `SecurityAgent` dialog.
- **Why it is open rather than accepted:** a detector that silently returns `false` would make every guard above it inert while every test still passes. That is the same failure shape as `RISK-SP-006-DEFAULT-GRANT-BREADTH`, whose test-only closure proved premature on live evidence.
- **Why it is not owned by SP-008:** the prompt's hard boundary withholds launch/install/TCC authority, and when asked directly the user elected to close on the deterministic boundary.
- **Closure criterion:** a user-present run on granted Accessibility/Screen Recording hardware showing (1) a real password field producing `.secureFieldBlocked` with no keystroke delivered, (2) a real system modal producing `.unexpectedModalDialog`, and (3) generated events verifiably ceasing on stop and not resuming without explicit re-arm.
- **Evidence:** `EV-SP-008-20260817-ADVERSARIAL-01`

- **Risk ID:** `RISK-SP-008-PLANNER-DECLARED-INTENT-TRUST`
- **Status:** **Open — new, bounded**
- **Owner:** whichever prompt introduces a model-backed `ComputerUsePlanning` conformer
- **Risk:** `ComputerUseSemanticIntent` is **declared by the planner**, and `Capability.forComputerUse(intent:)` derives the policy risk tier as a pure function of that declaration. A planner that labels a destructive keystroke `.observe` is therefore evaluated at observation tier and never reaches the mandatory-confirmation gate. The type comment states the tier "can never be spoofed or under-reported by a caller" — that is true of a *caller* downstream of the planner, but not of the planner itself.
- **Assessment:** not a live defect. The only production conformer is `DeterministicComputerUsePlanner`, whose intents come from the curated `ComputerUseAppFixtures` table, and SP-008 proved a hostile planner still cannot smuggle text into an executed action (`plannerRationaleTextNeverBecomesTheExecutedAction`) or retarget another application. The exposure appears only when an untrusted planner can choose intents.
- **Deliberately not "fixed" here:** inferring intent from the action kind would be a guess, and asserting the current behaviour in a test would bless it. Recording it is the truthful handling.
- **Closure criterion:** either an intent-verification step that derives or cross-checks risk tier independently of the planner's declaration, or an explicit accepted-risk decision by the release owner at the point a model-backed planner is introduced.
- **Evidence:** `EV-SP-008-20260817-ADVERSARIAL-01`

### 2026-08-17T08:15:11Z — SP-008 post-closure re-verification finding

- **Risk ID:** `RISK-R4-COMPUTER-USE-NOT-USER-REACHABLE`
- **Status:** **Open — new**
- **Owner:** R4 productization / NL reachability (whichever prompt wires computer use into dispatch)
- **Risk:** the hardened computer-use path has no user-reachable entry point. `ComputerUseControlLoop.run` is invoked from exactly one place, `AuraKernel.computerUseRun(appBundleIdentifier:objective:)` in `Sources/AURA/AuraKernel_RuntimeAPI.swift`, and that function has **no caller** in `Sources` or in `Tests`. `IntentKind` declares no computer-use case and `ToolRouter` has no computer-use branch, so no utterance can reach it either. The `computerUse.run` capability manifest, the policy capability, the beta allowlist and the deterministic planner all exist and are tested; the wiring between dispatch and the loop does not.
- **Assessment:** not a safety defect — an unreachable action path fails closed by construction, and SP-008's guards are correct and regression-covered independently of reachability. It is a **truthfulness and productization** risk: the capability is registered and the allowlist is `.liveValidated` for three apps, which reads as "usable" in the capability surface while no route exists. It is also the deeper form of the residual SP-007 recorded — its live actions used AppleScript/System Events rather than the app's own `ComputerUseControlLoop.run`, which is not merely unexercised but currently unreachable.
- **Why it is not owned by SP-008:** adding an `IntentKind` case and a router branch is product wiring, not an adversarial or recovery residual; SP-008's hard boundary forbids absorbing another prompt's objective, and the user's go-ahead covered correcting the records, not extending scope.
- **Closure criterion:** either a dispatch route from a typed intent to `computerUseRun` with reachability tests and a live run through the app's own loop, or an explicit decision — recorded, not implied — that computer use stays an internal API for this release, with the capability surface saying so.
- **Evidence:** `EV-SP-008-20260817-CORRECTION-03`
### 2026-08-17T09:20:00Z — SP-008 detector-layer residual reduction

- **Risk ID:** `RISK-SP-008-LIVE-ADVERSARIAL-RESIDUAL`
- **Status:** **Open — reduced (mechanism closed, live-positive legs remain)**
- **Owner:** R4 live acceptance / R9 (live-positive validation); the silent-failure mechanism is now closed by construction
- **Risk:** the original entry named three live legs — a real focused secure field, a real system modal / security dialog, and observed cessation of generated CGEvents after an emergency stop — and stated the mechanism that made them dangerous: "a detector that silently returns `false` would make every guard above it inert while every test still passes." **That mechanism is now false by construction and by regression.** `AccessibilitySecureFieldDetector` and `AccessibilityModalDialogDetector` no longer collapse every Accessibility failure into "nothing found"; a failed read returns `SecureFieldProbe.indeterminate` / `ModalProbe.indeterminate`, and every caller (control loop and executor) refuses on it under its own terminal reason. Eleven new tests in `R4DetectorFailClosedTests.swift` prove the classification and the refusal at both layers, including the environment-independent invariant that the boolean contract equals the probe's fail-closed collapse. The live legs that remain open are the *positive* detections only: whether a real password field yields `kAXSecureTextFieldSubrole`, whether a real `SecurityAgent` dialog is seen as modal, and whether generated CGEvents actually cease after `EmergencyStopController.trigger`. No deterministic evidence can close those, and SP-008's authority excludes app launch.
- **Assessment:** the most dangerous property of this risk — silent guard disabling — is removed. What remains is live-positive validation, which is R4 live acceptance / R9 work requiring hardware authority.
- **Closure criterion (updated):** a user-present run on granted Accessibility/Screen Recording hardware showing (1) a real password field producing `.secureFieldBlocked` with no keystroke delivered, (2) a real system modal producing `.unexpectedModalDialog`, and (3) generated events verifiably ceasing on stop and not resuming without explicit re-arm. The silent-failure leg is already closed and needs no live evidence.
- **Evidence:** `EV-SP-008-20260817-DETECTOR-04` (reduction); `EV-SP-008-20260817-ADVERSARIAL-01` (original disposition)

### 2026-08-19T09:55:06Z — SP-011 native permission legs resolved; Safari trust path narrowed to one credential

- **Risk ID:** `RISK-SP-010-LIVE-OAUTH-TCC`
- **Status:** **Closed for the TCC half**
- **Owner:** R5 productivity
- **Risk:** live provider OAuth consent and the Calendar/Contacts TCC prompts were unexercised, so the native legs' authorization behavior was unknown.
- **Resolution:** the OAuth half closed under `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07`. The TCC half closes here: both prompts were raised by the product's own controls, displayed AURA's own Info.plist usage strings, were granted, and moved their rows to ready. Closing it required fixing three real defects first — no production caller for `requestReadAccess()`, missing `com.apple.security.personal-information.*` entitlements (tccd refused to prompt at all), and missing usage descriptions (which would have terminated the app).
- **Evidence:** `EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08`

- **Risk ID:** `RISK-SAFARI-BRIDGE-NOT-LIVE`
- **Status:** **Open — reduced**
- **Owner:** R5 productivity / R11 release (signing)
- **Risk:** the Safari extension was "packaged as source only, not installed/signed/live-verified", and the producing half of the bridge did not exist at all.
- **Assessment:** the missing half is now written and covered by the existing regression suite, and the extension is a real signed, sandboxed `.appex` that the system registers at `com.apple.Safari.web-extension` — verified by `pluginkit`, which returned `(no matches)` before the App Sandbox entitlement was added. What remains is narrower and precisely identified: Safari will not *enable* a non-Developer-ID extension without its `Allow unsigned extensions` toggle, which requires a Touch ID or password authentication that was deliberately not supplied.
- **Closure criterion:** either a Developer ID signature plus notarization (which removes the toggle entirely and is the production answer, owned by R11), or a user-present session that authenticates the toggle, enables the extension, and captures the approved-page summary, the browser injection-ignore leg, and the browser revocation.
- **Evidence:** `EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08`

- **Risk ID:** `RISK-SP-011-CONTACTS-NON-EMPTY-READ`
- **Status:** **Open — accepted for this prompt**
- **Owner:** R5 productivity / R9 UI acceptance
- **Risk:** the contacts lookup is proven authorized and reachable, but no non-empty result was observed, so the candidate-scoping and tie-clarification paths are covered only by deterministic tests.
- **Assessment:** deliberate. The only contacts on this machine are the user's own, and SP-011's own procedure forbids recording real private account data; a disposable fixture was attempted through three routes and each was refused by TCC or hung. The empty result still proves an authorized query executed, because an unauthorized one refuses with the remediation text instead.
- **Closure criterion:** a live lookup against a disposable contact on an account whose contents may be recorded, showing one bounded candidate and a tie clarification, with no address or phone number spoken back.
- **Evidence:** `EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08`

### 2026-08-19T13:05:00Z — SP-011 Safari bridge trust path re-diagnosed

- **Risk ID:** `RISK-SAFARI-BRIDGE-NOT-LIVE`
- **Status:** **Open — re-diagnosed, previous closure criterion superseded**
- **Owner:** R5 productivity (design) / R11 release (signing)
- **Risk:** the earlier entry named Safari's `Allow unsigned extensions` authentication as the binding blocker. That is now answered, the extension is enabled, and its toolbar button reaches the native half live — yet no envelope is written.
- **Assessment:** the real constraint is structural. Safari requires the extension to be App Sandbox confined; a sandboxed process uses the data-protection keychain while the unsandboxed containing app uses the file-based login keychain; and sharing either a keychain item or a container across that boundary requires `keychain-access-groups` or `com.apple.security.application-groups`, which are restricted entitlements needing a provisioning profile. Adding them made the app fail to launch (POSIX 163). This machine has only a self-signed identity and no Team ID, so the SP-009 shared-secret design is unexercisable here as written.
- **Closure criterion (updated):** either (a) Apple Developer Program enrollment, after which the App Group plus keychain access group work as designed and Developer ID signing with notarization also removes the unsigned-extension toggle; or (b) an asymmetric bridge in which the extension keeps a private signing key in its own keychain and publishes only its public key to the shared directory, which the app pins when the user connects the profile — no Team ID, no shared secret, but it supersedes `SafariBridgeAuthenticator` and needs its own ADR.
- **Evidence:** `EV-SP-011-20260819-SAFARI-TRUST-PATH-09`

### 2026-08-19T15:31:13Z — SP-011 Safari bridge Team ID dependency removed

- **Risk ID:** `RISK-SAFARI-BRIDGE-NOT-LIVE`
- **Status:** **Open — substantially reduced**
- **Owner:** R11 release (signing)
- **Risk:** the bridge could not be exercised without an Apple Developer Team ID.
- **Assessment:** the dependency is gone. The bridge is now asymmetric — the extension holds a private signing key in its own keychain and publishes only its public key, which the app pins on connect — so no entitlement has to span the sandbox boundary. Live, the extension signs an envelope into the shared directory and the app's pinned key is byte-identical to the published one. What remains is Safari's `Allow unsigned extensions` toggle, which does not survive a Safari restart and requires a Touch ID or password each time.
- **Closure criterion:** one observed conversational page summary from a live envelope. Developer ID signing plus notarization removes the toggle permanently and is the production answer.
- **Evidence:** `EV-SP-011-20260819-ASYMMETRIC-BRIDGE-10`

- **Risk ID:** `RISK-SP-011-BRIDGE-TOFU-PINNING`
- **Status:** **Open — accepted, documented**
- **Owner:** R5 productivity / R10 security review
- **Risk:** the app pins whatever verifying key is published at the moment the user connects. A hostile extension that published first would be pinned instead of the real one.
- **Assessment:** deliberate and bounded. Pinning happens only on an explicit user action, the key file lives in a directory only the extension and the app can write, and a later key is refused as impersonation until the user disconnects and reconnects. The alternative — a shared secret — needs a Team ID and is what this design replaced.
- **Closure criterion:** independent security review of the trust-on-first-use boundary as part of R10, or a Developer ID build where the extension's code identity can be checked directly.
- **Evidence:** `EV-SP-011-20260819-ASYMMETRIC-BRIDGE-10`

- **Risk ID:** `RISK-SP-011-LAUNCH-KEYCHAIN-BLOCKING`
- **Status:** **Closed — fixed and asserted**
- **Owner:** R5 productivity / composition root
- **Risk:** `AuraKernel.construct()` probed external capability availability inline. Each probe reads the Keychain, `SecItemCopyMatching` blocks until securityd answers, and securityd may first need to authorize the calling binary — which it cannot do while the app is still launching. The observed failure was total: the app never finished launching, never presented a window, and because an `LSUIElement` app with no window cannot be activated, no control was reachable by any means. Any user whose Keychain prompted — after an app update, for instance — would have got an application that never starts.
- **Assessment:** found by sampling the hung process, not by reading source. `construct()` now records the affected components as `.loading` and `start()` dispatches `probeExternalAvailability()` detached; launch is bounded by construction alone. Nothing routes against the unresolved placeholder because `submitText` re-derives availability before every turn.
- **Closure criterion:** met. Five cases assert the construction path contains no call that reads the Keychain, and that unprobed integrations are recorded as loading rather than ready.
- **Evidence:** `EV-SP-011-20260819-LAUNCH-AND-HARNESS-11`

- **Risk ID:** `RISK-SP-011-TRANSCRIPT-ACCESSIBILITY`
- **Status:** **Closed — fixed**
- **Owner:** R9 product surfaces
- **Risk:** `AuraMessageBubble` combined its children into one accessibility element, which this SwiftUI version exposes as an unlabelled `AXUnknown` once the bubble is inside a lazy stack — no value, no description, no children. Every message in AURA's conversation was an anonymous blank node to assistive technology, so a VoiceOver user could not read the assistant's answers at all. The six section pills and the composer's buttons were likewise nameless.
- **Assessment:** a product accessibility failure, not merely a test-harness obstacle; it is what forced earlier live runs to address controls positionally. Fixed with `.contain` on the bubble and stable, deliberately unlocalized identifiers (`AuraAccessibilityID`) on the tabs, composer and integration rows.
- **Closure criterion:** met for the controls and the transcript; a full VoiceOver audit of the remaining surfaces is not in SP-011's scope and belongs to an R9 accessibility pass.
- **Evidence:** `EV-SP-011-20260819-LAUNCH-AND-HARNESS-11`

- **Risk ID:** `RISK-SP-011-EXTENSION-WRITE-LATENCY`
- **Status:** **Open — instrumented, not yet measured**
- **Owner:** R5 productivity
- **Risk:** the Safari extension takes roughly thirteen seconds from toolbar click to envelope on disk, which consumes most of the envelope's own thirty-second lifetime and makes the natural "click, then ask" flow miss its window.
- **Assessment:** the earlier record attributed this to the Keychain without measuring it. `SafariWebExtensionHandler` now logs `sign-and-write` and `accept-total` durations — durations only, no page text, identity or key material — so the appex's internal cost can be separated from appex cold start. No fix has been made on the strength of a guess.
- **Closure criterion:** one live toolbar click with the instrumented build, then a fix targeted at whichever phase dominates.
- **Evidence:** `EV-SP-011-20260819-LAUNCH-AND-HARNESS-11`

- **Risk ID:** `RISK-SP-011-OBSERVATION-LIFETIME`
- **Status:** **Open — accepted, documented, needs R10 review**
- **Owner:** R5 productivity / R10 security review
- **Risk:** the Safari bridge's observation lifetime was raised from 30 to 180 seconds, widening the window in which a signed observation can be replayed.
- **Assessment:** at 30 seconds the capability could not work at all. The flow it exists for is "click the toolbar button, then ask AURA about the page", and that pipeline costs roughly 13 s of extension cold start plus one local-model turn, measured at 19.8–36.1 s in SP-006 and budgeted at 120 s by the product's own text driver. The envelope expired while the model was still classifying the request, every time. What widens is the replay window for a signed observation of a page the user explicitly shared, held in a directory only the app and the extension can write; the practical cost is that a summary can describe a page up to three minutes old — a freshness question rather than a confidentiality one.
- **Closure criterion:** R10 review of the window, or a design in which freshness is judged once at admission and the admitted observation is carried through the turn, which would allow a shorter window without breaking the flow.
- **Evidence:** `EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`

### SP-017 risk disposition — 2026-08-23

The historical `Open` rows for `RISK-MODEL-MEMORY-PRESSURE` and
`RISK-NEURAL-TTS-LATENCY` are preserved: they describe future neural or broad
co-resident qualification, not the bounded release path. SP-017's direct
resource observation (`EV-SP-017-20260823-RESOURCE-SCOPE-02`) found a CPU neural
helper sample near 3991 MiB on the 16 GiB host, so the release default is now
system TTS only and the neural risk is **mitigated by explicit exclusion**, not
closed by an unsupported performance claim. `RISK-VOICE-RECOVERY-LIVE` remains
Open for physical headset/route/sleep/echo verification; SP-017's direct live
system-TTS interruption evidence does not substitute for that physical test.

- **Risk ID:** `RISK-SP-011-CALENDAR-GRANT-DESTROYED`
- **Status:** **Closed 2026-08-20 — the risk as originally stated did not exist.** The original status line read *"Open — damage caused by SP-011, remedy is the operator's"* and is preserved here; the closure note at the end of this entry explains what was actually happening.
- **Owner:** SP-011 live acceptance
- **Risk:** the calendar authorization was working and is now stuck. This attempt ran `tccutil reset Calendar ai.aura.local.agent` against a working grant, on the strength of a "denied" reading taken from a build that was hung at launch.
- **Assessment:** neither `tccutil reset Calendar` nor `reset All` clears the resulting state; `EKEventStore.authorizationStatus(for: .event)` still reports denied or restricted, and AURA is no longer listed in System Settings › Privacy & Security › Calendars, so the product's own remediation points at a control that does not exist. `reset All` reported success while leaving microphone, screen-recording and contacts grants intact, so it did not take effect either. This is not a product defect; the product reported the state it was given, truthfully.
- **Closure criterion:** the authorization restored — a logout or restart is the normal remedy for a stuck TCC decision — and one live free-window read returning a non-empty result.
- **Evidence:** `EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`
- **Closed 2026-08-20 — and the diagnosis above is wrong.** No grant was destroyed. The machine was restarted and the row still read denied; a second `tccutil reset Calendar ai.aura.local.agent` reported success and changed nothing. The mechanism is TCC responsible-process attribution: `scripts/sp011-acceptance/launch-aura.sh` exec'd the bundle's binary from the shell so the app would inherit the acceptance environment, and a terminal-exec'd binary is not responsible for its own TCC requests — its ancestor is. System Settings listed only *Visual Studio Code* under both Calendars (No Access) and Contacts (on), with AURA absent from both, so AURA was truthfully reporting the terminal's decisions. `tccutil reset` was a no-op because no AURA decision existed. Relaunching the identical bundle through LaunchServices (`open --env`, PPID 1) moved Read Calendar and Find Contact to `notDetermined` before any permission was changed. The operator then granted both to AURA itself, and the free-window read returned `2 free window(s): 10:07–14:00, 15:00–00:00`. The launcher and preflight now assert `PPID == 1`. Closing evidence: `EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13`.

- **Risk ID:** `RISK-SP-011-TCC-RESPONSIBLE-PROCESS-ATTRIBUTION`
- **Status:** **Closed for the acceptance harness; the class remains**
- **Owner:** SP-011 live acceptance / R11 packaging
- **Risk:** any tooling that starts AURA by exec'ing its binary — a script, a test harness, a debugger, a CI step — makes an ancestor process responsible for AURA's TCC requests. The app then reads and reports *that* process's permission decisions as its own, truthfully and wrongly, and `tccutil` operations against AURA's bundle identifier are silent no-ops.
- **Assessment:** this cost SP-011 two attempts and produced a false root-cause record (`RISK-SP-011-CALENDAR-GRANT-DESTROYED`). It is invisible at launch: no error, no log line, no degraded state — only a permission row that reports someone else's decision. It is also self-concealing, because the wrong decision is often *permissive*, in which case the leg passes and the evidence silently claims an authorization the app does not hold. That is what happened to the contacts leg in `EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`, which had to be re-run.
- **Closure criterion for the class:** a check that cannot be bypassed by a future launcher — ideally the app itself refusing to present a permission row when it is not its own responsible process, rather than two shell assertions.
- **Mitigation in place:** `launch-aura.sh` launches through LaunchServices with `open --env` and asserts `PPID == 1`; `preflight.sh` carries the same assertion and names the remediation; the harness README records why the obvious shell-exec is wrong.
- **Evidence:** `EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13`

- **Risk ID:** `RISK-SP-011-OBJC-EXCEPTIONS-ABORT-THE-APP`
- **Status:** **Closed for the two observed paths; the class remains**
- **Owner:** R5 productivity
- **Risk:** the Contacts framework raises Objective-C exceptions that Swift cannot catch. Two of them aborted the whole application on the ordinary path of asking AURA to find a contact, and the surrounding `do`/`catch` was inert in both cases.
- **Assessment:** both were fixed at their cause — the unified-contacts query in place of enumerating a name predicate, and the formatter's own key descriptor in place of a hand-written key list. The general hazard is not closed: any Cocoa API that raises rather than returning an error can still take the process down, and Swift offers no seam to contain it.
- **Closure criterion:** an audit of the remaining Contacts and EventKit call sites for raise-rather-than-return APIs, owned by R10.
- **Evidence:** `EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`

### 2026-08-24 — SP-018 verification correction risk disposition

- **Risk ID:** `RISK-SP-018-AURAGENT-TEST-RUNNER-PARALLELISM`
- **Status:** **Mitigated for the repository's default runner; toolchain residual remains**
- **Owner:** SP-018 verification / test infrastructure
- **Risk:** unrestricted Swift Testing parallelism can make the mixed
  `AuraAgentTests` bundle produce scheduling-dependent false failures when
  live CLI, real-worktree, and actor-backed fixtures contend under the full
  matrix.
- **Assessment / mitigation:** the failure was reproduced in the default
  matrix and passed in isolation. `scripts/aura-test.sh` now bounds only this
  bundle to one worker by default, with an explicit environment override for
  controlled experiments; a regression test protects the runner contract.
- **Evidence:** `EV-SP-018-20260824-TEST-RUNNER-FIX-06` — regression test passed,
  corrected AuraAgentTests passed 237/237, and the default matrix passed 21/21
  bundles with zero failed.
- **Residual / closure criterion:** the control uses an experimental
  Swift-Testing toolchain variable and must be rechecked if the Xcode/Testing
  toolchain changes. A later independent default run reproducing the same
  width-one failure would reopen this risk. This risk does not represent a
  production memory-wiring, live-app, provider, release, or deployment claim.

### 2026-08-24 — SP-019 live memory controls attempt

- **Risk ID:** `RISK-SP-019-LIVE-MEMORY-CONTROLS`
- **Status:** **Open — deterministic local slice delivered; user-present acceptance missing**
- **Owner:** R8 memory/personalization and R9 product surfaces
- **Risk:** source and deterministic tests can pass while the launched product
  still fails to persist a preference across restart, expose all controls, or
  keep remembered content from becoming hidden execution authority.
- **Assessment / mitigation:** production composition now wires the bounded
  profile store, runtime APIs, and Privacy controls; local policy rejects a
  preference that would widen remote context, and the memory tests cover
  provenance, conflicts, supersession, deletion, export, retention, audit
  exclusion, and policy non-weakening. A LaunchServices smoke proved only
  startup and stop. The temporary HOME did not isolate Application Support,
  and no user-present control sequence was completed.
- **Evidence:** `EV-SP-019-20260824-LOCAL-CONTROLS-01` and
  `EV-SP-019-20260824-LAUNCH-SMOKE-02`.
- **Closure criterion:** a direct user-present run must complete all eight R8
  scenarios, capture redacted scope/purpose/provenance/control evidence, prove
  preference persistence after a real quit/relaunch, and verify that memory
  cannot authorize a risky action. ADR-043 must then be explicitly accepted
  or remain Proposed by decision.

### 2026-08-24 — SP-019 live controls evidence reconciliation

- **Risk ID:** `RISK-SP-019-LIVE-MEMORY-CONTROLS`
- **Status:** **Open — partial direct live evidence; deletion/export and several R8 scenarios remain unproven**
- **Assessment:** `EV-SP-019-20260824-LIVE-CONTROLS-04` directly reduces the
  restart/control portion of the risk: a bounded `Concise` preference survived
  a real menu quit/relaunch in an isolated Foundation home; purpose, scope,
  retention, provenance, correction, audit exclusion, retention cleanup, and
  local-only policy rejection were visible in the product. The run did not
  produce a verified local tool fact, resolved reference, conflict resolution,
  export artifact, deletion receipt, or direct transport trace. The Delete
  control remains pending action-time confirmation.
- **Falsifier:** a fresh final-app run that fails to restore `Concise`, permits
  remote-context widening, exposes audit/security memory, or loses the user
  correction would falsify the reduced conclusion; a located export artifact,
  conflict resolution, and deletion receipt would close the corresponding
  residuals.
- **Evidence:** `EV-SP-019-20260824-LIVE-CONTROLS-04` plus the deterministic
  `EV-SP-019-20260824-LOCAL-CONTROLS-01`.
- **Next safe action:** obtain immediate confirmation before deleting one
  disposable `workingConversation` record; then rerun the export and remaining
  R8 scenarios. Keep SP-019 `in_progress` and do not start SP-020.
### 2026-08-24 — SP-019 export artifact observed

- **Risk ID:** `RISK-SP-019-LIVE-MEMORY-CONTROLS`
- **Status:** **Open — export now directly observed; deletion and remaining live scenarios remain unproven**
- **Assessment / mitigation:** The live Privacy export control created and
  saved a native JSON artifact in the isolated `/tmp` profile. Structural
  inspection confirmed `conflicts`, `generatedAt`, and `records`, 203 records,
  no audit field, and no raw audio/screenshot/token/secret marker. Evidence:
  `EV-SP-019-20260824-LIVE-CONTROLS-06`.
- **Residual / falsifier:** A missing file, changed hash, audit record in the
  export, or a raw-content marker would falsify this export conclusion. The
  verified tool fact, resolved reference, contradiction resolution, deletion
  receipt, and direct transport trace remain open. Delete requires immediate
  user confirmation.

### RISK-SP-019-LIVE-MEMORY-CONTROLS — 2026-08-24 update (post tool-evidence wiring)

- **Risk ID:** `RISK-SP-019-LIVE-MEMORY-CONTROLS`
- **Status:** **Substantially reduced — five of six open scenarios now carry direct live evidence; one remains open on a newly identified classifier limitation**
- **Assessment:** the earlier "live attempt failed" readings were mis-attributed.
  Four of the scenarios could not have passed because the product had no such
  path: no site wrote `projectFact`, produced `.observed` provenance, or used
  `.verifiedToolEvidence`; the only live subject was globally unique so
  `ContradictionDetector` was unreachable; `explicitlyConfirmedTargetID` had no
  producer; and the deletion receipt was discarded by the kernel
  (`EV-SP-019-20260824-TOOL-EVIDENCE-WIRING-08`). After wiring, live acceptance
  produced a verified tool fact with `observed` provenance, a real contradiction
  and its user-selected resolution, restart persistence, a permanent deletion
  with a user-visible receipt, a live refusal of a risky action, and two
  socket-table transport traces showing zero non-loopback peers
  (`-09`, `-10`, `-11`, `-12`).
- **Residual risk:** the multi-turn reference clarification is proven only
  deterministically. The production rule-based classifier cannot emit an intent
  carrying an unresolved implicit reference, so the resolver is reachable in
  production only through the structured-NLU backend. Until that is exercised,
  a regression in the clarification path would not be caught by live acceptance.
- **Mitigation:** 19 new deterministic tests, including safety negatives that
  pin that a loose or shared-token answer never manufactures a confirmation and
  that secret-looking tool output is refused rather than retained.
- **Falsifier:** a live turn in which a stored statement changed a policy
  decision, a deleted record still readable, or a non-loopback peer observed on
  the live process.

### RISK-SP-019-REFERENCE-UNREACHABLE — new, 2026-08-24

- **Risk ID:** `RISK-SP-019-REFERENCE-UNREACHABLE`
- **Status:** **Open — reference resolution is unreachable through the production rule-based classifier**
- **Owner:** R8 context/reference and intent classification
- **Risk:** the reference resolver, its guarded-tier evidence checks, and the new
  clarification round trip are fully implemented and tested, yet no live
  utterance can reach them without the structured-NLU backend. A user asking
  "open the file" gets `.unknown`, not a clarifying question about a real target.
- **Assessment / mitigation:** `classifyFileCommand` guards on `looksLikePath`
  and `classifyAppCommand` on a known application name; `applyingResolvedReference`
  applies only to `.fileOpen`, `.appActivate`, and `.appTerminate`. Deterministic
  coverage is in place; production reachability is not.
- **Next step:** exercise the path through the structured-NLU backend, or widen
  the rule-based classifier to emit a reference-carrying intent. Out of scope
  for SP-019.

### RISK-SP-019-REFERENCE-UNREACHABLE — 2026-08-24 closure

- **Risk ID:** `RISK-SP-019-REFERENCE-UNREACHABLE`
- **Status:** **Closed — the resolver is reachable through the production classifier and proven live**
- **Assessment:** the single guard responsible was `classifyFileCommand`'s
  `looksLikePath` requirement, which sent every reference-carrying utterance to
  application matching and thence to `.unknown`. An open-prefixed target that is
  a known reference phrase now yields `.fileOpen` (or `.appActivate` for
  `the app`) with its target slot empty, at confidence 0.7 — above the 0.6 gate,
  below an explicit path's 0.85. Live acceptance showed `open the file` refusing
  to guess between two candidates and `open the file alpha` resolving to alpha
  and opening the real file (`EV-SP-019-20260824-LIVE-REFERENCE-13`).
- **Residual:** `revealPrefixes` ("show the file") still requires a path-shaped
  target, so reveal-by-reference remains unreachable. Tracked as a follow-up,
  not a blocker for SP-019's scenarios.
- **Falsifier:** a reference resolving while several candidates remain
  plausible, or `open safari` regressing away from `.appActivate`.

### RISK-SP-019-LIVE-MEMORY-CONTROLS — 2026-08-25 closure

- **Risk ID:** `RISK-SP-019-LIVE-MEMORY-CONTROLS`
- **Status:** **Closed — all eight R8 live/product scenarios pass on one build**
- **Assessment:** the risk was that source and deterministic tests could pass
  while the launched product failed to persist a preference, expose its
  controls, or keep remembered content from becoming hidden execution
  authority. `EV-SP-019-20260825-CONSOLIDATED-ACCEPTANCE-14` re-ran every
  scenario against build `fccf1520…` in one isolated profile: preference
  restart, verified tool fact, reference resolution, contradiction and its
  resolution, correction with supersession, inspection/retention/export/
  deletion-with-receipt/audit exclusion, machine-policy refusal of remote
  context, refusal of an unconfirmed mutation-tier command, and two transport
  traces with zero non-loopback peers.
- **Residual:** reveal-by-reference (`revealPrefixes` requires a path-shaped
  target) and expiry-driven retention purging are covered only by the
  deterministic suite. Both are follow-ups outside SP-019's scenarios.
- **Falsifier:** any of the eight scenarios failing on a single-build re-run.
