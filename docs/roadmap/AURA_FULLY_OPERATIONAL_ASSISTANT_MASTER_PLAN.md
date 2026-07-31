# AURA Fully Operational Assistant — Master Recovery, Integration, and Delivery Plan

> **Document type:** Repository-grounded production plan  
> **Status:** Proposed execution baseline  
> **Prepared:** 2026-07-31  
> **Repository:** `mustafaras/AURA-Local-Voice-Agent-Premium-Pack`  
> **Audited commit:** `a11633288ada3c93598ce0eb5587bd190142f06b`  
> **Primary target device:** MacBook Air M5-class Apple Silicon, 16 GB unified memory, 512 GB storage  
> **Primary interaction languages:** Turkish and English, including code-switching  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience  
> **Target outcome:** A dependable, conversational, local-first macOS assistant that can hear, understand, reason, speak, use approved applications, inspect and operate the desktop, manage personal productivity workflows, orchestrate coding agents, remember relevant context, and truthfully report outcomes.

---

## 1. Executive Decision

AURA is not a blank prototype. The repository already contains a substantial safety-oriented foundation:

- a native SwiftUI application and menu-bar shell;
- microphone and Speech Recognition onboarding;
- AVFoundation audio capture;
- on-device Apple Speech transcription;
- system TTS and an isolated Chatterbox V3 path;
- a conversation state machine;
- a policy engine with grants and confirmation challenges;
- typed shell and application automation;
- durable tasks;
- Codex, Claude Code, Copilot, and Ollama adapters;
- memory and provenance graph components;
- context reconstruction;
- screen capture, OCR/redaction, and a bounded computer-use loop;
- plugin verification and an isolated plugin host;
- layered configuration governance;
- adversarial tests and security documentation.

The central problem is **not the absence of modules**. The central problem is that the implemented modules do not yet form one complete, truthful, user-operable assistant.

The current runtime has multiple “dead-end” integrations:

- `AuraKernel` constructs `OllamaAdapter`, `VSCodeAdapter`, `ScreenContextEngine`, `ComputerUseControlLoop`, plugin, worktree, and multi-agent services, but the active spoken-intent path cannot invoke most of them.
- `IntentKind` contains only conversation, application activation, application termination, shell execution, coding-agent execution, and unknown.
- `RuleBasedUtteranceClassifier` is an English-only closed vocabulary.
- open-ended conversation produces the fixed response `Got it.` instead of invoking a reasoning model.
- no production `ComputerUsePlanning` implementation is wired.
- the VS Code adapter emits a policy-request event but does not actually await a `PolicyEngine` decision, and task/test bridge routes deliberately fail.
- browser, mail, calendar, contacts, URL navigation, and personal-assistant adapters are absent.
- wake detection is disabled in production; the only detector is a synthetic marker-tone test detector.
- release, notarization, update, launch-at-login, and independent CI evidence remain incomplete.

Therefore, the correct next program is not “continue with Phase 26” as if the product were feature-complete. The correct program is a **runtime completion and productization track** that first reconciles repository claims with executable reality, then connects the existing subsystems through a typed, bilingual, model-assisted orchestration layer.

---

## 2. Definition of a Fully Operational AURA

AURA may be described as fully operational only when all of the following are true on a clean target Mac.

### 2.1 Voice and conversation

1. The user can activate AURA with Push to Talk and, when enabled, a real local wake-word model.
2. Turkish, English, and Turkish–English code-switching are transcribed reliably.
3. Natural instructions are understood without requiring rigid English command prefixes.
4. AURA can hold a multi-turn conversation and answer general questions through an explicitly selected local or remote reasoning backend.
5. AURA can interrupt, clarify, confirm, recover from errors, and resume the same task.
6. Spoken output is natural, responsive, interruptible, and never falsely claims success.

### 2.2 Desktop and personal productivity

1. AURA can open, focus, hide, and quit applications.
2. AURA can open files, folders, URLs, and workspaces.
3. AURA can inspect the active application and approved windows.
4. AURA can use typed, policy-gated Accessibility and computer-use actions.
5. AURA can perform practical browser workflows.
6. AURA can read and summarize approved mail, calendar, and task data through structured adapters where available.
7. Any action that sends, deletes, purchases, publishes, modifies permissions, exposes private data, or has destructive effects requires the correct confirmation.

### 2.3 Coding workflows

1. AURA can identify the current repository and VS Code workspace.
2. It can open files and symbols, inspect diagnostics, run tests, and use the terminal through a policy-gated path.
3. It can delegate bounded work to Codex, Claude Code, Copilot, or a local model.
4. It can show task progress, diffs, test results, failures, and approval requests.
5. It does not report a coding task as complete until verification evidence exists.

### 2.4 Memory and context

1. AURA remembers explicit user preferences and project facts with provenance.
2. It reconstructs relevant context without flooding the model.
3. References such as “that repo,” “the previous file,” or “ask Claude to review it” resolve safely.
4. The user can inspect, correct, export, and delete eligible memories.
5. Weakly resolved destructive targets never execute.

### 2.5 Operations and trust

1. The app installs cleanly and survives restart.
2. Required permissions are explainable and revocable.
3. Health, model, adapter, permission, and task status are visible.
4. Every consequential action has a correlated audit trail.
5. The app is signed with Developer ID, hardened, notarized, packaged, updateable, and recoverable.
6. Automated CI, hardware tests, and release evidence independently verify the build.
7. The repository ledger and product status contain no contradictory completion claims.

---

## 3. Audit Scope and Evidence Base

This plan is based on a direct review of the current `main` branch, including:

- `README.md`
- `AGENTS.md`
- `Package.swift`
- `docs/00_SYSTEM_VISION.md`
- `docs/01_MASTER_SPEC.md`
- `docs/architecture/02_ARCHITECTURE.md`
- `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md`
- `ledger/CURRENT_STATE.md`
- `SESSION_STARTER.md`
- the latest commits through `a116332`
- the SwiftUI application shell
- `AuraKernel`
- voice, STT, TTS, conversation, intent, routing, policy, automation, shell, task, model, memory, context, screen, computer-use, VS Code, plugin, security, and configuration implementations
- app-bundle, signing, test, and CI scripts
- available GitHub commit status and workflow evidence.

The audit distinguishes four states:

| State | Meaning |
|---|---|
| **Operational** | A real runtime path is connected and can perform the behavior on supported hardware. |
| **Implemented but disconnected** | Substantial code exists, but no end-to-end user path reaches it. |
| **Test fixture / simulated** | Deterministic fake or synthetic implementation exists for tests. |
| **Missing / release gate** | The capability or external requirement does not yet exist. |

A high unit-test count is not treated as proof of live usability. A module is operational only when the production composition root reaches it, permissions and configuration are valid, a user can invoke it, and the result is verified.

---

## 4. Current Repository Capability Map

### 4.1 Application shell

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| SwiftUI app | `Sources/AURA/AURA.swift` | Operational shell | No full conversation interface or text fallback. |
| Menu bar | `MenuBarExtra` with status | Operational shell | Limited health and task detail. |
| Push to Talk | `AuraMenuView` → `AuraAppModel` → `AuraKernel` | Operational path | No hold-to-talk semantics, transcript display, or wake word. |
| Permission onboarding | Microphone, Speech, Accessibility, Screen Recording | Partly operational | No guided permission rationale, verification workflow, or degraded-mode matrix. |
| Confirmation UI | `UIConfirmationPresenter` and confirmation card | Partly operational | Confirmation/resumption semantics are incomplete for some tool classes. |
| Emergency stop | UI and global keyboard shortcut | Operational foundation | Voice stop and computer-use resume/recovery need live validation. |
| Settings | Permission links and one configuration toggle | Minimal | Most configuration, models, privacy, memory, adapter, and diagnostics controls are absent. |

