# ADR-047 — Beta Evidence, SLOs, Release-Candidate Authority, and Final Completion Declaration

- **Status:** Accepted (local-only scope)
- **Date:** 2026-09-02
- **Owners:** AURA Runtime Completion Program / release owner
- **Scope:** R12 / OPEN-13; local-only package evidence and any future beta or
  release-candidate decision
- **Depends on:** ADR-045, ADR-046, ADR-049, ADR-050, ADR-051, ADR-052

## Context

R12 requires objective SLO and scenario evidence, incident review, preserved
evidence classes, independent review, rollback/kill-switch readiness, and an
explicit release-owner decision. Earlier local records correctly kept the
artifact `development_unverified` and `beta-readiness.json` blocked. ADR-051
and ADR-052 allow a bounded local-only package preparation attempt; they do not
turn deterministic evidence into live beta evidence or grant release approval.

SP-031 has now assembled a reproducible unsigned local package from the clean
source commit `bee334782262089fa117124ababa9b3c6dfed394`. The package evidence
is recorded at `EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01`. The package is useful
for local review. The owner has now independently reviewed the declared scope,
approved the exact package for local-only use, and accepted this ADR only for
that scope; the record is `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`.

## Decision (accepted — local-only scope)

1. A local package may be labelled only `development_unverified` unless a
   separately authorized decision and direct evidence satisfy the applicable
   beta or release-candidate gate. A local package is never silently promoted
   to `release_candidate`, beta, production, signed, or notarized status.
2. The minimum provenance bundle for a local-only package is the exact clean
   source commit, artifact and manifest hashes, bundle metadata, SBOM/dependency
   and model/toolchain manifests or explicit absence, deterministic CI/test/
   coverage/adversarial evidence, SLO/scenario/incident limitations, scope
   exclusions, rollback/kill-switch procedure, and named evidence classes.
3. Every measurement retains its class and provenance. `deterministic_harness`
   and `synthetic_speech` results cannot satisfy a `live_user_present` or
   `live_beta_sample` gate. Missing samples, incidents, or permissions remain
   missing rather than being filled by a model assertion, fake, historical
   ledger line, or local contract.
4. Package reproducibility is necessary but not sufficient. Completion of the
   local-only SP-031 package requires an independent review of the declared
   scope, an explicit owner decision approving local-only use, and an accepted
   ADR-047 record. Opening SP-031 or saying “approve everything” in a prior
   scope record is not by itself that package decision.
5. Until those gates are directly evidenced, `beta-readiness.json` remains
   `blocked`, `telemetry.enabled` remains `false`, and
   `release_candidate.status` remains `blocked` with `approved: false`.
6. External distribution, Developer ID signing, notarization, public release,
   and deployment remain outside this ADR's local-only preparation scope under
   ADR-049. A future external decision must identify its own authority and
   direct evidence.

## Alternatives considered

- **Promote the reproducible ZIP to release-candidate status:** rejected;
  `development_unverified` is a deliberate safety label and the package lacks
  independent approval, live gates, and external release evidence.
- **Treat deterministic or synthetic results as beta measurements:** rejected;
  that would erase evidence-class limitations and create a false-success path.
- **Wait for a live beta before recording any package preparation:** useful for
  the broader R12 gate but not required for this bounded local-only attempt;
  live beta remains separately deferred and must not be manufactured here.

## Consequences

Positive consequences are reproducible local review, explicit provenance,
fail-closed status projections, and a durable owner decision point. Negative
consequences are that the package cannot be used as an external release and
does not close R11/R12. The missing external model manifest excludes the
neural voice capability from qualified package scope until its provenance is
provided. The live SLO, scenario, incident, and recovery limitations remain
visible and require a separately authorized evidence pass.

## Current verification and disposition

`EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01` records two identical local archive
productions from the clean source commit, artifact SHA-256
`d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837`, manifest
SHA-256 `4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5`,
and deterministic coverage of 70.20% across 1325 tests / 87 suites / 22
bundles with zero failures. The package is unsigned and unnotarized. These
facts support local review only. The separate owner review and decision are
recorded at `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`; together they
satisfy the SP-031 local-only approval postcondition, not any beta or release
gate.

## Falsifiers

This proposal is falsified by any unexplained artifact/provenance mismatch,
failed reproducibility or validator result, an unqualified model/dependency
input, or a state/ledger record that promotes local evidence to beta,
production, signed, notarized, or release-approved status.

## Acceptance record

The release owner explicitly approved the exact artifact SHA-256
`d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837` and
manifest SHA-256
`4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5` for
local `development_unverified` use only, accepted the listed limitations, and
accepted ADR-047 only for that scope. The decision expressly excludes beta,
production, `release_candidate`, signing, notarization, and external release.
It cannot set `release_candidate` to approved.

The review instrument for that decision is
`docs/operations/SP-031_LOCAL_ONLY_PACKAGE_REVIEW_PACKET.md`; its preparation
is recorded by `EV-SP-031-20260902-REVIEW-PACKET-01`. The recorded review and
decision are `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`.
