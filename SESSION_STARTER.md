# AURA Session Starter — Phase 21: Advanced Memory Engine and Provenance Graph

> Conversation date: 28 July 2026  
> Read this first, then `AGENTS.md` and `ledger/CURRENT_STATE.md`.

## Project

- **Name:** AURA — local-first macOS voice and computer-use agent
- **Repo:** https://github.com/mustafaras/AURA-Local-Voice-Agent-Premium-Pack
- **Device profile:** MacBook Air M5, 16 GB RAM, 512 GB SSD
- **Platform:** macOS 26+ on Apple Silicon
- **Language:** Swift 6.4
- **Toolchain:** `/Library/Developer/CommandLineTools` (no full Xcode on this machine)
- **Package:** SwiftPM package `AURA` with many modular targets.

## Current State (as of this session)

- **Phase completed:** Phase 20 — Release Readiness; plus gap-filled Phase 03 Streaming STT (native Speech.framework adapter, Chatterbox TTS boundary, latency tests, ADRs)
- **Active milestone:** Phase 21
- **Last verified commit on `main`:** `acded28`
- **Next safe action:** Implement Phase 21 — Advanced Memory Engine and Provenance Graph per `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 21.
- **Build status:** `swift build --build-path /tmp/aurabuild-stt` passes
- **Test status:** `./scripts/aura-test.sh /tmp/aurabuild-stt AuraSTTTests` passes; earlier bundles also pass
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
7. `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 21 — this phase's master spec
8. `docs/decisions/ADR-016-memory-engine.md` — prior memory ADR
9. `docs/subsystems/21_MEMORY_ENGINE.md` — subsystem specification
10. `Sources/AuraMemory/MemoryEngine.swift` — current stub

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
- `ADR-016` — Memory engine
- `ADR-020` — Security hardening
- `ADR-021` — Intent engine / tool router
- `ADR-022` — Composition root wiring
- `ADR-024` — Chatterbox on-device TTS
- `ADR-025` — Native Speech.framework STT adapter

## Unresolved risks

- `MemoryEngine` is implemented but has no real caller.
- Real acoustic wake-word, on-device neural STT, and Chatterbox TTS inference are not yet integrated.
- `AuraScreen`/`AuraComputerUse`/`AuraSecurity`/`AuraPlugins`/`AuraVSCode`/`WorktreeManager`/`MultiAgentOrchestrator` remain unconstructed by `AuraKernel`.
- `swiftpm-testing-helper` may hang after suite summary (handled by wrapper timeout).

## What to do next

1. Read `AGENTS.md` startup sequence.
2. Read `ledger/CURRENT_STATE.md` and `ledger/PROJECT_LEDGER.md` (latest entry).
3. Read `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 21.
4. Read `docs/subsystems/21_MEMORY_ENGINE.md` and `docs/decisions/ADR-016-memory-engine.md`.
5. Inspect current `Sources/AuraMemory/MemoryEngine.swift` and pick the first real caller (suggested: `IntentEngine`).
6. Split `MemoryEngine` into provenance graph modules, implement graph schema, persistence, contradiction detection, belief revision, and user-controlled forgetting.
7. Wire the first caller and add integration tests.
8. Run `./scripts/aura-test.sh AuraMemoryTests` and affected caller tests.
9. Write `docs/decisions/ADR-026-provenance-graph-memory.md`.
10. Append entry to `ledger/PROJECT_LEDGER.md` and atomically update `ledger/CURRENT_STATE.md`.

## Phase 21 acceptance criteria

- Provenance graph schema supports `fact`, `decision`, `task`, `utterance`, `file`, `preference` nodes and `evidenceFor`, `derivedFrom`, `supersedes`, `conflictsWith`, `confirms`, `denies` edges.
- `AuraMemory` target is split into `ProvenanceGraph`, `GraphQuery`, `ContradictionDetector`, `BeliefRevision`, and the public `MemoryEngine` facade.
- Nodes and edges are persisted in `AuraStore` with append-only semantics.
- Deletion is user-controlled, leaves an audit shadow record, and never hard-deletes.
- At least one real caller writes and reads memory through `MemoryEngine`.
- All tests pass; no regressions in other bundles.
- ADR-026 and ledger current state are written.

## Out of scope for Phase 21

- JSON-LD/Markdown import-export (defer until schema stabilizes).
- Multi-hop context reconstruction (Phase 22).
- Plugin marketplace (Phase 23).
- Cross-device sync (Phase 27).