### 4.2 Voice pipeline

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| Audio capture | AVFoundation-based `AuraAudio` | Implemented | Long-duration live soak and device-switch evidence remain required. |
| VAD | Energy-based VAD | Implemented | Adaptive noise calibration and real acoustic evaluation are incomplete. |
| Wake word | `MarkerWakeWordDetector` | Test fixture only | It detects a synthetic marker tone and explicitly warns not to use it for real speech. |
| Production activation | Push to Talk | Operational | Always-available activation is absent. |
| STT | `SystemSTTEngine`, `requiresOnDeviceRecognition = true` | Operational foundation | Single configured locale per engine, no bilingual router or robust code-switch fallback. |
| TTS fallback | Apple Yelda voice | Operational | Quality and latency must be measured on release hardware. |
| Neural TTS | Chatterbox V3 helper | Implemented but gated | MPS stall, CPU latency, reference-audio consent, and human listening gates remain. |
| Turn taking | `Conversation` actor | Implemented | Correlation, real-model timing metadata, recovery, and multi-turn dialogue need repair. |

### 4.3 Intent, reasoning, and conversation

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| Rule classifier | `RuleBasedUtteranceClassifier` | Operational but narrow | English-only command prefixes and tiny closed app/command dictionaries. |
| Typed intent | `TypedIntent` | Strong foundation | Schema does not cover most intended assistant capabilities. |
| Open conversation | `ToolRouter.handleConverse` | Placeholder behavior | Always returns `Got it.` |
| Local model | `OllamaAdapter` | Implemented but disconnected | Not used by intent classification, dialogue, planning, or response generation. |
| Context reconstruction | `ContextBuilder`, `ContextEngine` | Implemented foundation | Context is built but not consumed by a conversational model or planner. |
| Clarification | Deterministic unknown handling | Minimal | No multi-turn slot filling, confirmation carry-over, or entity-resolution dialogue. |
| Tool planning | Closed switch in `ToolRouter` | Narrow | No dynamic typed tool catalog or model-generated validated plans. |

### 4.4 Tools and automation

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| App lifecycle | `AuraAutomation` | Operational narrow path | Only a small hardcoded app-name map is reachable from speech. |
| Typed shell | `AuraShell` and `ToolRouter` | Operational guarded path | Voice grammar exposes only a few executables; working-directory context is weak. |
| Computer use | Screen engine, action executor, bounded loop | Implemented but disconnected | No production planner, user target selection, routing intent, confirmation resume, or live E2E proof. |
| Screen understanding | ScreenCaptureKit + Vision + redaction | Implemented but disconnected | No user-facing observation workflow and no default policy/grant route. |
| VS Code | `VSCodeAdapter` | Partly implemented, disconnected | No intent route; policy is logged but not enforced; run-task and run-tests bridge paths fail. |
| Plugins | Verified host and registry | Implemented foundation | Public vendor PKI/catalog and real third-party lifecycle evidence are missing. |
| Browser | No dedicated adapter found | Missing | Must add structured browser and URL capabilities before relying on coordinate automation. |
| Mail | No dedicated adapter found | Missing | Must add user-approved Mail/Gmail access and typed read/draft/send operations. |
| Calendar/contacts | No dedicated adapters found | Missing | Needed for a practical personal assistant. |

### 4.5 Agent orchestration

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| Codex | Policy-gated CLI adapter | Strong foundation | Installation/version readiness, live run evidence, UI progress, and end-to-end working-directory resolution. |
| Claude Code | Adapter and tests | Implemented foundation | Same production readiness and verification requirements. |
| Copilot | Adapter and tests | Implemented foundation | Supported interface must be reverified at release; local/cloud boundaries need UI. |
| Ollama | Health, registry, routing, structured output, memory budget | Strong but disconnected | No primary assistant orchestration path. |
| Worktrees | `WorktreeManager` | Implemented foundation | Not exposed as a user-operable workflow. |
| Multi-agent | Orchestrator | Implemented foundation | No user-facing planner/reviewer flow in the active runtime. |
| Durable tasks | `AuraTaskEngine` | Implemented | Task detail, progress stream, retry/resume, and user controls are incomplete in UI. |

### 4.6 Memory and context

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| Durable store | SQLite-backed `AuraStore` | Implemented | Encryption and migration/recovery evidence must be release-validated. |
| Memory engine | Append-only memory and provenance graph | Implemented | Limited product surfaces and incomplete use in dialogue/tool selection. |
| Contradiction handling | Implemented | Foundation | Needs user-resolution UI and realistic cross-session tests. |
| Context ranking | Implemented | Foundation | Must be connected to local reasoning and typed plan generation. |
| User controls | APIs exist | Incomplete product | Inspection, correction, export, deletion, and retention UI are absent. |

### 4.7 Security and release

| Area | Current implementation | Status | Main gap |
|---|---|---:|---|
| Policy engine | Deny-by-default with scoped grants | Strong foundation | Capability coverage and confirmation-resume semantics need expansion. |
| Prompt-injection tests | Adversarial suite | Implemented | Must be applied to real browser/mail/screen/model inputs, not only deterministic fixtures. |
| Network allowlist | Constructed | Incomplete enforcement | Must be enforced at every HTTP and subprocess boundary. |
| Privilege separation | Plugin helper separated | Partial | Main app still holds Accessibility and CLI privileges in-process. |
| Signing | Stable local identity / ad hoc fallback | Development only | Developer ID and notarization are required for distribution. |
| CI | Self-hosted macOS workflow | Defined, no associated runs found | Need independent, repeatable CI evidence and artifact retention. |
| Coverage | Approximately 70% recorded | Below original 80% target | Increase coverage and add live-system gates. |
| Updates | Design documentation | Release gate | No signed production updater. |
| Launch at login | No implementation found | Missing | Required for a continuously available assistant. |

---

## 5. Critical Findings That Must Be Repaired Before Feature Expansion

### 5.1 The product-status ledger is not a reliable source of truth

`ledger/CURRENT_STATE.md` contains mutually inconsistent statements. Earlier sections say Phase 24 and Phase 25 are committed and pushed, while a later stale section says they are uncommitted and that the adversarial target is the next action. Repository state must be generated from verified evidence, not manually accumulated prose.

**Required correction**

- Split immutable evidence from generated status.
- Keep `PROJECT_LEDGER.md` append-only.
- Generate `CURRENT_STATE.md` from a typed status source or a deterministic script.
- Add a CI check that rejects contradictory phase, commit, test, and release claims.
- Remove “phase complete” language when only deterministic fixtures have passed and live acceptance gates remain.

### 5.2 The composition root creates services that the assistant cannot use

`AuraKernel` constructs advanced services, but they are stored and never invoked by the active intent path. This creates a false impression of completion.

**Required correction**

Introduce one explicit `AssistantRuntime`/`CapabilityOrchestrator` that owns:

- intent classification;
- dialogue and slot filling;
- context retrieval;
- typed plan generation;
- policy evaluation;
- tool execution;
- verification;
- response generation;
- task persistence;
- event correlation.

Every production subsystem must be registered through this orchestrator or marked `inactive` in runtime health.

### 5.3 The current natural-language interface is not bilingual or general

The STT locale is Turkish, but the recognized command grammar is English. General utterances produce a canned response.

**Required correction**

Use a layered bilingual pipeline:

1. deterministic Turkish/English command recognizer for high-frequency, low-latency actions;
2. local structured NLU using the existing Ollama adapter;
3. context-aware disambiguation;
4. typed tool planning;
5. clarification when schema confidence or entity resolution is insufficient;
6. optional remote reasoning only after explicit mode/policy selection.

