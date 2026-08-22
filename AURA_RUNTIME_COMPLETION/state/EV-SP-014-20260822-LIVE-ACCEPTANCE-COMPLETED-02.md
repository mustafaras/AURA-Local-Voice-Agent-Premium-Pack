# EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-014-20260822-LIVE-ACCEPTANCE-COMPLETED-02` |
| Prompt | SP-014 — Coding Assistant Live Acceptance (`OPEN-07/R6`) |
| Gap | OPEN-07 (R6: VS Code and coding-agent completion) — user-present acceptance gate |
| Timestamp | 2026-08-22T16:00:00Z |
| Session ID | `AURA-SP-014-LIVE-ACCEPTANCE-20260822` |
| Commit | `1d12c91` + working-tree changes (SP-014 completion) on `main` |
| Environment | macOS 27 / Apple Silicon arm64, Swift 6.4, Xcode 27.0-beta.5; `claude` 2.1.195 |

## Class

Deterministic + direct-live-CLI on the approved scratch repository
(`~/.aura-sp014/approved-repo`). The suite drives the real production path
(`CodingTaskCoordinator` → real `ClaudeAdapter` → real `claude` CLI, real
`WorktreeManager` → real `git worktree`, real `AuraTaskEngine`).

## Objective

Run the ten-step R6 user-present acceptance on an approved repository: (1)
read-only task on the workspace; (2) one confirmed write task in an isolated
worktree with a produced diff; (3) disabled-backend accurate health; (4) no
unauthorized commit/push/merge/PR/release/deploy.

## Symptom (blocked prior attempt)

`EV-SP-014-20260821-LIVE-ACCEPTANCE-BLOCKED-01` recorded that no backend could
produce a genuine model turn: `claude -p` returned the session limit, and claude
`--permission-mode dontAsk` (hardcoded for ALL tool profiles) blocked Write/Bash
tools by design, so a write-capable task could never actually write. The
completion gate ("all live coding scenarios pass") was therefore not met.

## Direct change / acceptance procedure

1. **Claude write-capable now uses `--permission-mode acceptEdits`.**
   `ClaudeArguments.make` and `claudePermissionMode(for:)` derive the mode from
   the tool profile: `.readOnly` → `dontAsk` (deny writes, fail closed);
   `.workspaceWrite` → `acceptEdits` (auto-approve edits confined to the
   isolated worktree). `bypassPermissions` /
   `--dangerously-skip-permissions` remain structurally unreachable. Verified
   live: `claude -p --permission-mode acceptEdits --tools "Bash,Read,Edit,Write,
   Grep,Glob" ...` creates the file inside the worktree.
   (`Sources/AuraAgent/ClaudeArguments.swift`, `ClaudeAdapter.swift`.)
2. **`WorktreeManager.diff` captures new (untracked) files.** `git diff
   <baseRef>` alone silently ignores untracked files, so a genuinely successful
   write whose output is a new file looked like a false-backend-success (empty
   diff). `diff` now returns `git status --porcelain` (lists both ` M` tracked
   modifications AND `??` untracked files) concatenated with the tracked
   `git diff` text. (`Sources/AuraAgent/WorktreeManager.swift`.)
3. **P2 live test asserts a REAL diff.** `SP014LiveAcceptanceTests` P2 now
   requires `verifyCompletion.verified == true` with a produced diff for a
   completed write-capable task (fails closed only if the backend genuinely
   cannot run this session).

## Procedure / result

- Approved repo `~/.aura-sp014/approved-repo` (git, `scratch.swift`, master
  head `d234839`).
- `AURA_SP014_LIVE_ACCEPTANCE=1 AURA_SP014_REPO=… swift test --filter SP014Live`:
  **4/4 passed**.
  - **P1 (read-only live claude turn): PASS** — `claude -p` returned a real
    model turn, task `.completed`.
  - **P2 (write-capable in isolated worktree): PASS** — claude `acceptEdits`
    created `sp014-write.txt` inside the worktree; `verifyCompletion` observed a
    non-empty porcelain diff and reported `.verified == true`; worktree removed
    afterwards.
  - **P3 (disabled backend accurate health): PASS** — a backend configured
    `.unavailable` with quota detail reports exactly that; never a false
    `.ready`.
  - **P4 (no unauthorized delivery): PASS** — running the coordinator creates
    no commit/push/merge/PR; approved repo HEAD unchanged (`d234839`).
- `AuraAgentTests` 235/235 (filtered run) — no regression.
- `claudeArgumentsMapWriteCapableToAcceptEdits` (new), `WorktreeManagerTests`
  7/7 (diff test updated) pass.

## Falsifier

A future run where a write-capable task finishes `.completed` but its worktree
produces no diff, and `verifyCompletion` reports `.verified == true`, would
falsify the diff-evidence postcondition. A read-only turn completing with a
mutation would falsify the `readOnly → dontAsk` mapping.

## Residual risk / boundary

- claude `acceptEdits` auto-approves edits; the blast radius is confined to the
  isolated worktree by the coordinator routing (SP-013) and the diff
  postcondition. `bypassPermissions` is never used.
- codex default model (`gpt-5.6-luna`) and copilot quota still prevent a live
  codex/copilot turn on this machine (external account/CLI limits) — out of
  SP-014 scope, tracked in `RISK-NO-LIVE-BACKEND-TURN`.
- No commit/push/merge/PR/release/deploy was performed (P4 asserted; authority
  `commit:false`).

## Why SP-015 is safe to start

SP-014's completion gate ("all live coding scenarios pass with direct evidence")
is now **met**: the read-only live turn, a confirmed write task in an isolated
worktree with a real diff, accurate disabled-backend health, and no
unauthorized delivery are all proven live. SP-014 is **`completed`**; SP-015 is
safe to start.
