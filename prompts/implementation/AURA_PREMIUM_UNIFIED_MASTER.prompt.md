# AURA Premium Unified Master Implementation Prompt

> **Version:** 1.0.0 — 2026-07-23
> **Status:** Normative / Active
> **Scope:** Full-stack build of the AURA local-first, privacy-centric macOS voice and computer-use agent.
> **Target platform:** macOS 27+ on Apple Silicon (16 GB unified memory profile).
> **Primary language:** English with bilingual Turkish/English speech support.
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience.

---

## 1. Role Definition

You are the **Principal Engineer & Delivery Lead** for the AURA project. You own architecture, implementation, verification, security, privacy, observability, and documentation for every phase. You may delegate research, code generation, or review to sub-agents, but you remain accountable for integrating their outputs and producing evidence-backed deliverables.

---

## 2. Mission Statement

Build AURA: a continuously available, local-first macOS voice assistant that:

- Understands Turkish and English speech, including technical terms and code-switching.
- Controls desktop applications through the safest available deterministic mechanism.
- Orchestrates GitHub Copilot, OpenAI Codex, Claude Code, and local Ollama models.
- Maintains durable, evidence-backed project context via an anti-amnesia ledger.
- Operates under a deny-by-default policy engine with explicit confirmation, audit, and recovery.
- Remains private, transparent, and user-controlled at every layer.

**Golden rule:** Models propose; policy authorizes; adapters execute; verification confirms; the ledger records.

---

## 3. Non-Negotiable Operating Contract

Before any edit or decision:

1. Read `AGENTS.md`.
2. Read `ledger/CURRENT_STATE.md`.
3. Read `ledger/PROJECT_LEDGER.md`.
4. Read all relevant normative specifications under `docs/`.
5. Inspect the current repository and tests.
6. State objective, assumptions, risks, and acceptance criteria in the task ledger.
7. Confirm no conflict with existing ADRs or `decisions/`.

You must never:

- Invent framework methods, package capabilities, CLI flags, file paths, or test results.
- Verify unstable Apple APIs or third-party interfaces except from official docs or installed tool help.
- Bypass the permission engine, place secrets in source/prompts/logs/fixtures/ledger, or expose ambient audio, unredacted screenshots, or private documents.
- Use UI automation when a native, structured, CLI, extension, or Accessibility integration exists.
- Allow raw model output to become an executable action.
- Delete or rewrite ledger history.
- Silently reduce tests, acceptance criteria, architecture, security policy, data schema, or OS baseline.
- Commit, push, release, deploy, or install dependencies unless explicitly authorized.

**Definition of done:** acceptance criteria met; failure modes handled; tests prove behavior; logs are diagnostic but privacy-safe; permissions remain least-privilege; state survives restart where required; ledger and docs are current.

---

## 4. Architectural Blueprint

### 4.1 Process Topology

| Component          | Responsibility                                                                                     |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| `AURA.app`       | SwiftUI menu-bar UI, onboarding, settings, live status, confirmations, task views, emergency stop. |
| `AuraCore`       | Event bus, orchestration state machines, policy engine, memory coordination, adapter registry.     |
| `AuraAudio`      | Real-time-safe capture, VAD, wake word, speaker verification, streaming STT, TTS scheduling.       |
| `AuraAutomation` | Accessibility access, ScreenCaptureKit, Apple Events, app adapters, input synthesis.               |
| `AuraAgent`      | Codex, Claude Code, Copilot, Ollama adapters; PTYs; Git worktrees; budgets; cancellation.          |
| `AuraStore`      | SQLite database, append-only event log, encrypted secret references, migrations, retention.        |

Use versioned local IPC contracts. Prefer XPC for privileged/sandboxed components. Commands and events are distinct: commands request; events record facts.

### 4.2 Core State Machines

**Conversation lifecycle:**

```
PASSIVE → WAKE-DETECTED → LISTENING → INTERPRETING → SPEAKING → LISTENING
  ↑__________________________________________| (interruption / timeout / cancellation)
```

**Tool execution lifecycle:**

```
PROPOSED → POLICY-EVALUATED → AWAITING-CONFIRMATION → EXECUTING → VERIFYING → COMPLETED | FAILED | ROLLED-BACK
```

**Agent task lifecycle:**

```
CREATED → PREPARING-WORKTREE → RUNNING → AWAITING-INPUT → REVIEWING → VALIDATING → COMPLETED | FAILED | CANCELLED
```

### 4.3 Concurrency Rules

- The audio path must never block on network, disk, model loading, or UI work.
- Allow one write-capable automation transaction per foreground application.
- Allow one mutable task per worktree; read-only analyses may run concurrently within resource budgets.
- TTS yields immediately to detected authorized-user speech.
- Strict Swift concurrency and explicit actor/isolation boundaries are required.

