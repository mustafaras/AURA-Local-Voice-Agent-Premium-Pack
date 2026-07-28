# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live Git and command evidence on 2026-07-28.

- Phase: Phase 22 Deep Context Reconstruction and Reference Resolution complete; awaiting user direction
- Active milestone: 20_RELEASE_READINESS → TTS_ROADMAP (parked) → 03_STREAMING_STT → 21_PROVENANCE_GRAPH_MEMORY → 22_DEEP_CONTEXT_RECONSTRUCTION
- Active task: None — Phase 22 implementation, adversarial tests, documentation, and evidence review are complete in the working tree.
- Last verified commit: `58fb9be` on `main`, equal to `origin/main`. Phase 22 changes are not committed or pushed.
- Build status: Passes `swift build --target AURA --build-path /tmp/aurabuild-phase22-static -Xswiftc -warnings-as-errors`; only CommandLineTools linker search-path warnings are emitted.
- Test status:
  - Full default 10-bundle run passes via `./scripts/aura-test.sh /tmp/aurabuild-phase22-full`: 355 tests total (`AURAIntegrationTests` 7, `AuraAgentTests` 205, `AuraAudioTests` 31, `AuraAutomationTests` 6, `AuraCoreTests` 7, `AuraIntentTests` 29, `AuraMemoryTests` 25, `AuraSTTTests` 14, `AuraShellTests` 23, `AuraStoreTests` 8).
  - Phase-specific `AuraContextTests` passes 30/30 on the final reviewed source via `/tmp/aurabuild-phase22-postreview`.
  - Targeted `AuraIntentTests` 29/29 and `AURAIntegrationTests` 7/7 also passed in isolated pre-full-suite runs.
- Known blockers: None
- Pending confirmations:
  - **Phase 22 is implemented but not committed.** Commit/push requires explicit user authorization; release remains separately user-authorized.
  - **Workspace build path remains environment-limited.** Use `/tmp/aurabuild*`; Desktop/iCloud extended attributes can break SwiftPM ad-hoc codesign.
  - **Real-device speech evidence remains incomplete.** Native on-device STT is wired, but real wake-word accuracy, Chatterbox neural inference, energy/thermal budgets, and conversation-level real-engine latency remain unvalidated.
  - **Packaging/update work remains scaffolding/design.** No Developer ID signing, notarization, distribution, or release was performed.
- Resolved in Phase 22:
  - Added typed `ContextBuilder` pipeline traces for utterance parse → intent schema → entity extraction → scope filter → evidence rank → ambiguity check → final bundle.
  - Added an inspectable reference-resolution graph with entity-kind matching and conversational salience.
  - Mutation/destructive candidates still require direct evidence, non-inferred authority, scope match, and configured confidence; exact UUID-bound explicit confirmation is supported but does not grant policy permission.
  - Added cross-session memory injection and bounded provenance traversal (`maxGraphDepth`, `maxGraphItems`) supporting tested file → task → decision → preference lookup.
  - Added hard estimated-token budgeting, fail-closed mandatory-context overflow, secret/non-injectable override rejection, per-turn inclusion/exclusion controls, provenance IDs, confidence, score, token cost, and inclusion reasons.
  - `AuraKernel` now constructs `ContextBuilder`; `IntentEngine` calls it for every completed turn before memory persistence/routing, exposes `inspectLastContext()`, and treats retrieval failure as audited best-effort.
  - Added `DeepContextBuiltEvent` and `DeepContextBuildFailedEvent`.
  - Added ADR-027, updated subsystem documentation, repaired ADR-023 through ADR-027 decision-index rows, and refreshed `SESSION_STARTER.md`.
- Unresolved Phase 22 risks:
  - Live `IntentEngine` builds currently have no active-workspace/reference-candidate provider, so cross-session injection is live but candidate-based pronoun resolution is exercised through the public API/tests rather than a real spoken action path.
  - There is no visual inspection or confirmation UI; the Phase 22 surface is programmatic.
  - Provenance graph traversal materializes retained nodes/edges in memory; the tested small fixture meets the 250 ms default lookup budget, but no large-store performance claim is made.
  - Token budgeting uses a conservative local UTF-8 estimate rather than a model-specific tokenizer.
  - Legacy memory records without provenance nodes remain retrievable but cannot provide graph-expanded lineage until back-filled.
  - `AuraScreen`/`AuraComputerUse`/`AuraSecurity`/`AuraPlugins`/`AuraVSCode`/`WorktreeManager`/`MultiAgentOrchestrator` remain unconstructed by `AuraKernel`.
- Next safe action: Review the Phase 22 diff. On explicit user direction, either (1) commit/push the verified working tree, or (2) proceed to Phase 23 Verified Plugin and Adapter Marketplace after re-reading its specification and inspecting the existing Phase 19 plugin-security foundation. No release without explicit authorization.
