# ADR-026: Provenance Graph Integration for the Memory Engine

- **Status:** Accepted
- **Date:** 2026-08-06
- **Owners:** GitHub Copilot
- **Supersedes:** None
- **Superseded by:** None

## Context

`AuraMemory` had an append-only `memory_records` table and a separate `memory_conflicts` table, but no first-class way to answer:

- *Where did this fact come from?*
- *What evidence supports it?*
- *What later corrected or contradicted it?*
- *Which belief should win when two records disagree?*

Phase 21 requires a provenance graph that links memory records to evidence, derivation, supersession, and conflict edges, plus a belief-revision pass that can exclude superseded facts from active context while preserving them for audit.

The graph must be deterministic, local, privacy-safe, and queryable by the context-reconstruction work in Phase 22.

## Decision

We store the provenance graph in `AuraStore` alongside memory records and expose it through a dedicated `AuraMemory` target with three internal actors:

1. `ProvenanceGraph` — append-only writer for nodes and edges.
2. `GraphQueryEngine` — deterministic BFS traversal with node-kind / edge-kind / depth filters.
3. `ContradictionDetector` — finds active records that share `(memoryClass, subject, scope)` but make different statements.
4. `BeliefRevision` — computes the active belief set from non-shadowed, non-superseded records using authority and confidence tie-breaking.
5. `MemoryEngine` — public facade coordinating the above.

### Schema

`AuraStore` persists three new tables:

- `provenance_nodes` — one row per node, with `id`, `record_id`, `kind`, `label`, `authority`, `confidence`, `actor`, `correlation_id`, `created_at`.
- `provenance_edges` — one row per directed edge, with `id`, `kind`, `source_id`, `target_id`, `actor`, `correlation_id`, `created_at`.
- `provenance_shadows` — one row per user deletion, with `record_id`, `actor`, `reason`, `correlation_id`, `created_at`, so deleted records can be excluded from active context without erasing history.

### Node and edge semantics

| `ProvenanceNodeKind` | Meaning |
| -------------------- | ------- |
| `fact` | A memory record that asserts something about the world. |
| `decision` | A subsystem choice, e.g. an intent classification. |
| `task` | A durable agent task. |
| `utterance` | A raw or normalized user utterance. |
| `file` | A file or artifact referenced as evidence. |

| `ProvenanceEdgeKind` | Meaning |
| -------------------- | ------- |
| `evidenceFor` | The source node supports the target node. |
| `derivedFrom` | The source node was derived from the target node. |
| `supersedes` | The source node intentionally replaces the target node. |
| `conflictsWith` | The source node contradicts the target node. |
| `confirms` | The source node corroborates the target node. |
| `denies` | The source node refutes the target node. |

### Authority ranking

`ProvenanceAuthority` defines a strict ranking used by belief revision:

1. `userConfirmed` (4) — user explicitly confirmed the fact.
2. `userStated` (3) — user stated the fact directly.
3. `derivedPolicy` (2) — derived from policy/system rules.
4. `derivedTool` (1) — derived from a tool or subsystem such as `IntentEngine`.
5. `inferred` (0) — inferred without direct evidence.

When two active records conflict, the higher authority wins; on a tie, higher confidence wins; on a further tie, the more recent record wins.

### Memory engine behavior changes

- `append()` now creates a provenance node for every record automatically.
- `append()` creates `evidenceFor` edges for every UUID-shaped `evidenceReferences` entry.
- `append()` with a non-nil `supersedes` field creates a `supersedes` edge and skips contradiction detection.
- `append()` without supersession runs contradiction detection; when a conflict is found it appends a `MemoryConflict` **and** a `conflictsWith` provenance edge.
- `deleteRecord()` rejects audit-class records, appends a `provenance_shadows` row, and emits a content-free audit event.
- `annotate()` returns the created `ProvenanceNode` so callers can continue graph traversal by node ID.
- `provenance(forNodeID:)` was added so callers can start a subgraph query from a decision or evidence node, not just from a record.
- `activeBeliefs()` projects the current belief set using the graph and authority/confidence tie-breaking.
- `currentState()` returns the most recent non-superseded, non-shadowed record for a `(memoryClass, subject, scope)` key, falling back to belief-revision tie-breaking on unresolved conflict.