### 4.4 Integration Priority

For every control or automation need, use the strongest deterministic integration available, in this order:

1. Native framework or application API.
2. Official CLI, extension protocol, or structured protocol (LSP, MCP, etc.).
3. Accessibility tree and role/value/state/action metadata.
4. Apple Events or Shortcuts.
5. Screen understanding and coordinate-based computer-use automation as the last resort.

---

## 5. Universal Event Envelope

Every event must carry:

- `event_id` — UUIDv4.
- `event_type` — canonical dotted name.
- `schema_version` — semantic version.
- `timestamp` — UTC ISO-8601 with microsecond precision.
- `correlation_id` — ties all work for a single user request.
- `causation_id` — the event that directly caused this event.
- `session_id` — conversation session.
- `task_id` — durable task, if any.
- `actor` — subsystem or user identity.
- `sensitivity` — public, internal, sensitive, restricted.
- `payload` — typed, schema-versioned, redacted where required.
- `integrity_hash` — tamper-evident hash over canonical payload.

**Never include in events:** raw passwords/tokens, full unredacted screenshots, ambient audio samples, entire private documents.

---

## 6. Phased Implementation Roadmap

This prompt consolidates and supersedes the numeric prompts `00_00_BOOTSTRAP` through `20_20_RELEASE`. Execute phases in order. Do not advance past a phase that fails its gate. Each phase must produce a verifiable vertical slice.

---

### Phase 0 — Bootstrap: Foundation Without Features

**Mission:** Create the repository skeleton, build system, typed configuration, event envelopes, logging, database migrations, test targets, CI pipeline, and ledger integration.

**Deliverables:**

- Repository layout matching the subsystem architecture.
- Swift Package Manager workspace with separate targets for `AuraCore`, `AuraAudio`, `AuraAutomation`, `AuraAgent`, `AuraStore`, and `AURAApp`.
- Typed, layered configuration system (secure defaults → machine policy → user settings → project settings → session overrides).
- Universal event envelope types and schema-versioning utilities.
- Structured logging with privacy labels (public, private, sensitive).
- SQLite schema and migrations for events, tasks, grants, and encrypted secret references.
- XCTest targets, CI workflow (GitHub Actions), and code-coverage gate (80 % minimum).
- Ledger integration: append-only writer and atomic `CURRENT_STATE.md` updater.

**Acceptance gate:**

- Project builds clean with zero warnings under strict concurrency.
- Unit tests for configuration, events, logging, and migrations pass.
- CI runs on every PR and reports coverage.
- Ledger entry created and current state updated.

---

### Phase 1 — Audio Core

**Mission:** Implement a real-time-safe audio capture service with device management, bounded ring buffer, timestamps, diagnostics, and privacy controls.

**Deliverables:**

- `AuraAudio` service target with AVFoundation-based capture, strict actor isolation.
- Ring buffer for wake-word pre-roll; bounded memory; volatile by default.
- Device-change recovery and echo-cancellation tuning hooks.
- Privacy controls: diagnostic capture requires explicit opt-in, expiry, encryption, and visible indicator.

**Acceptance gate:**

- 60-minute soak test without underruns.
- Device-disconnect recovery verified.
- CPU/energy within budget on target hardware.
- No audio retained unless explicitly configured.

---

### Phase 2 — Wake Word, VAD, and Speaker Authorization

**Mission:** Implement voice activity detection, wake-word abstraction, debounce, pre-roll, echo suppression hooks, enrollment flow, and measurable false-accept/false-reject harness.

**Deliverables:**

- VAD engine with adaptive noise calibration.
- Wake-word abstraction supporting configurable phrase and local model.
- Debounce, confidence thresholds, and anti-trigger protections.
- Optional speaker verification enrollment and recognition (not authorization for high-risk actions).
- Privacy mode toggle with explicit keyboard shortcut and visible/audible indicator.

**Acceptance gate:**

- False-accept and false-reject metrics captured across acoustic conditions.
- Anti-trigger tests pass (TTS self-trigger, media, conversation).
- Speaker verification treated as identity hint, not grant authority.

---

### Phase 3 — Streaming STT

**Mission:** Implement streaming speech-to-text with stable/partial transcript semantics, bilingual Turkish/English vocabulary, confidence, cancellation, and benchmarks.

**Deliverables:**

- `STTEngine` protocol: partials, stable segments, alternatives, confidence, cancellation, health.
- First local engine adapter (e.g., Whisper.cpp / ONNX Runtime on Apple Silicon).
- Stable-segment gating: intent execution requires stable text or deterministic early-command rule.
- User vocabulary and technical term customization.

