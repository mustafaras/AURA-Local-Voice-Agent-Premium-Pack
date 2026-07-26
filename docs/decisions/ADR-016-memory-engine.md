# ADR-016 — Memory Engine

- Status: Accepted
- Date: 2026-07-26
- Owners: Claude Sonnet 5 (Claude Code)
- Supersedes: —
- Superseded by: —

## Context

Phase 15 of the AURA implementation roadmap requires the basic Memory Engine: the record schema, an append-only writer, current-state projection, contradiction records, retention enforcement, and user inspection/export/correction/deletion of non-audit memory — per `docs/subsystems/21_MEMORY_ENGINE.md`. Phase 21 ("Advanced Memory Engine and Provenance Graph") later evolves this into a queryable, evidence-linked provenance graph with belief revision; this phase deliberately stays within the simpler, mechanically-verifiable scope the master prompt actually asks for here.

Before this phase, AURA had no memory subsystem at all — only `ProjectLedgerEntry`/`LedgerBackend` (a *human-authored* project-history ledger, unrelated to what a memory engine tracks about the user/project/conversation) and `AuraTaskEngine`'s per-task key-value snapshots (single-current-value-per-key, not an append-only multi-record log).

## Decision

1. **A new `AuraMemory` module, not code stuffed into `AuraStore`.** `PolicyEngine`/`AuraPolicy` and `AuraTaskEngine`/`AuraTasks` both already establish the pattern of "domain logic (rules, contradiction handling, lifecycle) lives in its own module; `AuraStore` only persists." `MemoryEngine`'s rules (evidence requirements, contradiction detection, retention enforcement, audit-class access control) are substantial enough domain logic to warrant the same separation — and creating `AuraMemory` now, rather than waiting for Phase 21's "`AuraMemory` target with graph store" line item, means Phase 21 *extends* this module instead of creating it from a standing start.

2. **`memory_records`/`memory_conflicts` are real SQL tables in `AuraDatabase`, not key-value blobs.** `AuraTaskEngine`'s `TaskStoreBackend` persists task snapshots as JSON blobs under single keys — appropriate for "one current value per task ID," and its own code comments acknowledge the resulting limitation ("AuraStore key-value does not support listing by prefix"). Memory records are structurally different: unbounded, ever-growing, and need real `WHERE`-clause queryability (by class, subject, scope, time) for contradiction detection, retention sweeps, and export. This matches `ledger_entries`' existing precedent (a first-class table with `append`/query methods directly on `AuraStore`) far better than `TaskStoreBackend`'s workaround.

3. **`supersedes` is the only stored pointer; "superseded-by" is always derived.** The schema in `docs/subsystems/21_MEMORY_ENGINE.md` lists "supersedes/superseded-by" as if both are stored fields, but storing a reverse pointer would require mutating an *older* record after a newer one is appended — a real violation of append-only immutability, not a cosmetic one. `MemoryRecord` therefore has only a forward `supersedes: UUID?`; `MemoryEngine.supersedingRecord(of:)` computes the reverse relationship at query time by searching for any record whose `supersedes` equals the given ID.

