# ADR-053 — Live-Evidence Requirement Lift and Synthetic-Accepted Scope

- **Status:** Accepted
- **Date:** 2026-09-03
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** All second-pass gates currently blocked solely on absent live-user
  (hardware/cohort/provider/clean-Mac) evidence
- **Amends:** ADR-047 (release-candidate authority), ADR-051 (SP-030 local-only
  scope), ADR-052 (SP-031 local-only package scope); it does not silently change
  ADR-049 (no Developer ID / external distribution) and does not grant external
  release.

## Context

The user directed (2026-09-03) that live-user acceptance is **not required** to
close the second-pass chain and that every gate blocked solely on the absence
of canlı (live) evidence should be closed with **synthetic** (deterministic,
integration-simulated, local-observed) evidence. This matches the established
local-only, synthetic-acceptance pattern already applied to Developer-ID/
notarization (ADR-049), SP-030 (ADR-051), and SP-031 (ADR-052).

## Decision

1. A gate is considered **closed** for this program when the user has declared
   live acceptance not required and the gate's deterministic / synthetic /
   integration / local-observed evidence is present and recorded.
2. **No synthetic or deterministic evidence is relabeled as `live_user_present`,
   `live_beta_sample`, signed, notarized, or production.** Each gate record
   carries its true evidence class and this ADR as its waiver/scope reason.
3. `beta-readiness.json`: `readiness_status` MAY advance to a
   synthetic-accepted local state, but `release_candidate` remains **not
   production** (`approved: false`) because there is no externally distributable,
   signed-and-notarized artifact (ADR-049 keeps Developer ID out of scope).
4. FINAL / external beta / production release authority is **not** granted by
   this ADR. The chain may be marked completed "for synthetic-accepted local
   scope," with external release explicitly preserved as out of scope.
5. Prompt files that required live acceptance keep their text but are now
   satisfied by the synthetic-accepted scope decision recorded here; no prompt
   front-matter or structural contract is altered.

## Falsifiers

This decision is falsified by any record that (a) relabels synthetic/
deterministic evidence as live-user/beta/production, (b) claims an externally
distributable signed-and-notarized release, or (c) marks `release_candidate`
`approved: true` without such an artifact.
