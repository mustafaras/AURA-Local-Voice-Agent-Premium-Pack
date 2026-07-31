# AURA Runtime Completion Risk Register

Status values: `Open`, `Mitigating`, `Blocked`, `Accepted`, `Closed`. Probability/impact: `Low`, `Medium`, `High`, `Critical`.

| ID | Risk | Track | Probability | Impact | Status | Required mitigation / closure evidence |
|---|---|---:|---:|---:|---|---|
| RISK-STATE-CONTRADICTION | Legacy state and handoff prose contains stale and contradictory completion claims. | R0 | High | High | Open | Machine-projected status, contradiction validator, reconciled legacy pointers, evidence-linked phase claims. |
| RISK-TOOLCHAIN-PREVIEW | Swift/macOS baseline may depend on a preview or locally unusual toolchain. | R0 | High | High | Open | Exact pinned toolchain manifest, supported release target, stable-build strategy, CI validation. |
| RISK-DISCONNECTED-RUNTIME | Services are constructed but not registered or reachable through the user runtime. | R1 | High | Critical | Open | Runtime health registry, capability registration, complete production integration tests. |
| RISK-FALSE-SUCCESS | Process/tool success may be reported without independent postcondition verification. | R1 | Medium | Critical | Open | Explicit executed/verified states, verification coordinator, false-success tests and beta metric. |
| RISK-CONFIRMATION-RESUME | Confirmations may be denied twice, lost, replayed, or resume against changed state. | R1 | Medium | Critical | Open | Immutable transaction hash, nonce/expiry, persisted checkpoint, recapture/revalidation, race tests. |
| RISK-EVENT-CORRELATION | Conversation and downstream events can lose the original correlation/causation chain. | R1 | High | High | Open | `TurnContext`, trace completeness tests, actual engine/backend metadata. |
| RISK-ENGLISH-ONLY-INTENT | Turkish STT output is routed through an English-oriented closed grammar. | R2 | High | High | Open | Bilingual deterministic grammar, structured local NLU, golden intent dataset. |
| RISK-CANNED-CONVERSATION | General conversation returns a fixed acknowledgement rather than a model-backed answer. | R2 | High | High | Open | Dialogue engine, local model path, degraded-mode behavior, multi-turn tests. |
| RISK-CLOSED-TOOL-ROUTER | Five-intent switch prevents safe extensibility and encourages disconnected features. | R3 | High | High | Open | Typed capability manifests, registry, planner, schema validation, capability health. |
| RISK-NO-PRODUCTION-COMPUTER-USE-PLANNER | Real action executor exists without a production typed planner/user route. | R4 | High | Critical | Open | Production planner, app allowlist, fresh observation, live E2E evidence. |
| RISK-INDIRECT-PROMPT-INJECTION | Web/mail/document/screen content can attempt to redirect tools or policy. | R4/R5/R10 | High | Critical | Open | Provenance separation, instruction isolation, adversarial fixtures, typed plans, no content authority. |
| RISK-MISSING-PRODUCTIVITY-ADAPTERS | Browser, mail, calendar, and contacts workflows are absent. | R5 | High | High | Open | Structured read-first adapters, OAuth/Keychain, integration and live tests. |
| RISK-OAUTH-OVERPRIVILEGE | Productivity integrations may request broader scopes or retain tokens insecurely. | R5/R10 | Medium | Critical | Open | Least-privilege scopes, incremental consent, Keychain references, revocation and audit. |
| RISK-VSCODE-POLICY-NOT-ENFORCED | VS Code adapter emits a policy request but does not await/enforce a decision. | R6 | High | Critical | Open | Direct policy enforcement, confirmation, adapter contract tests. |
| RISK-BRIDGE-INCOMPLETE | VS Code task/test bridge routes fail and bridge authentication is absent. | R6 | High | High | Open | Authenticated extension bridge, enumerated commands, diagnostics/tasks/tests/live validation. |
| RISK-AGENT-BACKEND-DRIFT | Codex/Claude/Copilot interfaces, auth, or flags may change. | R6 | Medium | High | Open | Official-version verification, capability health, contract fixtures, disabled unavailable backends. |
| RISK-NO-REAL-WAKE-WORD | Only a synthetic test detector exists. | R7 | High | Medium | Open | Real local acoustic model, FAR/FRR, anti-trigger and soak evidence; or explicit Push-to-Talk-only release scope. |
| RISK-MODEL-MEMORY-PRESSURE | STT/NLU/TTS models can exceed 16 GB resource/thermal budgets. | R7 | High | High | Open | Resource governor, residency policy, unload/circuit breaker, live pressure/thermal tests. |
| RISK-NEURAL-TTS-LATENCY | Chatterbox CPU synthesis is too slow and MPS stalled in live evidence. | R7 | High | Medium | Open | Performance correction or system-TTS-only release, consented reference and human quality gate if enabled. |
| RISK-MEMORY-NOT-PRODUCTIZED | Memory/context exists but is not visibly or materially used and controlled. | R8 | High | High | Open | Dialogue/tool integration, bounded context, provenance UI, correction/export/delete tests. |
| RISK-CONTROL-PANEL-NOT-ASSISTANT-UI | Existing menu is insufficient for dialogue, tasks, health, permissions, evidence, and recovery. | R9 | High | High | Open | Full product UI, text fallback, onboarding, accessibility/localization evidence. |
| RISK-MAIN-PROCESS-PRIVILEGE-CONCENTRATION | Main process combines Accessibility, generated input, CLI, models/network, and UI. | R10 | High | Critical | Open | Least-privilege helpers/XPC, authenticated requests, entitlement and compromise-boundary tests. |
| RISK-NETWORK-ALLOWLIST-INCOMPLETE | Allowlist object may not be enforced by every network path. | R10 | Medium | Critical | Open | Mandatory client factory, redirects/DNS/scheme/port tests, per-adapter grants. |
| RISK-NOT-NOTARIZED | Development signing may be mistaken for distributable release readiness. | R11 | High | High | Open | Developer ID, hardened nested signing, notarization, staple, clean Gatekeeper evidence. |
| RISK-NO-SIGNED-UPDATER | No implemented authenticated update/rollback path. | R11 | High | Critical | Open | Signed manifest/package, atomic update, downgrade/replay protection, rollback tests. |
| RISK-NO-LAUNCH-AT-LOGIN | Continuously available assistant lacks supported user-controlled launch at login. | R11 | High | Medium | Open | ServiceManagement implementation, UI control, sleep/wake/crash recovery evidence. |
| RISK-NO-INDEPENDENT-BETA-EVIDENCE | Unit/integration evidence may not reflect real daily use. | R12 | High | Critical | Open | Dogfood/beta window, SLO dashboard, incident review, security/accessibility sign-off, RC evidence package. |

## Rules

- Add a risk when a new failure mode is discovered; do not hide it in prose.
- Close a risk only with evidence IDs or explicit accepted-risk authority.
- `Accepted` risks must record owner, rationale, scope, expiry/review date, and release impact in a new ledger entry.
- Critical open risks block external beta unless the final authority explicitly accepts them and the release scope excludes the affected capability.