4. **Contradiction detection is a mechanical equality check, not semantic/NLP inference.** Appending a record with `supersedes == nil` triggers a search for any other *active* (non-superseded) record sharing the same `(memoryClass, subject, scope)` key with a *different* `statement`. If found, a `MemoryConflict` is appended alongside the new record — the existing record is never touched or removed. Passing an explicit `supersedes` (an intentional correction) skips this check entirely, since the caller has already declared awareness of replacing prior information. This is honestly scoped: real belief-revision/canonicalization (Phase 21's job) would need actual semantic comparison; a same-key-different-text equality check is exactly the amount of "contradiction detection" a basic engine can implement without fabricating NLP capability that doesn't exist here.

5. **Current-state projection is computed on read, never materialized on write.** Unlike the human-authored `ledger/CURRENT_STATE.md` (which must be an explicit, atomic rewrite because Markdown isn't queryable), `MemoryEngine.currentState(...)` runs a live query over the append-only table and picks, per `(memoryClass, subject, scope)` key, the most-recently-created active record. This can never drift out of sync with the underlying log, at the cost of being a query rather than an O(1) lookup — an acceptable trade-off at this phase's scale. When a genuine unresolved conflict leaves two active records for the same key, the more recent one wins the *projection* for display purposes, but the `MemoryConflict` itself remains permanently queryable — the disagreement is resolved for display, never silently discarded from the record.

6. **"Facts require evidence. Inference is labeled." is enforced mechanically at append time, not just documented.** Any `MemoryRecordDraft` whose `provenance` is not `.inferred` must supply at least one `evidenceReferences` entry, or `MemoryEngine.append` throws. `.inferred(basis:)` is the one provenance case exempt from this — its very shape *is* the required label, so an inference can never be silently indistinguishable from an observed or user-stated fact.

7. **"Sensitive personal facts are not retained without explicit purpose and consent" is enforced mechanically for the transient memory classes.** `.secret`-sensitivity records in `.ephemeralAudio`/`.workingConversation`/`.sessionSummary` classes are rejected outright if they request `.indefinite` or `.auditRetention` retention — a secret, transient fact cannot accidentally become permanent. `.projectFact`/`.userPreference`/`.proceduralKnowledge` (classes that are inherently meant to persist once the user has approved them) are not constrained this way, since indefinite retention is their whole purpose.

8. **Deletion actually removes content; its own audit trail does not resurrect it.** `MemoryEngine.deleteRecord` issues a real `DELETE` against `memory_records` (via `AuraStore.deleteMemoryRecord`) — not a soft-delete/tombstone flag, which would defeat the purpose of a user-requested deletion. The accompanying `MemoryDeletedEvent` carries only `recordID`/`memoryClass`/`reason`/timestamp — deliberately no `subject`/`statement` — so "corrections/deletions preserve provenance" (there is proof deletion happened, when, and why) without contradicting the deletion itself (the content is genuinely gone, not merely relocated into an audit log).

9. **Audit/security-class records (`.auditSecurity`) are excluded from every user-facing operation** (`inspect`, `export`, `correct`, `deleteRecord` all throw or filter them out), matching "the user can inspect, correct, export, and delete **non-audit** memory" precisely. They are not permanently un-removable, however: `enforceRetention` still purges them once their `.auditRetention(days:)` window elapses — the constraint is specifically that a user cannot delete them *on demand*, not that they live forever.

10. **A `MemoryConflict`'s `resolution` field is the one piece of genuinely mutable state in this phase**, updated in place via `AuraStore.setMemoryConflictResolution` rather than re-appended. This is a deliberate, narrow exception: a conflict record represents operational triage status ("has a human looked at this disagreement yet, and what did they decide"), not a memory statement whose own history must be preserved verbatim — the two memory records the conflict references remain fully immutable regardless of how the conflict itself is later resolved.

## Alternatives considered

- **Store `supersededBy` as a mutable field on `MemoryRecord`.** Rejected — would require mutating an already-appended, supposedly-immutable record, contradicting the entire append-only design. The derived, query-time relationship (`supersedingRecord(of:)`) achieves the same lookup without that mutation.
- **Persist memory as JSON blobs under `AuraStore`'s existing `key_value_store`, mirroring `TaskStoreBackend`.** Rejected — that pattern exists specifically for single-current-value-per-key state; memory needs real multi-dimensional queryability (class, subject, scope, time) that a blob-per-key model cannot provide without reinventing indexing by hand.
- **Attempt semantic contradiction detection (e.g. comparing statement meaning, not just text equality).** Rejected as out of scope and likely to fabricate a capability that doesn't genuinely exist yet — Phase 21's belief-revision work is where that would need to be built for real, with real evaluation.
- **Soft-delete (tombstone flag) instead of a real `DELETE`.** Rejected — a user asking to delete sensitive memory and having it merely flagged-but-retained would not honor "the user can ... delete non-audit memory" in any meaningful sense.
- **Let `deleteRecord`/`correct` operate on audit-class records with sufficient authorization.** Rejected for this phase — no such privileged-access path exists yet, and building one prematurely risked a half-specified permission model; audit immutability from the user-facing API is the safe default.

## Security and privacy impact

- `.secret`-sensitivity transient records cannot be given indefinite/audit retention — enforced at append time, not merely documented policy.
- Deletion is real removal from the SQL table; the accompanying audit event carries no content that would defeat the deletion's purpose.
- Audit/security memory is unreachable through every user-facing verb (`inspect`/`export`/`correct`/`deleteRecord`), preventing both accidental exposure and tampering with the audit trail via the memory API surface.
- Every mutation (append, conflict detected/resolved, correction, deletion, retention purge) emits a typed event on the existing `AuraEventBus`/`AuraStore.persistEvent` audit mechanism — no new, separate logging channel was invented.

## Operational impact

- `Sources/AuraCore/` gains `MemoryTypes.swift` and `MemoryEventPayloads.swift`, plus additive fields on `ActorID` (`.memory`) and `AuraError` (`.memoryError`).
- `Sources/AuraStore/` gains two new tables (`memory_records`, `memory_conflicts`, migration `v1_2_0_memory_records`) and typed CRUD methods on `AuraStore` — `ledger_entries`/`events`/`key_value_store` and their existing methods are untouched.
- A new `AuraMemory` library target (depends on `AuraCore`, `AuraStore`) and `AuraMemoryTests` test target were added to `Package.swift`. Neither the `AURA` executable target nor `AURAIntegrationTests` were changed — `MemoryEngine` is not wired into the app composition root, matching the existing precedent that none of the Phase 9–14 subsystems (task engine, four backend adapters, worktree manager, multi-agent orchestrator) are wired in yet either.
- `scripts/aura-test.sh`'s default 8-bundle loop still omits `AuraPolicyTests`/`AuraTasksTests`/`AuraVSCodeTests` (a pre-existing, not-yet-fixed gap) — `AuraMemoryTests` joins that same explicitly-run-by-filter list rather than being added to the default loop, to avoid mixing an unrelated script fix into this feature phase.

## Migration

No breaking migration. The two new tables are created with `CREATE TABLE IF NOT EXISTS` and a new, additive `schema_migrations` row (`v1_2_0_memory_records`); existing databases upgrade transparently on next `AuraDatabase.migrate()` call, matching the `v1_1_0_key_value_store` precedent.

## Validation evidence

- `swift build --build-path /tmp/aurabuild-final15` (full project) — exit 0, zero non-linker warnings.
- `./scripts/aura-test.sh /tmp/aurabuild-final15` (full default 8-bundle sweep) — 265/265 tests pass (`AURAIntegrationTests`, `AuraAgentTests`, `AuraAudioTests`, `AuraAutomationTests`, `AuraCoreTests`, `AuraSTTTests`, `AuraShellTests`, `AuraStoreTests` — the latter now includes 4 new memory-persistence round-trip tests).
- `./scripts/aura-test.sh /tmp/aurabuild-final15 AuraPolicyTests` — 17/17 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-final15 AuraTasksTests` — 10/10 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-final15 AuraVSCodeTests` — 13/13 pass.
- `./scripts/aura-test.sh /tmp/aurabuild-final15 AuraMemoryTests` — 17/17 pass, run 3× consecutively with no flakiness.
- Combined total across all 12 bundles: **322 tests, 0 failures** (301 pre-existing + 21 new: 17 `AuraMemoryTests` + 4 new `AuraStoreTests` memory round-trip tests).
- Explicit tests exercise: fact-with-evidence acceptance, fact-without-evidence rejection, inference-without-evidence acceptance, secret-transient-with-indefinite-retention rejection, contradiction detection + conflict record creation, supersession skipping conflict detection, conflict resolution persistence, current-state projection (supersession chains and unresolved-conflict most-recent-wins), derived `supersedingRecord` lookup, correction (append-only, original untouched, event emitted), correction/deletion rejection for audit-class records, real deletion with content-free audit event, retention purge for ephemeral/session-scoped/audit-class records with an indefinite control record surviving, and inspection/export excluding audit memory.
- Secret-pattern grep (`sk-`, `AKIA`, `gh[pousr]_`, PEM private-key headers, JWT shape) across every new/modified Phase 15 file — no matches.

## Consequences

- **Positive:** AURA has a real, tested, append-only memory subsystem with mechanically-enforced evidence/inference labeling, contradiction recording that never silently overwrites, retention enforcement (including a genuine "secret + transient can't be indefinite" guard), and a real, provenance-preserving deletion path for non-audit memory — laying direct groundwork for Phase 21's provenance graph to extend rather than replace.
- **Negative:** Contradiction detection is same-key-exact-text-inequality only — it will flag two differently-worded but compatible statements as a conflict, and will not flag two identically-scoped-but-differently-keyed statements that actually do contradict each other (e.g. a bad `subject` choice upstream). This is an honest limitation of a non-semantic check, not a bug.
- **Risk:** `MemoryEngine` is not yet wired into any real caller (conversation engine, intent engine, task engine) — this phase proves the engine works correctly in isolation, but no subsystem yet actually writes real project facts/preferences/conversation summaries into it. That integration is future work.

## Related

- `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` (Phase 15 mission/deliverables/acceptance gate; Phase 21 forward reference)
- `docs/subsystems/21_MEMORY_ENGINE.md`
- `docs/decisions/ADR-010-durable-task-engine.md` (the `TaskStoreBackend` key-value precedent this phase deliberately did not follow)
- `docs/decisions/ADR-006-policy-engine-architecture.md` (the module-boundary precedent this phase did follow)
- `Sources/AuraCore/MemoryTypes.swift`
- `Sources/AuraCore/MemoryEventPayloads.swift`
- `Sources/AuraStore/AuraDatabase.swift`
- `Sources/AuraStore/AuraStore.swift`
- `Sources/AuraMemory/MemoryEngine.swift`
- `Tests/AuraStoreTests/AuraStoreTests.swift`
- `Tests/AuraMemoryTests/MemoryEngineTests.swift`
