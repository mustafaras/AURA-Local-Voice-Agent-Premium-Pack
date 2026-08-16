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
| RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER | Real action executor exists without a production typed planner/user route. | R4 | High | Critical | Mitigating | `DeterministicComputerUsePlanner` (`Sources/AuraComputerUse/DeterministicComputerUsePlanner.swift`) is the first production `ComputerUsePlanning` conformer, emitting only closed `ComputerUsePlan` values and stopping/clarifying for unapproved apps, unknown objectives, secure fields, or modals; `ComputerUseBetaAllowlist` structurally gates every production target to a deliberately small, `.liveValidated`-only app set; `ComputerUseConfirmationStore`/`ComputerUseVerifier` add resumable hash-bound confirmation and semantic postcondition verification; ADR-039 accepted. `computerUse.run` capability is registered in the registry and `AuraKernel.computerUseRun` wires the bounded loop through policy + allowlist (`EV-R4-20260807-PRODUCTIZATION-CORE-01`, `EV-R4-20260807-WIRING-REGISTRY-01`, `ADR-039`). Still `Mitigating` not `Closed`: `computerUse.run` remains `.disabled` until an app is explicitly live-validated, the live end-to-end path has not been exercised on real hardware, and the required live beta-app evidence (safe tasks in ≥3 approved apps on granted Accessibility/Screen-Recording hardware, live confirmation, live emergency stop, live screen-content injection fixture) has not been performed — it requires the user physically present. |
| RISK-INDIRECT-PROMPT-INJECTION | Web/mail/document/screen content can attempt to redirect tools or policy. | R4/R5/R10 | High | Critical | Mitigating | R5 external page/mail/event/contact content is typed with non-authoritative provenance, scanned by `PromptInjectionClassifier`, and blocked on direct injection fixtures; content cannot influence actions structurally. General R10 coverage and live provider/extension acceptance remain open. Evidence: `EV-R5-20260808-READ-FIRST-ADAPTERS-01`. |
| RISK-MISSING-PRODUCTIVITY-ADAPTERS | Browser, mail, calendar, and contacts workflows are absent. | R5 | High | High | Mitigating | Typed read-first Safari bridge, Gmail read adapter, EventKit calendar adapter, and Contacts candidate adapter now exist with focused/full contract evidence. Composition-root/NLU/UI wiring, live provider/browser configuration, mutation/send flows, and live acceptance remain open. Evidence: `EV-R5-20260808-READ-FIRST-ADAPTERS-01`. |
| RISK-OAUTH-OVERPRIVILEGE | Productivity integrations may request broader scopes or retain tokens insecurely. | R5/R10 | Medium | Critical | Mitigating | Reviewed closed OAuth tiers reject read-to-compose/send escalation; read-only Gmail scope excludes send; tokens are Keychain-backed references with revoke deletion and no token values in references. Live consent/revocation and provider transport remain open. Evidence: `EV-R5-20260808-READ-FIRST-ADAPTERS-01`. |
| RISK-VSCODE-POLICY-NOT-ENFORCED | VS Code adapter emits a policy request but does not await/enforce a decision. | R6 | High | Critical | Mitigating | `VSCodeAdapter` now awaits `PolicyEngine` before CLI, shell, or bridge execution and fails closed for missing, denied, or confirmation-required decisions; `AuraVSCodeTests` covers deny/confirm paths. Production coding-agent natural-language routing now enters the coordinator instead of bypassing workspace/backend/worktree gates. UI confirmation completion and live action-path validation remain open. Evidence: `EV-R6-20260808-POLICY-BRIDGE-01`, `EV-R6-20260808-TYPED-ROUTES-02`. |
| RISK-BRIDGE-INCOMPLETE | VS Code task/test bridge routes fail and bridge authentication is absent. | R6 | High | High | Mitigating | Added bounded typed command/response routes over HMAC-SHA256 envelopes with protocol version, extension ID, nonce replay defense, freshness, payload-size, and tamper checks; workspace resolution fails closed on invalid/ambiguous targets. Real extension packaging/shared-secret provisioning, disconnect/version-mismatch live behavior, complete task/test/diagnostic acceptance, and user-present validation remain open. Evidence: `EV-R6-20260808-POLICY-BRIDGE-01`, `EV-R6-20260808-TYPED-ROUTES-02`. |
| RISK-AGENT-BACKEND-DRIFT | Codex/Claude/Copilot interfaces, auth, or flags may change. | R6 | Medium | High | Mitigating | The installed local CLIs were probed only through bounded `--version`/`--help` observations; health records exact output/interface evidence but keeps authentication and model availability `unverified`, making write-capable routing fail closed. Live auth/model/cancellation/network/budget evidence and disabled-backend acceptance remain required. Evidence: `EV-R6-20260808-TYPED-ROUTES-02`. |
| RISK-NO-REAL-WAKE-WORD | Only a synthetic test detector exists. | R7 | High | Medium | Open | Production now uses an explicit `DisabledWakeWordDetector` and truthful Push-to-Talk-only UI; a real local model, FAR/FRR, anti-trigger, license/hash, and soak evidence are still required before enablement. |
| RISK-MODEL-MEMORY-PRESSURE | STT/NLU/TTS models can exceed 16 GB resource/thermal budgets. | R7 | High | High | Open | `VoiceResourceGovernor` now provides bounded STT/neural-TTS reservations, memory-pressure/thermal admission, and circuit breaking; NLU/screen/coding integration and measured 16 GB pressure/energy/soak evidence remain open. |
| RISK-NEURAL-TTS-LATENCY | Chatterbox CPU synthesis is too slow and MPS stalled in live evidence. | R7 | High | Medium | Open | CPU is the safe default; helper timeout, reservation, cleanup, and Yelda fallback are implemented. Live first-audio/CPU latency, MPS qualification, consented reference, and human listening evidence remain open; system-TTS-only release is allowed. |
| RISK-STT-ROUTER-QUALITY | Native Speech locale fallback does not prove bilingual or mixed-language transcription quality. | R7 | High | High | Open | Router and on-device capability checks are implemented with engine metadata and duplicate-safe stream reuse; live Turkish/English/mixed WER/entity corpus, qualified local Whisper/equivalent fallback, and microphone acceptance remain required. |
| RISK-VOICE-RECOVERY-LIVE | Audio interruption, device changes, sleep/wake, permission revocation, and barge-in may diverge on real hardware. | R7 | Medium | High | Open | Local cancellation/fallback and bounded continuation tests exist; user-present headset/device/sleep/TCC/barge-in/echo/recovery evidence remains required. |
| RISK-MEMORY-NOT-PRODUCTIZED | Memory/context exists but is not yet visibly or materially used and controlled across the complete assistant product path. | R8 | High | High | Open | Local policy/context slice is implemented and focused-tested under `EV-R8-20260808-MEMORY-POLICY-01` and `EV-R8-20260808-CONTEXT-PRODUCT-02`; production reference-candidate wiring, user-present product demonstrations, R9 controls, and ADR-043 acceptance remain open. |
| RISK-MEMORY-LIVE-ACCEPTANCE | Restart-safe preferences, multi-turn references, ambiguity handling, contradiction correction, and user controls have not passed a user-present launched-app acceptance. | R8 | High | High | Open | Run the exact live product scenarios with the user present, record account/process/hardware authority and residuals, and retain local focused evidence as subsystem evidence only. |
| RISK-MEMORY-REFERENCE-WIRING | Context resolver contracts exist, but production candidate population from dialogue salience, recent files, tools, workspaces, and durable tasks is incomplete. | R8 | High | High | Open | Wire bounded reference candidates through the production composition path; clarify ambiguous/destructive references and verify postconditions before any mutation. |
| RISK-MEMORY-REMOTE-TRANSPORT-EVIDENCE | Remote context delivery is fail-closed, but there is no provider/transport evidence proving that sensitive or unapproved memory cannot leave the machine. | R8 | Medium | Critical | Open | Preserve local-only default; add an explicit redacted/user-approved remote path only with transport-level capture, allowlist, secret, and negative-transmission evidence. |
| RISK-ADR-043-PENDING | The R8 memory/personalization/control architecture has not received explicit user acceptance at its completion gate. | R8 | High | High | Open | Keep ADR-043 `Proposed`; obtain explicit user acceptance only after live gates, state/ledger evidence, and residual-risk review pass. |
| RISK-CONTROL-PANEL-NOT-ASSISTANT-UI | Existing menu was insufficient for dialogue, tasks, health, permissions, evidence, and recovery. | R9 | High | High | Mitigating | R9 now provides the six product surfaces, text fallback, onboarding, and recovery projections. User-present accessibility/localization evidence and remaining task/capability/model/control lifecycle coverage are still required for closure. Evidence: `EV-R9-20260808-UI-BUILD-02`, `EV-R9-20260808-UI-TESTS-03`. |
| RISK-R9-LIVE-ACCESSIBILITY | UI semantics, focus order, VoiceOver announcements, keyboard-only operation, target size, contrast, and scaled-text reflow have not passed a user-present macOS accessibility review. | R9 | High | High | Open | Add native SwiftUI labels/traits/focus semantics and automated state/a11y contract tests; run manual VoiceOver and keyboard evidence on a clean/configured profile. |
| RISK-R9-LOCALIZATION | Turkish/English product strings, status/error guidance, dates, and layout behavior may be incomplete or inconsistent. | R9 | Medium | High | Open | Centralize user-facing copy, test required keys and locale-aware formatting, and run Turkish/English scaled-layout review. |
| RISK-R9-ONBOARDING-RECOVERY | Staged permission onboarding, denial/revocation recovery, no-model/offline states, emergency stop, safe mode, and restart restoration are not yet exposed as a verified product path. | R9 | High | High | Open | Keep permission requests user-triggered and least-privilege; implement explicit stages and actionable recovery without claiming unavailable backend capabilities. |
| RISK-MAIN-PROCESS-PRIVILEGE-CONCENTRATION | Main process combines Accessibility, generated input, CLI, models/network, and UI. | R10 | High | Critical | Mitigating | Typed/hash-bound/replay-protected helper envelopes and helper-kind capability allowlists are implemented, but helpers are parent-launched echo boundaries and the main process still retains broad authority. Authenticated peer transport, real helper execution, entitlements, and compromise-boundary evidence remain required. Evidence: `EV-R10-20260809-BOUNDARY-SLICE-01`. |
| RISK-NETWORK-ALLOWLIST-INCOMPLETE | Allowlist object may not be enforced by every network path. | R10 | Medium | Critical | Mitigating | Endpoint scheme/host/port/path checks and redirect rejection cover the Ollama loopback client; a mandatory client factory, DNS/IP revalidation, TLS/proxy/download bounds, provider transport, and subprocess audit remain open. Evidence: `EV-R10-20260809-BOUNDARY-SLICE-01`. |
| RISK-IPC-PEER-AUTH-ABSENT | A typed pipe envelope can be replay/tamper resistant without authenticating the OS peer that supplied it. | R10 | Medium | Critical | Open | Add authenticated XPC/peer identity or an independently reviewed equivalent, bind authorization to the verified process identity, and test compromised-parent/helper scenarios. |
| RISK-OAUTH-LIFECYCLE-INCOMPLETE | OAuth contract and Keychain expiry handling exist, but provider transport, callback isolation, live revocation, and leakage coverage are incomplete. | R10 | Medium | Critical | Open | Wire PKCE/state-bound provider exchange, account-isolated callbacks, revocation/expiry UI, and redacted negative-leakage corpus across logs/events/crashes/support paths. Evidence: `EV-R10-20260809-BOUNDARY-SLICE-01`. |
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
- **Status:** **Open — new, bounded**
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
- **Evidence:** `EV-SP-006-20260816-7SCENARIO-02`
