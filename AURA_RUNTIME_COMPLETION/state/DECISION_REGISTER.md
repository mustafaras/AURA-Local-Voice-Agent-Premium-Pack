# AURA Runtime Completion Decision Register

Use this file as a compact index. Full rationale belongs in ADR files. Status values: `Proposed`, `Accepted`, `Superseded`, `Rejected`, `Deferred`.

| ID | Decision | Owning track | Status | Required before | ADR path | Notes |
|---|---|---:|---|---|---|---|
| ADR-034 | Accessibility and CLI privilege separation behind least-privilege helpers | R10 | Proposed | External beta | `docs/decisions/ADR-034-cli-ax-privilege-separation.md` | Milestone 1 helpers are packaged; protocol-boundary migration remains in progress. |
| ADR-035 | Correlation, causation, verification, and truthful completion semantics | R1 | Accepted | R1 completion | `docs/decisions/ADR-035-turn-context-trace-correctness.md` | Execution success is not verification success; one immutable TurnContext preserves the trace. |
| ADR-036 | Layered Turkish/English/mixed deterministic NLU, local structured NLU, and dialogue routing | R2 | Accepted | R2 completion | `docs/decisions/ADR-036-bilingual-nlu-dialogue-routing.md` | Define typed language/act metadata, provider-neutral schema boundary, bounded provenance context, and honest degradation. 2026-08-03 addendum: added default policy grant for `.agentOllamaLocalInference` after live testing found it was denied by default; see `EV-R2-20260803-TEXTDEMO-LIVE-01`. |
| ADR-037 | Immutable confirmation transaction and fail-closed execution lifecycle | R1 | Accepted | R1 completion | `docs/decisions/ADR-037-runtime-health-and-confirmation-transactions.md` | Bind approval to plan hash, target, context, nonce, risk, and expiry; restart does not replay approval. |
| ADR-038 | Typed capability manifest and multi-step plan contract | R3 | Accepted | R3 implementation | `docs/decisions/ADR-038-capability-registry-and-planner.md` | Replace unbounded enum/switch growth with closed registered schemas. Registry is now the sole production source of capability contracts; planner validates/binds immutable typed plans; ToolRouter migrated with zero regression (EV-R3-20260804-CAPABILITY-REGISTRY-PLANNER-01). |
| ADR-039 | Production computer-use planner and approved application beta boundary | R4 | Accepted | Live computer-use enablement | `docs/decisions/ADR-039-production-computer-use-planner.md` | Accessibility-first, fresh observation, strict typed actions, no raw model execution. Adds a deterministic first `ComputerUsePlanning` conformer, a beta allowlist gating every production target, resumable hash-bound confirmation, and semantic postcondition verification (ADR-039). |
| ADR-040 | Browser/mail/calendar/contacts integrations, OAuth scopes, and trust boundaries | R5 | Accepted | R5 implementation | `docs/decisions/ADR-040-productivity-integrations-oauth.md` | Read-first rollout and explicit send/mutation confirmation. Reuses KeychainSecretStore, NetworkAllowlist, ContentProvenance/PromptInjectionClassifier, ConfirmationTransaction, and CapabilityRegistry; read-only default, incremental least-privilege OAuth scopes, Keychain-only revocable tokens, deny-by-default network enforcement, untrusted-content provenance/isolation, and computer-use as explicit bounded fallback. |
| ADR-041 | Authenticated VS Code extension bridge and coding-workspace contract | R6 | Accepted | R6 implementation | `docs/decisions/ADR-041-vscode-extension-bridge.md` | Symmetric HMAC shared secret stored in AURA Keychain and VS Code `SecretStorage`; signed envelopes bind extension identity, protocol version, nonce, freshness, workspace, actor, and payload. VS Code capabilities remain disabled until live bridge health is `.ready`. Companion extension package is buildable but not yet installed/run live; SP-012 stays `in_progress` until live acceptance. |
| ADR-042 | Real wake-word engine, STT router, TTS chain, and local model resource governor | R7 | Proposed | Wake-word/model enablement | `docs/decisions/ADR-042-voice-routing-resource-governor.md` | Must fit 16 GB hardware and preserve Push-to-Talk fallback. **2026-08-22 note:** the referenced ADR-042 file does **not exist** in the repo (projection gap); SP-015 explicitly excludes wake word from the release scope (`EV-SP-015-20260822-WAKE-EXCLUSION-01`), so ADR-042 cannot be accepted in this pass. The ADR path must be authored and reconciled before any wake/model acceptance. |
| ADR-043 | User memory, preference scope, context budget, and explainability UI | R8 | Proposed | R8 implementation | `docs/decisions/ADR-043-memory-personalization-controls.md` | Draft authored with explicit persistence, provenance, correction, export, deletion, bounded context, and remote-boundary controls; explicit user acceptance and live R8 gate remain pending. |
| ADR-044 | Privileged XPC/helper topology, network enforcement, and secret boundaries | R10 | Proposed | External beta | `docs/decisions/ADR-044-privileged-helper-topology.md` | Separate local control powers from model/network process. |
| ADR-045 | Stable toolchain, state projection, deployment target, build/archive, Developer ID, and notarization | R0/R11 | Accepted | External beta | `docs/decisions/ADR-045-toolchain-release-pipeline.md` | Development CommandLineTools compatibility is distinct from full-Xcode release validation; projection-only descendants are explicitly bounded. |
| ADR-046 | Signed update, rollback, downgrade protection, safe mode, and recovery | R11 | Proposed | Release candidate | `docs/decisions/ADR-046-signed-update-recovery.md` | Prefer mature auditable mechanism over custom cryptography. |
| ADR-047 | Beta evidence, SLOs, release-candidate authority, and final completion declaration | R12 | Proposed | Final acceptance | `docs/decisions/ADR-047-beta-slos-release-authority.md` | Define objective release-candidate evidence and false-success threshold. |
| ADR-048 | Bounded unsafe constructs and privacy-safe diagnostics | H-006 | Accepted | H-006 completion | `docs/decisions/ADR-048-unsafe-constructs-and-diagnostics.md` | Replace proven fail-open/fail-unclear sites; retain lock/actor boundaries only with explicit invariants and focused evidence. |
| DEC-REPO-HYGIENE-H-007-COVERAGE | Coverage scope/ratchet disposition | H-007 | Accepted | H-007 readiness | `scripts/aura-coverage-scope.regex` | The 70% line-coverage ratchet is unchanged. Evidence supports excluding only four host-boundary files requiring app launch, SwiftUI rendering, TCC mutation, or a global AppKit event tap; AuraAppModel and AuraKernel remain in scope. Raw all-source coverage remains visible at 65.15%; scoped effective coverage is 70.02%. |
| DEC-REPO-HYGIENE-H-008-SUPPLY-CHAIN | Reproducible secret, dependency, and workflow provenance gate | H-008 | Accepted | H-008 readiness | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_SUPPLY_CHAIN_POLICY.json`; `scripts/validate_repo_hygiene_supply_chain.py` | Accept the local fail-closed gate: five exact synthetic fixture findings are allowlisted by marker/path/pattern; zero unallowlisted findings, zero external Swift dependencies, pinned/hashes-validated uv graph, and SHA-pinned Actions pass. This decision does not claim historical secret absence, vulnerability scanning, SBOM completeness, or hosted CI observation. |
| DEC-REPO-HYGIENE-H-010-FINAL-GATE | Final repository-hygiene acceptance disposition | H-010 | Deferred | Explicit blocker resolution or accepted scope disposition | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md` | Final gate is formally blocked by original Git fsck/history, strict formatter/SourceKit/full-Xcode, vulnerability/SBOM, and hosted-CI evidence limitations. No global repository/product/release completion claim is authorized. Evidence: `EV-REPO-HYGIENE-H-010-20260810-01`. |
| DEC-REPO-HYGIENE-REMEDIATION-20260810 | Separate remediation disposition | H-010 | Deferred | Original Git recovery, full-Xcode/SourceKit, dependency advisory, and hosted-CI evidence | `AURA_RUNTIME_COMPLETION/repo-hygiene/EXTERNAL_SCANNER_POLICY.md`; `REPO_HYGIENE_LEDGER.md` | Accept the recoverable clean-clone and local-tooling evidence without treating exact upstream dependency overrides, false-positive policies, local fsck, or local tests as global release proof. H-010 remains blocked; no H-011 exists. Evidence: `EV-REPO-HYGIENE-REMEDIATION-20260810-01`. |
| DEC-REPO-HYGIENE-DEPENDENCY-20260811 | Patched Chatterbox lock graph and added explicit TorchCodec runtime dependency | Remediation | Deferred | Revalidate under future upstream/lock changes and hosted CI | `Runtime/chatterbox/pyproject.toml`; `Runtime/chatterbox/uv.lock`; `AURA_RUNTIME_COMPLETION/repo-hygiene/EXTERNAL_SCANNER_POLICY.md` | Use explicit uv overrides only after isolated OSV/Grype, lock provenance, import, and audio round-trip evidence. This closes the current dependency advisory blocker, not full release or hosted-CI acceptance. Evidence: `EV-REPO-HYGIENE-DEPENDENCY-REMEDIATION-20260811-01`. |
| DEC-REPO-HYGIENE-GIT-ADOPTION-20260811 | Adopt the independently verified fsck-clean recovery candidate `.git` and preserve the damaged original for rollback | Remediation / H-010 | Deferred | Future Git migration, retention, or destructive cleanup decision | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`; `/tmp/aura-git-adoption-20260811.4xxAiP/` | Explicit user authority enabled exact replacement after byte-verified backup, fsck/show-ref/reachability checks, and rollback preservation. Current repository integrity is resolved; original backup disposition and any later destructive cleanup remain separately controlled. Evidence: `EV-REPO-HYGIENE-GIT-ADOPTION-20260811-01`. |
| DEC-REPO-HYGIENE-TOOLCHAIN-20260811 | Provision Apple CLT 27 beta and obtain full Xcode through authenticated Apple distribution | Remediation / H-010 | Deferred | User-controlled Apple ID/Xcode artifact and hosted-CI toolchain evidence | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`; `TOOLCHAIN.md` | CLT beta is installed and xcodes is available, but full Xcode cannot be claimed without authenticated Apple distribution. Do not bypass invalid TLS or store credentials. Evidence: `EV-REPO-HYGIENE-TOOLCHAIN-20260811-01`. |
| DEC-REPO-HYGIENE-SWIFTLINT-FORMATTER-20260812 | Reconcile strict SwiftLint with strict swift-format without weakening either policy | H-010 | Deferred | Reviewed policy decision and zero-finding exact rerun | `.swiftlint.yml`; `.swift-format`; `REPO_HYGIENE_LEDGER.md` | Current formatted tree passes swift-format but strict SwiftLint reports 528 findings, including 352 trailing-comma and 170 opening-brace findings. Keep both gates fail-closed; no disablement or coverage exclusion expansion is accepted. Evidence: `EV-REPO-HYGIENE-H-010-SWIFTLINT-REMEDIATION-20260812-01`. |
| DEC-REPO-HYGIENE-COVERAGE-SPLIT-20260812 | Preserve the six-file host-boundary scope after source decomposition and resolve the 66.10% regression | H-010 | Deferred | Reviewed test/measurement disposition and wrapper >=70% | `scripts/aura-coverage-scope.regex`; `REPO_HYGIENE_LEDGER.md` | The 70% threshold and original scope remain unchanged; split-file exclusions were rejected as policy weakening. Add reviewed measured tests or an equivalent explicit decision before reopening the gate. Evidence: `EV-REPO-HYGIENE-H-010-SWIFTLINT-REMEDIATION-20260812-01`. |