### 5.4 Confirmation is not a complete transactional protocol

The current router can resolve a confirmation challenge and then still block a mandatory-confirmation category. Computer-use returns a confirmation-required outcome but does not provide a complete persisted resume path.

**Required correction**

Implement a single confirmation transaction:

- proposed action and immutable plan hash;
- risk summary;
- target and side-effect summary;
- nonce, expiry, and requested scope;
- user response;
- policy re-evaluation;
- action execution;
- verification;
- completion or rollback;
- durable resume after app restart where safe.

A successful confirmation must authorize exactly the challenged action once. It must not be discarded by a second unconditional block, and it must not authorize a modified plan.

### 5.5 Event correlation and truthfulness need repair

`Conversation.emit` creates new correlation and causation IDs rather than preserving the user request. Latency events are marked as mock-engine measurements even in the production path.

**Required correction**

- Introduce a `TurnContext` carrying session, turn, correlation, causation, actor, sensitivity, and timing data.
- Pass it through STT → conversation → intent → context → planning → policy → tools → verification → TTS.
- Record the actual STT/TTS/model/backend identifiers.
- Make false-success prevention a hard invariant: execution success is distinct from verification success.
- Add trace completeness tests.

### 5.6 The VS Code adapter is not policy-complete

The adapter constructs a policy request and emits it, but does not await a policy decision. Some bridge routes intentionally return failure.

**Required correction**

- Inject `PolicyEngine` directly.
- Evaluate every VS Code action.
- Implement a real extension bridge command protocol for diagnostics, tests, tasks, editor state, file/symbol navigation, and terminal sessions.
- Sign and authenticate bridge messages.
- Add dirty-buffer confirmation and post-action verification.

### 5.7 Computer use lacks a production planner and user path

The observe–plan–policy–act–verify loop is substantial, but no production planner is wired, and no active intent can start the loop.

**Required correction**

- Add a typed `ComputerUsePlanner` backed by a local model with strict JSON schema validation.
- Prefer Accessibility-tree observations; use screenshots only when needed.
- Add window selection and scope approval.
- Register computer-use capabilities in the tool catalog.
- Persist resumable confirmation state.
- Add live E2E fixtures and a restricted application allowlist for beta.

### 5.8 The platform and toolchain baseline is pre-release-sensitive

The repository currently uses `swift-tools-version: 6.4` and macOS 27. The release process must not depend on an unpinned snapshot or undocumented local toolchain state.

**Required correction**

- Add `TOOLCHAIN.md` with exact Xcode build, Swift version, SDK build, and hashes.
- Add a bootstrap validator that fails with an actionable message.
- Separate the development SDK target from the minimum distributable deployment target.
- Verify Swift 6.4 final availability before release; until then, pin the exact snapshot and never describe it as a stable public baseline.
- Maintain a stable-toolchain release branch if the main branch uses beta SDK features.

---

## 6. Target Runtime Architecture

### 6.1 Process model

The end state should separate responsibilities more strongly than the current single-process composition.

#### `AURA.app`

- SwiftUI window/menu-bar UI;
- onboarding and permission explanations;
- transcript, conversation, task, memory, and health surfaces;
- confirmation presentation;
- user-visible privacy indicators;
- no direct arbitrary shell or generated input execution.

#### `AuraRuntimeService`

- conversation/session orchestration;
- model routing;
- context assembly;
- typed intent and plan generation;
- policy client;
- task coordination;
- audit/event persistence.

#### `AuraAudioService`

- real-time audio capture;
- VAD;
- wake word;
- optional speaker hint;
- STT streaming;
- TTS scheduling;
- strict resource and privacy controls.

#### `AuraAutomationHelper`

- Accessibility;
- Apple Events;
- Shortcuts;
- ScreenCaptureKit;
- approved generated input;
- app-specific automation;
- no model inference.

#### `AuraAgentHelper`

- typed shell;
- Codex/Claude/Copilot/Ollama process/network boundaries;
- working-directory sandbox;
- worktrees;
- budgets and cancellation.

#### `AuraPluginHost`

- existing isolated plugin execution;
- signed manifest and capability enforcement.

#### `AuraStore`

- database and append-only evidence;
- encrypted secret references;
- migrations, retention, backup, and integrity verification.

Use XPC or an equivalently authenticated local IPC boundary for privileged helpers. Each request must include a typed capability, target, immutable request hash, correlation ID, and user/policy authority. Helpers must reject unregistered or replayed requests.

### 6.2 Runtime orchestration pipeline

```text
Audio/Text Input
    ↓
Turn Context + Language Detection
    ↓
Deterministic Bilingual Fast Path
    ↓ (if unresolved)
Local Structured NLU
    ↓
Context Reconstruction
    ↓
Dialogue Decision:
    answer | clarify | confirm | plan tools | delegate task
    ↓
Typed Plan Validation
    ↓
Policy Evaluation
    ↓
User Confirmation (when required)
    ↓
Adapter Execution
    ↓
Independent Verification
    ↓
Memory / Task / Audit Update
    ↓
Concise Spoken + Detailed Visual Response
```

No model response may skip plan validation, policy, or adapter typing.

### 6.3 Capability registry

Replace the closed `switch` as the only routing mechanism with a typed registry. A capability definition must include:

- stable capability ID and schema version;
- localized names and example utterances;
- input JSON schema;
- output/result schema;
- risk tier;
- required permissions;
- local/cloud classification;
- side effects;
- idempotency;
- timeout;
- confirmation rule;
- verification method;
- rollback method;
- adapter implementation;
- health state;
- privacy/sensitivity behavior.

The deterministic classifier and model planner select only capabilities already in this registry.

---

## 7. Natural-Language and Dialogue Architecture

### 7.1 Bilingual deterministic fast path

Expand the deterministic grammar for Turkish and English without converting it into an unmaintainable list.

Required categories:

- open/activate/hide/quit application;
- open file/folder/workspace/URL;
- read current status;
- stop/pause/resume/cancel;
- task status;
- run test/build;
- ask Codex/Claude/Copilot;
- inspect current window;
- mail/calendar summary;
- timer/reminder handoff where supported;
- volume/media controls where policy permits.

Use normalized lemmas, aliases, localized application names, and a generated app registry. Do not hardcode only eight apps.

Example equivalence:

```text
Safari'yi aç
Safari aç
open Safari
launch Safari
switch to Safari
```

All map to the same typed `app.activate` capability.

### 7.2 Structured local NLU

Use `OllamaAdapter.classify` or a dedicated local structured-generation API to produce a schema such as:

```json
{
  "dialogue_act": "execute|answer|clarify|confirm|delegate",
  "language": "tr|en|mixed",
  "capability_id": "mail.summarize_unread",
  "arguments": {},
  "confidence": 0.0,
  "references": [],
  "requires_context": true
}
```

Rules:

- schema validation is mandatory;
- unknown capability IDs are rejected;
- arguments are normalized and validated independently;
- model confidence is advisory, not authority;
- destructive intent requires direct evidence and explicit confirmation;
- prompt-injection content from screens, mail, web pages, files, or tool output is always untrusted data.

### 7.3 Conversational reasoning

Add a `DialogueEngine` that can invoke:

- deterministic responses for status and simple commands;
- a local model for ordinary conversation, summarization, clarification, and plan explanation;
- optional remote reasoning for explicitly allowed complex tasks;
- no-model degraded responses when neither is available.

The dialogue engine must receive:

- minimal current turn;
- language and locale;
- relevant context bundle with provenance;
- tool catalog summaries;
- policy constraints;
- response-length and voice constraints.

