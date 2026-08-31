# EV-SP-030-20260830-A11Y-REMEDIATION-01

**Evidence ID:** EV-SP-030-20260830-A11Y-REMEDIATION-01
**Track:** SP-030 / R12 / OPEN-13 — F-005 safety-critical instance + F-006
**Type:** Remediation — emergency control localized, Dynamic Type restored
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty)
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830

## Provenance of this file — read first

**This record was reconstructed on 2026-08-30, after the fact, and is not a
contemporaneous artifact.** The originating session cited this evidence ID in six
places — `EVIDENCE_INDEX.md` (a full row), `PROGRAM_LEDGER.md`,
`SECOND_PASS_LEDGER.md`, `ledger/PROJECT_LEDGER.md`, `RISK_REGISTER.md`, and
`SECOND_PASS_STATE.json` — but never wrote the file itself. Of the 134 standalone evidence files in `AURA_RUNTIME_COMPLETION/state/`, **eight** SP-era cited IDs had no file behind them. This was the only one belonging to the active prompt; the other seven — `EV-SP-000-…-BASELINE-01`, `EV-SP-000-…-DELIVERY-01`, `EV-SP-001-…-ATTEMPT-01`, `EV-SP-001-…-CLOSEOUT-02`, `EV-SP-001-…-CLOSEOUT-03`, `EV-SP-003-…-R2-DIALOGUE-TESTS-15`, `EV-SP-010-…-COMPOSITION-01` — are older and remain open. Pre-SP tracks (R0–R12, REPO-HYGIENE, BOOTSTRAP) never used standalone files at all; their evidence lives only as index rows. The per-ID file is therefore an **SP-era** convention, not a universal one.

The reconstruction is **not** a transcription of the index row. Every factual
claim below was re-verified against the working tree and against `HEAD`
(`8b16142`) before being written down; the verification method is stated with
each claim. Anything the index row asserted that could not be re-verified is
marked as such rather than repeated.

## What was done

**F-005, safety-critical instance.** The emergency control — the surface that
disables generated mouse and keyboard input — was entirely English. A
Turkish-speaking VoiceOver user was read English for the control that stops
generated input. Five strings were routed through the existing `AuraCopy` keyed
table via five new `emergency.*` keys.

*Re-verified:* `grep -c '"emergency\.' Sources/AURA/ProductUIState.swift` → `5`.
The keys are `emergency.group`, `emergency.stop`, `emergency.stopHint`,
`emergency.rearm`, `emergency.rearmHint`, and both VoiceOver hints are among
them, matching the claim that the hints were included.

Three regression tests (`EmergencyControlCopyTests` in
`Tests/AURAIntegrationTests/AuraAccessibilityIdentifierTests.swift`) assert the
keys resolve in both languages, genuinely differ between them, and never revert
to the two shipped English hint literals.

**F-006, Dynamic Type.** Six `.font(.system(size:))` call sites — which pin a
point size and therefore ignore the user's Dynamic Type setting — were replaced
with semantic text styles (`.subheadline`, `.footnote`, `.caption2`, `.title3`,
`.caption`).

*Re-verified:* at `HEAD` the count of `font(.system(size:` was 1 in
`AuraDesign.swift` and 5 in `AuraMenuView_Content.swift` — six, matching the
claim. In the working tree the count across all of `Sources/AURA/*.swift` is
**zero**. F-006 is closed.

## What could not be re-verified

The index row records `AURAIntegrationTests 89 → 92`. The pre-change figure of 89
cannot be recovered without reverting the working tree, which the owner has not
authorized. The post-change figure is consistent with the later record
(`EV-SP-030-20260830-A11Y-COVERAGE-01`, 92 → 95) and with the present measured
count of 99, but **89 is carried forward from the index row on trust, not
re-measured.**

## What was NOT done

This fixes the **safety-critical instance only**. The systemic F-005 gap remained
open at the time of this remediation: the majority of user-facing and
accessibility strings across `Sources/AURA` still had no language conditional,
and no repo-wide guard existed. See `EV-SP-030-20260830-A11Y-COVERAGE-01` and
`EV-SP-030-20260830-A11Y-COVERAGE-02` for the subsequent passes.

Every Turkish string here was written by the implementing agent, which cannot
assess its own Turkish. **Unreviewed translation is not correct translation.**
This remediation was authored by the same agent that reviewed the finding, so
under ADR-050 §4 it requires a different reviewer.
`accessibility_localization` stays **REFUSED**.

## Falsifiers

Any claim that this file is contemporaneous evidence; that F-005 was closed
systemically rather than at its safety-critical instance; that the translations
were reviewed; that the `89` baseline was re-measured; or that
`accessibility_localization` was obtained, would falsify this record.