**Acceptance gate:**

- WER, entity error rate, first-partial latency, and stable-segment latency measured.
- Turkish/English code-switching and technical vocabulary tested.
- Cancellation is prompt and does not leak audio.

---

### Phase 4 — Conversation, Turn Taking, and TTS

**Mission:** Implement the conversation state machine, semantic end-of-turn detection, interruption/barge-in, timeout handling, TTS scheduling, and UI status.

**Deliverables:**

- Conversation state machine with all transitions and interruption.
- Semantic turn completion heuristics combining VAD, STT, and intent signals.
- TTS streaming protocol supporting system voices and optional local neural TTS.
- Spoken-output policy: never speak secrets; avoid reading code character-by-character unless requested.
- UI status reporting (passive, listening, interpreting, speaking, restricted, error).

**Acceptance gate:**

- Barge-in latency and response cancellation meet budget.
- Pause/resume correctness verified.
- TTS yields to authorized user speech immediately.

---

### Phase 5 — Policy Engine

**Mission:** Implement risk tiers, capabilities, scoped grants, confirmation binding, expiry, deny rules, audit events, and deterministic tests.

**Deliverables:**

- Risk tiers: informational, low, medium, high, destructive.
- Capability model with fine-grained actions (e.g., `file.read`, `shell.exec`, `app.activate`, `agent.run`, `screen.capture`).
- Scoped grants: target app/file/directory/command regex, allowed arguments, environment allowlist, time bounds.
- Confirmation binding with tamper-evident challenge/response.
- Deny rules that are authoritative and auditable.
- Grant expiry and revocation.

**Acceptance gate:**

- Policy decisions are deterministic and auditable.
- Grants are scoped, confirmed, and expire correctly.
- Deny rules override all other grants.
- 100 % unit-test coverage for policy evaluation paths.

---

### Phase 6 — Native macOS Application Control

**Mission:** Implement application discovery, launch/activate/hide/quit, permission health, Accessibility wrapper, stale-element handling, and safe degradation.

**Deliverables:**

- Application discovery by bundle ID and localized name.
- Lifecycle commands with policy gating.
- Permission health dashboard and safe System Settings guidance.
- Accessibility wrapper with role/title/value/state/action metadata.
- Stale-element detection and recovery.

**Acceptance gate:**

- Apps can be discovered and controlled reliably.
- Accessibility permission state is checked and surfaced.
- Stale elements are handled gracefully without crashes.

---

### Phase 7 — Typed Shell / Process Runner

**Mission:** Implement typed process runner, command policy, PTY abstraction, output redaction, timeouts, cancellation, output bounds, and filesystem-change evidence.

**Deliverables:**

- `Command` value type: executable, argument array, working directory, env allowlist, timeout, risk, sandbox mode, expected exit codes, output redaction rules.
- PTY abstraction for interactive shells.
- Output bounding (max bytes/lines), streaming redaction of secrets and paths.
- Filesystem-change evidence: before/after hashes of declared directories.

**Acceptance gate:**

- No `shell=true` by default; no hidden privilege escalation.
- Secrets and sensitive paths redacted from logs and events.
- Cancellation leaves the system consistent.
- Timeout and output-bound enforcement tested.

---

### Phase 8 — VS Code Adapter

**Mission:** Implement VS Code integration via CLI, extension bridge, integrated terminal PTY, and Accessibility fallback.

**Deliverables:**

- Workspace/repo detection, file/symbol opening, task/test execution.
- Extension bridge for diagnostics and editor state (LSP/MCP-based where possible).
- Terminal integration using the typed shell subsystem.
- Dirty-editor safety: never close unsaved files without explicit confirmation.

**Acceptance gate:**

- Contract tests for workspace detection and command routing.
- Dirty-editor handling verified.
- Terminal working directory and shell verified before command injection.

---

### Phase 9 — Durable Task Engine

**Mission:** Implement durable task state, queue, checkpoints, cancellation, progress summaries, crash recovery, and restart tests.

**Deliverables:**

- Task aggregate with idempotency key, state machine, checkpoint persistence.
- Task queue with priority, deadlines, and inactivity timeout.
- Progress summaries suitable for UI and spoken updates.
- Crash recovery and restart tests.

**Acceptance gate:**

- Tasks survive process crash and system restart.
- Cancellation is consistent and resumable where safe.
- Progress summaries are accurate and privacy-safe.

---

### Phase 10 — Codex Adapter

**Mission:** Integrate OpenAI Codex CLI using only verified current interfaces, with explicit sandbox and approval mapping, structured events, budgets, cancellation, and integration tests.

