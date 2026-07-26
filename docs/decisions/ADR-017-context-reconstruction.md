# ADR-017 — Context Reconstruction

- Status: Accepted
- Date: 2026-07-26
- Owners: Claude Sonnet 5 (Claude Code)
- Supersedes: —
- Superseded by: —

## Context

Phase 16 of the AURA implementation roadmap requires minimal context reconstruction: a fixed retrieval sequence (current utterance → conversation state → pending confirmation/task → active app/workspace → project ledger → recent decisions → preferences → semantic retrieval), ranking by scope match/recency/authority/confidence/direct evidence, ambiguity handling, and source IDs in every bundle — per `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md`. Phase 22 ("Deep Context Reconstruction and Reference Resolution") later builds a full multi-hop `ContextBuilder` pipeline with a reference-resolution graph and cross-session memory injection; this phase deliberately stays within the simpler, mechanically-verifiable scope the master prompt asks for at Phase 16, matching the same "basic now, advanced later" split already used between Phase 15 (`MemoryEngine`) and Phase 21 (provenance graph).

Before this phase, the retrieval sequence's later stages already had real backing data with no consumer: `ProjectLedgerEntry`/`AuraStore.entries` (added in Phase 0, explicitly documented as existing so "the runtime can reconstruct recent context without parsing Markdown") and `MemoryEngine.currentState` (Phase 15's `.userPreference`/`.projectFact`/`.proceduralKnowledge` classes) had no subsystem that actually read them back out for a live request. The earlier stages — conversation state, pending confirmation, pending task, active app/workspace — are transient, live state owned by other actors (`AuraAgent.Conversation`, `AuraPolicy.PolicyEngine`, `AuraTasks.AuraTaskEngine`, `AuraAutomation`/`AuraVSCode`) that did not previously have a shared, typed shape for "what am I currently looking at" to be handed to anything else.

## Decision

1. **A new `AuraContext` module, depending only on `AuraCore`, `AuraStore`, and `AuraMemory`.** `ContextEngine` needs real read access to the project ledger (`AuraStore`) and preferences/facts (`AuraMemory`), but the first four retrieval-sequence stages (utterance, conversation state, pending confirmation/task, active workspace) are transient state that lives in `AuraAgent`, `AuraPolicy`, `AuraTasks`, `AuraAutomation`, and `AuraVSCode`. Rather than adding `AuraContext` as a dependency of all five of those modules (or vice versa, an unacceptable dependency-graph blowup for a phase whose own mission is "minimal"), `ContextEngine.reconstruct` accepts those four stages as plain typed parameters that a future composition root or dialogue-turn caller supplies from whatever live actor state it already holds. This mirrors `MemoryEngine`'s own precedent of staying dependency-light and taking already-assembled data in, rather than reaching across the whole subsystem graph itself.

2. **Five ranking dimensions are pure, dependency-free functions in `AuraCore/ContextRanking.swift`, shared verbatim by `ContextEngine` and `ReferenceResolver`.** Both the "which optional bundle candidates make the cut" ranking and the "which reference candidate is the resolved target" ranking use the exact same scope-match/recency/authority/confidence/evidence composite score (`ContextRanking.score`), each contributing a configurable weight (`ContextConfiguration.rankingWeight*`, validated to sum to `1.0`). One scoring implementation, unit-tested once, backs both call sites instead of two hand-rolled, potentially-diverging heuristics.

3. **`ContextRetrievalStage` marks stages 0–3 as mandatory, never subject to ranking or truncation.** The current utterance, conversation state, and (when present) pending confirmation/task and active workspace are always included verbatim in a bundle — they are not "candidates competing for a budget," they are the request itself and what is currently happening. Only stages 4–7 (project ledger, recent decisions, preferences, semantic retrieval) are scored, ranked, and truncated to `ContextConfiguration.maxBundleItems`, which is what makes a bundle "minimal and sufficient" a property of the optional tail rather than something that could ever drop the utterance itself.

