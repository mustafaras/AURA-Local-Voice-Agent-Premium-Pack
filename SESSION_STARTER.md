# AURA Session Starter — Phase 22: Deep Context Reconstruction and Reference Resolution

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

- **Phase completed:** Phase 21 — Advanced Memory Engine and Provenance Graph (provenance nodes/edges/shadows, intent-to-memory wiring, 25 AuraMemoryTests + 27 AuraIntentTests, ADR-026)
- **Active milestone:** Phase 22
- **Last verified commit on `main`:** `f83f053`
- **Next safe action:** Implement Phase 22 — Deep Context Reconstruction and Reference Resolution per `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 22.
- **Build status:** `swift build --target AURA --build-path /tmp/aurabuild` passes
- **Test status:** All 10 test bundles pass via `./scripts/aura-test.sh /tmp/aurabuild` (AuraMemoryTests 25/25, AuraIntentTests 27/27, AuraCoreTests 7/7, AuraStoreTests 8/8, AuraAutomationTests 6/6, AuraShellTests 23/23, AuraSTTTests 14/14, AuraAudioTests 31/31, AuraAgentTests 205/205, AURAIntegrationTests 7/7)
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
10. `Sources/AuraContext/ContextEngine.swift` — current Phase 16 implementation
11. `Sources/AuraMemory/MemoryEngine.swift` — provenance-graph integration completed in Phase 21
12. `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md` — subsystem specification
13. `docs/decisions/ADR-017-context-reconstruction.md` — prior context-reconstruction ADR

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
- `ADR-026` — Provenance graph memory engine

## Unresolved risks

- `ContextEngine` (Phase 16 minimal context reconstruction) exists but has no real caller during a live conversation turn; Phase 22 must integrate it with `IntentEngine`/`Conversation` while preserving safety invariants.
- Reference resolution guardrails (`.ambiguous`, `.blockedWeakEvidence`) are tested in isolation but not yet exercised end-to-end in a spoken turn.
- Real acoustic wake-word, on-device neural STT, and Chatterbox TTS inference are not yet integrated.
- `AuraScreen`/`AuraComputerUse`/`AuraSecurity`/`AuraPlugins`/`AuraVSCode`/`WorktreeManager`/`MultiAgentOrchestrator` remain unconstructed by `AuraKernel`.
- `swiftpm-testing-helper` may hang after suite summary (handled by wrapper timeout).

## What to do next

1. Read `AGENTS.md` startup sequence.
2. Read `ledger/CURRENT_STATE.md` and `ledger/PROJECT_LEDGER.md` (latest entry).
3. Read `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 21.
4. Read `docs/subsystems/21_MEMORY_ENGINE.md` and `docs/decisions/ADR-016-memory-engine.md`.
5. Inspect current `Sources/AuraContext/ContextEngine.swift` and existing `Sources/AuraMemory/MemoryEngine.swift`.
6. Design the Phase 22 `ContextBuilder` pipeline: utterance parse → intent schema → entity extraction → scope filter → evidence rank → ambiguity check → final bundle.
7. Implement reference resolution graph: rank candidates by scope, recency, authority, and conversational salience; map pronouns and implicit targets safely.
8. Add negative guardrails: destructive/mutation candidates require direct evidence or explicit confirmation; weakly resolved targets are rejected/ambiguous.
9. Wire `ContextEngine` as the first real caller of `MemoryEngine` for cross-session memory injection; keep token budget and latency constraints.
10. Add adversarial reference-resolution tests and context-bundle tests.
11. Run `./scripts/aura-test.sh /tmp/aurabuild AuraContextTests` and all affected bundles.
12. Write `docs/decisions/ADR-027-deep-context-reconstruction.md`.
13. Append entry to `ledger/PROJECT_LEDGER.md` and atomically update `ledger/CURRENT_STATE.md`.

## Phase 22 acceptance criteria

- `ContextBuilder` pipeline assembles the smallest sufficient bundle: utterance → intent schema → entity extraction → scope filter → evidence rank → ambiguity check → final bundle.
- Reference resolution graph resolves pronouns/implicit targets (`it`, `that`, `the file`, `the last one`) by scope, recency, authority, and conversational salience.
- Negative guardrails prevent destructive/mutation targets from resolving on weak evidence; ambiguous or weakly supported references surface `.ambiguous` or `.blockedWeakEvidence` outcomes.
- Cross-session memory injection loads relevant project facts, decisions, and preferences without exceeding token budget.
- Every context bundle includes provenance IDs and confidence scores; explainability is testable.
- `ContextEngine` becomes a real caller of `MemoryEngine` and/or provenance graph queries.
- Adversarial reference-resolution test suite passes (e.g., “delete it” without clear target is rejected/confirmed).
- Context bundles fit within configured token budgets while retaining necessary facts.
- Multi-hop lookups (file → task → decision → preference) complete within latency budget.
- User can inspect and override context inclusions.
- All tests pass; no regressions in other bundles.
- ADR-027 and ledger current state are written.

## Out of scope for Phase 22

- Embedding-based semantic retrieval (keep deterministic keyword containment; upgrade in later phase).
- Real UI for context inspection (expose programmatic API/tests now).
- Plugin marketplace (Phase 23).
- Cross-device sync (Phase 27).