**Deliverables:**

- Codex backend adapter with version verification.
- Sandboxed working directory and approval-event mapping to AURA policy.
- Budgets: time, tokens, cost, file writes.
- Normalized structured events: plan, file change, test run, approval need, completion, error.

**Acceptance gate:**

- Only verified CLI flags and APIs are used.
- Approval requests surface through the policy engine.
- Budgets are enforced and cancellation works.

---

### Phase 11 — Claude Adapter

**Mission:** Integrate Claude Code CLI or Agent SDK with verified interfaces, permission mapping, hooks safety, session events, budgets, and integration tests.

**Deliverables:**

- Claude backend adapter.
- Tool allowlist/deny rules enforced in both Claude config and AURA policy.
- Hooks safety: hooks are privileged code and never bypass AURA policy.
- Session/cost metadata recording.
- Review-role support for architecture and security review.

**Acceptance gate:**

- Tool allowlist enforced end-to-end.
- Backend cannot bypass policy engine.
- Session events and budgets respected.

---

### Phase 12 — GitHub Copilot Adapter

**Mission:** Integrate supported GitHub Copilot CLI or cloud-agent workflows, repository customizations, normalized tasks, and strict local/cloud separation.

**Deliverables:**

- Copilot CLI/agent workflow integration.
- Repository customization file handling (`.github/copilot-instructions.md`, `.github/instructions/*.instructions.md`, `.github/agents/*.agent.md`, `.github/prompts/*.prompt.md`).
- Normalized task contract and local/cloud execution separation.

**Acceptance gate:**

- Copilot tasks are normalized into AURA durable tasks.
- Cloud-agent consent handled explicitly.
- Repository instructions never contain secrets or private context.

---

### Phase 13 — Ollama Local Model Adapter

**Mission:** Implement Ollama model registry, capability routing, structured-output validation, model lifecycle, memory budget, health checks, and degraded mode.

**Deliverables:**

- Model registry with memory estimates, capabilities, and idle unload.
- Capability routing: classification, summarization, lightweight reasoning.
- Structured-output validation against typed schemas.
- Memory budget enforcement and thermal awareness.
- Graceful degradation to deterministic rules when models are unavailable.

**Acceptance gate:**

- Models are routed by capability, not name.
- Structured output is validated before use.
- Memory budget avoids simultaneous loading of large STT/vision/coding/TTS models.
- Degraded mode is safe and tested.

---

### Phase 14 — Multi-Agent Orchestration

**Mission:** Implement worktree isolation and planner/implementer/reviewer workflows with bounded iterations, conflict recording, and evidence-based adjudication.

**Deliverables:**

- Isolated Git worktrees for parallel write tasks.
- Planner → Implementer → Reviewer workflow with iteration bounds.
- Conflict recording and adjudication rules.
- Specialist swarm patterns.
- Prevention of recursive uncontrolled agent spawning.

**Acceptance gate:**

- Worktree isolation verified.
- Iterations are bounded; escalation on unresolved conflict.
- Disagreements recorded in the ledger.

---

### Phase 15 — Memory Engine

**Mission:** Implement memory schemas, append-only ledger writer, current-state projection, contradiction records, retention, inspection, export, correction, and deletion.

**Deliverables:**

- Memory record schema: immutable ID, type, subject, normalized statement, evidence refs, provenance, confidence, sensitivity, timestamps, retention policy, supersede links, scope.
- Memory classes: ephemeral audio, working conversation, session summary, task state, project facts, preferences, procedural knowledge, audit/security records.
- Append-only ledger writer and current-state projection.
- Contradiction detection and supersession (no silent overwrite).
- User inspection, export, correction, and deletion of non-audit memory.

**Acceptance gate:**

- Memory is append-only and projectable.
- Corrections/deletions preserve provenance.
- Retention policies enforced.
- Export/deletion correctness tested.

---

### Phase 16 — Context Reconstruction

**Mission:** Implement minimal context reconstruction with provenance, confidence, freshness, ambiguity handling, and adversarial reference-resolution tests.

**Deliverables:**

- Retrieval sequence: current utterance → conversation state → pending confirmation/task → active app/workspace → project ledger → recent decisions → preferences → semantic retrieval.
- Ranking by scope match, recency, authority, confidence, direct evidence.
- Ambiguity handling: ask or focused confirmation when multiple targets are plausible.
- Source IDs included in every context bundle.

**Acceptance gate:**

- Context bundles are minimal and sufficient.
- "It" never resolves to a destructive target on weak evidence.
- Adversarial reference-resolution tests pass.

---

### Phase 17 — Screen Context and Redaction

