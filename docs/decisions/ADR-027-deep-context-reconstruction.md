# ADR-027 — Deep Context Reconstruction and Reference Resolution

- Status: Accepted
- Date: 2026-07-28
- Owners: Codex
- Supersedes: —
- Superseded by: —

## Context

Phase 16 introduced a deliberately small `ContextEngine`: mandatory live-state inclusion, deterministic optional retrieval, composite evidence ranking, and a flat `ReferenceResolver`. ADR-017 explicitly deferred multi-hop graph traversal, cross-session injection, token budgeting, inspection/override, and live conversation integration to Phase 22.

Phase 21 then added an append-only provenance graph and `MemoryEngine.provenance(...)`. `IntentEngine` wrote classified turns to memory but still did not read reconstructed context during a live turn. The remaining gap was not another memory store; it was a bounded consumer that composes the existing context and provenance APIs without gaining policy authority.

## Decision

1. **Compose Phase 16 through a new `ContextBuilder` actor.** `ContextBuilder` owns the Phase 22 pipeline and calls `ContextEngine.reconstruct` rather than duplicating its retrieval order. The observable trace is fixed: utterance parse → intent schema → entity extraction → scope filter → evidence rank → ambiguity check → final bundle.

2. **Keep the context/intent dependency direction acyclic.** `ContextIntentSchema` is defined in `AuraCore`. `AuraIntent.TypedIntent` maps into that neutral schema, so `AuraContext` never imports `AuraIntent`.

3. **Use an inspectable reference graph, not an opaque score.** `ReferenceResolutionGraph` records each candidate, evidence score, lexical-kind match, conversational salience, and exact confirmation binding. Candidate order uses scope, recency, authority, confidence, direct evidence, lexical kind, and conversational salience. Lexical phrases such as “the file” narrow ambiguity checks to matching entity kinds when matches exist.

4. **Salience cannot authorize mutation.** For the configured guarded tier (mutation by default) and above, a candidate still requires direct evidence, non-inferred authority, scope match, and minimum confidence. Salience and lexical boosts only rank candidates. An explicit confirmation bypass is accepted only when bound to the exact candidate UUID; it does not grant policy permission or confirm neighboring candidates.

5. **Expand only from persisted provenance, with hard bounds.** Every included memory record is queried through `MemoryEngine.provenance` using `maxGraphDepth`. Graph-derived items are capped by `maxGraphItems`, scored, and expose their provenance node UUIDs. This enables deterministic file → task → decision → preference reconstruction without embedding search or another database.

6. **Enforce a conservative local token estimate.** `maxTokenBudget` is a hard ceiling over final item summaries using a deterministic UTF-8 estimate. Mandatory live context is never silently removed; if it alone exceeds the budget, the build fails closed with `AuraError.contextError`. Optional items are admitted by explicit inclusion first and evidence rank second.

7. **Overrides are turn-local and non-persistent.** `ContextInclusionOverride` can exclude optional source IDs or request inclusion of current memory record IDs. Explicit inclusion remains subject to existence, scope, and token budgets. Overrides never mutate memory, provenance, permissions, or the human ledger.

8. **Make `IntentEngine` the live caller, best-effort.** `AuraKernel` constructs one `ContextBuilder` and injects it into `IntentEngine`. Every completed turn builds context before intent memory persistence/routing. `inspectLastContext()` exposes the last result. Retrieval failure emits `DeepContextBuildFailedEvent` and does not make classification unavailable.

9. **Measure without overclaiming.** `DeepContextBuiltEvent` records elapsed time, configured latency budget, token count, and whether the individual invocation met its budget. Tests prove the small deterministic fixture is below the configured budget; this is not a large-store performance claim.

## Alternatives considered

- **Replace `ContextEngine`.** Rejected because it would duplicate tested Phase 16 retrieval and break source compatibility.
- **Have `AuraContext` import `AuraIntent`.** Rejected because it creates a sibling dependency cycle and couples context storage to one classifier vocabulary.
- **Let salience resolve a destructive target.** Rejected because recent hostile or accidental mentions could outrank direct evidence.
- **Silently truncate the current utterance.** Rejected because the model would receive a misleading request. The builder fails closed when mandatory content cannot fit.
- **Embedding retrieval or a remote tokenizer.** Rejected as out of Phase 22 scope and unnecessary for deterministic acceptance tests.
- **Persist inclusion overrides.** Rejected because an inspection choice for one turn must not silently become a durable preference or permission.

## Security and privacy impact

- No remote service, network entitlement, ambient audio, screenshot, secret, or raw private document transmission is added.
- Context remains local in the existing store and process.
- Context reconstruction has no capability-grant API and cannot bypass `PolicyEngine` or `ToolRouter`.
- Weak, inferred, out-of-scope, or ambiguous guarded targets do not auto-resolve.
- Events record counts, timing, IDs, and failure descriptions; they do not add raw ambient inputs.

## Compatibility and migration

- Existing `ContextEngine.reconstruct` and `resolveReference` call sites remain valid.
- New configuration fields decode with defaults, preserving partial configuration compatibility.
- Existing memory rows without provenance remain retrievable as Phase 16 memory items but cannot produce graph-expanded lineage until back-filled.
- No database migration is required.

## Validation

- `swift format lint` on the new/modified Phase 22 Swift files: no Phase 22 diagnostics (pre-existing long-line diagnostics in unrelated `AuraConfiguration` sections remain unchanged).
- `swift build --target AURA --build-path /tmp/aurabuild-phase22`: pass.
- `./scripts/aura-test.sh /tmp/aurabuild-phase22-context2 AuraContextTests`: 28/28 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-phase22-intent AuraIntentTests`: 29/29 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-phase22-integration AURAIntegrationTests`: 7/7 pass.
- Full-suite evidence is recorded in the Phase 22 completion ledger entry.

## Consequences

- AURA has one deterministic, explainable context path from a live turn through cross-session memory and multi-hop provenance.
- Callers can inspect why every item was included and can apply bounded per-turn overrides.
- Reference resolution is safer but intentionally conservative; real confirmation UI and richer action vocabulary remain separate work.
- Graph traversal still materializes retained graph data in memory; large-store profiling and lazy adjacency queries remain future optimization work.
