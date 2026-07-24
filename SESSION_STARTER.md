# AURA Conversation Notes / Session Starter

> Conversation date: 23 July 2026  
> Compact hand-off for the next agent / next chat. Read this first, then `AGENTS.md` and `ledger/CURRENT_STATE.md`.

## Project

- **Name:** AURA — local-first macOS voice and computer-use agent
- **Repo:** https://github.com/mustafaras/AURA-Local-Voice-Agent-Premium-Pack
- **Device profile:** MacBook Air M5, 16 GB RAM, 512 GB SSD
- **Platform:** macOS 26+ on Apple Silicon
- **Language:** Swift 6.4
- **Toolchain:** `/Library/Developer/CommandLineTools` (no full Xcode on this machine)
- **Package:** SwiftPM package `AURA` with targets `AURA`, `AuraCore`, `AuraAudio`, `AuraAutomation`, `AuraAgent`, `AuraStore`, `AuraSTT`, and matching test targets.

## Current State (as of latest chat)

- **Phase completed:** Phase 3 — Streaming STT
- **Active milestone:** 3
- **Last verified commit on `main`:** `b0401da`
- **Next safe action:** Phase 4 — Conversation/Turn-taking/TTS per `prompts/implementation/04_04_CONVERSATION.prompt.md`
- **Build status:** `swift build --build-path /tmp/aurabuild-stt` passes
- **Test status:** `./scripts/aura-test.sh /tmp/aurabuild-stt AuraSTTTests` passes (7/7); earlier six test bundles also pass
- **Known blockers:** None

## Core vision

AURA combines natural conversation, tool execution, and coding-agent orchestration. Speech must feel fluid, but every executed action remains controlled, typed, and test-backed. The user proposes in natural language; models turn proposals into typed intents; the policy engine authorizes; adapters execute; verification confirms; the ledger records.

## Model roles

| Role | Model | Responsibility |
|---|---|---|
| Principal implementation agent | Kimi K2.7 Code | Primary coding agent for Swift implementation, tests, and ledger updates. |
| Architecture / security reviewer | GLM-5.2 | Architecture and security reviews, threat modeling, ADR validation. |
| Local assistant model | Qwen3 8B Q4/Q5 | Lightweight on-device helper for low-latency classification, routing, and simple context tasks. |

## TTS strategy

1. **Primary:** Chatterbox TTS — selected for natural voice and prosodic/expressive control.
2. **Experimental:** Dia TTS — for advanced non-verbal expression and emotional range.
3. **Fallback:** macOS system speech synthesizer — always available, no external dependency.

All TTS output flows through the spoken-output policy in `persona/AURA_VOICE_AND_BEHAVIOR.md`.

## AURA persona

- Warm, smart, calm, lightly witty.
- Does not over-explain or chatter.
- Reacts naturally but never theatrical.
- Full behavior spec: `persona/AURA_VOICE_AND_BEHAVIOR.md`

## Key normative files

1. `AGENTS.md` — operating contract (read before editing)
2. `ledger/CURRENT_STATE.md` — compact atomic state
3. `ledger/PROJECT_LEDGER.md` — append-only evidence log
4. `ledger/DECISION_INDEX.md` — ADR index
5. `README.md` — project overview
6. `persona/AURA_VOICE_AND_BEHAVIOR.md` — voice and behavior persona
7. `prompts/implementation/04_04_CONVERSATION.prompt.md` — next phase prompt

## Critical toolchain facts

- Do **not** use `swift test` directly in this environment; it fails due to missing `Testing.framework`/`lib_TestingInterop.dylib` resolution and iCloud extended-attribute codesign issues.
- Use `./scripts/aura-test.sh [<build-path>] [<bundle-filter>]` for all test execution.
- The script builds in `/tmp` and invokes `swiftpm-testing-helper` with the correct `DYLD_FRAMEWORK_PATH`, `DYLD_LIBRARY_PATH`, and `DYLD_INSERT_LIBRARIES`.
- System Swift Testing runtime lives at:
  - `/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework`
  - `/Library/Developer/CommandLineTools/Library/Developer/usr/lib/lib_TestingInterop.dylib`

## Recent decisions (ADRs)

- `ADR-001` — CommandLineTools test-runner workaround
- `ADR-002` — Real-time audio core architecture
- `ADR-003` — Wake/VAD/speaker/privacy/anti-trigger
- `ADR-004` — Streaming STT `STTEngine` protocol, `AsyncStream`, Sendable adapters, recursive-lock mock

## Unresolved risks

- Real on-device STT model not yet integrated.
- Turkish/English code-switch only deterministically validated.
- `swiftpm-testing-helper` may hang after suite summary (handled by wrapper timeout).
- Test mock uses recursive lock; real adapter needs queue-based isolation.

## What to do next

1. Read `AGENTS.md` startup sequence.
2. Read `ledger/CURRENT_STATE.md` and `ledger/PROJECT_LEDGER.md` (latest entry).
3. Read `prompts/implementation/04_04_CONVERSATION.prompt.md`.
4. Implement Phase 4, run `./scripts/aura-test.sh`, update ledgers and ADRs.
