# EV-SP-013-20260821-COORDINATOR-ROUTING-01

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-013-20260821-COORDINATOR-ROUTING-01` |
| Prompt | SP-013 — Coding Backend and Durable Task Lifecycle (`OPEN-07/R6`) |
| Gap | OPEN-07 (R6: VS Code and coding-agent completion) — backend/task lifecycle slice |
| Timestamp | 2026-08-21T14:45:00Z |
| Session ID | `AURA-SP-013-COORDINATOR-LIFECYCLE-20260821` |
| Commit | `c6e5d3d183c8e293806bb9d55bbf4e44dffcefea` on `main` (working tree includes uncommitted SP-013 changes) |
| Environment | macOS 27 / Apple Silicon arm64, Swift 6.4, Xcode 27.0-beta.5 |

## Objective

Close SP-013's coding-backend truthfulness and durable-task-control gate: probe
exact CLI version/interface and expose unverified states as disabled; route the
resolved workspace and the mode's sandbox tier into the per-backend runner
context; isolate write-capable work in a real worktree; and verify diff/test
evidence postconditions so a backend that "completes" without producing a diff
is a false success and fails closed.

## Class

Direct live CLI probe evidence (real `codex`/`claude`/`copilot` binaries) plus
deterministic contract/system tests against real production source, a real
`AuraTaskEngine`/`AuraStore`, and a real `WorktreeManager` on a real scratch
`git` repository. The backend in the coordinator tests is a fake `TaskRunner`
that records what it was handed; the safety-relevant isolation/durability
boundaries are real.

## Symptom / missing postcondition observed

`CodingTaskCoordinator.enqueue` resolved a workspace and, for write-capable
mode, prepared an isolated worktree — but **never routed either into the
per-backend context keys the task runners actually read**
(`codex.workingDirectory` / `claude.workingDirectory` /
`copilot.workingDirectory`, plus the sandbox/profile keys). Consequences:

1. A write-capable task ran in the backend's `defaultWorkingDirectory` with its
   **default read-only sandbox**, not the isolated worktree and the
   workspace-write tier — the worktree was disconnected from execution.
2. readOnly / reviewOnly / writeCapable all executed with the same read-only
   sandbox; the mode had no effect on what the backend could do.

This is the disconnected-wiring class the shared execution contract forbids:
code that *appears* isolated but does not actually constrain execution.

## Direct change / acceptance procedure

In `Sources/AuraAgent/CodingTaskCoordinator.swift`:

- After resolving the workspace and preparing the worktree, map the resolved
  working directory (`preparedWorktree?.path ?? workspace.path`) and the mode's
  sandbox tier into the per-backend context keys that `CodexTaskRunner`,
  `ClaudeTaskRunner`, and `CopilotTaskRunner` actually read:
  - `.codex` → `codex.workingDirectory` + `codex.sandbox`
  - `.claude` → `claude.workingDirectory` + `claude.toolProfile`
  - `.copilot` → `copilot.workingDirectory` + `copilot.toolProfile`
- The sandbox tier is `readOnly` for read-only and review-only modes and
  `workspaceWrite` for write-capable mode.
- Added `CodingTaskVerification` and `CodingTaskCoordinator.verifyCompletion`:
  a write-capable task is only verified if its prepared worktree has a
  **non-empty `git diff` against its base ref**; a "completed" task with no diff
  is a false-backend-success and fails closed. Read-only/review-only have no
  mutable-diff postcondition.

## Tests added (Procedure 4)

`Tests/AuraAgentTests/CodingTaskCoordinatorTests.swift` (7 tests), each against
a real `WorktreeManager` on a real scratch `git` repo and a real
`AuraTaskEngine`/`AuraStore`:

1. **read-only mode routes the resolved workspace and read-only sandbox** — the
   backend received `workingDirectory == repo` and sandbox `readOnly`.
2. **review-only mode routes read-only and needs no worktree** — Claude routing,
   `workingDirectory == repo`, `readOnly`, no worktree prepared.
3. **write-capable mode requires a worktree manager** — fails closed with no
   manager.
4. **write-capable mode prepares an isolated worktree and routes it to the
   backend** — backend received the worktree path and `workspaceWrite`.
5. **a write-capable task that completes with no diff is a false success** —
   `verifyCompletion` returns `verified == false` and "no diff".
6. **a write-capable task that produced a diff verifies** — real file modified in
   the worktree, `verifyCompletion` returns `verified == true`.
7. **read-only and review-only modes have no diff postcondition** — both verify
   trivially.

## Procedure 1 — live CLI version/interface probe (real binaries)

`Tests/AuraAgentTests/AgentBackendHealthTests.swift` gained
`AgentBackendHealthLiveProbeTests` (3 tests, `.serialized`) that invoke the
**real installed CLIs** through the production `AuraShellAgentBackendCommandRunner`
(the same runner the kernel constructs). Each asserts the health state is
truthful: presence + `--version`/`--help` is only `.degraded`, never `.ready`,
because authentication and model availability remain `.unverified` (fail-closed
until onboarding evidence). Observed on this machine:

- **codex** `codex-cli 0.142.0` — `exec --help` confirms `-s/--sandbox`
  (`read-only`, `workspace-write`, and `danger-full-access`, the last unreachable
  by construction), `-C/--cd`, `--ephemeral`, `--model`.
- **claude** `2.1.195 (Claude Code)` — `-p/--print`, `--permission-mode`,
  `-w/--worktree`, `--output-format`.
- **copilot** `GitHub Copilot CLI 1.0.80` — `-p/--prompt`, `--allow-tool`,
  `--add-dir`, `--agent`.

All three probe tests assert `.degraded` with a captured `version`, `.unverified`
authentication, and `unverified` model availability.

## Commands run

```
swift build --build-path /tmp/aura-build-sp013                    → Build complete
swift test --filter CodingTaskCoordinatorTests --build-path /tmp/aura-build-sp013
  → 7/7 passed (real scratch git worktrees, real task engine)