It returns a typed `DialogueResponse`, never executable text.

### 7.4 Multi-turn slot filling

Persist pending dialogue state:

- unresolved capability;
- missing arguments;
- candidate entities;
- confirmation challenge;
- selected window/application;
- task being discussed;
- expiry and cancellation rules.

Examples:

- “Mailimi kontrol et.” → “Which account, or all accounts?”
- “Sonuncusunu aç.” → resolve candidates with provenance; clarify if tied.
- “Gönder.” → require an existing reviewed draft and recipient confirmation.
- “Onu sil.” → reject or clarify unless the target is direct and recent.

### 7.5 Response generation

Separate:

1. factual execution result;
2. verification result;
3. user-facing summary;
4. TTS-safe text;
5. detailed UI evidence.

Spoken responses should be concise. The UI should show targets, adapters, permissions, sources, elapsed time, and failures.

---

## 8. Voice System Completion

### 8.1 Activation modes

Implement three user-controlled modes:

- **Push to Talk:** default and always available.
- **Wake word:** local acoustic model, optional, visible state.
- **Conversation continuation:** limited post-response listening window with explicit indicator.

The wake-word implementation must not use `MarkerWakeWordDetector`. Select a real acoustic engine only after:

- Turkish phrase support;
- Apple Silicon latency/energy benchmark;
- license review;
- offline operation;
- false-accept/false-reject evaluation;
- anti-trigger testing against AURA’s own TTS;
- cancellation and privacy verification.

### 8.2 STT routing

Retain Apple Speech as one adapter, but add an `STTRouter`:

- Apple on-device Speech for low-latency supported locales;
- local Whisper-family adapter for bilingual/code-switch reliability and offline fallback;
- optional vocabulary adaptation;
- language detection per turn;
- per-engine confidence normalization;
- fallback on availability or quality failure.

Acceptance data must include Turkish, English, mixed technical speech, names, paths, commands, and noisy environments.

### 8.3 Turn completion

Replace “every final STT segment ends the turn” with a combined decision using:

- VAD silence;
- STT finality;
- punctuation/prosody where available;
- incomplete-sentence detection;
- deterministic command completion;
- maximum latency bound.

### 8.4 TTS routing

Use system Yelda as the reliable default until neural TTS meets latency and quality gates.

Add:

- cached frequent prompts;
- neural warm pool with strict memory limit;
- MPS watchdog and CPU fallback policy;
- voice/reference consent record;
- Turkish pronunciation evaluation;
- first-audio latency and synthesis-factor metrics;
- immediate barge-in cancellation;
- no reading of secrets or raw tokens.

On a 16 GB device, TTS, STT, and reasoning models must share a resource governor. A 3.5 GB TTS model must not remain resident while a large reasoning model is required unless measured memory pressure permits it.

---

## 9. Tool and Adapter Completion

### 9.1 Application and filesystem capabilities

Add typed capabilities for:

- application discovery, activation, hiding, quitting;
- opening files, folders, URLs, and workspaces;
- locating recent files;
- reading file metadata;
- safe file read;
- copy/move/rename;
- Trash rather than permanent delete by default;
- Finder selection and reveal;
- explicit directory scopes.

Use native APIs first. File mutations require verification and, where appropriate, rollback metadata.

### 9.2 Browser architecture

Implement a browser adapter stack in priority order:

1. browser extension or structured debugging/automation protocol where explicitly enabled;
2. URL/open/search through native APIs;
3. Accessibility tree;
4. Apple Events/Shortcuts;
5. screen-based computer use as last resort.

Capabilities should include:

- open URL/search query;
- list tabs and active tab metadata;
- read approved page text;
- navigate back/forward/reload;
- focus a tab;
- fill a non-sensitive field;
- click a semantically identified control;
- download to an approved directory;
- summarize a page;
- detect authentication/payment/destructive boundaries.

Never extract passwords, session cookies, or hidden tokens. Web content is untrusted and cannot change AURA policy.

### 9.3 Mail

Implement two explicit modes:

#### Apple Mail adapter

Use structured Apple Events/Shortcuts/Accessibility only after verifying current supported interfaces. Support:

- list accounts/mailboxes;
- count unread;
- retrieve approved message headers and bodies;
- summarize threads;
- search;
- draft;
- mark read/archive;
- send only after recipient, subject, body, and attachment confirmation.

#### Gmail adapter

Use OAuth with least-privilege scopes and Keychain-backed tokens. Separate scopes for read, modify, compose, and send. Do not request send scope for a read-only installation.

Required actions:

- unread summary;
- search;
- thread read;
- attachment metadata/download with confirmation;
- draft creation;
- explicit send confirmation;
- audit of message IDs without storing entire private bodies by default.

Browser-based Gmail computer use remains a fallback, not the primary integration.

### 9.4 Calendar and contacts

Add structured adapters for:

- today/tomorrow agenda;
- free/busy windows;
- event search and details;
- create/update/delete event with confirmations;
- attendee resolution through contacts;
- conflict detection;
- time-zone handling;
- contact lookup without broad address-book exposure.

### 9.5 Notifications and reminders

Support notification summaries and reminders only through verified system APIs or Shortcuts. Avoid broad notification scraping. Provide per-application permission and redaction controls.

---

## 10. Computer-Use Productization

### 10.1 Observation model

A `ScreenObservation` used by a planner should contain:

- approved app/window identity;
- Accessibility tree summary;
- OCR text with redaction;
- semantic controls and actions;
- bounded visual descriptors;
- freshness;
- content hash;
- secure-field state;
- modal-dialog state;
- source provenance.

Raw images should remain ephemeral and local unless the user explicitly enables a bounded diagnostic mode.

### 10.2 Production planner

Implement a local `ComputerUsePlanning` conformer that:

- receives a typed objective and observation;
- emits only `ComputerUsePlan` JSON validated against the closed action schema;
- limits steps and coordinates;
- includes expected postcondition per step;
- prefers Accessibility anchors;
- cannot invent bundle IDs or capabilities;
- treats screen/page text as untrusted;
- stops when uncertain.

### 10.3 Confirmation and resume

When the loop encounters a confirmation boundary:

1. persist the loop checkpoint and observation hash;
2. show the proposed action and target;
3. after approval, recapture the window;
4. verify app identity, target anchor, and plan hash;
5. continue only if the state remains compatible;
6. otherwise discard and re-plan.

### 10.4 Beta allowlist

Initial live computer-use support should be restricted to:

- Finder;
- Safari or one selected browser;
- VS Code;
- Terminal;
- Notes;
- Calendar;
- Mail in read-only mode.

Expand only after per-app live fixtures and safety tests pass.

---

## 11. VS Code and Coding-Agent Completion

### 11.1 VS Code bridge

Build a small signed VS Code extension with an authenticated local protocol. It should expose:

- active workspace and repo;
- active editor and selection;
- open/dirty files;
- diagnostics;
- symbols;
- tasks and tests;
- terminal sessions and working directories;
- command results;
- extension version/health.

The bridge must not execute arbitrary untyped text. Commands are enumerated and schema-versioned.

### 11.2 Fix policy enforcement

`VSCodeAdapter.execute` must call `PolicyEngine.evaluate`, resolve confirmation, and record the decision before invoking CLI, bridge, or terminal actions. An emitted request is not enforcement.

### 11.3 Complete task/test execution

Implement real bridge commands for:

- run named task;
- run current-file tests;
- run workspace tests;
- collect diagnostics and test results;
- cancel;
- verify exit/result state.

### 11.4 Coding-agent task flow

A coding request should:

