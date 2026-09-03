# EV-SP-030-20260901-DEEPSEEK-ROUND4-REVIEW-01

**Evidence ID:** EV-SP-030-20260901-DEEPSEEK-ROUND4-REVIEW-01
**Track:** SP-030 / R12 — the DeepSeek half of the ADR-050 cross-review loop
**Type:** Review received + independently spot-verified + F-007 remediated + F-003/F-004 investigated and accepted — **`security` sign-off OBTAINED, first of R12's five**
**Commit:** `ebc323b6a25329288d7fd079d0a58c29a4bc0ba9` at authoring time (`main`; working tree dirty from this record's own changes)
**Session:** AURA-SP-030-SLO-INSTRUMENTATION-20260831 (continuation, 2026-09-01)

## What happened

The owner ran `docs/operations/CROSS_REVIEW_REQUEST_FOR_DEEPSEEK.md` through
`deepseek-v4-flash` directly and appended the result as `## Round 4 —
2026-09-01 — cross-agent independent review (Artifact 4 continuation)` in
`docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md` (190 lines, one
finding — F-007 — plus eight "reviewed with no finding" items and a
Limitations section, matching Round 2's structure exactly).

**This record does not take that review on trust.** It was authored by an
independent LLM agent, but "independent" is not "infallible", and the
falsification pressure this whole program applies to its own evidence applies
equally to a reviewer's. Before acting on Round 4, its most consequential claim
(F-007) and three of its highest-stakes "no finding" claims were re-derived
independently.

## Independent verification performed

**F-007 (validator accepts a fabricated evidence ID) — reproduced from
scratch, not copy-pasted.** Constructed a schema-valid mutation of the
committed `beta-readiness.json` (a `live_user_present` `stt_partial` measurement
naming `EV-SP-030-20260830-FABRICATED-99`) and ran it through
`validate_beta_readiness.validate_record`. First attempt failed on an unrelated
missing field (`sample_minimum`); the corrected, fully schema-valid mutation
was **accepted with zero complaint** — confirming F-007 independently rather
than trusting DeepSeek's stated output.

**Three "no finding" claims spot-checked against current source, not
DeepSeek's description of it:**

- F-001 byte-count comparison — `grep` confirmed
  `HelperIPCAuthenticator.constantTimeEquals` compares UTF-8 byte counts, not
  grapheme counts, exactly as claimed.
- `submitConfirmation`'s nonce/hash/expiry/requestID check — read directly from
  `PolicyEngine_Evaluation.swift`; matches DeepSeek's description verbatim,
  including the exact boolean expression.
- `matchingGrant`'s capability guard — `grant.capability == request.capability`
  is the first condition, confirmed at the source line DeepSeek cited.

All three checked out exactly as described. Combined with the executable F-007
reproduction, this review is assessed as **legitimate and substantive** — a real
adversarial pass, not a formality.

## F-007 — fixed, with TDD and falsification

`scripts/validate_beta_readiness.py`'s `_require_evidence_id` checked only that
an evidence ID was *well-formed* (`EVIDENCE_ID_RE.fullmatch`), never that it
*existed*. Fixed by adding `_load_known_evidence_ids()`, which scans
`AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md` (293 real IDs as of this
record) for every substring shaped like an evidence ID, and threading the
resulting set through every one of the validator's nine
`_require_evidence_id` call sites. `validate_record` gained an optional
`known_evidence_ids` override — tests inject a controlled set; production
(`main()`) always uses the real committed index, unchanged call signature.

**Existing tests, not new behavior, needed updating.** Eleven fixtures across
`scripts/tests/test_beta_readiness.py` used synthetic placeholder IDs
(`EV-SP-030-20260830-SLO-01` and similar) that never existed in the real
index; four of them back an "accepted" assertion and would have started
failing for the *wrong* reason. Swapped to a real, permanent ID
(`EV-SP-030-20260830-PRIVACY-REVIEW-01`) rather than to a synthetic one that
would only reintroduce the same gap in the test suite itself.

**Six new tests** (`EvidenceIdMustExistTests`) pin the fix, including a direct
reproduction of DeepSeek's exact scenario and dedicated coverage of the
`known_evidence_ids` override mechanism and its fail-closed behavior when the
index is unreadable.

**Falsified, not just run.** Neutered the existence check (`value in
known_ids` → `True`) and re-ran: exactly the two tests that depend on it
failed (the F-007 reproduction and the reject-outside-the-set test), the other
four in that suite still passed. Fix restored from a checksummed copy.

| Check | Result |
|---|---|
| `python3 -m unittest discover -s scripts/tests` (outside sandbox) | **64 tests** (58 → 64), only the expected transient `working_tree_state` mismatch from this record's own uncommitted edits |
| `python3 scripts/validate_beta_readiness.py --record …/beta-readiness.json` | exit 0 |
| Neutered-check falsification | exactly 2 of 6 new tests fail, as intended |

## The `security` sign-off decision — OBTAINED, and every finding it rests on named

Both directions of the ADR-050 cross-review loop now exist: Round 2
(2026-08-30, Claude reviewing DeepSeek's SP-023/024/025) and Round 4
(2026-09-01, DeepSeek reviewing Claude's Artifacts 1–5, including the R11
authorization pipeline). The `CROSS_REVIEW_REQUEST_FOR_DEEPSEEK.md`'s own
closing line names this as the precondition for a sign-off to even be
considered, and this record is written by the agent holding the owner's
instruction to record it once that precondition is met.

**This session first concluded "not obtained"**, on the reasoning that F-002
(Medium, Round 2) sat open. That was wrong in a specific, checkable way: F-002
already carried an **explicit owner-accepted-risk decision dated 2026-08-30**
in `RISK_REGISTER.md` — missed on first read, found on a second pass before
acting, and the correction is recorded here rather than silently overwritten.
Put to the owner directly rather than decided unilaterally: F-003 and F-004
(Low) still had no formal disposition, so the choice was to close them with
F-002's own rigor before granting the sign-off, or grant it now with them
disclosed as open. **The owner chose to close them first.**

**F-003 (PID-based peer identity) — investigated, not just asserted, then
accepted.** A real audit-token fix was checked for feasibility before
accepting the risk: `HelperIPCClient.swift` launches the helper over a plain
POSIX `Pipe()` (stdin/stdout of a spawned `Process`), confirmed by reading the
launch code directly — not a Unix domain socket, not XPC. Anonymous pipes
carry no OS-level peer-credential mechanism (no `SO_PEERCRED`/`getpeereid()`
equivalent), so there is no audit token to switch to without replacing the
entire privileged-process IPC transport — a structural rewrite out of
proportion to a Low-severity finding whose own review already characterized
the exposure as narrow (small race window, local code execution already
required to attempt it). Accepted as risk, `RISK-PEER-IDENTITY-PID-BASED`,
reversible if the transport is ever redesigned around sockets or XPC.

**F-004 (textual IP normalization) — accepted, tied explicitly to F-002.**
`ResolvedIPValidator` has zero production callers (F-002's own finding), so a
textual-vs-numeric comparison mismatch in it is inert today — fixing it now
would be a parser with no caller to exercise it. Accepted as risk,
`RISK-IP-NORMALIZATION-TEXTUAL`, with the ordering already stated in F-002's
row repeated as its own tracked item: if F-002 is ever re-opened, F-004 must
be fixed **first**.

**Net position at the moment of decision:** F-001 (High) fixed and verified by
an independent reviewer; F-002 (Medium) owner-accepted 2026-08-30 with
documented compensating controls; F-003, F-004 (Low) owner-accepted 2026-09-01
after a feasibility investigation, not a rubber stamp; F-007 (Medium) found by
Round 4 and fixed same-day, independently reproduced first. **No unresolved
Critical or High finding remains, and every open item carries an explicit,
reversible, rationale-bearing acceptance decision rather than silence.**

`beta-readiness.json`'s `signoffs.security` is now:

```json
{
  "status": "obtained",
  "evaluator": "Cross-agent review under ADR-050, both directions: …",
  "independent": true,
  "evaluator_is_implementing_agent": false,
  "evidence_id": "EV-SP-030-20260901-DEEPSEEK-ROUND4-REVIEW-01",
  "date": "2026-09-01"
}
```

The `evaluator` field discloses the asymmetry explicitly rather than naming a
single reviewer: neither Claude nor DeepSeek is independent of the half it
authored; together the two rounds cover the full surface, each half reviewed
by the other agent. This is the honest shape of a two-agent cross-review under
ADR-050 §2, not a simplification of it.

## What this does NOT change

`security` is the first of R12's five sign-offs to close; the other four
(`privacy` was already obtained 2026-08-30; `accessibility_localization`,
`release_recovery`, `product_truthfulness` remain outstanding) are untouched.
No SLO measured, no scenario re-run, no gate moved. SP-030 stays `blocked` —
R11's live gate remains open per `EV-SP-030-20260831-R11-LIVE-GATE-04`, and the
mandatory SLOs/scenarios/incident review are still not satisfied. SP-031 must
not start. `ptt_ack`/`stt_partial` remain at zero samples.

## Falsifiers

Any of the following would falsify this record: that F-007 was not
independently reproduced before being trusted; that the fix does not reject
DeepSeek's exact fabrication vector; that a real evidence ID from the
committed record now fails validation; that `security.status` is anything
other than `"obtained"` in the committed `beta-readiness.json`; that F-002,
F-003, or F-004 was recorded as fixed rather than as an explicit,
rationale-bearing accepted risk; that the F-003 feasibility investigation
(pipe-based transport, no peer-credential syscall available) did not actually
happen before the risk was accepted; or that this record claims SP-030's gate
is met — it is not, and the sign-off closing is one of several preconditions,
not the whole of it.
