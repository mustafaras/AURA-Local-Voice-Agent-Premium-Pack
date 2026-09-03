# SP-031 Local-Only Package Review Packet

- **Status:** Owner-reviewed; approved only for local `development_unverified` use
- **Prompt / gap:** SP-031 / OPEN-13 / R12
- **Prepared:** 2026-09-02
- **Decision record:** `docs/decisions/ADR-047-beta-slos-release-authority.md`
- **Decision evidence:** `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`
- **Package evidence:** `EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01`
- **Closeout evidence:** `EV-SP-031-20260902-CLOSEOUT-LOCAL-ONLY-PACKAGE-01`

## Review scope

This packet asks whether the exact package below may be used **only as a local
`development_unverified` artifact**. It is not a beta, production,
`release_candidate`, signed, notarized, or external-release approval.

| Check | Expected fact |
|---|---|
| Source commit | `bee334782262089fa117124ababa9b3c6dfed394`; detached build worktree clean |
| Artifact | `/tmp/aura-sp031-local-rc-20260902/output/AURA-development-unverified.zip` |
| Artifact SHA-256 | `d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837` |
| Artifact size | `58420226` bytes |
| Manifest | `/tmp/aura-sp031-local-rc-20260902/output/AURA-development-unverified.manifest.json` |
| Manifest SHA-256 | `4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5` |
| Release label | `development_unverified` |
| Bundle | `ai.aura.local.agent`, version `0.1.0`, build `1`, minimum macOS `27` |
| SBOM | `aura-bundle-inventory-v1`, bundle-files-only, 17 components |
| Signature state | Developer ID `false`; hardened runtime `false`; notarization `not_submitted`; stapled `false`; verification `not_performed` |
| Deterministic verification | 1325 tests / 87 suites / 22 bundles / 0 failures; 70.20% line coverage |
| Reproducibility | Two package builds compared byte-for-byte with `cmp` success |

The full procedure, environment, dependency hashes, toolchain hash, model
manifest limitation, logs, rollback/kill-switch scope, and evidence-class
limitations are in the package evidence record. No raw audio, screenshots,
secrets, tokens, private account data, or unredacted model output belongs in
this packet or the decision record.

## Falsification checklist

The reviewer must treat any failed check as a return for correction, not as an
approval:

1. Recompute both listed SHA-256 values and compare the manifest's own source,
   release-status, artifact, signature, and SBOM fields.
2. Confirm the source commit is exact and the package build worktree was clean;
   a different commit or dirty source invalidates this package binding.
3. Confirm the two archive outputs were byte-identical and that the direct
   release-manifest validator passed against the bundle root and artifact.
4. Confirm every test/coverage result is deterministic or otherwise labelled;
   none may be called `live_user_present` or `live_beta_sample`.
5. Confirm the external `AURA_MODEL_MANIFEST.json`/weights are absent from the
   package qualification and that neural voice is excluded, not silently
   treated as verified.
6. Confirm `beta-readiness.json` remains `blocked`, telemetry remains disabled
   with `transport: none`, and `release_candidate.approved` remains `false`.
7. Confirm the residual live R11, live SLO, live scenario, incident, and
   external signing/notarization limitations are visible and accepted only as
   limitations, not closed gates.

## Independence and conflicts

Under ADR-050, independence is based on authorship. Codex prepared the package,
the evidence record, and this packet. The owner did not author those artifacts
and may review this declared local-only scope as the owner decision-maker. This
is not a human expert audit, third-party certification, or external security
review. No reviewer may approve a claim they authored.

## Historical decision procedure

**Current outcome — 2026-09-02:** The owner completed this packet's declared
review and approved only the exact artifact and manifest hashes for local
`development_unverified` use in
`EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`. ADR-047 is accepted at that
narrow scope. This is not beta, `release_candidate`, production, signing,
notarization, or external-release approval. The original approve/return text
below is retained as the historical review procedure.

At packet preparation, the owner was required to record one of these outcomes
in a new evidence entry:

- **Approve local-only use:** approve exactly the package evidence ID and hashes
  above for local `development_unverified` use only; accept the listed
  limitations; accept that this is not beta, production, `release_candidate`,
  signed, notarized, or external-release approval; and accept ADR-047 for this
  local-only scope.
- **Return for correction:** identify the failed check and leave SP-031
  `in_progress` or `blocked` until corrected and independently reviewed.

The following text is a copyable decision template, not an already-recorded
approval:

> I reviewed `EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01` and the falsification
> checklist in this packet. I approve artifact SHA-256
> `d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837` and
> manifest SHA-256
> `4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5` for
> local `development_unverified` use only. This is not beta, production,
> `release_candidate`, signed, notarized, or external-release approval. I
> accept the listed limitations and accept ADR-047 only for this local-only
> scope.

At that time, until the decision was separately recorded, SP-031 remained
`in_progress` and SP-032 could not start.

That decision is now separately recorded at
`EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`; this historical condition is
therefore satisfied only for SP-031's local package gate. SP-032 remains blocked
on its own direct FINAL evidence and authority.
