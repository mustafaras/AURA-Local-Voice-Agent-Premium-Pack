# Repository Instructions for GitHub Copilot

Read `AGENTS.md`, `ledger/CURRENT_STATE.md`, and the relevant normative specifications before editing.

This repository builds a privacy-first macOS voice and computer-use agent. Safety, correctness, recoverability, latency, and convenience are prioritized in that order.

Never invent Apple framework APIs, CLI flags, model capabilities, test results, or permission behavior. Verify unstable interfaces from official documentation or installed command help.

Use Swift strict concurrency and explicit isolation. Keep the real-time audio path free of blocking work, allocation, disk I/O, network calls, and model loading. Use typed schemas at every model/tool boundary.

Models do not execute actions. They propose typed intents or plans. The policy engine authorizes. Adapters execute. Verification confirms. The ledger records.

Prefer native APIs and structured application adapters over Accessibility, and Accessibility over screen-coordinate automation.

Do not expose secrets, ambient audio, screenshots, private documents, or personal memory in prompts, logs, fixtures, or repository files.

Every behavior change requires tests. Every material architecture change requires an ADR. Every completed task requires an append-only project-ledger entry and an atomic current-state update.

Do not commit, push, deploy, release, delete user data, install dependencies, or change system permissions unless the active task explicitly authorizes it.