4. **"Recent decisions" are derived from the same `ProjectLedgerEntry.decisions` arrays already fetched for the project-ledger stage, not a new memory class.** The retrieval sequence lists project-ledger entries and recent decisions as two distinct stages; rather than inventing a new `MemoryClass` case or a parallel decisions table, each decision string inside a fetched ledger entry becomes its own `ContextItem` (`sourceID: .decision(entryID:index:)`), inheriting the parent entry's evidence/timestamp. This reuses real, already-authoritative data (the same evidence-backed decisions recorded in `ledger/PROJECT_LEDGER.md` and mirrored into `AuraStore`) instead of asking a caller to duplicate them into a second system.

5. **Semantic retrieval is a real, deterministic keyword-containment search, not a stub.** `ContextRanking.tokenize`/`containmentScore` lowercase, split, drop stopwords/short tokens, and score a memory record's subject+statement by what fraction of the utterance's tokens it contains, scoped to `.projectFact`/`.proceduralKnowledge`/`.taskState`. This is the same "real but simple deterministic implementation now, upgrade later" pattern already established by Phase 2's marker-tone wake-word/VAD detectors — a working, testable mechanism now, with an embedding-based upgrade left to Phase 21/22 rather than fabricated today.

6. **Reference resolution has three outcomes, not two, so "ask" and "confirm" guardrails are independently observable.** `ReferenceResolution` is `.resolved`, `.ambiguous([...])`, `.blockedWeakEvidence(_)`, or `.none`. `.ambiguous` fires when the top two candidates are not clearly separated (`referenceSeparationMargin`) — "ask which one." `.blockedWeakEvidence` fires when there is a single, clear top candidate, but its capability's risk tier is at or above `referenceGuardedTierThreshold` (default `.mutation`) and the evidence backing it is not strong enough — "confirm this one, explicitly," distinct from genuine multi-candidate ambiguity. Collapsing these into one `.ambiguous` case (as an earlier draft of this design did) would have made the destructive-weak-evidence gate untestable as its own property; keeping them separate makes the acceptance gate a directly assertable outcome rather than an inferred one.

7. **The weak-evidence gate is a hard requirement, not a ranking tiebreak.** For a guarded-tier top candidate, `ReferenceResolver.resolve` requires *all* of: direct evidence present, authority not `.inferred`, in scope, and confidence at or above `referenceGuardedMinimumConfidence` (default `0.85`). Failing any single one of these blocks resolution regardless of how far ahead the candidate's composite score is — a candidate cannot "outscore its way past" a missing evidence dimension. This is deliberately more conservative than the acceptance gate's literal wording (which only names "destructive"): the default `referenceGuardedTierThreshold` is `.mutation`, one tier below `.destructive`, because a real assistant capable of overwriting (not just deleting) files on weak evidence is not meaningfully safer, and this project's own priority order is "Safety → Correctness → Recoverability → Latency → Convenience."

8. **`MemoryScope`-based scope matching is a ranking signal, not a hard filter.** `ContextRanking.scopeMatches` treats a record with no scope constraints (`.global`) as always in-scope, a record whose *any* constrained field (project/task/session) matches the request as in-scope, and a record scoped to a different project/task/session as out-of-scope. `ContextEngine` fetches preferences/facts unfiltered from `MemoryEngine` (passing `scope: nil`) and applies this as a ranking dimension instead of a query-time `WHERE` filter, so a global preference remains usable in a project-scoped session (just outranked by a more specific in-scope one), matching "prioritize ... scope match" (a ranking instruction) rather than "exclude out-of-scope items" (which is not what the spec says).

## Alternatives considered

- **Have `ContextEngine` depend on `AuraAgent`/`AuraPolicy`/`AuraTasks`/`AuraAutomation`/`AuraVSCode` directly and pull live state itself.** Rejected — this phase's own mission is "minimal," and building a context engine that fans out into five sibling subsystems' internals (several of which, like `PolicyEngine.pendingConfirmations`, are not even public) is the opposite of minimal. Accepting typed snapshots as parameters keeps the module boundary honest about what Phase 16 actually implements versus what a future composition root wires together.
- **One `ReferenceResolution.ambiguous` case covering both "multiple plausible targets" and "one target, weak evidence."** Rejected — collapsing them would make it impossible to write a test that specifically proves the destructive-weak-evidence gate fires (as opposed to a generic multi-candidate tie), which is exactly the acceptance gate's own wording.
- **Guard only `.destructive` tier, matching the acceptance gate's literal text.** Rejected in favor of guarding `.mutation` and above by default (configurable) — see decision 7. `referenceGuardedTierThreshold` is a `ContextConfiguration` field precisely so this can be tuned per deployment without a code change, but the safer default was chosen given the project's stated safety priority.
- **Hard-filter memory queries by scope instead of ranking by scope match.** Rejected — the acceptance criteria and `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md` both describe scope match as one ranking dimension among several, not an exclusion filter; a global fact would otherwise become invisible inside any scoped session.
- **Leave semantic retrieval unimplemented (return an empty list) since the spec calls it "optional."** Rejected — "optional" describes when the stage contributes to a bundle (only when there is a real match), not whether the mechanism exists; an empty-always implementation would be exactly the "stubbed-as-complete" pattern the phase's hard constraints forbid.

