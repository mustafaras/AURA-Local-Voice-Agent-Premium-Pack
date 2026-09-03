# EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01` |
| Prompt | SP-014 — Coding Assistant Live Acceptance (`OPEN-07/R6`) |
| Gap | OPEN-07 (R6: VS Code and coding-agent completion) — user-present acceptance gate |
| Timestamp | 2026-08-21T16:40:00Z |
| Session ID | `AURA-SP-014-LIVE-ACCEPTANCE-20260821` |
| Commit | `1d12c91` on `main` (working tree adds `Tests/AuraAgentTests/SP014LiveAcceptanceTests.swift`, uncommitted) |
| Environment | macOS 27 / Apple Silicon arm64, Swift 6.4, Xcode 27.0-beta.5; `claude` 2.1.195, `codex` 0.142.0, `copilot` 1.0.80 |

## Class

Deterministic + direct-live-CLI evidence on the approved scratch repository
(`~/.aura-sp014/approved-repo`, git init, `scratch.swift`, master). The suite
drives the real production path (`CodingTaskCoordinator` → real `ClaudeAdapter`
→ real `claude` CLI, real `WorktreeManager` → real `git worktree`, real
`AuraTaskEngine`). This attempt is **blocked**, not complete: a genuine
read-only and write-capable model turn could not be produced because no backend
is currently able to run one.

## Objective

Run the ten-step R6 user-present acceptance on an approved repository: (1)
identify workspace/file, read diagnostics, run tests, run a harmless typed
terminal command, start a read-only task; (2) run one confirmed write task in an
isolated worktree with progress/diff/tests/evidence/cancellation/cleanup; (3)
disable a backend and verify accurate health; (4) prove no unauthorized
commit/push/merge/PR/release/deploy.

## Symptom / missing postcondition

The SP-014 completion gate requires **all live coding scenarios pass with direct
evidence**. On this machine:

- **P2 (write-capable fail-closed): PASS.** A write-capable task in an isolated
  worktree that reported `.completed` but produced **no diff** was correctly
  rejected by `verifyCompletion` (false-backend-success → fail closed). Cleanup
  removed the worktree.
- **P3 (disabled-backend accurate health): PASS.** A backend configured as
  `.unavailable` with a quota detail reports exactly that; no false `.ready`.
- **P4 (no unauthorized delivery): PASS.** Running the coordinator on the
  approved repo created **no commit/push/merge/PR**; the repo HEAD was
  unchanged (`after == before`).
- **P1 (read-only live model turn): FAIL (blocked).** `claude -p` returns
  `You've hit your session limit · resets 8:50pm (Europe/Istanbul)`, so the
  read-only turn cannot complete. The suite fails closed (`.failed`) — it does
  **not** fabricate a `.completed`.

No backend can currently produce a genuine model turn:

1. **claude** — provider session limit reached (external account/timing
   constraint, resets 8:50pm Europe/Istanbul). Additionally `--permission-mode
   dontAsk` (the only safe unattended mode) **blocks Write/Bash tools by
   design**, so a write-capable turn under the safe mode cannot produce a diff.
2. **codex** — default model `gpt-5.6-luna` requires a newer CLI than the
   installed 0.142.0 (`"The 'gpt-5.6-luna' model requires a newer version of
   Codex"`); `gpt-5.1-codex` is rejected (`"not supported when using Codex with
   a ChatGPT account"`).
3. **copilot** — monthly quota exhausted.

## Mechanism / root cause / layer

Not a source defect in the coordinator/adapter/task stack — those fail closed
correctly (proven by P2/P3/P4). The blocker is the **backend/account supply
layer**: the installed CLIs cannot obtain a model response in this session
(claude quota, codex version/account model mismatch, copilot quota). The
write-capable design constraint is also architectural: claude's only safe
unattended mode (`dontAsk`) deliberately blocks Write/Bash tools, so a genuine
write turn under the safe policy requires a worktree-scoped approval path that
is out of SP-014's scope (it is a product/policy design decision, not a live
acceptance step).

## Direct procedure / result

- Approved repo: `~/.aura-sp014/approved-repo` (git repo, `master` head
  `d234839`).
- Ran `swift test --filter SP014Live` with `AURA_SP014_LIVE_ACCEPTANCE=1` and
  `AURA_SP014_REPO` set. Result: **4 tests, 3 pass (P2, P3, P4), 1 fail
  (P1 — read-only live turn blocked by claude session limit; fails closed).**
- Manually confirmed each backend: `claude -p` → session-limit message; `codex
  exec -s read-only` → `gpt-5.6-luna requires newer Codex`; `copilot -p` →
  quota exceeded.

## Falsifier

A future run in which a backend account is authenticated and quota/version is
available, so the read-only and write-capable tasks genuinely complete with a
produced diff, would falsify the "blocked" conclusion. Any backend that can
return a model turn in `read-only` and `write-capable` modes would let P1 and P2
re-run green.

## Residual risk / boundary

- `RISK-AGENT-BACKEND-DRIFT` — live auth/model turn not exercised; no genuine
  read-only or write-capable model turn has been produced end to end.
- claude `dontAsk` write-block: write-capable under the safe unattended mode
  cannot produce a diff (product/policy design item, out of SP-014 scope).
- No commit/push/merge/PR/release/deploy was performed (P4 asserted; authority
  `commit:false`).

## Why SP-015 is NOT safe to start

SP-014's completion gate ("all live coding scenarios pass") is **not met**:
P1 read-only live turn is blocked by the claude session limit, and no backend
can produce a genuine write-capable turn. SP-014 stays **`blocked`**; SP-015
must not be opened.
