# Current State

This file is a compact, atomically replaced projection of the append-only ledger.

- Phase: VS Code Adapter complete
- Active milestone: 8
- Active task: 08_VSCODE_ADAPTER — completed
- Last verified commit: (pending Phase 8 commit)
- Build status: Passes (`swift build` with Swift 6.4 CommandLineTools)
- Test status: Passes via `./scripts/aura-test.sh /tmp/aurabuild-final`; all 10 test bundles pass, including 13 `AuraVSCodeTests` and previously passing AuraAgentTests, AuraAudioTests, AuraAutomationTests, AuraCoreTests, AuraPolicyTests, AuraSTTTests, AuraShellTests, AuraStoreTests, AURAIntegrationTests
- Known blockers: None
- Pending confirmations:
  - Real on-device STT model integration (Speech.framework / ONNX / Core ML) and acoustic WER/latency measurement.
  - Turkish/English code-switch acoustic validation with live audio.
  - Real-adapter isolation: replace recursive-lock/lock mock TTS with queue-based, real-time-safe isolation.
  - `swiftpm-testing-helper` hang after suite summary; workaround in `scripts/aura-test.sh` should be removed after toolchain/SwiftPM fix.
  - Integration of `Conversation`, `PolicyEngine`, wake pipeline, intent engine, and tool adapters into a single orchestrated turn.
  - Live macOS app lifecycle validation with sandboxed entitlements and Accessibility permission prompts.
  - End-to-end confirmation flow from `PolicyEngine` through UI to `AuraAutomation` tool adapters.
  - Real policy-engine authorization wired into `AuraShell.execute` before launching commands.
  - Interactive PTY adapter integrated with terminal-agent and multi-agent protocol.
  - Companion VS Code extension that writes bridge snapshots for live editor/terminal/diagnostics state.
- Next safe action: Review Phase 8 diff for scope expansion, then proceed to Phase 9 per `prompts/implementation/09_09_CODEX_CONTROLLER.prompt.md`; read Phase 9 prompt and ADR-009 before starting.
