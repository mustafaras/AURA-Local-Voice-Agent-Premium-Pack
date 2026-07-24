# Current State

This file is a compact, atomically replaced projection of the append-only ledger.

- Phase: Typed shell / process runner complete and cancellation-hardened
- Active milestone: 7
- Active task: 07_TYPED_SHELL — completed
- Last verified commit: working tree (Phase 7 changes not yet committed)
- Build status: Passes (`swift build` with Swift 6.4 CommandLineTools)
- Test status: Passes via `./scripts/aura-test.sh /tmp/aurabuild-phase7-perfect`; all 9 test bundles pass, including 16 `AuraShellTests` (15 original + 1 new cancellation test) and previously passing AuraAgentTests, AuraAudioTests, AuraAutomationTests, AuraCoreTests, AuraPolicyTests, AuraSTTTests, AuraStoreTests, AURAIntegrationTests
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
- Next safe action: Review Phase 7 diff for scope expansion, then proceed to Phase 8 per `prompts/implementation/08_08_VSCODE_ADAPTER.prompt.md`; read Phase 8 prompt and ADR-008 before starting.
