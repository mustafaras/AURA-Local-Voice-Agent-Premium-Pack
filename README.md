# AURA — Local Voice and Computer-Use Agent

A production-oriented implementation pack for a continuously available, privacy-first macOS voice assistant that can understand Turkish and English speech, control desktop applications, orchestrate GitHub Copilot, Codex, Claude Code, and local Ollama models, and preserve durable project context through an anti-amnesia ledger.


> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## What this pack contains

- A complete system vision and architecture.
- Native macOS control requirements.
- Streaming audio, wake-word, VAD, STT, intent, TTS, and interruption behavior.
- Deterministic tool routing and computer-use fallback.
- Codex, Claude Code, GitHub Copilot, and local model orchestration.
- Append-only anti-amnesia ledger and context reconstruction.
- Permission, privacy, audit, and threat models.
- Testing, release, observability, recovery, and deployment specifications.
- Ordered implementation prompts for coding agents.
- Repository-level GitHub Copilot instructions.
- Specialized GitHub Copilot custom agent profiles.
- Agent skills for memory discipline and release readiness.

## Non-goals

- Unattended execution of destructive actions.
- Continuous cloud streaming of ambient audio.
- Silent collection of passwords, private messages, or protected content.
- Treating screenshots or UI automation as more reliable than native APIs.
- Allowing an LLM to execute arbitrary shell strings without policy evaluation.

## Recommended execution order

1. Read `AGENTS.md`.
2. Read `docs/00_SYSTEM_VISION.md`.
3. Read `docs/01_MASTER_SPEC.md`.
4. Read `docs/architecture/02_ARCHITECTURE.md`.
5. Initialize `ledger/PROJECT_LEDGER.md`.
6. Execute prompts in `prompts/implementation/` in numeric order.
7. Run the review prompts after every milestone.
8. Do not begin a later phase until the prior phase's acceptance gate passes.

## Core design principle

Use the strongest deterministic integration available:

1. Native framework or application API.
2. Application CLI or structured protocol.
3. Accessibility tree.
4. Apple Events or Shortcuts.
5. Screen understanding and computer-use automation as the last resort.

## Source verification note

The implementation must verify exact current SDK signatures and CLI flags before coding. Technology references in this pack are architectural choices, not permission to invent APIs.