swift test --filter AgentBackendHealthLiveProbe --build-path /tmp/aura-build-sp013
  → 3/3 passed (real codex/claude/copilot CLI invocations)
swift test --filter AuraAgentTests --build-path /tmp/aura-build-sp013
  → 230/230 passed (220 prior + 7 coordinator + 3 live probe; no regression)
swift test --filter AuraTasksTests --build-path /tmp/aura-build-sp013
  → 12/12 passed (no regression)
./scripts/aura-test.sh /tmp/aura-sp013-count → "Done. Failed bundles: 0"
python3 scripts/validate_second_pass_program.py → SECOND-PASS VALIDATION PASSED
```

## Result

- Write-capable coding tasks now execute in an **isolated worktree** under the
  **workspace-write** sandbox tier; read-only and review-only tasks run in the
  resolved workspace at the read-only tier.
- A backend that reports completion without producing a diff is caught as a
  false success and fails closed.
- The real CLI health probe confirms exact versions/interfaces and leaves
  authentication and model availability `.unverified` (never a false `.ready`).
- No commit/push/merge was made; the working tree remains dirty with the SP-013
  changes.

## Class / verdict

Direct live CLI probe evidence (Procedure 1) plus deterministic contract/system
test evidence (Procedures 2–4) against real production source and real
git/task isolation. **Passed** for the SP-013 durable-task-control scope.

## Limitations / residual

- Procedure 1 proves the real CLI **version/interface** probe and the fail-closed
  auth/model states. It does not run a live **model turn** end to end — that
  needs real model/backend execution, authentication onboarding evidence, and
  the first-pass R6 live acceptance gate, which is outside this deterministic
  slice.
- The coordinator's per-mode sandbox/profile routing is asserted through a
  recording runner (a real CLI turn would additionally prove the flags reach the
  real process).
- Budget enforcement (token/cost/file-write) lives in the Codex/Claude/Copilot
  adapters and is covered by their own suites; this evidence does not re-prove it.
- Write-capable diff verification uses `git diff` against the base ref; it does
  not itself run a test harness. "Verify diff/test/evidence postconditions" is
  satisfied at the diff-evidence level; running the backend's test command is a
  separate live-model gate.
