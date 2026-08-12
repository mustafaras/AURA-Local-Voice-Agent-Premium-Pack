# R3 — Capability Registry and Typed Planner Prompt

Execute after R2 is complete.

## Mission

Replace the closed five-intent routing ceiling with a typed, inspectable capability registry and bounded planner. Every user-reachable action must have a registered schema, risk model, permission contract, verification method, and health state.

## Required context

Read:

- R1 runtime/confirmation contracts;
- R2 NLU/dialogue contracts;
- current intent kinds, tool registry, router, policy and risk mappings;
- app automation, shell, task, coding-agent, screen, VS Code, memory, and store interfaces;
- capability matrix;
- ADR-038 proposal.

## Capability manifest

Define a versioned manifest containing:

- stable capability ID and localized title/description/examples;
- input and output schemas;
- owning adapter;
- risk tier and side effects;
- required OS permissions, grants, secrets, network domains, and external dependencies;
- local/cloud classification;
- idempotency;
- timeout, cancellation, retry, and resource budget;
- confirmation rule;
- verification and rollback strategy;
- availability/health;
- sensitivity and retention behavior;
- minimum evidence class required to expose it in development, beta, and release.

Unknown IDs or schema versions fail closed.

## Planner

Implement a bounded typed planner that can produce:

- direct answer;
- clarification;
- one capability call;
- a small dependency-aware multi-step plan;
- durable delegated task;
- refusal/unsupported result.

Each step must include:

- capability ID/version;
- validated arguments;
- expected preconditions and postconditions;
- risk and confirmation boundary recomputed from the registry;
- dependencies;
- timeout/resource budget;
- verification method;
- rollback/compensation when supported.

Plans must be immutable after confirmation. Replanning creates a new plan identity.

## Initial production capability set

Register and connect only capabilities whose adapters can meet the R1 execution/verification contract:

- `app.discover`;
- `app.activate`;
- `app.hide` if implemented and verified;
- `app.quit`;
- `filesystem.open_file`;
- `filesystem.open_folder`;
- `filesystem.reveal`;
- `url.open`;
- `shell.execute_typed`;
- `task.status`;
- `task.cancel`;
- coding-agent start/status/cancel for available backends;
- runtime/capability health query.

Screen, computer use, VS Code, browser, mail, and calendar may be registered as disabled/degraded placeholders only if health and user-facing reasons are truthful. Do not expose unimplemented behavior.

## Adapter contract

Each adapter must return a typed result with:

- execution status;
- observable effects;
- verification evidence;
- warnings;
- retryability;
- rollback result;
- privacy-safe diagnostics.

No adapter accepts free-form executable model text.

## Policy integration

Generate policy requests from manifest metadata and validated arguments. Deny rules and mandatory confirmation remain authoritative. Prevent project/session configuration from weakening risk or confirmation.

## Tests

Required:

- manifest/schema versioning;
- duplicate/unknown capability IDs;
- localization/alias resolution;
- invalid arguments;
- missing permissions/dependencies;
- unavailable capability health;
- risk and confirmation derivation;
- multi-step dependency ordering;
- plan cycle and budget rejection;
- plan hash immutability;
- cancellation and partial failure;
- rollback/compensation;
- verification failure;
- model-proposed unknown/out-of-schema tools;
- configuration cannot lower security;
- existing app/shell/agent behavior migrates without regression.

## Completion demonstration

Demonstrate from natural Turkish/English input:

1. one observation capability;
2. one reversible app/file/URL capability;
3. one confirmed mutation;
4. one two-step safe plan;
5. one unavailable capability with an accurate explanation;
6. one malformed model plan rejected;
7. evidence and capability-health inspection.

## Completion gate

R3 is complete only when:

- the registry is the sole production source for user-reachable tools;
- all registered capabilities have closed schemas and health;
- planning is bounded and validated;
- confirmation binds immutable plans;
- execution and verification use typed adapter results;
- initial capabilities are genuinely reachable and tested;
- disconnected future capabilities are visibly disabled rather than falsely ready;
- R4, R5, R6, and R8 can add capabilities without changing core routing architecture.

Accept ADR-038, update state/capability/evidence/risk/ledger/handoff, mark eligible parallel tracks ready, and run closeout.
