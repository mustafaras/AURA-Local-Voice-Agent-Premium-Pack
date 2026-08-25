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
- Layered typed configuration, expiring feature flags, local tuning
  recommendations, inspection, and restart-safe rollback.
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
6. For governed work, use the canonical active prompt in
   `AURA_RUNTIME_COMPLETION/state/current-state.json` and its manifest; do not
   infer work from historical prompt-path references.
7. Run the relevant review or closeout prompt after every milestone.
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
bundled; use the visible **Push to Talk** action, speak, then pause briefly.
macOS consent sheets are secure system UI: select **Allow** for Microphone and
then Speech Recognition when they appear; AURA cannot grant these itself.
The turn closes after detected speech followed by configured silence, with a
bounded fallback before the conversation deadline. Command-Shift-Escape is the
global emergency-stop shortcut.

### Local Chatterbox V3 voice (primary)

AURA's primary voice is the local Chatterbox Multilingual V3 neural adapter.
Install the exact pinned runtime and model snapshot:

```sh
./scripts/install-chatterbox-runtime.sh
```

This creates a Python 3.11 environment and model cache under
`~/Library/Application Support/AURA`; model weights are not added to the
repository or app bundle. Installation requires network access, but runtime
synthesis is forced offline.

Neural production speech is consent-gated. Place an owned or explicitly
consented female Turkish WAV at:

```text
~/Library/Application Support/AURA/Voices/aura-female-reference.wav
```

Do not use another person's recording without explicit consent. AURA does not
upload this file. If the file, runtime, model manifest, or helper is
unavailable, AURA fails closed to the on-device system synthesizer, which
auto-selects the best installed voice for the locale by platform quality — no
specific system voice is hardcoded or preferred. The reference must be 3–30
seconds of clean PCM WAV, mono or stereo, at 16–48 kHz. A human-listened
Turkish turn is still required before accepting a reference recording for
regular use.

Run all 21 test bundles with coverage. The repository source and
`scripts/aura-test.sh` currently enumerate 21 Swift test bundles. The enforced
line-coverage ratchet is 70%. The raw all-source matrix is retained as 65.15%;
the enforced scope excludes only four host-boundary files documented in
`scripts/aura-coverage-scope.regex` and measured 70.02% in the latest full
matrix:

```sh
AURA_ENABLE_COVERAGE=1 ./scripts/aura-test.sh /tmp/aurabuild
```

The runner bounds Swift Testing parallelism to one worker for the
`AuraAgentTests` bundle by default. That bundle combines live CLI probes, real
git worktree operations, and actor-backed fixtures; unrestricted parallel
execution can otherwise produce scheduling-dependent false failures in the
full matrix. For controlled experiments only, set
`AURA_AGENT_TEST_PARALLELIZATION_WIDTH` to an explicit width.

For a local installed smoke test, build and sign first, replace any prior
development copy at `/Applications/AURA.app`, then open the app and select
**Enable Voice Permissions**. Microphone and Speech Recognition consent are
requested directly by AURA. Accessibility and Screen Recording are granted in
System Settings when those policy-gated features are needed; their explicit
request buttons register AURA with the corresponding macOS privacy service
before opening manual settings as a fallback. On a provisioned
development Mac, the signing script reuses the locally trusted
`AURA Stable Local Signing` Keychain identity so the app's designated
requirement stays stable across rebuilds and TCC grants can persist. Other
machines fall back to ad-hoc signing. This local identity is not Developer ID
or notarization. The signature uses Hardened Runtime with the audio-input
entitlement; Accessibility and Screen Recording are TCC services, not
code-signing entitlements.

## Core design principle

Use the strongest deterministic integration available:

1. Native framework or application API.
2. Application CLI or structured protocol.
3. Accessibility tree.
4. Apple Events or Shortcuts.
5. Screen understanding and computer-use automation as the last resort.

## Source verification note

The implementation must verify exact current SDK signatures and CLI flags before coding. Technology references in this pack are architectural choices, not permission to invent APIs.
