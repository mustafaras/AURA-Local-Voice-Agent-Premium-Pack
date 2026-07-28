> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Context Reconstruction

## Goal
Rebuild the smallest sufficient context for the current request without flooding the model or relying on stale summaries.

## Retrieval sequence
1. Current utterance and stable transcript.
2. Active conversation state.
3. Pending confirmation or task.
4. Active application/workspace.
5. Relevant project ledger entries.
6. Recent evidence-backed decisions.
7. User-approved preferences.
8. Optional semantic retrieval.

## Ranking
Prioritize scope match, recency, authority, confidence, and direct evidence.

## Guardrails
- Never resolve “it” to a destructive target on weak evidence.
- Ask or surface a focused confirmation when multiple targets remain plausible.
- Include source IDs in internal context bundles.

## Phase 22 pipeline

`ContextBuilder` composes the Phase 16 `ContextEngine` in this fixed,
inspectable order:

1. Parse and normalize the utterance; identify supported implicit-reference
   phrases (`it`, `that`, `the file`, `the document`, `the app`, `the last
   one`).
2. Accept the already-typed intent as a dependency-neutral
   `ContextIntentSchema`.
3. Extract typed entities from active workspace state, reference candidates,
   and provenance nodes.
4. Evaluate project/task/session scope. Out-of-scope action candidates remain
   visible to the resolver only so it can reject them explicitly.
5. Rank evidence by scope, recency, authority, confidence, direct evidence,
   lexical entity kind, and conversational salience.
6. Surface `.ambiguous`, `.blockedWeakEvidence`, `.resolved`, or `.none`.
7. Assemble the smallest sufficient bundle within the configured graph,
   item, and token budgets.

## Reference-resolution graph

Every reference candidate carries a stable ID, source ID, entity kind,
capability, authority, confidence, timestamp, direct-evidence flag, scope
match, conversational salience, and provenance node IDs. Salience and lexical
matches affect rank only. For mutation/destructive capabilities, resolution
still requires direct evidence, non-inferred authority, scope match, and the
configured minimum confidence. An explicit confirmation is accepted only for
the exact candidate UUID and never substitutes for policy authorization.

## Cross-session memory and provenance

The builder obtains project facts, user-approved preferences, task state, and
procedural knowledge through `MemoryEngine`. For every included memory record,
it follows the local provenance graph up to `maxGraphDepth`, admits at most
`maxGraphItems`, and can therefore reconstruct relationships such as file →
task → decision → preference. Embedding retrieval is not part of Phase 22;
semantic retrieval remains deterministic keyword containment.

## Budgets and explainability

- `maxTokenBudget` is a hard, deterministic local estimate over final item
  summaries. Mandatory live context is never silently removed; an impossible
  budget fails closed.
- Each item exposes its source ID, provenance node IDs, confidence, composite
  score, estimated token cost, and inclusion reason.
- `DeepContextResult.trace` exposes every pipeline stage and its input/output
  counts.
- `ContextInclusionOverride` lets a caller exclude optional sources or request
  scoped current-memory inclusions for one turn. Overrides do not persist and
  do not alter permissions.
- `DeepContextBuiltEvent` records token and elapsed-time evidence for each
  build. Meeting the deterministic fixture budget is not evidence for
  unbounded graph sizes.

## Live integration

`AuraKernel` constructs `ContextBuilder` and injects it into `IntentEngine`.
Every completed turn performs a best-effort context build before intent memory
persistence and routing. `IntentEngine.inspectLastContext()` exposes the most
recent result. A context failure emits `DeepContextBuildFailedEvent` but does
not block classification; the permission and tool-routing layers remain the
only action authorities.