1. resolve repository and workspace;
2. create or select a worktree if writes are allowed;
3. show backend, model, sandbox, time, file-write, and cost budgets;
4. obtain confirmation;
5. start a durable task;
6. stream normalized progress;
7. surface approval requests;
8. run validation;
9. present diff and test evidence;
10. never push, merge, release, or deploy without separate explicit authorization.

### 11.5 Agent capability health

Before offering a backend, verify:

- executable installed;
- version supported;
- authenticated state;
- working directory allowed;
- configuration valid;
- network policy compatible;
- model available;
- cancellation proven.

Unavailable backends should be visibly disabled, not silently selected.

---

## 12. Memory and Personalization Activation

### 12.1 Memory write policy

Only persist information that is:

- explicitly stated as a preference or fact;
- required for an active durable task;
- derived from verified tool evidence;
- summarized with provenance and retention.

Do not automatically store full mail, page, document, or transcript content.

### 12.2 Context bundle contract

Every model call should receive a bounded `ContextBundle` with:

- purpose;
- included records;
- source IDs;
- confidence;
- freshness;
- sensitivity;
- token estimate;
- exclusions;
- unresolved contradictions.

### 12.3 User interface

Add:

- memory search;
- “why AURA remembered this” provenance view;
- correction/supersession;
- delete/forget;
- retention controls;
- project scope;
- export.

### 12.4 Personal assistant profile

Store user-controlled preferences such as:

- preferred language and response length;
- default browser/mail account/calendar;
- coding backend preferences;
- confirmation strictness where policy permits;
- working directories;
- voice selection;
- quiet hours;
- local-only/cloud-allowed mode.

Security boundaries cannot be weakened by preference.

---

## 13. Security Architecture

### 13.1 Authority model

Maintain the golden rule:

> Models propose; policy authorizes; typed adapters execute; verification confirms; evidence records.

Untrusted sources include:

- web pages;
- email bodies and attachments;
- documents;
- screen OCR;
- terminal output;
- model output;
- plugin output;
- remote-agent output.

None carries user authority.

### 13.2 Privilege separation

Move shell, Accessibility, screen capture, and generated input behind least-privilege helpers. The UI/runtime process should not combine unrestricted network access with all local control privileges.

### 13.3 Network enforcement

The current network allowlist must become an enforced dependency:

- all `URLSession` creation goes through an approved factory;
- DNS/IP rebinding defenses;
- scheme and port restrictions;
- loopback policy for Ollama;
- TLS validation;
- no redirects to unapproved domains;
- per-adapter domain grants;
- audit without leaking tokens or content.

### 13.4 Secrets

Use Keychain references for:

- OAuth tokens;
- API keys;
- signing/update credentials;
- plugin vendor keys;
- remote-agent credentials.

Never place secret values in configuration, logs, events, prompts, test fixtures, crash reports, or ledger entries.

### 13.5 Confirmation tiers

At minimum:

- **No confirmation:** reversible observation and user-approved status queries.
- **Confirm once:** app quit, file mutation, mail archive/mark, calendar creation, generated UI input.
- **Review and confirm:** send mail, upload file, publish, share, add attendee, execute write-capable coding agent.
- **Typed/high-friction confirmation:** permanent deletion, credential/permission changes, destructive shell, financial or account actions.
- **Always denied unless separately enabled:** password entry, secret extraction, security-control bypass, silent surveillance.

### 13.6 Supply chain

- pin Swift toolchain and external Python/model revisions;
- generate dependency SBOM;
- verify hashes;
- scan packaged helper source;
- sign all nested code;
- reproducible build evidence where practical;
- plugin vendor PKI before public marketplace claims.

---

## 14. UI and User Experience

The current menu is a control panel, not yet a full assistant.

Add the following surfaces.

### 14.1 Conversation window

- live partial transcript;
- final user turn;
- AURA response;
- tool plan and status;
- clarification prompts;
- confirmation card;
- evidence and error expansion;
- text input fallback;
- stop/cancel;
- privacy state.

### 14.2 Task center

- queued/running/paused/awaiting-confirmation/completed/failed;
- progress and latest event;
- backend/model;
- workspace;
- budgets;
- cancel/resume/retry;
- diff/tests/evidence.

### 14.3 Capability and permission center

- installed capabilities;
- adapter health;
- required permissions;
- grants and expiry;
- revoke;
- per-capability local/cloud designation;
- test action.

### 14.4 Model center

- STT, NLU/reasoning, TTS, coding models;
- installed/available/loaded;
- memory estimate;
- language support;
- health and benchmark;
- selected fallback chain.

### 14.5 Privacy and memory center

- retained data;
- recent captures;
- diagnostic opt-ins;
- memory inspection;
- export/delete;
- local-only mode;
- network activity summary.

### 14.6 Onboarding

Onboarding should run a real capability check:

1. verify hardware/OS/toolchain for development builds;
2. explain local vs optional cloud processing;
3. request only voice permissions initially;
4. test microphone and STT;
5. test TTS;
6. offer Accessibility/Screen Recording only when enabling desktop control;
7. choose models;
8. choose mail/calendar/browser integrations;
9. run a guided safe command;
10. show emergency stop and privacy controls.

---

## 15. Observability and Truthfulness

### 15.1 Trace model

One user turn must preserve the same correlation chain across:

- activation;
- audio;
- STT;
- intent;
- context;
- dialogue;
- plan;
- policy;
- confirmation;
- tool;
- verification;
- memory;
- response;
- TTS.

### 15.2 Runtime health

Expose health for every subsystem:

- ready;
- degraded;
- permission blocked;
- configuration invalid;
- dependency missing;
- model loading;
- circuit open;
- disabled by user;
- unsupported.

Do not use `try?` for production service construction without retaining and displaying the failure.

### 15.3 Success semantics

Use distinct outcomes:

- `proposed`;
- `authorized`;
- `started`;
- `executed`;
- `verified`;
- `completed`;
- `completed_with_warning`;
- `failed`;
- `cancelled`;
- `unknown_outcome`.

AURA says “done” only for `verified` or an explicitly defined equivalent.

### 15.4 Metrics

Collect local, content-free aggregates:

- wake false accepts/rejects;
- STT word/entity error;
- classification accuracy;
- clarification rate;
- policy denial/confirmation rate;
- tool success and verification rate;
- first partial, stable transcript, first token, first audio, and completion latency;
- model load/residency;
- memory pressure and thermal state;
- crash and recovery;
- user correction rate.

Telemetry export remains opt-in and excludes raw content.

---

## 16. Testing and Evaluation Program

### 16.1 Test pyramid

1. **Pure unit tests:** schemas, policies, parsers, reducers, migrations.
2. **Contract tests:** each adapter against recorded official outputs.
3. **Integration tests:** real service composition with controlled dependencies.
4. **System tests:** signed app with permissions on dedicated Macs.
5. **Adversarial tests:** injection, spoofing, poisoning, confirmation races.
6. **Soak tests:** audio, wake word, tasks, memory, update/recovery.
7. **Human evaluation:** Turkish/English speech, TTS quality, accessibility, usability.

### 16.2 Required golden datasets

- Turkish and English command set;
- code-switch speech;
- names, technical vocabulary, paths, repo terms;
- ambiguous reference set;
- destructive-intent set;
- prompt-injection mail/web/document fixtures;
- screen redaction fixtures;
- browser and VS Code UI fixtures;
- computer-use progress/no-progress cases;
- mail/calendar confirmation cases.

### 16.3 Live hardware matrix

At minimum:

- primary M5/16 GB target;
- one earlier supported Apple Silicon Mac;
- clean macOS account;
- upgraded account;
- permissions denied/revoked;
- no Ollama/no coding CLI;
- low disk;
- memory pressure;
- offline network;
- external microphone/headset;
- display scaling and multiple displays.

