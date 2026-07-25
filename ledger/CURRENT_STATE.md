# Current State

This file is a compact, atomically replaced projection of the append-only ledger.

- Phase: Ollama Local Model Adapter complete
- Active milestone: 13
- Active task: 13_OLLAMA_ADAPTER — completed
- Last verified commit: 6e6537a (origin/main, Phase 10–12); Phase 13 changes present locally, not yet committed
- Build status: Passes (`swift build --build-path /tmp/aurabuild-final13`, zero non-linker warnings)
- Test status: Passes via `./scripts/aura-test.sh /tmp/aurabuild-final13`; all 8 default-loop bundles pass, plus `AuraPolicyTests` (17/17), `AuraTasksTests` (10/10), and `AuraVSCodeTests` (13/13) run explicitly — 11/11 test bundles pass with zero failures, 270 tests total. `AuraAgentTests` now 171/171 (41 new Ollama tests alongside the 130 from Phase 10–12), re-run 3× with no flakiness.
- Known blockers: None
- Pending confirmations:
  - Ollama: `/api/show`'s deeper `model_info` (per-architecture context length, exact parameter counts) is never consumed — the registry uses only `/api/tags`'s fields; sufficient for this phase but coarser than theoretically possible.
  - Ollama: `maxResidentModelBytes`'s 6 GB default is a reasoned starting point, not benchmarked against real concurrent STT/TTS/vision footprints on the documented 16 GB target device.
  - Ollama: multi-turn session continuation (`/api/generate`'s `context` array) is unimplemented, matching the Codex/Claude/Copilot `resume`-scoping precedent.
  - Copilot: no successful-completion event was ever really captured (account quota exhausted both authorized smoke-test attempts); `assistant`-with-text-content and any `tool_use`/`tool_result`-equivalent event shapes remain entirely unconfirmed — `CopilotEventNormalizer` falls back to `.unrecognizedTopLevel` for anything not matching the two real captures.
  - GitHub's cloud-hosted "Copilot coding agent" (issue-assignment-triggered, runs on GitHub Actions) is not implemented at all — out of scope by design; the local CLI adapter has no path to it.
  - `copilot --continue`/`--resume`/`--session-id`, `claude --resume`/`--continue`, and `codex exec resume` (multi-turn sessions for the three CLI adapters) are unimplemented, as is Claude's token-level streaming (`--include-partial-messages`).
  - Claude item-level JSONL classification covers only `text` content blocks, `system` subtypes `hook_started`/`hook_response`/`init`, `result`, and `rate_limit_event`; `tool_use`/`tool_result`/`thinking`/`api_retry`/`plugin_install`/`stream_event` remain opaque pending an authorized run that exercises tools.
  - Claude adapter has no live file-write budget enforcement (structural tool-tier restriction via `--tools` only, not live counting); cost budget is enforced natively by `--max-budget-usd` plus a post-hoc observability check.
  - `--setting-sources user` (Claude hooks-safety default) is a narrower guarantee than Anthropic's own recommended `--bare` mode, which requires API-key auth this environment does not have configured.
  - Codex item-level JSONL classification covers only `error`/`reasoning`/`agent_message`; `file_change`/`plan_update`/`command_execution`/`mcp_tool_call`/`web_search` remain opaque pending an authorized run that exercises file/command tools.
  - Codex token/cost budgets are advisory-only (captured via `turn.completed.usage`, not enforced pre-turn) — no CLI-native budget flag exists for Codex, unlike Claude's `--max-budget-usd` or Copilot's `--max-ai-credits`.
  - Real on-device STT model integration (Speech.framework / ONNX / Core ML) and acoustic WER/latency measurement.
  - Turkish/English code-switch acoustic validation with live audio.
  - Real-adapter isolation: replace recursive-lock/lock mock TTS with queue-based, real-time-safe isolation.
  - `swiftpm-testing-helper` hang after suite summary; workaround in `scripts/aura-test.sh` should be removed after toolchain/SwiftPM fix.
  - Integration of `Conversation`, `PolicyEngine`, wake pipeline, intent engine, and tool adapters into a single orchestrated turn.
  - Live macOS app lifecycle validation with sandboxed entitlements and Accessibility permission prompts.
  - End-to-end confirmation flow from `PolicyEngine` through UI to `AuraAutomation` tool adapters.
  - Real policy-engine authorization wired into `AuraShell.execute` and `AuraTaskEngine` before launching commands (`CodexAdapter`/`ClaudeAdapter`/`CopilotAdapter`/`OllamaAdapter` each perform their own real `PolicyEngine.evaluate` call and do not depend on this).
  - Interactive PTY adapter integrated with terminal-agent and multi-agent protocol.
  - Companion VS Code extension that writes bridge snapshots for live editor/terminal/diagnostics state.
  - Active watchdog enforcing `TaskConfiguration.deadline` and `inactivityTimeoutSeconds`.
  - None of `CodexAdapter`/`CodexTaskRunner`, `ClaudeAdapter`/`ClaudeTaskRunner`, `CopilotAdapter`/`CopilotTaskRunner`, or `OllamaAdapter`/`OllamaTaskRunner` is wired into the `AURA` app composition root yet.
  - `scripts/aura-test.sh`'s default loop still omits `AuraPolicyTests`/`AuraTasksTests`/`AuraVSCodeTests` (must be run explicitly with a target filter).
- Next safe action: Review the Phase 13 diff with the user; on approval, commit and push. Then proceed to Phase 14 — Multi-Agent Orchestration (`prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md`) only when the user next signals to continue.