## Security and privacy impact

- The weak-evidence gate is mechanically enforced in `ReferenceResolver.resolve`, not merely documented: a guarded-tier candidate missing any of {direct evidence, non-inferred authority, in-scope, high confidence} can never reach `.resolved`, regardless of its composite rank score. Adversarial tests (`ReferenceResolverTests`) construct candidates designed to win on raw ranking (freshest, highest apparent confidence) while still failing the evidence gate, and confirm they are blocked rather than silently acted on.
- Every `reconstruct`/`resolveReference` call emits a typed, internal-sensitivity audit event (`ContextBundleAssembledEvent`, `ReferenceResolutionEvent`) on the existing `AuraEventBus`/`AuraStore.persistEvent` mechanism — no new logging channel was invented, and `ReferenceResolutionEvent.outcome == .blockedWeakEvidence` is a directly queryable, mechanically-produced record every time the safety gate actually fires.
- No new secret handling, network access, or credential surface is introduced; `ContextEngine` only reads already-persisted `ProjectLedgerEntry`/`MemoryRecord` data and plain parameters passed in by its caller.

## Operational impact

- `Sources/AuraCore/` gains `ContextTypes.swift`, `ContextRanking.swift`, `ContextEventPayloads.swift`, plus additive fields on `ActorID` (`.context`) and `AuraError` (`.contextError`), plus a new `ContextConfiguration` nested inside `AuraConfiguration` (ranking weights, budgets, semantic-match threshold, reference-resolution guard thresholds).
- While editing `AuraConfiguration.validate()` to call `context.validate()`, a pre-existing gap was found and fixed: `AuraConfiguration.validate()` never called `worktree.validate()` (added in Phase 14) even though `worktree.mergedWithDefaults()` was already wired into `mergedWithDefaults()`. This one-line fix (`try worktree.validate()`) is included in this phase's diff since it was directly adjacent to the code being changed; `WorktreeConfiguration()`'s own defaults already satisfy its `validate()`, so this cannot newly reject a previously-accepted configuration.
- A new `AuraContext` library target (depends on `AuraCore`, `AuraStore`, `AuraMemory`) and `AuraContextTests` test target were added to `Package.swift`. Neither the `AURA` executable target nor `AURAIntegrationTests` were changed — `ContextEngine` is not wired into the app composition root, matching the existing precedent for every subsystem since Phase 9 (task engine, four backend adapters, worktree manager, multi-agent orchestrator, memory engine).
- `scripts/aura-test.sh`'s default 8-bundle loop still omits `AuraPolicyTests`/`AuraTasksTests`/`AuraVSCodeTests`/`AuraMemoryTests` (a pre-existing, not-yet-fixed gap) — `AuraContextTests` joins that same explicitly-run-by-filter list rather than being added to the default loop, to avoid mixing an unrelated script fix into this feature phase.

## Migration

No breaking migration. No new database tables or schema migrations were introduced — `ContextEngine` reads existing `ledger_entries`/`memory_records` tables through `AuraStore`/`MemoryEngine`'s existing public API. Existing `AuraConfiguration` JSON files decode unchanged; a missing `context` key merges in `ContextConfiguration()`'s defaults exactly like every other nested configuration struct.

## Validation evidence