| DEC-REPO-HYGIENE-SWIFTLINT-FORMATTER-20260812-FINAL | Adopt the explicit formatter-compatible SwiftLint contract after source/test remediation | H-010 | Deferred pending hosted verification | Exact configured SwiftLint zero-finding rerun and formatter zero-diagnostic rerun | `.swiftlint.yml`; `.swift-format`; `REPO_HYGIENE_LEDGER.md` | No rule is disabled, no new path exclusion is added, and no coverage threshold is changed. The default-policy 504-finding falsification is retained as evidence that the two tools' defaults conflict; reopen on toolchain/configuration change. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. |
| DEC-REPO-HYGIENE-COVERAGE-SPLIT-20260812-FINAL | Resolve measured coverage regression with equivalent tests while retaining the original six-file scope | H-010 | Deferred pending hosted verification | Canonical wrapper exits 0 at 70.57% with 21/21 bundles and 795 tests | `Tests/AURAIntegrationTests/R9ProductUIStateTests.swift`; `scripts/aura-coverage-scope.regex` | Measured product-state/UI projection tests raised coverage above the unchanged 70% threshold; no split-file exclusion was introduced. Evidence: `EV-REPO-HYGIENE-H-010-FINAL-20260812-01`. |
| DEC-REPO-HYGIENE-H-010-HOSTED-20260812 | Close the terminal H-010 repository-hygiene gate after exact hosted verification | H-010 | Accepted | H-010 completion | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md`; `.github/workflows/ci.yml` | Final run `31598491689` on `6d4d6da` passed governance/build/test/coverage and development-unverified artifact upload. The runner was temporary and removed. This decision supersedes the earlier H-010 hosted-blocker disposition for the recorded workflow; it does not close product, beta, release, signing, deployment, ADR-034/044, or FINAL gates. Evidence: `EV-REPO-HYGIENE-H-010-HOSTED-CI-FINAL-20260812-01`. |
| DEC-REPO-HYGIENE-H-010-PROJECTION-20260812 | Reconcile current H-010 status projections after terminal hosted closure | H-010 | Accepted | No current projection may present H-010 as blocked; historical evidence remains append-only | `AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json`; `ledger/CURRENT_STATE.md`; `AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md` | Mark H-010 terminally completed at live projection `b4610f0`; bind hosted proof to workflow/source SHA `6d4d6da`; identify later descendants as control-plane-only; retain prior blocked/pending records as superseded historical evidence. No product source, second-pass state, H-011, release, or deployment claim follows. Evidence: `EV-REPO-HYGIENE-H-010-PROJECTION-RECONCILIATION-20260812-01`. |

| DEC-SP-001-LIVE-TRACE-20260814 | Direct user-present trace, confirmation, reversible mutation, and universal postcondition evidence | R1 / SP-001 | Deferred | Explicit target-Mac/app-launch authority and complete live evidence bundle | `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_LEDGER.md`; `docs/decisions/ADR-035-turn-context-trace-correctness.md`; `docs/decisions/ADR-037-runtime-health-and-confirmation-transactions.md` | Deterministic suites pass 316 tests, but live UI/runtime evidence is not proven. Keep SP-001 blocked; do not substitute fakes or historical assertions. Evidence: `EV-SP-001-20260814-ATTEMPT-01`. |

### 2026-08-14T08:44:20Z — DEC-SP-001-LIVE-TRACE update

The explicit live-launch authority was exercised and direct user-present
evidence now proves bounded safe observation, displayed confirmation, one
allowed reversible mutation with local process verification, deny,
changed-plan blocking, emergency-stop interlock, and restart no-replay
behavior. The decision remains **Deferred** because the live UI and runtime
do not expose a redacted correlation/causation ID chain or a durable event
ledger, and distinct dismissal, explicit confirmation-timeout,
failed-verification, and concurrent-turn-isolation traces remain unproven.
Evidence: `EV-SP-001-20260814-LIVE-TRACE-03`. SP-001 remains blocked; no
SP-002 transition follows.

### 2026-08-14T11:11:19Z — DEC-SP-001-TRACE-PROJECTION-20260814

The OPEN-02 source-side residual is resolved with a narrow privacy-safe
projection: persist only redacted correlation/causation/request/action/outcome
fields in a dedicated local table, keep generic event payload persistence
unwired, and display only opaque ID prefixes in the UI. Confirmation terminal
outcomes are recorded for audit visibility but never authorize replay. The
decision is **Deferred** for prompt completion because target-Mac live evidence
must still prove the UI/store chain and the remaining negative/verification
matrix. Evidence: `EV-SP-001-20260814-TRACE-FIX-04`.

### 2026-08-14T12:10:25Z — DEC-SP-001-TRACE-PROJECTION live update

The post-fix user-present run confirms the chosen redacted projection in the
real UI and local store: date allow/deny, Calculator expiry, one allowed
reversible close, distinct verification, and no-process verification are
truthfully represented. The decision remains **Deferred** because the narrow
authority did not cover post-fix changed-plan, replay, dismissal, cancellation,
or concurrent-turn cases. Evidence:
`EV-SP-001-20260814-LIVE-TRACE-FIX-05`. SP-001 remains blocked; no SP-002
transition follows.

### 2026-08-14T12:16:54Z — DEC-SP-001-TRACE-PROJECTION closeout reconciliation

The mandatory closeout confirms the post-fix bounded live evidence and all
local validators/build checks, but does not change the decision from **Deferred**:
the remaining post-fix negative/verification matrix was outside the explicit
authority. Authority is reset to edit-only; SP-001 remains blocked and SP-002
is not opened. Evidence: `EV-SP-001-20260814-CLOSEOUT-06`.

## Decision rules

### 2026-08-15T09:32:18Z — DEC-SP-001-TRACE-PROJECTION dismissal update

The red close path was found not to call the existing application-menu quit
method. A narrow WindowGroup lifecycle hook now resolves a pending
confirmation as `dismissed`, with a focused redacted-persistence test and a
direct live requested → dismissed → blocked observation. The decision remains
**Deferred** pending the remaining post-fix live matrix. Evidence:
`EV-SP-001-20260815-LIVE-DISMISSAL-07`.

### 2026-08-15T09:45:50Z — DEC-SP-001-TRACE-PROJECTION mandatory closeout

The bounded source/evidence delivery and pointer reconciliation do not change
the decision from **Deferred**. The remaining live matrix is not satisfied,
so `SP-001` stays blocked and `SP-002` stays unopened. Authority resets to
edit-only. Evidence: `EV-SP-001-20260815-CLOSEOUT-09`.

### 2026-08-15T11:17:34Z — DEC-SP-001-TRACE-PROJECTION completion update

The bounded `SP-001` / `OPEN-02` decision is now **Accepted for prompt
completion**. The current unsigned build directly persisted a matching
`confirmation.cancelled` terminal outcome after emergency stop without
execution, and the same live run proved truthful reversible execution and
independent verification. This does not accept the broader R1/FINAL program
gates or any release/security/provider/beta boundary. Evidence:
`EV-SP-001-20260815-CANCELLATION-12`; authority resets to edit-only and
`SP-002` remains pending/unopened.

### 2026-08-15T11:29:26Z — DEC-SP-001-TRACE-PROJECTION mandatory closeout

The accepted bounded `SP-001` / `OPEN-02` completion decision is confirmed by
`EV-SP-001-20260815-CLOSEOUT-13` after the required validators and full local
regression passed. This closeout does not accept first-pass R2–R12/FINAL or any
release/security/provider/beta boundary. `SP-002` remains pending and unopened;
authority is edit-only.

- Add a row before implementing a material decision.
- Do not mark `Accepted` until the ADR contains context, decision, alternatives, consequences, migration, security/privacy analysis, and verification plan.
- Record supersession rather than rewriting history.
- Update `current-state.json` when an accepted decision changes dependencies, gates, or program order.
