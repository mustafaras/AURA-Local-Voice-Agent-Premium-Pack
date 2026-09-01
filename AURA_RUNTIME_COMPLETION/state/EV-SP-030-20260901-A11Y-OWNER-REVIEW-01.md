# EV-SP-030-20260901-A11Y-OWNER-REVIEW-01

**Evidence ID:** EV-SP-030-20260901-A11Y-OWNER-REVIEW-01
**Track:** SP-030 / R12 — `accessibility_localization` sign-off
**Type:** Owner-performed independent review (translation) + live assistive-technology check (VoiceOver) — **sign-off OBTAINED, second of R12's five**
**Commit:** `72a4c17ed0afed96090646c02abb67d6d0435eb5` at authoring time (`main`; working tree dirty from this record's own changes)
**Session:** AURA-SP-030-SLO-INSTRUMENTATION-20260831 (continuation, 2026-09-01)

## Why the owner, not an agent

`accessibility_localization` had been refused three times over, most recently
in `EV-SP-030-20260830-A11Y-COVERAGE-03`, on exactly three named grounds:
*"unreviewed translation, absent live VoiceOver verification and ADR-050 §4
reviewer independence — no longer on coverage."* Coverage itself was already
closed (184 → all `AuraCopy` keys routed, guarded by
`AuraCopyTableGuardTests`); what remained was never a code gap.

Neither Claude nor DeepSeek could close the independence problem for this
specific domain: the Turkish strings under review were overwhelmingly authored
by Claude across SP-021 and this program's SP-030 sessions, so Claude is
disqualified under ADR-050 §4 ("no exception, no owner override" — this is
stated in the ADR itself and was not waived here despite the owner offering
full authority). DeepSeek's Round 4 already noted the same limit from its own
side: *"the reviewer is not a native speaker and cannot certify register under
stress."* The one party who both did not author these strings and can
plausibly read them as a native speaker is the release owner, and that is who
performed this review.

## What was reviewed, and how

**Translation, all 190 keys.** Extracted verbatim from
`Sources/AURA/ProductUIState.swift` by regex (not hand-copied, so nothing could
be silently dropped or altered in transcription) and published as an
interactive review artifact — searchable, filterable by section, with
per-string "reviewed"/"flagged" state persisted in the owner's browser. The
owner reviewed all 190 entries and reported no problems.

**Live VoiceOver, three representative screens.** VoiceOver could not be
enabled by this session's own automation — `pgrep -x VoiceOver` confirmed the
process never started after a synthetic `Cmd+F5` keystroke, consistent with
macOS restricting programmatic activation of this specific accessibility
feature (the same class of restriction as the `-25211` refusal on synthetic
clicks encountered earlier this session — a deliberate anti-abuse boundary,
not a scripting bug to work around). The owner performed the check directly:
enabled VoiceOver, navigated the main panel (*Konuşma*), *Ayarlar*, and the
emergency-stop control, and confirmed the Turkish was read correctly.

## Scope, stated precisely

**Covered:** every `AuraCopy` string's translation quality (190 of 190, full
pass); live VoiceOver reading of three high-traffic and one safety-critical
surface (main panel, Settings, emergency stop).

**Not covered, and not claimed:** VoiceOver was not driven through all 190
strings or every screen — the three checked were chosen as representative
(general navigation, a settings form, and the highest-stakes single control
in the app), not exhaustive. No formal WCAG conformance audit. No assistive
technology other than VoiceOver (no Switch Control, no Zoom interaction
check). Single reviewer — the release owner alone, not a panel. This is a
review record, not a certification.

## Sign-off written

`beta-readiness.json.signoffs.accessibility_localization`:

```json
{
  "status": "obtained",
  "evaluator": "AURA release owner — independent under ADR-050 (authored none of the reviewed AuraCopy strings); reviewed as a Turkish speaker, which neither Claude nor DeepSeek could certify for this domain",
  "independent": true,
  "evaluator_is_implementing_agent": false,
  "evidence_id": "EV-SP-030-20260901-A11Y-OWNER-REVIEW-01",
  "date": "2026-09-01"
}
```

## Verification

| Check | Result |
|---|---|
| `python3 scripts/validate_beta_readiness.py --record …/beta-readiness.json` | exit 0 |
| `pgrep -x VoiceOver` after the synthetic keystroke attempt | not running — confirms this session did not fabricate the live check |
| 190-row extraction cross-checked against source count | matches (`AuraCopyTableGuardTests` independently pins full-table coverage) |

## What this does NOT change

`security` and `privacy` were already obtained; `accessibility_localization`
is now the second closed of R12's five. `release_recovery` and
`product_truthfulness` remain outstanding — owner-judgment domains per
ADR-050 §3, requiring their own falsification-packet review, not carried by
this record. No SLO measured, no scenario re-run, no gate moved. SP-030 stays
`blocked` — R11's live gate is still open and `ptt_ack`/`stt_partial` remain
at zero samples. SP-031 must not start.

## Falsifiers

Any of the following would falsify this record: that fewer than 190 strings
were actually reviewed; that the owner authored any of the reviewed strings;
that VoiceOver was toggled by this session's automation rather than by the
owner directly; that the VoiceOver check covered more than the three named
screens; or that this record claims SP-030's gate is met — it does not, and
`release_recovery`/`product_truthfulness` plus R11's live gate plus the
mandatory SLOs remain open.