- `swift build --build-path /tmp/aurabuild-context16` (full project) — exit 0, zero non-linker warnings.
- `swift build --build-path /tmp/aurabuild-context16 --target AuraContextTests` — exit 0.
- `./scripts/aura-test.sh /tmp/aurabuild-context16` (full default 8-bundle sweep) — all pass, no regressions from the `AuraConfiguration`/`ActorID`/`AuraError` additive changes.
- `./scripts/aura-test.sh /tmp/aurabuild-context16 AuraPolicyTests` — 17/17 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-context16 AuraTasksTests` — 10/10 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-context16 AuraVSCodeTests` — 13/13 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-context16 AuraMemoryTests` — 17/17 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-context16 AuraContextTests` — 19/19 pass.
- `AuraPolicyTests`, `AuraTasksTests`, `AuraVSCodeTests`, `AuraMemoryTests`, and `AuraContextTests` each re-run 3× consecutively with no flakiness.
- Combined total across all 13 bundles: **341 tests, 0 failures** (322 pre-existing + 19 new `AuraContextTests`).
- Explicit tests exercise: mandatory-stage inclusion (utterance/conversation state/pending confirmation/pending task/active workspace) regardless of optional data; project-ledger and decision extraction from real `AuraStore` entries; recency-driven ranking under a tight budget; scope-match ranking (a scope-matching preference outranking a more recent, mismatched-scope one); semantic retrieval matching a relevant fact and correctly skipping an unrelated one; bundle truncation with accurate `consideredCandidateCount`/`droppedCandidateCount`; reference resolution for a single strong destructive candidate (resolves), a single weak-evidence destructive candidate (blocked), a weak mutation-tier candidate (blocked), an out-of-scope high-confidence destructive candidate (blocked on scope alone), two competing destructive candidates with no clear separation (ambiguous, never guessed), two "tied" strong destructive candidates under a wide separation margin (still ambiguous), a low-risk candidate with weak evidence (resolves — the gate does not over-block ordinary usage), and two adversarial-injection scenarios (a fresh, unevidenced decoy competing against a legitimate evidenced target, and the same decoy alone) that never produce a silent `.resolved` outcome.
- Secret-pattern grep (`sk-`, `AKIA`, `gh[pousr]_`, PEM private-key headers, JWT shape) across every new/modified Phase 16 file — no matches.

## Consequences

- **Positive:** AURA has a real, tested context-reconstruction engine that assembles bounded, source-traceable bundles from real ledger/memory data, and a reference resolver whose destructive/mutation-weak-evidence guard is a mechanically-enforced, adversarially-tested property rather than a documented intention — directly satisfying the Phase 16 acceptance gate ('"it" never resolves to a destructive target on weak evidence').
- **Negative:** Semantic retrieval is deterministic keyword containment, not embedding-based similarity — it will miss a relevant fact phrased with entirely different vocabulary from the utterance, and can occasionally match on a coincidental shared word. This is an honest limitation of a non-semantic check, matching `MemoryEngine`'s own contradiction-detection precedent, not a bug.
- **Risk:** `ContextEngine` is not yet wired into any real caller (conversation turn, intent engine, dialogue manager) — this phase proves the engine assembles correct, safe bundles and resolves references correctly in isolation, but no subsystem yet actually calls `reconstruct`/`resolveReference` during a live turn, and the "ask or surface a focused confirmation" half of ambiguity handling (turning `.ambiguous`/`.blockedWeakEvidence` into an actual clarifying question or confirmation challenge) is a caller responsibility not yet built. That integration is future work, most naturally landing alongside whatever phase wires `Conversation`/`PolicyEngine`/`AuraTaskEngine` into a single orchestrated turn.

## Related

- `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` (Phase 16 mission/deliverables/acceptance gate; Phase 22 forward reference)
- `prompts/implementation/16_16_CONTEXT.prompt.md`
- `docs/subsystems/22_CONTEXT_RECONSTRUCTION.md`
- `docs/decisions/ADR-016-memory-engine.md` (the module-boundary and "real but simple deterministic mechanism" precedents this phase followed)
- `Sources/AuraCore/ContextTypes.swift`
- `Sources/AuraCore/ContextRanking.swift`
- `Sources/AuraCore/ContextEventPayloads.swift`
- `Sources/AuraCore/AuraConfiguration.swift`
- `Sources/AuraContext/ContextEngine.swift`
- `Sources/AuraContext/ReferenceResolver.swift`
- `Tests/AuraContextTests/ContextEngineTests.swift`
- `Tests/AuraContextTests/ReferenceResolverTests.swift`
