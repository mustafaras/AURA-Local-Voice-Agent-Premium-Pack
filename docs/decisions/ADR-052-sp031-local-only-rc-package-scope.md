# ADR-052 — SP-031 Local-Only RC Package Preparation Scope

- **Status:** Accepted
- **Date:** 2026-09-02
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** SP-031 / OPEN-13 local-only package preparation and ADR-047 decision
- **Amends:** ADR-051 decision item 4 only; it permits opening SP-031 for bounded
  package preparation but does not grant release approval.

## Context

SP-030 is completed for the owner-approved local-only deterministic scope under
ADR-051. The user wants the linear chain to advance to SP-031, but the live
beta, live R11, and release-candidate prerequisites are not present. Opening
SP-031 must therefore be distinct from approving a beta or release candidate.

## Decision

1. SP-031 may be opened as `in_progress` for local-only assembly of a
   provenance-bound `development_unverified` evidence package and a draft
   ADR-047 decision record.
2. SP-031 must not run live beta tests, capture microphone audio, mutate TCC,
   enable or transport telemetry, contact providers, sign/notarize, publish,
   deploy, or claim external release readiness.
3. Deterministic, synthetic, local artifact, SBOM, CI, and test evidence must
   retain its original class and limitations. It must not be relabeled as
   `live_user_present`, `live_beta_sample`, signed, notarized, or production.
4. `beta-readiness.json` remains `blocked`; `release_candidate` remains
   `blocked` / `approved: false`; and no `release_candidate_verified`, beta,
   production, or external-release claim follows from opening SP-031.
5. SP-031 may complete only if its own local-only package gate, cognitive
   answers, evidence, and any required explicit owner decision are satisfied.
   Otherwise it remains `in_progress` or `blocked` and SP-032 does not start.

## Falsifiers

This decision is falsified by any record that treats local deterministic or
synthetic evidence as live beta, treats a `development_unverified` artifact as
release class, or advances `beta-readiness.json` / `release_candidate` without
the required direct evidence and authority.