### Intent engine wiring

`IntentEngine` now accepts an optional `MemoryEngine?` and a `sessionID`. After classifying a turn, it persists a `.workingConversation` record with provenance `.systemDerived(source: .intent)` and annotates a `.decision` provenance node. Memory persistence is best-effort: failures emit `IntentMemoryFailedEvent` but never block intent routing. This gives Phase 22 a concrete provenance trail from raw utterance → classified intent → remembered decision.

## Alternatives considered

1. **Separate graph database.** Rejected. Adding another persistence engine would increase attack surface, backup complexity, and dependency risk. SQLite already supports the relational edge-list model and is already audited for secrets and retention.
2. **Encode provenance as JSON inside `memory_records`.** Rejected. Edges are first-class query targets for context reconstruction and belief revision; normalizing them simplifies BFS, sorting, and integrity.
3. **Use an external provenance standard (W3C PROV).** Rejected for v1. The project needs a small, typed, local model first. Export to JSON-LD/PROV can be added later without changing the internal schema.
4. **Mutable provenance records.** Rejected. The graph is append-only. Corrections create new nodes and `supersedes`/`conflictsWith` edges, preserving history.

## Security and privacy impact

- Provenance labels must never include raw secrets, transcripts, screenshots, or private document content. `IntentEngine` uses the intent kind, normalized utterance, and slot names/values, but not ambient audio.
- Evidence references are stored as opaque strings. If a reference is a UUID, it is resolved to a provenance node when possible; otherwise it is stored as a string without dereferencing external content.
- User deletion appends a shadow record instead of erasing history, satisfying audit and recovery requirements.
- Audit-class records cannot be deleted through the public API.
- All graph writes happen on `AuraStore`, which already enforces local-only storage and retention rules.

## Operational impact

- Adds three SQLite tables and two new targets in the migration path. `AuraStore` opens with migrations, so existing stores will be upgraded automatically.
- Graph queries load all nodes and edges into memory before BFS. This is acceptable for v1 because the working memory set is bounded by retention enforcement. If the graph grows large, a lazy adjacency cursor can replace the in-memory map later.
- Belief revision and current-state projection now depend on provenance edges, so retention enforcement must run regularly to prevent unbounded growth.

## Migration

- Existing `memory_records` rows created before this change have no provenance nodes. They remain queryable through the legacy API but will not appear in graph-based active beliefs unless back-filled.
- No back-fill is performed automatically; new appends create nodes going forward. A future migration could synthesize `fact` nodes for legacy rows if needed.

## Validation evidence

- `./scripts/aura-test.sh /tmp/aurabuild AuraMemoryTests` — 25/25 pass.
- `./scripts/aura-test.sh /tmp/aurabuild AuraIntentTests` — 27/27 pass, including the new intent-to-memory wiring tests.
- `./scripts/aura-test.sh` (default build path, full suite) — all bundles pass; `AuraMemoryTests` and `AuraIntentTests` are now included in the default test-target build list.
- `AuraAudioTests` contains wall-clock latency tests that occasionally exceed budget under heavy parallel load; running the bundle in isolation passes consistently. This is pre-existing environmental flakiness, not a Phase 21 regression.
- The workspace-relative `build` path remains unreliable on this iCloud-synced Desktop because `com.apple.FinderInfo` / `com.apple.fileprovider.fpfs#P` extended attributes are re-applied to `.xctest` bundles during SwiftPM's codesign step. The default `/tmp/aurabuild` path is the validated, supported build path.

## Consequences

- Context reconstruction (Phase 22) can now traverse evidence chains and rank beliefs by authority.
- The policy engine can ask the memory engine why it believes something and receive a deterministic subgraph.
- User corrections and deletions leave an audit trail instead of silently rewriting history.
- The graph model is intentionally minimal; richer semantics (time intervals, weighted edges, model-version attribution) can be added later as new node/edge kinds without invalidating existing records.
- The test runner was updated to strip iCloud extended attributes after each SwiftPM build step and to include `AuraMemoryTests` and `AuraIntentTests` in the default full-suite build list.
