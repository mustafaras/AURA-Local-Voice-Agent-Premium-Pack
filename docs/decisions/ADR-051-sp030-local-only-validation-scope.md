# ADR-051 — SP-030 Local-Only Validation Scope

- **Status:** Accepted
- **Date:** 2026-09-02
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** SP-030 / OPEN-13 local-only validation and downstream readiness
- **Supersedes:** SP-030's live-beta-only completion interpretation for this local-only scope

## Context

The current SP-030 prompt requires live-beta SLO samples, a live scenario
window, live R11 transitions, and an incident review. The release owner has
explicitly decided that no live test will be performed. AURA is already
permanently local-only under ADR-049, and its telemetry transport remains
disabled.

Treating deterministic tests as live evidence would be false. Leaving the
local-only validation work without a bounded disposition would also leave the
prompt needlessly ambiguous. A scope decision is therefore required.

## Decision

1. SP-030 is completed only for the **local-only deterministic validation
   scope**: existing lifecycle, integration, STT, safety, and state-contract
   checks; evidence classification; and the explicit non-live limitation.
2. Live user-present beta sessions, microphone/STT quality, live latency
   samples, live R11 sleep/wake/crash recovery, live scenario execution, and
   incident review are **deferred and excluded from this scope**. They remain
   open readiness limitations and are not marked passed, waived, or measured.
3. `beta-readiness.json` remains `blocked`, telemetry remains disabled with
   `transport: none`, and no release-candidate or external-beta claim follows
   from this decision.
4. SP-031 may not execute or approve an RC from this decision. It remains
   blocked downstream because the live-beta/R11 prerequisites and RC authority
   are absent.
5. Any future live beta or external-release objective requires a new explicit
   scope decision and a new evidence pass; this ADR must not be used to
   relabel synthetic or deterministic evidence as live.

## Local-only acceptance evidence

- `EV-SP-030-20260902-UNATTENDED-ALTERNATE-01`: lifecycle 48/10/0,
  integration 111/22/0, STT 19/4/0; synthetic Speech failed closed at missing
  authorization without TCC mutation.
- `EV-SP-030-20260902-LOCAL-ONLY-SCOPE-01`: scope decision, limitations,
  validator results, and downstream blocked disposition.

## Consequences

- The prompt chain can record SP-030 as **completed for the declared
  local-only scope** without claiming beta readiness.
- OPEN-13 remains open for the deliberately excluded live-beta/R11/incident
  evidence, and the overall R12 program remains blocked.
- This is a product-scope decision, not a scientific claim that latency,
  speech quality, recovery, or incident behavior passed in production.

## Falsifiers

This ADR would be falsified by any record claiming that deterministic or
synthetic evidence is a live-beta sample, that `beta-readiness.json` is
release-ready, that live R11 or incident gates ran, or that SP-031 was
approved from this local-only decision.
