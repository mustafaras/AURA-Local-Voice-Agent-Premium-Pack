# EV-SP-030-20260830-A11Y-CORRECTION-01

**Evidence ID:** EV-SP-030-20260830-A11Y-CORRECTION-01
**Corrects:** `EV-SP-030-20260830-A11Y-REVIEW-01` (Round 3 accessibility/localization review)
**Track:** SP-030 / R12 / OPEN-13
**Type:** Correction — a published finding of this reviewer's own was materially overstated
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty)
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830

## The error

`EV-SP-030-20260830-A11Y-REVIEW-01` reported that **38 of 42** accessibility
strings and **45 of 49** user-facing literals in `Sources/AURA` were unlocalized.
Both figures came from a six-line proximity heuristic that could not see
multi-line modifier calls and did not recognise inline
`language == .turkish ? "…" : "…"` ternaries — which are fully localized.

The claim was published to the findings document, the risk register, the evidence
index and three ledgers, and an `accessibility_localization` sign-off was refused
partly on its strength.

## The corrected figures

| | Published | Actual |
|---|---|---|
| Accessibility strings not localized | 38 of 42 | **13 of 41** |
| User-facing visible literals | 45 of 49 | **withdrawn — unmeasured** |

The visible-literal figure is **withdrawn rather than replaced.** The corrected
extractor produced obviously corrupt output (matching literals from continuation
lines), and publishing a second unverified ratio would repeat the original mistake.

Of the 13, several interpolate already-localized content — `AURA.swift:36` wraps
`model.status.title(for: language)`; `AuraDesign.swift:122` composes
`\(title). \(detail)` from localized parts — so only an English prefix or separator
is untranslated. Substantive static gaps number roughly eight:
`"Corrected memory statement"`, `"Read VS Code editor state"`,
`"Performs a read-only, policy-authorized live bridge check"`,
`"Search inspectable memory"`, `"Memory deletion receipt…"`, and the `"Trace: "`
(×2), `"Diagnostic: "` and `"AURA status: "` prefixes.

## What stands, what changes

- **Stands:** the emergency-control finding. It was verified by direct source
  reading, not by the heuristic; it is fixed, and three regression tests pin it.
- **Stands:** the `accessibility_localization` **refusal**, on corrected grounds —
  13 of 41 is a genuine gap.
- **Changes:** F-005 severity **High → Medium**.
- **Unaffected:** Round 2. F-001 was proven by an executable crash; F-002 by an
  exhaustive call-path grep. Neither used this heuristic.

## Why this is recorded rather than edited away

Round 3 criticised `EV-SP-021-20260825-ACCESSIBILITY-LOCALIZATION-01` for
generalising from two verified surfaces to a broad claim. The reviewer then made
the same error in the same document. Correcting by appending, not by rewriting,
keeps both the mistake and its scope legible — which is the standard this
repository applies to every other actor.

**Method rule for future rounds:** a proximity heuristic over source text is not
evidence. Either parse structure, or hand-verify each hit and report it as a
hand-verified sample — never as an exhaustive ratio.

## Falsifiers

Any citation of the withdrawn 38/42 or 45/49 figures as current; any claim that
the visible-literal gap has a measured value; or any claim that this correction
closes the `accessibility_localization` refusal, would falsify this record.
