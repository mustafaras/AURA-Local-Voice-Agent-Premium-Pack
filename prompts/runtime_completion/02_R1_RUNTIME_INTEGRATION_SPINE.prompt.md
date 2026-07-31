# R1 — Runtime Integration Spine and Trace Correctness Prompt

Execute only after R0 is complete and R1 is ready.

## Mission

Create one production orchestration spine that owns the complete lifecycle of a user turn. Repair correlation, confirmation, runtime health, verification, and truthful completion semantics before expanding capabilities.

The required vertical slice is:

```text
Push to Talk or text input
→ TurnContext
→ intent
→ policy
→ bound confirmation when required
→ registered tool
→ independent verification
→ durable evidence/state
→ concise spoken and visual response
```

## Required context

Read direct production and tests for:

- `AuraKernel` and `AuraAppModel`;
- event bus/envelopes;
- conversation;
- intent engine and dispatcher;
- tool router;
- policy engine and confirmation presenter;
- automation, shell, and task interfaces;
- store/event persistence;
- existing ADRs 021/022 and proposed ADRs 034/035/037.

## Required architecture

### A. `TurnContext`

Introduce one immutable context carrying:

- session ID;
- turn ID;
- correlation and causation IDs;
- activation/input source;
- actor and authority provenance;
- sensitivity;
- language/locale;
- timing origin;
- actual STT/TTS/model/tool backend IDs;
- pending task/confirmation references.

Pass it through every stage. Do not generate unrelated correlation IDs inside downstream actors.

### B. Runtime health registry

Every constructed subsystem must publish a typed state:

- ready;
- degraded;
- disabled by user/configuration;
- permission blocked;
- dependency missing;
- configuration invalid;
- loading;
- circuit open;
- unsupported;
- failed.

Replace silent `try?` construction with retained error/health information. A disconnected service must not appear ready.

### C. Capability orchestrator

Create a production `AssistantRuntime` or `CapabilityOrchestrator` that owns:

- turn intake;
- classification;
- context request;
- plan/response decision;
- policy evaluation;
- confirmation transaction;
- execution;
- verification;
- task/memory/audit update;
- response generation and TTS handoff.

Register only the currently proven app lifecycle, typed shell, and coding-agent launch paths in this track. Do not yet add the full capability catalog.

### D. Confirmation transaction

Implement a single transaction with:

- immutable request/plan hash;
- capability, target, arguments, side effects, risk;
- nonce and expiry;
- requested scope;
- user response;
- policy resolution;
- one-time execution authority;
- post-confirmation state revalidation;
- execution and verification outcome;
- durable cancellation/restart behavior.

A valid approval must not be discarded by an unconditional second block. A changed plan must not inherit the approval. Overlap, timeout, dismissal, restart, and replay must fail closed.

### E. Truthful outcomes

Use separate states:

- proposed;
- authorized;
- executing;
- executed;
- verifying;
- verified;
- completed with warning;
- failed;
- cancelled;
- unknown outcome.

AURA may say “done” only after the capability-specific verification passes.

### F. Metrics correctness

Record actual engines/backends. Remove hardcoded `isMockEngine: true` behavior from production measurements. Use one monotonic timing origin.

## UI changes in scope

Add only the minimum UI needed to prove the integration spine:

- text input fallback;
- current transcript/request;
- pending confirmation;
- execution/verification state;
- runtime health summary;
- visible failure and retry/cancel path.

Full product UI belongs to R9.

## Testing

Required tests include:

- full trace preserves IDs across all stages;
- causation chain is valid;
- actual backend metadata is recorded;
- unavailable subsystem reports degraded/disabled, not ready;
- confirmation allow executes exactly once;
- deny/timeout/dismiss/replay/plan-change do not execute;
- restart with pending confirmation fails or resumes according to ADR;
- execution success with failed verification is not reported complete;
- cancellation at each stage leaves consistent state;
- concurrent turns do not cross-contaminate context;
- existing app/shell/coding-agent routes remain policy-controlled.

Run focused tests, full integration tests, adversarial confirmation tests, and coverage.

## Required live demonstration

On authorized target hardware, demonstrate one safe observation/reversible command and one mutation requiring confirmation. Capture:

- one complete correlated trace;
- displayed confirmation;
- execution evidence;
- verification result;
- spoken/visual truthful response;
- denied or expired confirmation behavior.

Do not mutate TCC or launch/install the app without explicit authority.

## Completion gate

R1 is complete only when:

- one orchestration owner exists;
- trace identity is preserved;
- runtime health is honest;
- confirmation is transactional and resumable/fail-closed;
- execution and verification are distinct;
- minimum text/voice vertical slice passes integration and live evidence;
- existing safety tests remain green;
- R2 and R3 can build on stable typed contracts.

Accept ADRs 034/035/037 as appropriate, update state/capability/risk/evidence/ledger/handoff, mark R2 ready, and run closeout.