### 16.4 CI

Create separate jobs:

- stable compiler build;
- pinned development compiler build;
- formatting/lint;
- unit/integration tests;
- adversarial tests;
- coverage;
- package/signature structure validation;
- Python helper tests;
- SBOM and dependency verification;
- release-candidate notarization dry run where credentials permit.

Self-hosted runner health must be monitored. CI results and artifacts must be attached to the commit/release.

### 16.5 Coverage

Restore the documented 80% line-coverage target for production Swift sources. Require higher branch/path coverage for:

- policy;
- confirmation;
- shell;
- generated input;
- memory mutation;
- OAuth/token handling;
- updater;
- migration/recovery.

Coverage is not a substitute for live tests.

---

## 17. Packaging, Distribution, and Operations

### 17.1 Build system

Move from an assembly-only SwiftPM script toward a reproducible Xcode project/workspace or a rigorously maintained package pipeline that can:

- sign every nested executable;
- apply entitlements per process;
- archive;
- export;
- notarize;
- staple;
- build DMG/PKG;
- produce symbols and update metadata.

### 17.2 Developer ID and notarization

Before external distribution:

- enroll and provision Developer ID;
- use Hardened Runtime;
- remove development-only entitlements;
- sign app and all helpers with appropriate identities;
- include secure timestamp;
- submit with `notarytool` or Notary API;
- inspect logs;
- staple ticket;
- validate with `codesign`, `spctl`, and clean-machine launch.

Local signing is not release signing.

### 17.3 Updates

Implement signed atomic updates with:

- channel selection;
- manifest signature;
- package hash;
- downgrade/replay protection;
- staged rollout;
- rollback;
- helper compatibility;
- migration preflight;
- recovery mode.

Do not build a custom updater cryptographic protocol when a mature, auditable solution can meet the architecture.

### 17.4 Launch at login and continuous operation

Add explicit user-controlled launch-at-login through the supported ServiceManagement path. Include:

- enable/disable UI;
- background-service health;
- crash restart bounds;
- safe mode;
- no microphone activation when privacy mode is off;
- sleep/wake and device-change recovery.

### 17.5 Recovery

Provide:

- reset permissions guidance;
- reset model cache;
- reset grants;
- reset non-audit memory;
- rebuild database projection;
- safe-mode launch;
- export support bundle;
- full uninstall;
- factory reset preserving required audit records.

---

## 18. Execution Roadmap

This roadmap supersedes using optional Phases 26–30 as the immediate next action. Those phases may resume after the assistant is actually integrated and release-ready.

### Track R0 — Repository Truth and Governance Repair

**Objective:** Make repository status, evidence, and toolchain claims reliable.

**Work**

- Reconcile `CURRENT_STATE.md`, `SESSION_STARTER.md`, project ledger, README, and ADR index.
- Add generated status schema and validator.
- Record operational vs disconnected vs simulated vs release-gated capability states.
- Pin toolchain/SDK.
- Add an architecture-debt register.
- Add CI checks for stale commit IDs, contradictory phase state, and unverified success claims.

**Acceptance**

- One unambiguous current state.
- Every completion claim links to command evidence or a live acceptance record.
- Toolchain bootstrap is deterministic.
- No stale next-action text.

### Track R1 — Integration Spine and Trace Correctness

**Objective:** Create one production orchestration path and repair event/confirmation semantics.

**Work**

- Add `TurnContext`.
- Add `CapabilityRegistry`.
- Add `CapabilityOrchestrator`.
- Register currently operational app, shell, and coding-agent tools.
- Preserve event correlation.
- Replace silent `try?` service construction with health results.
- Implement confirmation transaction and resume.
- Separate execution from verification.
- Add trace-completeness and confirmation-race tests.

**Acceptance**

- A Push-to-Talk command creates one complete correlated trace.
- Confirmed actions execute once; denied/expired actions do not.
- Restart behavior for pending confirmations is deterministic.
- Runtime health accurately reports every subsystem.

### Track R2 — Bilingual Intent and Dialogue Engine

**Objective:** Make Turkish/English natural instructions and general conversation functional.

**Work**

- Add bilingual deterministic grammar.
- Add application/entity registry.
- Connect Ollama structured classification.
- Add `DialogueEngine`.
- Add local free-form reasoning for conversation.
- Add typed clarification and slot filling.
- Add text input UI.
- Connect context bundle to dialogue.

**Acceptance**

- Golden Turkish/English command dataset meets target accuracy.
- Open-ended questions produce model-backed responses, not canned text.
- Unknown/ambiguous instructions clarify rather than guess.
- No model output bypasses typed schemas.

### Track R3 — Dynamic Tool Catalog and Plan Execution

**Objective:** Expand beyond the five hardcoded intent kinds.

**Work**

- Define capability manifests.
- Register filesystem, URL, status, model, task, screen, and VS Code capabilities.
- Add typed multi-step plans.
- Validate plan dependencies, budgets, and risk.
- Add postcondition verification and rollback metadata.
- Localize capability names/examples.

**Acceptance**

- Model can select only registered capabilities.
- Invalid capability/argument output is rejected.
- Multi-step read-only workflows execute and verify.
- Side-effecting workflows pause at correct confirmation gates.

### Track R4 — Computer Use and Screen Context

**Objective:** Make existing screen/computer-use components operable and safe.

**Work**

- Add production planner.
- Add active-window/approved-window selection.
- Add policy grants and UI onboarding.
- Add confirmation checkpoint/resume.
- Add Accessibility-tree observation.
- Add beta app allowlist and live fixtures.
- Add voice emergency-stop path.

**Acceptance**

- Complete bounded tasks in the beta app set.
- No action occurs in secure fields or unapproved apps.
- Identity/modal/no-progress changes stop safely.
- Confirmation resume recaptures and revalidates state.

### Track R5 — Browser and Personal Productivity Adapters

**Objective:** Deliver the practical assistant workflows the product currently lacks.

**Work**

- Browser adapter.
- Apple Mail and/or Gmail OAuth adapter.
- Calendar adapter.
- Contacts resolution.
- URL/search/page summarization.
- Read-only first rollout; mutation/send after review gates.
- Keychain token storage and scope UI.

**Acceptance**

- “Check my unread mail” works through an approved structured adapter.
- “What is on my calendar tomorrow?” works with conflict/time-zone accuracy.
- Drafting is separated from sending.
- Web/mail injection tests pass.
- Revoking integration access immediately disables it.

### Track R6 — VS Code and Coding Workspace Completion

**Objective:** Make coding interaction genuinely useful from voice and UI.

**Work**

- Build authenticated VS Code extension bridge.
- Enforce policy in `VSCodeAdapter`.
- Implement run task/tests and diagnostics.
- Resolve workspace/repo/working directory.
- Connect coding tasks to Task Center.
- Verify CLI versions and auth.
- Add diff/test review.

**Acceptance**

- Open file/symbol, run tests, read diagnostics, and start an agent from natural Turkish/English instructions.
- Dirty editors are protected.
- All write-capable agent actions are bounded and reviewable.
- Completion claims include tests/diff evidence.

### Track R7 — Always-Available Voice and Model Resource Governor

**Objective:** Add safe wake-word operation and stable local model coexistence.

**Work**

- Evaluate and integrate real wake-word engine.
- Add adaptive VAD/noise calibration.
- Add STT router and Whisper fallback.
- Add resource governor for STT/NLU/TTS.
- Improve turn completion and barge-in.
- Benchmark neural TTS and select production fallback.
- Add sleep/wake and audio-device recovery.

**Acceptance**

- Wake-word FAR/FRR targets met.
- Turkish/English mixed speech targets met.
- No self-trigger loop.
- 8-hour voice soak passes.
- Memory/thermal budget remains safe on 16 GB.

