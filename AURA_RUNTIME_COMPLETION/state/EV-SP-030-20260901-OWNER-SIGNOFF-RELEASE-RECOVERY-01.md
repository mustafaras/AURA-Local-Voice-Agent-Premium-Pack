# EV-SP-030-20260901-OWNER-SIGNOFF-RELEASE-RECOVERY-01

**Evidence ID:** EV-SP-030-20260901-OWNER-SIGNOFF-RELEASE-RECOVERY-01
**Track:** SP-030 / R12 — `release_recovery` sign-off (owner-judgment domain, ADR-050 §3)
**Type:** Owner verdict against an updated falsification packet — **sign-off OBTAINED, third of R12's five, known gap explicitly accepted**
**Commit:** `510a58485809e8a65fe233506e23c3ce74752b30` at authoring time (`main`; working tree dirty from this record's own changes)
**Session:** AURA-SP-030-SLO-INSTRUMENTATION-20260831 (continuation, 2026-09-01)

## Why the owner, and why this record updates the packet before using it

ADR-050 §3: *"`release_recovery` and `product_truthfulness` are owner
decisions, not technical audits… Owner sign-off MUST be based on a
falsification packet… not on a summary asserting that things are fine."*
`docs/operations/OWNER_SIGNOFF_FALSIFICATION_PACKET.md` is that packet, dated
2026-08-30. It was **not** handed to the owner unverified — every claim in
its Section A was re-checked against the current tree first, because the
packet itself predates two full sessions of work and its own preamble warns:
*"Do not sign anything in this packet on the strength of this document alone."*

## Verification of the packet's three claims, against current state

| Claim | Packet says (2026-08-30) | Verified now (2026-09-01) |
|---|---|---|
| 1 — updater/rollback/recovery/safe-mode/reset tested | `AuraLifecycleTests`, 48 tests / 10 suites | **Confirmed unchanged.** `SafeModeTests.swift` drives real async state (`setSafeModeRequested`/`isSafeModeRequested`), not stubs. |
| 2 — no signed update/distribution claimed | ADR-046 "Accepted (local-only scope)" | **Confirmed.** Status line unchanged. |
| 3 — artifact still `development_unverified` | — | **Confirmed.** `r11_release_status: development_unverified`; `release_candidate.status: blocked`; `release_candidate.approved: false`. |

One packet fact was stale and is corrected here: it states *"ADR-050 is
Proposed. Accept it first, or these sign-offs have no agreed definition."*
ADR-050's own status line now reads **Accepted** (2026-08-30), so that
precondition is met and was not silently skipped.

## The "known gap" — updated with what actually changed since the packet was written

The packet's original language: *"live launch-at-login, live sleep/wake/crash
recovery, live safe-mode export, and live migration against a populated
profile have **not** been exercised on this Mac. They are implemented and
unit-tested only."*

**This is now only partly true, and the owner was told so before deciding.**
Launch-at-login specifically *was* exercised live across
`EV-SP-030-20260831-R11-LIVE-GATE-01` through `-04`: the original
authorization pipeline was found broken (denied before reaching
`SMAppService`), fixed under owner authorization, and the fix was live-tested
— the confirmation card now genuinely renders and `sfltool dumpbtm` proves
`service.register()` executed successfully on this Mac at least once. What
was **not** achieved is a clean, human-confirmed end-to-end pass (toggle click
→ card accepted → toggle reads back enabled); the most recent read showed the
toggle OFF. Sleep/wake/crash recovery, safe-mode export, and migration against
a populated profile remain exactly as the packet described: implemented and
unit-tested, never exercised live.

## Owner's verdict

Presented with the verified claims and the corrected gap description, the
owner chose: **sign now, with the residual gap accepted explicitly in
writing** — not "not yet" (the packet's own stated legitimate alternative),
and not silently.

## Sign-off written

`beta-readiness.json.signoffs.release_recovery`:

```json
{
  "status": "obtained",
  "evaluator": "AURA release owner — independent under ADR-050 §1 (did not author the reviewed code); signatory for this owner-judgment domain under ADR-050 §3",
  "independent": true,
  "evaluator_is_implementing_agent": false,
  "evidence_id": "EV-SP-030-20260901-OWNER-SIGNOFF-RELEASE-RECOVERY-01",
  "date": "2026-09-01"
}
```

## Risk register entry for the accepted gap

`RISK-LIVE-LIFECYCLE-UNVERIFIED` records the residual, matching the rigor of
the F-002/F-003/F-004 acceptances already in this register: what remains
untested, what compensating evidence exists (the BTM proof for
launch-at-login specifically), and the reversal condition (any future
`release_recovery` re-review, or before any change to R11's local-only scope,
must re-check this row).

## Verification

| Check | Result |
|---|---|
| `python3 scripts/validate_beta_readiness.py --record …/beta-readiness.json` | exit 0 |
| Packet Claim 1–3 re-verified against current tree, not trusted from the 2026-08-30 document | done, table above |
| ADR-050 acceptance precondition | met (`Status: Accepted`) |

## What this does NOT change

`product_truthfulness` remains outstanding — its own falsification packet
section (B) has not yet been walked. R11's live gate is **not** closed by
this record: the packet's gap description, now corrected, is what the owner
signed over, not a claim that launch-at-login works end to end. `ptt_ack`/
`stt_partial` remain at zero samples. No SLO measured, no scenario re-run, no
gate moved. SP-030 stays `blocked`; SP-031 must not start.

## Falsifiers

Any of the following would falsify this record: that any of the three
packet claims was not actually re-verified against the current tree before
this sign-off; that the corrected gap description overstates what was
live-tested for launch-at-login (i.e., that it claims the toggle now works
end to end — it does not); that sleep/wake/crash recovery, safe-mode export,
or migration were claimed as live-tested when they were not; or that this
record closes R11's live gate or SP-030's overall completion gate.