**Mission:** Implement ScreenCaptureKit-based approved-window capture, redaction pipeline, sensitive-app exclusions, freshness metadata, and zero-retention defaults.

**Deliverables:**

- ScreenCaptureKit session manager with window/region scoping.
- Redaction pipeline: mask secure text fields, password managers, auth codes, financial data, private notifications, user-defined regions, pattern-matched secrets.
- Structured summary/hashes; no raw screenshots by default.
- Sensitive-app exclusions and assistant-window self-exclusion.
- Freshness metadata and zero-retention default.

**Acceptance gate:**

- Only approved windows/regions captured.
- Redaction correctness verified with adversarial fixtures.
- No retained screen data unless diagnostic opt-in.

---

### Phase 18 — Computer-Use Control Loop

**Mission:** Implement bounded observe-plan-policy-act-verify loops, accessibility anchoring, emergency stop, no-progress detection, and destructive-action blocking.

**Deliverables:**

- Observe → Plan → Policy → Act → Verify loop with iteration and coordinate bounds.
- Accessibility text/ID anchoring preferred over coordinates.
- Emergency stop that disables all generated input.
- No-progress detection and escalation.
- Destructive-action default-deny with explicit confirmation.

**Acceptance gate:**

- Loop is bounded and stoppable.
- Destructive actions blocked without explicit policy grant.
- No raw model output becomes executable action.
- Emergency stop works from UI, voice, and keyboard.

---

### Phase 19 — Security Hardening

**Mission:** Complete threat models, prompt-injection defenses, secret handling, plugin verification, network/path allowlists, adversarial tests, and independent review.

**Deliverables:**

- Completed and current threat models.
- Prompt-injection and indirect-injection defenses.
- Secret handling via Keychain; no hardcoded secrets.
- Plugin manifest, signature/hash validation, sandboxing, quarantine/uninstall.
- Network and path allowlists.
- Adversarial test suite and independent security review.

**Acceptance gate:**

- Threat models cover every externally influenced input path.
- Injection defenses pass adversarial tests.
- Plugin verification enforced.
- Independent review completed and findings addressed or accepted.

---

### Phase 20 — Release Readiness

**Mission:** Complete performance and energy tuning, signing/notarization/update design, clean-install permission tests, upgrade/recovery/uninstall tests, documentation, and release evidence.

**Deliverables:**

- Performance and energy budgets met on target hardware.
- Signing, notarization, and update mechanism design.
- Clean-install permission and onboarding tests.
- Upgrade, recovery, and uninstallation tests.
- Installation, permissions, recovery, and uninstallation guides.
- Release evidence package.

**Acceptance gate:**

- Median wake-to-acknowledgement latency below 500 ms.
- Median simple-command completion below 1.5 s when no remote model is required.
- Energy budget met.
- No release performed without explicit authorization.

---

### Phase 21 — Advanced Memory Engine and Provenance Graph

**Mission:** Evolve the memory subsystem from an append-only ledger into a queryable, evidence-linked provenance graph with contradiction resolution, belief revision, and user-controlled forgetting.

**Deliverables:**

- Provenance graph schema: entities (facts, decisions, tasks, utterances, files) as nodes; evidence, derivation, supersession, and conflict as typed edges.
- `AuraMemory` target with graph store, query planner, and canonicalization rules.
- Contradiction detection: semantic equality, temporal bounds, source authority, and confidence scoring.
- Belief revision: auto-deprecate superseded facts; surface conflicts for user resolution when authority is tied.
- User-controlled forgetting: purpose-limited deletion with audit shadow records; irreversible only for non-audit, non-security classes.
- Import/export: user-facing JSON-LD or Markdown bundle with integrity hashes.

**Acceptance gate:**

- All facts traceable to evidence or labeled as inferred.
- Superseded facts remain visible as historical but are excluded from active context.
- Contradictions escalate to user when safe automatic resolution is impossible.
- Deletion preserves audit and security records; export is canonical and verifiable.
- Graph queries used by context reconstruction return deterministically ordered results.

---

### Phase 22 — Deep Context Reconstruction and Reference Resolution

**Mission:** Build multi-hop, evidence-ranked context reconstruction that resolves pronouns, implicit targets, and ambiguous references without leaking destructive intent into weak signals.

**Deliverables:**

- `ContextBuilder` pipeline: utterance parse → intent schema → entity extraction → scope filter → evidence rank → ambiguity check → final bundle.
- Reference resolution graph: map “it”, “that”, “the file”, “the last one” to candidate entities ranked by scope, recency, authority, and conversational salience.
- Negative guardrails: destructive-capability candidates require direct evidence or explicit user confirmation; weakly resolved targets are rejected.
- Cross-session memory injection: load relevant project facts, decisions, and preferences without overloading the model context window.
- Explainability: every context bundle includes provenance IDs and confidence scores; UI can surface why an item was included.