### Track R8 — Memory, Personalization, and Explainability

**Objective:** Make the existing memory/context system visible and useful.

**Work**

- Connect context to dialogue and tools.
- Add memory UI.
- Add preference profile.
- Add contradiction resolution.
- Add retention and deletion controls.
- Add context-inspection view.

**Acceptance**

- Cross-session references resolve with provenance.
- User can inspect and correct remembered facts.
- Destructive targets never resolve from weak memory.
- Retention/deletion tests pass.

### Track R9 — Product UI, Accessibility, and Operating Modes

**Objective:** Transform the control panel into a usable assistant application.

**Work**

- Conversation UI.
- Task Center.
- Capability/permission center.
- Model center.
- Privacy/memory center.
- onboarding.
- accessibility labels, keyboard navigation, VoiceOver order, contrast, Dynamic Type.
- localization.

**Acceptance**

- All primary workflows are operable without terminal setup.
- VoiceOver and keyboard-only paths pass.
- Error/degraded states are actionable.
- Turkish and English UI localization complete.

### Track R10 — Security Boundary Hardening

**Objective:** Reduce blast radius before beta distribution.

**Work**

- Move privileged actions into helpers.
- Enforce network factory.
- Harden IPC.
- Keychain integration.
- OAuth threat model.
- browser/mail/document indirect-injection tests.
- signed plugin/update trust roots.
- independent security review.

**Acceptance**

- Main UI/runtime does not combine unrestricted network and unrestricted local automation privileges.
- Every externally influenced input path has a threat model.
- Red-team blockers are resolved or explicitly accepted.
- Security review findings tracked.

### Track R11 — Release Engineering and Continuous Operation

**Objective:** Produce an installable, updateable, recoverable beta.

**Work**

- Xcode/archive pipeline.
- Developer ID signing.
- notarization.
- DMG/PKG.
- launch at login.
- signed updates.
- safe mode and support bundle.
- clean install/upgrade/uninstall tests.
- release notes and privacy documentation.

**Acceptance**

- Clean target Mac installs and launches without developer tools.
- Gatekeeper accepts the package.
- Permissions persist appropriately across update.
- Update rollback works.
- Uninstall and factory reset are documented and tested.

### Track R12 — Beta Validation and Release Candidate

**Objective:** Prove real-world reliability before “fully operational” status.

**Work**

- dogfood group;
- telemetry opt-in;
- issue severity/SLA;
- daily crash and failure review;
- speech and task success evaluation;
- security simulation;
- accessibility review;
- release candidate freeze.

**Acceptance**

- SLOs sustained over the defined beta window.
- No open critical security or data-loss issue.
- False-success rate below threshold.
- Release evidence package approved.
- Status documentation updated from verified evidence.

---

## 19. Priority Backlog

### P0 — Blocks meaningful assistant use

- fix ledger/status contradictions;
- add integration orchestrator;
- preserve event correlation;
- repair confirmation/resume semantics;
- connect Ollama to NLU/dialogue;
- add bilingual intent handling;
- replace canned conversation;
- expose runtime health;
- implement text input;
- enforce VS Code policy;
- add production computer-use planner or mark feature disabled.

### P1 — Delivers the intended personal assistant

- browser adapter;
- mail/Gmail;
- calendar/contacts;
- full VS Code bridge;
- practical file/workspace actions;
- Task Center;
- memory UI;
- STT router;
- real wake word;
- launch at login;
- model/resource manager.

### P2 — Required for public beta/release

- privilege separation;
- independent CI;
- 80%+ coverage and live hardware gates;
- Developer ID/notarization;
- signed updates;
- OAuth/keychain hardening;
- accessibility/localization;
- support bundle and safe mode;
- independent security review.

### P3 — Post-beta ecosystem

- public plugin catalog/PKI;
- cross-device sync;
- persona/workflow marketplace;
- enterprise governance;
- SDK and external adapter ecosystem.

---

## 20. File-Level Change Map

### Existing files requiring near-term modification

- `Sources/AURA/AuraKernel.swift`
  - replace passive construction with registered capability wiring;
  - add subsystem health;
  - inject orchestrator and confirmation transaction manager.

- `Sources/AURA/AuraAppModel.swift`
  - conversation transcript;
  - text input;
  - task and health detail;
  - pending clarification/confirmation state;
  - integration setup.

- `Sources/AURA/AuraMenuView.swift`
  - redesign into navigation for conversation, tasks, capabilities, privacy, and diagnostics.

- `Sources/AuraIntent/IntentEngine.swift`
  - bilingual layered classifier;
  - model-assisted typed NLU;
  - context-aware dialogue state.

- `Sources/AuraIntent/TypedIntent.swift`
  - evolve to capability-based schema without unbounded enum growth.

- `Sources/AuraIntent/ToolRouter.swift`
  - replace/augment closed switch with capability registry;
  - fix confirmation behavior;
  - add verification.

- `Sources/AuraIntent/IntentDispatchCoordinator.swift`
  - preserve turn context;
  - support dialogue, clarification, multi-step plans, and resumable tasks.

- `Sources/AuraAgent/Conversation.swift`
  - preserve correlation;
  - correct engine metadata;
  - improve turn-completion and recovery.

- `Sources/AuraAgent/OllamaAdapter.swift`
  - connect to dialogue/NLU/planning;
  - enforce network factory;
  - add streaming and model health visibility.

- `Sources/AuraVSCode/VSCodeAdapter.swift`
  - real policy decision;
  - authenticated bridge;
  - run-task/test implementation.

- `Sources/AuraComputerUse/ComputerUseControlLoop.swift`
  - persisted checkpoints;
  - confirmation resume;
  - stronger postconditions.

- `Sources/AuraScreen/ScreenContextEngine.swift`
  - Accessibility-tree integration;
  - observation consumption controls;
  - runtime health.

- `Sources/AuraCore/AuraConfiguration.swift`
  - model routing, integrations, operating modes, and deployment configuration;
  - avoid insecure override paths.

- `Package.swift`
  - new targets/adapters;
  - explicit toolchain strategy;
  - eventual XPC/helper targets.

- `.github/workflows/ci.yml`
  - stable and pinned jobs;
  - artifacts/status;
  - security and packaging checks.

- `scripts/*`
  - bootstrap, status verification, archive, notarization, package, update, and system-test scripts.

- `ledger/CURRENT_STATE.md`
  - generated projection rather than contradictory manual prose.

### Proposed new modules

```text
Sources/AuraRuntime/
  AssistantRuntime.swift
  CapabilityOrchestrator.swift
  TurnContext.swift
  DialogueEngine.swift
  ConfirmationTransaction.swift
  VerificationCoordinator.swift
  RuntimeHealthRegistry.swift

Sources/AuraCapabilities/
  CapabilityManifest.swift
  CapabilityRegistry.swift
  CapabilityPlan.swift
  CapabilityResult.swift
  BuiltInCapabilities.swift

Sources/AuraNLU/
  BilingualFastPath.swift
  StructuredNLU.swift
  LanguageRouter.swift
  SlotFilling.swift

Sources/AuraBrowser/
Sources/AuraMail/
Sources/AuraCalendar/
Sources/AuraContacts/
Sources/AuraFileSystem/
Sources/AuraModels/
Sources/AuraIPC/

Extensions/AURAVSCode/
Helpers/AuraAutomationHelper/
Helpers/AuraAgentHelper/

Tests/AuraRuntimeTests/
Tests/AuraCapabilitiesTests/
Tests/AuraNLUTests/
Tests/AuraBrowserTests/
Tests/AuraMailTests/
Tests/AuraCalendarTests/
Tests/AuraSystemTests/
```

