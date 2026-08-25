# ADR-043 — Memory, Personalization, and Explainability Controls

- Status: Proposed
- Date: 2026-08-08
- Owners: AURA runtime completion
- Supersedes: —
- Superseded by: —

## Context

AURA already has append-only memory records, provenance graphs, bounded context
reconstruction, reference guards, correction/deletion, and retention sweeps.
R8 requires those foundations to become a user-controlled product boundary
without treating remembered text as authority, storing raw private content, or
allowing context growth to become an unbounded model prompt.

## Decision (proposed)

1. Memory writes cross an explicit `MemoryWriteRequest` boundary. The source
   classifies the write as user-stated, verified tool evidence, active task,
   approved summary, classifier-derived, inferred, or prohibited raw,
   untrusted, and model-generated content.
2. Each persisted record carries a non-authority `purpose` alongside its
   existing provenance, evidence, confidence, sensitivity, scope, retention,
   and supersession fields. SQLite migration `v1_5_0_memory_purpose` keeps old
   databases readable.
3. `UserPreferenceProfileStore` persists one bounded, supersession-linked
   profile through `AuraMemory`. It supports language, response length,
   provider accounts, coding backend/model, projects/directories, voice and
   activation preferences, local-only mode, quiet hours, enabled categories,
   and retention overrides. Machine policy bounds are evaluated before save;
   preferences cannot widen them.
4. `ContextBundle` carries purpose/requester, delivery destination, sensitivity
   and redaction state per item, token budget/estimate, exclusions, provenance
   IDs, and unresolved contradiction records. Context retrieval selects active
   beliefs by authority/confidence/freshness while leaving material conflicts
   visible.
5. Remote delivery is a separate explicit policy. The default is local-only;
   remote context is fail-closed unless the caller supplies an independently
   redacted, user-approved turn summary, and secret/sensitive content is never
   eligible for remote delivery.

## Alternatives considered

- Keep using raw `MemoryRecordDraft` as implicit authorization. Rejected because
  callers could persist model output, raw external content, or durable facts
  without stating purpose or source.
- Store preferences in an unrelated key/value table. Rejected because it would
  bypass provenance, correction, export, retention, and deletion controls.
- Let the newest conflicting record win silently. Rejected because recency is
  not authority and tied/material contradictions must remain inspectable.
- Permit remote models to receive the ordinary local context bundle. Rejected
  because a local-only preference must be enforceable at the context boundary,
  before any transport exists.

## Security and privacy impact

Raw/model/untrusted write sources and secret-like patterns are rejected by the
memory boundary. User inspection/export excludes audit/security records, while
correction uses supersession and deletion leaves only content-free audit data.
Context bundles remain bounded and expose exclusions/provenance; a remembered
statement never becomes a policy grant or confirmation. The current R8 slice
does not claim live provider transport, user-present acceptance, or release
clearance.

## Migration

Existing records receive `purpose = "unspecified"` during the additive SQLite
migration. Existing callers using the compatibility `append(draft:)` path are
classified from their typed provenance; new product callers should use
`MemoryWriteRequest` directly. No existing memory content is rewritten.

## Verification plan

- Policy tests reject raw, model-generated, untrusted, secret-like, and
  evidence-free derived writes.
- Profile tests verify persistence through a second store handle and reject a
  preference that enables remote context under local-only machine policy.
- Context tests verify authority winner selection, unresolved conflict
  surfacing, provenance inspection, deterministic bounded budgets, and remote
  fail-closed behavior.
- Full repository regression and governance validation are required before a
  delivery claim.

## Acceptance status

This ADR remains **Proposed** until the user explicitly accepts it and the live
R8 product demonstrations pass: restart preference, verified project fact,
multi-turn reference, ambiguous destructive clarification, contradiction
resolution, inspect/correct/delete/export, provenance display, and proof that
local-only mode produces no remote transmission.

## SP-019 implementation note — 2026-08-24

The bounded profile store is now wired through the production `AuraKernel`
composition, and the Privacy surface exposes the local inspection, correction,
deletion, export, conflict, retention, and preference controls described by
this ADR. The implementation is source/build/test verified under
`EV-SP-019-20260824-LOCAL-CONTROLS-01`; the live product demonstrations above
remain outstanding, so the ADR status is unchanged.