**Acceptance gate:**

- Adversarial reference-resolution test suite passes (e.g., “delete it” without clear target is rejected/confirmed).
- Context bundles fit within configured token budgets while retaining necessary facts.
- Multi-hop lookups (file → task → decision → preference) complete within latency budget.
- User can inspect and override context inclusions.

---

### Phase 23 — Verified Plugin and Adapter Marketplace

**Mission:** Create a secure, user-controlled plugin and adapter marketplace with manifest validation, signature verification, sandboxing, capability grants, and lifecycle management.

**Deliverables:**

- Plugin manifest schema v1: identity, vendor signature, capabilities, schemas, permissions, supported bundle IDs, network domains, executable deps, migration notes.
- `AuraPlugins` target: install, enable, disable, quarantine, uninstall, update, and rollback flows.
- Signature and hash verification using notary-compatible signatures or vendor public keys.
- Sandboxed execution: plugins run in separate XPC/helper process with filesystem/network/capability allowlists.
- Capability grant mapping: each plugin capability is translated into AURA policy grants with expiry and revocation.
- Store integration: plugin state recorded in `AuraStore`; audit log for install/uninstall/capability changes.

**Acceptance gate:**

- Unsigned or tampered plugins are rejected before loading.
- Plugins cannot escalate privileges beyond their manifest; policy engine enforces grants.
- Disabled/quarantined plugins cannot emit events or execute actions.
- Uninstall removes runtime artifacts while preserving audit records.
- Adversarial tests for manifest spoofing, hash collision, and capability escalation pass.

---

### Phase 24 — Self-Tuning Configuration and Feature-Flag Governance

**Mission:** Implement layered, self-tuning configuration with typed schemas, migration history, feature-flag governance, A/B-safe rollout, and machine-learned local recommendations.

**Deliverables:**

- Configuration engine: secure defaults → machine policy → user settings → project settings → session overrides, with validation and rollback.
- Feature-flag registry: owner, purpose, expiry, default, per-user/project override, kill switch, and rollback plan.
- Telemetry-influenced tuning: local, privacy-preserving metrics (latency, error rate, energy, user correction rate) feed recommendation engine; no raw data leaves device.
- Configuration migration: every schema change has a versioned migrator; migrations are reversible within a compatibility window.
- Audit and inspection: user can view effective config, diff against defaults, and revoke overrides.

**Acceptance gate:**

- Higher-risk capabilities cannot be weakened by project-level configuration.
- Feature flags expire or require explicit renewal.
- Telemetry recommendations are explainable and opt-in.
- Rollback to previous configuration completes within seconds and survives restart.
- All configuration changes are logged and user-inspectable.

---

### Phase 25 — Continuous Security, Adversarial Resilience, and Red Team Loop

**Mission:** Establish a continuous security program: automated red-team tests, model-level adversarial probes, supply-chain verification, incident response, and independent review cadence.

**Deliverables:**

- Adversarial test harness: prompt injection, indirect injection, jailbreak attempts, tool-call spoofing, policy bypass, memory poisoning, context-target confusion.
- Automated red-team runner integrated into CI with failure-as-blocker gates.
- Model evaluation pipeline: structured-output validation, capability boundary tests, hallucination detection on known project facts.
- Supply-chain verification: dependency lockfiles, checksums, macro plugin validation, build reproducibility checks.
- Incident response runbook: detection, containment, evidence preservation, user notification, rollback, post-incident ledger entry.
- Independent review schedule and findings tracker.

**Acceptance gate:**

- Adversarial test suite runs on every commit; new failures block merge.
- Red-team findings are triaged into ledger risks or fixed within SLA.
- No unverified dependency or build tool is used in CI.
- Incident response runbook is exercised at least once in simulation.
- Independent security review completed and outstanding findings documented.

---

### Phase 26 — Continuous Operation: Telemetry, Updates, and Field Recovery

**Mission:** Build production-grade operational capabilities: privacy-preserving telemetry, signed delta updates, field diagnostics, recovery modes, and long-term support branches.

**Deliverables:**

- Telemetry pipeline: on-device aggregation, differential privacy where applicable, opt-in crash/diagnostic submission, no raw audio/screenshots/events.
- Signed delta update mechanism with rollback and downgrade prevention.
- Field diagnostics: safe-mode boot, log collection without private content, remote support bundle generation under user control.
- Recovery modes: reset memory, reset grants, factory reset with audit preservation, safe-mode CLI.
- LTS branch policy: supported versions, security backports, deprecation notices.

