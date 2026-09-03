# EV-DELIVERY-20260902-GRAPHIFY-01

**Evidence ID:** `EV-DELIVERY-20260902-GRAPHIFY-01`
**Track:** Repository delivery / SP-030 handoff
**Type:** Source-helper verification, repository delivery, local build/launch smoke
**Session:** `AURA-DELIVERY-20260902-GRAPHIFY`
**Verified source baseline:** `25abcb70cfe11dd8e92af1de78ea3e8b2e2425b6` on `main`
**Environment:** macOS 27.0 arm64, Swift 6.4, Python 3.14.6, Git 2.54, `gh` 2.95

## Graphify result

- `scripts/generate_network_viz.py` and `scripts/render_network.py` compile
  successfully in memory; NumPy import succeeds.
- `graphify-out/graph.json` contains 13,515 nodes and 35,358 links.
- The generated visualization contains 400 node records and 1,478 edge
  records; the node and edge datasets are distinct and have the expected
  `id` / `from` / `to` shapes.
- The full renderer completed for all 13,515 nodes and 35,358 links.
- A shared template defect was fixed before delivery: node and edge JSON now
  use separate replacement tokens, so node records cannot be inserted into the
  edge dataset.
- `graphify-out/` is approximately 60 MB and remains on disk. It is excluded
  locally through `.git/info/exclude`; it was not deleted and is not in Git.

## Repository and test gates

- Strict build passed:
  `swift build --build-path /tmp/aura-delivery-20260902-strict-build-2
  -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`.
- Full authoritative wrapper passed: 1,325 tests / 87 suites / 22 bundles,
  zero failures; line coverage 70.20% against the 70% gate.
- Focused `AuraLifecycleTests` passed: 48 tests / 10 suites, zero failures.
- Python governance suite passed: 64 tests, `OK`.
- Runtime-completion, second-pass, beta-readiness, repository-hygiene, and
  supply-chain validators passed.
- `git diff --check` and shell syntax checks passed for the delivered scope.
- `SupportBundleExporter.swift` had six unnecessary `await` markers removed
  from synchronous writes; this is strict-build warning hygiene with no
  intended behavior change.

## Git delivery and merge status

- Commit created: `25abcb70cfe11dd8e92af1de78ea3e8b2e2425b6`,
  `feat(tools): add graph visualization helpers`.
- Push succeeded from `cd2c3cdf4a581c607bfd32e34bb882f13bb2e679` to
  `25abcb70cfe11dd8e92af1de78ea3e8b2e2425b6`; `git ls-remote` matched the
  pushed commit.
- No open pull request targets `main`; this is direct-main delivery, so there
  is no separate merge commit to claim.
- GitHub Actions run `33601259000` was observed in `queued` state. CI success
  is not claimed.

## Local deploy boundary

- `scripts/build-app-bundle.sh` built `/tmp/aura-delivery-20260902-app/AURA.app`.
- The main executable remained alive for 12 seconds when launched with an
  isolated `CFFIXED_USER_HOME`; launch log:
  `/tmp/aura-delivery-20260902-launch.log`.
- Main executable SHA-256:
  `28ab65cb4cb10ffa2c7e10d676a7cbdceeeee91e5281041a4b192f7417fee9dc`.
- This was an unsigned local build/launch smoke only. No Developer ID signing,
  notarization, `/Applications` installation, external distribution, or
  production deployment was performed. The remaining local launch smoke log
  contains only the observed sandbox extension warning; the process stayed
  alive for the measured interval.

## SP-030 reconciliation

This delivery does not advance SP-030 to completed. The owner single-participant
cohort is enrolled/consented, all five R12 sign-offs are obtained, and
launch-at-login is closed live. SP-030 remains blocked because:

1. R11 sleep/wake/crash recovery, safe-mode export, and populated-profile
   migration are unit-tested only, not live-verified.
2. `ptt_ack`, `stt_partial`, and `dialogue_first_token` have no qualifying
   live-beta sample set; `stt_partial` requires a speech-capable owner-present
   run.
3. The five scenario records are `deterministic_harness` only, not a live beta
   window, and `incident_review.status` is `not_run`.
4. `beta-readiness.json` is `blocked`; telemetry is disabled with
   `transport: none`; `release_candidate` is `blocked` and unapproved.

SP-031 must not start. The signed RC package and ADR-047 remain absent.

## Limits and falsifiers

This record does not prove GitHub Actions completion, signed/notarized release
readiness, clean-machine recovery, real-device acceptance, live microphone
metrics, a live beta scenario window, or incident absence. Any claim that
`graphify-out/` was pushed, that CI succeeded, or that SP-030 completed would
falsify this record.
