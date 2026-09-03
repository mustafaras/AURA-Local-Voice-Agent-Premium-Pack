# Owner Sign-Off Falsification Packet — R12

> **Purpose.** You are the signatory for `release_recovery` and
> `product_truthfulness` (ADR-050 §3). This packet is deliberately written to help
> you **disprove** the claims, not to reassure you. Every item gives you the claim,
> the command or file that shows it, and **the observation that would prove it
> wrong**. If you cannot falsify a claim after checking, signing it is honest. If
> you can, do not sign — file it as a finding.
>
> **Do not sign anything in this packet on the strength of this document alone.**
> It was assembled by the implementing agent. Its value is that it tells you where
> to look and what would break it.
>
> **Historical setup status:** At packet preparation, ADR-050 was `Proposed` and
> the sign-offs below were not yet recorded.
>
> **Current correction — 2026-09-02:** ADR-050 is accepted; all five scoped R12
> sign-offs are recorded. Launch-at-login now has direct local evidence, while
> sleep/wake/crash recovery, safe-mode export, and populated-profile migration
> remain unproved. The original packet text is retained as the review instrument
> used at the time; it does not make R12 ready or replace the remaining direct
> SLO, scenario, incident, R11, RC, or FINAL gates.

## A. `release_recovery`

**Claim 1 — the updater / rollback / recovery / safe-mode / reset contract is implemented and tested.**
- Check: `./scripts/aura-test.sh /tmp/aurabuild AuraLifecycleTests`
- Expect: `48 tests in 10 suites passed`.
- **Falsified if:** the bundle fails, or the tests only assert types/mocks without
  exercising a state transition. Open `Tests/AuraLifecycleTests/SafeModeTests.swift`
  and confirm it drives real state, not a stub.

**Claim 2 — no real signed update, network transport, or distribution is claimed.**
- Check: `docs/decisions/ADR-046-signed-update-recovery.md` status line; ADR-049.
- Expect: "Accepted (local-only scope)", with external signing explicitly excluded.
- **Falsified if:** any document claims a working signed-update download, a
  notarized artifact, or clean-machine Gatekeeper evidence. None exists.

**Claim 3 — the release artifact is still `development_unverified`.**
- Check: `grep -n "r11_release_status" archive/runtime-completion/state/beta-readiness.json`
- Expect: `development_unverified`.
- **Falsified if:** it reads anything else, or any record calls the artifact a
  release candidate. `release_candidate.status` must be `blocked`.

**Historical known gap:** At packet preparation, launch-at-login, sleep/wake/crash
recovery, live safe-mode export, and live migration against a populated profile
had not been exercised on this Mac. Launch-at-login later gained direct local
evidence; the remaining lifecycle items are still not proved. The owner could
legitimately refuse the sign-off then; the current open FINAL gates require
direct evidence rather than a document change.

## B. `product_truthfulness`

> **Current correction — 2026-09-02:** the original SLO count in this historical
> packet was corrected before the owner decision. `ptt_ack` and `stt_partial`
> are the two `not_measured` SLOs; all recorded measurements retain their
> deterministic-harness limitations. The current `beta-readiness.json` is still
> `blocked` and is the authoritative source.

**Claim 1 — no SLO, scenario, incident, or sign-off result is fabricated.**
- Check: `python3 scripts/validate_beta_readiness.py --record archive/runtime-completion/state/beta-readiness.json`
- Expect: exit 0. Then read `slo_definitions` — two of five must say
  `not_measured`; the three measured ones must carry `measurement_class:
  deterministic_harness` and a `limitations` string saying it is not a live beta.
- **Falsified if:** any SLO claims `live_user_present` class, any
  `live_beta_sample: true` appears, or `incident_review.status` is anything but
  `not_run` (no beta window has run).

**Claim 2 — the scenario matrix is harness coverage, not a live beta run.**
- Check: `scenario_matrix` entries in the same file.
- Expect: every entry `passed` with `measurement_class: deterministic_harness` and
  a `limitations` line naming the covering tests.
- **Falsified if:** any entry implies a live user-present run occurred. None did.

**Claim 3 — the full test suite genuinely covers what records claim.**
- Check: `./scripts/aura-test.sh /tmp/aurabuild` then compare the bundle count to `ls Tests/`.
- Expect: 22 bundles, 1325 tests, `Done. Failed bundles: 0`.
- **Falsified if:** the bundle count is lower than the directory count. *This exact
  defect was real:* `AuraLifecycleTests` was missing from the runner's hardcoded
  `TEST_TARGETS` and every prior "full suite passed" record excluded it. It was
  fixed this session — verify the fix rather than trusting this sentence.

**Claim 4 — the independent review is not overstated.**
- Check: `docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md` Round 2.
- Expect: an explicit COI disclosure stating the reviewer is an LLM agent, not a
  human auditor, and that it is not independent of the SP-030 contract work or the
  F-001 remediation.
- **Falsified if:** anything in the repository describes AURA as having passed an
  external, human, or third-party audit. It has not.

**Historical accepted finding:** F-002 — DNS/IP pinning
(`ResolvedIPValidator`) is implemented and tested but has **zero production
callers**, while SP-024's evidence describes network enforcement as covering
DNS/IP. The owner accepted it as a documented risk; it is not a current sign-off
blocker, but it remains a risk rather than a closed enforcement claim.

## C. What you are NOT signing

Per ADR-050 §6, these are accepted risks, not closed gates: no human expert
security audit, no penetration test, no external accessibility certification, no
third-party privacy review, no runtime fuzzing. They are acceptable only because
AURA is local-only with no external users (ADR-049). If that ever changes, these
sign-offs are void.

## D. How to record a sign-off

Do not hand-edit `beta-readiness.json`. Tell the agent your verdict per domain and
it will write the object the validator requires:

```json
"release_recovery": {
  "status": "obtained",
  "evaluator": "<your name/role>",
  "independent": true,
  "evaluator_is_implementing_agent": false,
  "evidence_id": "EV-SP-030-<date>-OWNER-SIGNOFF-01",
  "date": "<ISO date>"
}
```

A verdict of "not yet — close F-002 first" or "not yet — run the live R11 gates
first" is a perfectly good outcome and keeps the record honest.
