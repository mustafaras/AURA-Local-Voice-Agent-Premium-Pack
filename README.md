# AURA — Local Voice and Computer-Use Agent

A production-oriented implementation pack for a continuously available, privacy-first macOS voice assistant that can understand Turkish and English speech, control desktop applications, orchestrate GitHub Copilot, Codex, Claude Code, and local Ollama models, and preserve durable project context through an anti-amnesia ledger.


> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## What this pack contains

- A complete system vision and architecture.
- A native SwiftUI dashboard window plus menu-bar control with explicit
  permission onboarding, push-to-talk, confirmation, recent-task,
  runtime-health, settings, and emergency-stop surfaces.
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

## Build and run the current application

```sh
BUILD_DIR=/tmp/aura-app ./scripts/build-app-bundle.sh
./scripts/codesign-adhoc.sh /tmp/aura-app/AURA.app
./scripts/verify-signature.sh /tmp/aura-app/AURA.app
open /tmp/aura-app/AURA.app
```

The app creates its private Application Support directory on first launch and
does not prompt for microphone or Speech Recognition access until the user
selects **Enable Voice Permissions**. A trained acoustic wake-word model is not
bundled; use the visible **Push to Talk** action. Command-Shift-Escape is the
global emergency-stop shortcut.

Run all 18 test bundles with coverage. The enforced line-coverage ratchet is
70%, against the currently measured 70.63% baseline:

```sh
AURA_ENABLE_COVERAGE=1 ./scripts/aura-test.sh /tmp/aurabuild
```

For a local installed smoke test, build and sign first, replace any prior
development copy at `/Applications/AURA.app`, then open the app and select
**Enable Voice Permissions**. Microphone and Speech Recognition consent are
requested directly by AURA. Accessibility and Screen Recording are granted in
System Settings when those policy-gated features are needed. The development
signature uses Hardened Runtime with the audio-input entitlement; Accessibility
and Screen Recording are TCC services, not code-signing entitlements.

## Core design principle

Use the strongest deterministic integration available:

1. Native framework or application API.
2. Application CLI or structured protocol.
3. Accessibility tree.
4. Apple Events or Shortcuts.
5. Screen understanding and computer-use automation as the last resort.

## Source verification note

The implementation must verify exact current SDK signatures and CLI flags before coding. Technology references in this pack are architectural choices, not permission to invent APIs.
