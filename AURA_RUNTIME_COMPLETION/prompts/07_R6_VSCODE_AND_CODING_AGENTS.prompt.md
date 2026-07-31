# R6 — VS Code and Coding-Agent Completion Prompt

Execute after R3. R6 must use the capability registry, runtime health, confirmation transaction, durable task, and verification contracts established by R1–R3.

## Mission

Make AURA a reliable coding assistant that can understand the active workspace, inspect editor state and diagnostics, run tasks/tests, use a typed terminal, and delegate bounded work to Codex, Claude Code, Copilot, or local models. Every write-capable task must be policy-controlled, workspace-scoped, durable, reviewable, and evidence-backed.

## Required context

Read:

- `Sources/AuraVSCode` and tests;
- `Sources/AuraAgent` adapters and tests;
- `Sources/AuraTasks`, `AuraShell`, worktree manager, store, policy, runtime health;
- existing agent ADRs 011–015 and proposed ADR-041;
- current official VS Code extension API and installed CLI help;
- current official Codex, Claude Code, Copilot, and Ollama interfaces actually selected for support.

Do not assume old CLI flags or authentication behavior.

## A. Enforce policy in VS Code adapter

The adapter must await and enforce `PolicyEngine.evaluate` for every action. Merely constructing/emitting a request is insufficient.

Map each command to a registered capability, risk, target, arguments, side effects, confirmation requirement, and verification method.

Protect dirty/unsaved editors. Opening or replacing state must not lose work without a bound review/confirmation.

## B. Authenticated VS Code extension bridge

Build a minimal signed/versioned extension bridge exposing only enumerated commands and typed data:

- active workspace folders and repository roots;
- active editor/file/selection;
- dirty/open editors;
- diagnostics;
- symbols;
- available tasks and tests;
- run/cancel task or test;
- terminal sessions and working directories;
- extension and protocol health.

Requirements:

- authenticated local channel;
- schema version negotiation;
- nonce/replay protection where applicable;
- no arbitrary raw command execution;
- bounded payloads and redaction;
- stale-state/freshness metadata;
- disconnect and version mismatch behavior.

## C. Workspace and repository resolution

Resolve in this order:

1. explicit user target;
2. active VS Code workspace/repository;
3. active durable task/worktree;
4. project-context candidate requiring confirmation if ambiguous.

Never run a write-capable agent in an unresolved or unintended directory.

## D. Typed coding capabilities

At minimum register:

- workspace status;
- open file/folder/workspace/symbol;
- diagnostics summary;
- run/cancel named task;
- run/cancel tests;
- typed terminal command;
- start/status/cancel coding-agent task;
- inspect diff/test/evidence;
- create/reuse isolated worktree;
- review-only agent task.

Push, merge, release, deploy, secrets, credentials, and destructive repository operations remain separate high-risk capabilities.

## E. Agent readiness and routing

Before exposing a backend verify:

- executable and exact version;
- supported interface/flags;
- authentication health;
- model availability;
- sandbox/approval behavior;
- cancellation;
- network policy;
- working-directory permissions;
- cost/token/time/file-write budgets.

Unavailable backends are disabled with an actionable reason. Routing should be capability-based and user-configurable, not a blind hardcoded preference.

## F. Durable coding task flow

1. resolve objective and workspace;
2. show backend/model/sandbox/budgets;
3. choose read-only vs write-capable mode;
4. create isolated worktree when writes are allowed;
5. obtain confirmation;
6. enqueue durable task;
7. stream normalized progress and approval events;
8. handle user questions/cancellation;
9. run validation/tests;
10. summarize diff and risks;
11. mark complete only after verification;
12. require separate authority for commit/push/PR/merge/release.

## G. Verification

Use objective evidence:

- process exit and normalized events;
- filesystem/diff changes;
- diagnostics;
- test results;
- expected file/worktree state;
- cancellation/timeout status.

Do not equate a backend “completed” message with task verification.

## Tests

Required:

- VS Code policy allow/deny/confirm;
- dirty editor protection;
- bridge authentication, replay, version, stale data, and disconnect;
- workspace ambiguity and wrong-directory prevention;
- task/test execution and cancellation;
- terminal working-directory verification;
- backend version/auth/unavailable health;
- budgets and file-write limits;
- worktree isolation and cleanup;
- approval propagation;
- agent output/tool spoofing;
- prompt injection from repository files/terminal output;
- false backend success with failed tests;
- restart/resume of durable tasks;
- no unauthorized commit/push/release.

## Live acceptance

On an approved test repository:

1. identify workspace and active file;
2. read diagnostics;
3. run tests and report results;
4. execute a harmless typed terminal command;
5. start one read-only agent task;
6. start one write-capable task in an isolated worktree after confirmation;
7. show progress, diff, and verification;
8. cancel a task;
9. disable/uninstall a backend and observe accurate health;
10. prove no push/merge/release occurs without separate authority.

## Completion gate

R6 is complete only when VS Code policy is actually enforced, the bridge is authenticated and functional, workspace resolution is safe, agent backends expose truthful health, tasks are durable/bounded/reviewable, and completion includes diff/test evidence.

Accept ADR-041, update program records, unblock R9/R10, and run closeout.
