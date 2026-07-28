# AURA Session Starter — Phase 23: Verified Plugin and Adapter Marketplace

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

- **Phase completed:** Phase 22 — Deep Context Reconstruction and Reference Resolution (`ContextBuilder`, reference graph, token/graph budgets, cross-session provenance injection, inspection/override API, live `IntentEngine` caller, ADR-027)
- **Active milestone:** Awaiting user direction; Phase 23 is the next numbered phase
- **Last verified implementation commit on local `main`:** `520b71c` (Phase 22; remote verification pending post-commit state push)
- **Next safe action:** Push and verify the Phase 22 implementation/state commits, then implement Phase 23 per `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 23.
- **Build status:** `swift build --target AURA --build-path /tmp/aurabuild-phase22-static -Xswiftc -warnings-as-errors` passes (CommandLineTools linker search-path warnings only)
- **Test status:** Default 10-bundle suite passes (355 tests); `AuraContextTests` 30/30, `AuraIntentTests` 29/29, and `AURAIntegrationTests` 7/7 pass
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
7. `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §Phase 23 — next phase's master spec
8. `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md` — completed context subsystem specification
9. `docs/decisions/ADR-027-deep-context-reconstruction.md` — Phase 22 decision
10. `Sources/AuraContext/ContextBuilder.swift` — completed Phase 22 pipeline
11. `Sources/AuraContext/ReferenceResolver.swift` — reference graph and guarded resolution
12. `Sources/AuraMemory/MemoryEngine.swift` — provenance graph query facade
13. `Sources/AuraPlugins/` and `docs/decisions/ADR-020-security-hardening.md` — existing plugin-security foundation to inspect before Phase 23

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
- `ADR-027` — Deep context reconstruction and reference resolution

## Unresolved risks

- Phase 22 exposes reference resolution and inspection programmatically; no real confirmation/inspection UI exists yet.
- Live `IntentEngine` context builds currently have no active-workspace/reference-candidate provider, so typed graph resolution is exercised through the API/tests while cross-session memory injection is live.
- Provenance graph traversal still materializes retained nodes/edges in memory; large-store profiling and lazy adjacency queries remain future work.
- Real acoustic wake-word, on-device neural STT, and Chatterbox TTS inference are not yet integrated.
- `AuraScreen`/`AuraComputerUse`/`AuraSecurity`/`AuraPlugins`/`AuraVSCode`/`WorktreeManager`/`MultiAgentOrchestrator` remain unconstructed by `AuraKernel`.
- `swiftpm-testing-helper` may hang after suite summary (handled by wrapper timeout).

## What to do next

1. Read `AGENTS.md`, `ledger/CURRENT_STATE.md`, and the newest `ledger/PROJECT_LEDGER.md` entry.
2. Confirm the live Git status and whether the user wants the Phase 22 working tree committed/pushed or wants Phase 23 implemented without committing.
3. For Phase 23, read the master prompt §Phase 23, current `AuraPlugins` implementation/tests, ADR-020, threat model, policy grants, store schema, and plugin manifest types.
4. Record Phase 23 objective, assumptions, risks, and acceptance criteria in the ledger before editing.
5. Preserve Phase 22 safety boundaries: plugin content cannot become trusted context merely through recency/salience, and plugin actions cannot bypass policy.

## Phase 23 headline acceptance gate

- Unsigned/tampered plugins are rejected before loading.
- Plugins cannot exceed declared capabilities or policy grants.
- Disabled/quarantined plugins cannot emit events or execute.
- Uninstall preserves audit records.
- Manifest spoofing, hash collision, and capability-escalation adversarial tests pass.