Target names should be finalized through ADRs before implementation.

---

## 21. Measurable Product SLOs

Initial release-candidate targets:

| Metric | Target |
|---|---:|
| Push-to-Talk acknowledgement | median < 300 ms |
| Wake-to-acknowledgement | median < 500 ms |
| First STT partial | median < 500 ms |
| Stable transcript after end of speech | median < 900 ms |
| Deterministic simple-command completion | median < 1.5 s |
| Local conversational first token | median < 1.5 s after stable transcript |
| System TTS first audio | median < 250 ms |
| Tool false-success rate | < 0.1% |
| Destructive action without confirmation | 0 |
| Secure-field generated input | 0 |
| Unapproved screen capture | 0 |
| Crash-free sessions | > 99.5% in beta |
| Successful restart recovery for durable tasks | > 99% |
| Turkish/English intent accuracy on golden set | > 95% |
| Ambiguous destructive target auto-execution | 0 |

SLOs must be measured on the target 16 GB device and reported with sample size and engine/model versions.

---

## 22. Required ADRs Before Coding Major Changes

1. **ADR-034 — Runtime Completion Program and Capability Registry**
2. **ADR-035 — Turn Context, Correlation, and Truthful Completion Semantics**
3. **ADR-036 — Bilingual Hybrid NLU and Dialogue Model Routing**
4. **ADR-037 — Confirmation Transaction and Resumable Tool Execution**
5. **ADR-038 — Privileged Helper and XPC Boundary**
6. **ADR-039 — Browser/Mail/Calendar Integration and OAuth Scope Model**
7. **ADR-040 — Production Computer-Use Planner**
8. **ADR-041 — STT Router and Real Wake-Word Engine**
9. **ADR-042 — VS Code Authenticated Extension Bridge**
10. **ADR-043 — Stable Toolchain, Deployment Target, and Release Pipeline**
11. **ADR-044 — Signed Update and Rollback Mechanism**

Existing ADRs should be superseded only where their assumptions no longer match the connected product.

---

## 23. First Implementation Sequence

The first implementation cycle should contain small, reviewable commits in this order:

1. Reconcile status documentation and add capability-state inventory.
2. Add toolchain manifest and bootstrap validator.
3. Introduce `TurnContext` and trace tests.
4. Fix latency engine metadata and event correlation.
5. Introduce confirmation transaction tests and repair router behavior.
6. Add runtime health registry; remove silent construction failures.
7. Introduce capability manifest/registry with existing app/shell/agent tools.
8. Add bilingual deterministic command fixtures.
9. Connect Ollama structured classification behind a feature flag.
10. Add local dialogue response path and remove `Got it.` placeholder.
11. Add text input and transcript UI.
12. Add clarification/slot-filling state.
13. Register screen and VS Code capabilities as disabled until their acceptance gates pass.
14. Enforce VS Code policy and implement one verified bridge command.
15. Implement production computer-use planner prototype in read-only/no-input mode.
16. Add browser URL/open/read-only capability.
17. Add read-only mail/calendar integration.
18. Expand live system tests.
19. Begin privilege separation.
20. Build signed internal beta package.

Each commit must update evidence and must not claim subsequent capabilities as complete.

---

## 24. Explicit Non-Goals for the Completion Program

The following should not distract from making the core assistant work:

- cross-device sync before single-device reliability;
- public plugin marketplace before plugin PKI and core adapter maturity;
- autonomous persona creation;
- enterprise compliance reporting;
- broad coordinate-based automation across arbitrary applications;
- cloud-first ambient audio;
- silent mail sending or document publishing;
- running multiple large local models concurrently without measured resource safety;
- adding more “phases” whose code is not connected to the user runtime.

---

## 25. Release Readiness Checklist

A release candidate cannot be approved until:

- [ ] status and ledger are consistent;
- [ ] exact toolchain is pinned;
- [ ] all production modules expose health;
- [ ] Turkish/English dialogue works;
- [ ] general conversation is model-backed;
- [ ] confirmation transactions resume safely;
- [ ] app, file, browser, mail, calendar, and coding workflows have defined support;
- [ ] computer use has a production planner and beta allowlist;
- [ ] VS Code policy is enforced;
- [ ] wake word is real or clearly excluded from the release;
- [ ] STT/TTS/model resource budgets pass;
- [ ] memory and privacy controls are user-visible;
- [ ] privileged operations are separated;
- [ ] network allowlists are enforced;
- [ ] CI runs and publishes evidence;
- [ ] live hardware tests pass;
- [ ] coverage target is met;
- [ ] Developer ID signing and notarization pass;
- [ ] update/rollback passes;
- [ ] clean install, upgrade, recovery, and uninstall pass;
- [ ] no critical security issue is open;
- [ ] no false-success blocker is open;
- [ ] release documentation is complete.

---

## 26. Final Recommendation

AURA should be treated as a **strong subsystem prototype with a partially operational voice shell**, not as a completed assistant.

The repository has enough high-quality foundations that a rewrite would waste substantial work. The correct strategy is to preserve the existing typed, policy-controlled components and build the missing integration spine around them.

The next milestone should be named:

> **Runtime Completion Milestone 1 — One Truthful Bilingual Assistant Loop**

Its demonstration must be:

1. launch the signed development app;
2. press Push to Talk or type;
3. speak naturally in Turkish or English;
4. receive a structured local intent or conversational answer;
5. execute one registered safe tool;
6. request and honor confirmation for a mutation;
7. verify the result;
8. show one correlated trace and durable task/memory evidence;
9. speak a concise truthful response;
10. recover cleanly from a denied permission or unavailable model.

Only after this vertical slice works should browser, mail, full computer use, wake word, and release distribution be layered on top.

---

## Appendix A — Verified Repository Facts Used by This Plan

- `AURAApp` provides a SwiftUI window, menu bar item, and settings scene.
- Push to Talk is the supported production activation path.
- the configured production STT engine is Apple Speech with `requiresOnDeviceRecognition`.
- the production intent classifier is deterministic and English-command-oriented.
- the active intent vocabulary is limited to conversation, app activation/termination, shell, and coding-agent runs.
- open conversation returns a fixed acknowledgement.
- the kernel constructs advanced services that the router cannot invoke.
- the computer-use loop and generated-input executor contain real production API paths, but no production planner is wired.
- the VS Code adapter does not yet enforce the constructed policy decision and does not implement bridge task/test execution.
- no dedicated browser, mail, calendar, or contacts adapter was found.
- the wake-word detector is explicitly a synthetic test detector.
- Chatterbox remains subject to live performance and consent gates.
- the repository records approximately 70% line coverage, below the original 80% target.
- the GitHub workflow requires a self-hosted macOS Swift 6.4 runner, and no associated workflow runs/statuses were found for the audited commit.
- the package and Info.plist target macOS 27; the package declares Swift tools 6.4.
- local signing and package verification are development evidence, not Developer ID notarized distribution.

## Appendix B — External Platform Verification Gates

Before implementing or releasing platform-sensitive code, verify against current official documentation and installed SDK/tool help:

- Swift 6.4 final vs snapshot status and exact compiler build;
- macOS 27 SDK and minimum deployment behavior;
- Speech framework locale/on-device capabilities;
- ScreenCaptureKit and Accessibility behavior;
- ServiceManagement launch-at-login APIs;
- App Intents integration opportunities;
- Developer ID, Hardened Runtime, `notarytool`, and stapling requirements;
- OAuth and provider-specific API requirements;
- current Codex, Claude Code, Copilot, Ollama, and VS Code interfaces.

No architecture document may be treated as permission to invent or assume an API.