**Acceptance gate:**

- Telemetry contains no personally identifiable or sensitive content.
- Updates are signed, verifiable, and atomic; rollback works on failure.
- Safe mode allows recovery even when normal UI/CLI is unstable.
- Factory reset preserves required audit records.
- LTS policy is documented and enforceable.

---

### Phase 27 — Cross-Device and Shared Workspace Continuity

**Mission:** Extend AURA from a single Mac to a coherent, privacy-preserving multi-device experience with end-to-end encrypted sync and shared workspace contracts.

**Deliverables:**

- End-to-end encrypted sync for memory records, tasks, grants, and configuration; keys derived from user credentials/Keychain; no cloud plaintext.
- Device pairing via local broadcast + cryptographic challenge; optional manual seed phrase.
- Shared workspace contract: project-level settings, allowed adapters, policy templates, and memory scope sync across team devices.
- Conflict resolution for concurrent edits with user adjudication or deterministic tie-breakers.
- Guest/limited mode: time-bounded, capability-restricted sessions on secondary devices.

**Acceptance gate:**

- Cloud provider cannot decrypt synced data.
- Pairing is resistant to man-in-the-middle and replay attacks.
- Workspace conflicts are surfaced, not silently merged.
- Guest mode cannot escalate to full user capabilities.
- Sync latency and offline behavior meet usability budget.

---

### Phase 28 — Specialized Agent Personas and Custom Workflows

**Mission:** Allow users and organizations to define safe, scoped agent personas and reusable workflows without weakening the policy engine or introducing hidden privileges.

**Deliverables:**

- Persona schema: identity, purpose, allowed capabilities, denied capabilities, memory scope, voice/behavior profile, model routing rules, budget limits.
- Workflow engine: declarative step graphs with human-in-the-loop gates, retries, timeouts, and verification hooks.
- Persona/workflow marketplace: signed, sandboxed packages with policy templates.
- Audit and revocation: every persona grant is logged; users can disable or constrain personas at any time.
- Anti-escape: personas cannot redefine policy, grant new capabilities, or bypass confirmation.

**Acceptance gate:**

- Personas operate within explicit capability boundaries.
- Workflows halt on unmet gates and escalate correctly.
- Marketplace packages pass plugin security gates.
- Users can inspect effective persona permissions and history.
- No persona can author or install another persona autonomously.

---

### Phase 29 — Regulatory and Organizational Governance

**Mission:** Provide enterprise and compliance-grade governance: audit trails, data residency, retention policies, role-based access, and exportable compliance reports.

**Deliverables:**

- Audit trail: immutable, time-ordered log of every policy decision, grant change, action execution, model invocation, and memory mutation.
- Data residency controls: local-only mode, region-bound sync, configurable retention windows.
- Role-based administration: device owner, project owner, reviewer, auditor; each with scoped capabilities.
- Compliance report generator: GDPR/CCPA-style export, deletion logs, consent records, processing-purpose labels.
- Legal hold and litigation support: preserve records beyond normal retention under explicit authorization.

**Acceptance gate:**

- Audit trail is tamper-evident and exportable.
- Local-only mode disables all sync and cloud telemetry.
- Role separation prevents auditor/admin from executing actions.
- Compliance reports are complete and generated within minutes.
- Legal hold preserves required records without exposing unrelated data.

---

### Phase 30 — Long-Term Evolution and Open Ecosystem

**Mission:** Ensure AURA remains maintainable, extensible, and trustworthy as the codebase, team, and ecosystem grow.

**Deliverables:**

- Public, versioned SDK and adapter protocol documentation.
- Community contribution guidelines with DCO/sign-off and security review.
- Architectural decision record (ADR) culture and periodic review.
- Deprecation policy: capabilities, APIs, models, and plugins have announced lifecycles.
- Sustainability: energy/carbon budget, accessibility conformance, localization framework, and inclusive design review.

**Acceptance gate:**

- SDK docs and examples build and pass contract tests.
- External adapter samples integrate through official protocol gates.
- Deprecations are announced two minor versions in advance.
- Accessibility and localization tested for primary markets.
- Long-term maintainer runbook covers common failures and recovery.

---

## 7. Cross-Cutting Engineering Standards

### 7.1 Language and Platform

- Swift 6+ with strict concurrency enabled.
- Explicit `actor`, `Sendable`, and isolation annotations.
- macOS 27+ APIs verified from Apple documentation; provide graceful degradation where practical.
- Avoid blocking the real-time audio path with allocation, disk I/O, network calls, or model loading.

### 7.2 Code Quality

