# EV-SP-031-20260902-OPENED-LOCAL-ONLY-01

**Evidence ID:** `EV-SP-031-20260902-OPENED-LOCAL-ONLY-01`
**Track:** SP-031 / OPEN-13 — local-only RC package preparation opened
**Session:** `AURA-SP-031-LOCAL-ONLY-OPEN-20260902`
**Timestamp:** 2026-09-02
**Evidence class:** process/scope transition; not RC approval or release evidence
**Verified repository:** `main`, `HEAD == origin/main == bee334782262089fa117124ababa9b3c6dfed394`; worktree `dirty_expected` from this transition

## Transition

SP-030 is present in `completed_prompts` for its owner-approved local-only
deterministic scope under ADR-051. The linear chain is advanced to SP-031
`in_progress` under ADR-052 so the local-only `development_unverified` package
and ADR-047 decision record can be assembled.

This is an opening record, not a completion record. It does not assert a
reproducible/recoverable RC package, `release_candidate_verified`, beta
readiness, production readiness, or external release.

## Scope and boundaries

The in-scope work is limited to binding the existing local artifact, hashes,
SBOM/manifests, deterministic test and CI evidence, known limitations, rollback
plan, and a draft/local-only ADR-047 decision. Live beta sessions, microphone
capture, live SLO collection, live R11 recovery, incident review, telemetry
transport, signing/notarization, publication, and deployment are out of scope.

## Current state

`beta-readiness.json` remains `blocked`; R11 remains `in_progress` with
`development_unverified`; `release_candidate` remains `blocked` with
`approved: false` and no artifact; SP-032 must not start until SP-031's own
package gate is actually satisfied.

## Falsifier

This record is falsified if SP-031 is represented as completed or release
approved without the package evidence, explicit decision, and limitations
required by its prompt.