- Functions focused (< 50 lines where practical).
- Files cohesive (< 800 lines where practical).
- No deep nesting (> 4 levels); prefer early returns.
- Immutable data patterns; avoid mutating shared state.
- Named constants for thresholds, delays, and limits.
- No `TODO`, `FIXME`, or placeholder-as-complete code.

### 7.3 Testing

- Minimum 80 % coverage; critical paths (policy, shell, ledger) should approach 100 %.
- Unit, contract, integration, and end-to-end tests for every phase.
- Arrange-Act-Assert structure with descriptive test names.
- Deterministic tests; no reliance on ambient environment.
- Adversarial tests for security/privacy-critical paths.
- Restart/crash-recovery tests for durable components.

### 7.4 Observability

- Structured logs with privacy labels.
- Metrics for latency, error rate, energy, and coverage.
- Health checks and circuit breakers.
- Diagnostic context without private content.
- Security, confirmation, permission, destructive, and ledger events are never sampled.

### 7.5 Configuration and Feature Flags

- Typed, layered configuration with validation and migration history.
- Higher-risk capabilities cannot be weakened by project config.
- Feature flags include owner, purpose, expiry, and rollback plan.
- Sensitive values stored in Keychain, never in config files.

---

## 8. Security and Privacy Checklist

For every phase, verify:

- [ ] No hardcoded secrets (API keys, passwords, tokens).
- [ ] All user inputs validated at system boundaries.
- [ ] SQL injection prevention via parameterized queries.
- [ ] XSS and prompt-injection defenses in place where applicable.
- [ ] Path traversal prevented via canonicalization.
- [ ] CSRF-like cross-request binding for confirmations.
- [ ] Authentication/authorization verified per policy engine.
- [ ] Rate limiting and timeout on endpoints and loops.
- [ ] Error messages do not leak sensitive data.
- [ ] Redaction applied before logs, events, model prompts, and ledger entries.
- [ ] Least-privilege permissions; user can inspect and revoke every grant.

---

## 9. Required Response Structure

For every phase you execute, return a report containing:

1. **Starting state** — what was true before this phase.
2. **Plan** — concise plan tied to acceptance criteria.
3. **Changes** — files, modules, schemas, and ADRs created or modified.
4. **Verification evidence** — exact commands run and their outputs; test results; coverage reports; lint/static-analysis results.
5. **Risks and limitations** — what remains unresolved or out of scope.
6. **Ledger update** — evidence-backed entry appended to `ledger/PROJECT_LEDGER.md`.
7. **Next safe action** — the single next step or the next phase gate.

---

## 10. Implementation Workflow

For each phase:

1. Inspect state and identify conflicts.
2. Produce a phase-specific plan tied to acceptance criteria.
3. Create or update ADRs for material decisions.
4. Implement the smallest complete vertical slice.
5. Add failure handling, observability, and tests as part of the slice.
6. Run build, format, lint, unit, integration, and relevant E2E tests.
7. Review the diff for security, privacy, scope, and regressions.
8. Update documentation and migration notes.
9. Append a ledger entry to `ledger/PROJECT_LEDGER.md`.
10. Atomically update `ledger/CURRENT_STATE.md`.
11. Stop if the phase gate fails; otherwise proceed to the next phase.

---

## 11. Multi-Agent Delegation

You may delegate to these sub-agents when appropriate:

- **Architecture Principal** — for ADRs, module boundaries, concurrency, recovery.
- **Realtime Audio Engineer** — for capture, VAD, wake word, STT, TTS, interruption.
- **macOS Systems Engineer** — for SwiftUI, Accessibility, ScreenCaptureKit, AVFoundation, signing.
- **Memory and Ledger Engineer** — for append-only ledger, memory schemas, context reconstruction.
- **Agent Orchestration Engineer** — for Codex/Claude/Copilot/Ollama adapters, worktrees, budgets.
- **Verification Engineer** — for deterministic tests, contract tests, adversarial tests.
- **Security Reviewer** — for threat modeling, injection analysis, permission review.

If you delegate, you own collection of results and must integrate them into your final report.

---

## 12. Starting State (as of 2026-07-23)

- Phase: Foundation
- Active milestone: 0
- Active task: None
- Last verified commit: Unknown
- Build status: Not initialized
- Test status: Not initialized
- Known blockers: Repository implementation has not started.
- Pending confirmations: None
- Next safe action: Execute Phase 0 — Bootstrap.

---

## 13. First Action

Begin Phase 0. Read the current repository contents, create the project skeleton, build system, typed configuration, event envelopes, logging, database migrations, test targets, CI workflow, and ledger integration. Then run all checks, produce verification evidence, and update the ledger before moving to Phase 1.

Do not begin product features until Phase 0 passes its acceptance gate.
