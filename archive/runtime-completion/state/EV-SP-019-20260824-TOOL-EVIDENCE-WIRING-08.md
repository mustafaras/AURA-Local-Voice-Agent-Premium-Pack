# EV-SP-019-20260824-TOOL-EVIDENCE-WIRING-08

- **Evidence ID:** `EV-SP-019-20260824-TOOL-EVIDENCE-WIRING-08`
- **Prompt / gap:** SP-019 / OPEN-09 / R8
- **Timestamp:** 2026-08-24T15:07:21Z
- **Branch / commit:** `main`; `HEAD == origin/main == ed55a0c8db9c63059c7639f9160efebaf44816ac`; intentionally dirty worktree
- **Class:** Root-cause analysis of four missing product paths, plus the direct changes and deterministic tests that close them
- **Environment:** macOS 27, Apple Silicon, Swift 6.4.0.30.4, Xcode `27.0.0-beta.5`

## Symptom and root cause

The four SP-019 scenarios previously recorded as "live attempt failed" were not
procedure failures. The behaviour did not exist in the product:

1. **No project fact from verified tool evidence.** The only production memory
   write during a live turn was `IntentEngine.persistIntentAsMemory`
   (`Sources/AuraIntent/IntentEngine_Resolution.swift`), a classifier summary
   with `.systemDerived(source: .intent)` provenance. No production site ever
   wrote `MemoryClass.projectFact`, and no site ever produced
   `MemoryProvenance.observed` or the `MemoryWriteSource.verifiedToolEvidence`
   case — both existed in `AuraCore`, with a validation rule
   (`validateVerifiedToolSource`) that nothing reached.
2. **Contradiction detection structurally unreachable.** `ContradictionDetector`
   keys on `(memoryClass, subject, scope)`. The single live write used subject
   `intent:<uuid>`, globally unique, so two live records could never collide and
   no `MemoryConflict` could ever be raised in the shipped app.
3. **No multi-turn reference clarification.** `ReferenceResolver` accepts
   `explicitlyConfirmedTargetID`, but no production code ever populated
   `DeepContextRequest.explicitlyConfirmedTargetID`. An ambiguous reference
   asked a clarifying question whose answer had no path back into resolution,
   so the follow-up turn necessarily re-derived the same ambiguity.
4. **Deletion receipt discarded.** `MemoryEngine.deleteRecord` returns a
   `MemoryDeletionReceipt`, but `AuraKernel.deleteMemoryRecord` dropped it with
   `_ =`, and the app model showed only a transient sentence. No receipt ever
   reached the user.

## Direct change

- `Sources/AuraIntent/ToolObservation.swift` (new): bounded, single-line,
  control-character-stripped observation carrying a stable `factKey`,
  evidence references, and the observing actor.
- `Sources/AuraIntent/ToolRouter_ToolObservations.swift` (new) and
  `ToolRouter_Handlers.swift`: a successful (`exit 0`) shell command records
  one observation keyed by intent; blocked and failing commands record none.
  The spoken summary stays exit-code-only — output reaches bounded memory,
  never speech.
- `Sources/AuraIntent/IntentEngine_ToolEvidenceMemory.swift` (new): persists an
  observation as a `.projectFact` with `.observed(source:)` provenance,
  `.verifiedToolEvidence` write source, `indefinite` retention, and **global**
  scope, keyed by the stable `factKey` — which is what makes a second, differing
  observation collide and raise a contradiction.
- `Sources/AuraIntent/IntentDispatchCoordinator.swift`: consumes the
  observation once per turn, after routing.
- `Sources/AuraIntent/IntentEngine_ReferenceClarification.swift` (new) plus
  `IntentEngine_IntentEngine.swift` / `IntentEngine_Resolution.swift`: an
  ambiguous reference retains the offered candidates; the next turn's answer
  populates `explicitlyConfirmedTargetID` only when it names exactly one
  candidate, using tokens distinctive **within the offered set**.
- `Sources/AURA/AuraKernel_RuntimeAPI.swift`, `AuraAppModel*.swift`,
  `ProductUIState.swift`, `AuraMenuView_Tabs.swift`: the deletion receipt is
  returned, retained in observable state, and rendered persistently in the
  Privacy tab, carrying record id, class, reason, and time but no deleted
  content.

## Result

- `./scripts/aura-test.sh` full matrix: **21/21 bundles, 1,160 tests, 0 failed,
  exit 0** (baseline before this change: 1,141).
- 19 new tests: `Tests/AuraIntentTests/SP019ToolEvidenceMemoryTests.swift` (6),
  `SP019ReferenceClarificationTests.swift` (5),
  `ToolRouterTests.swift` (+6: observation recorded/consumed-once/not-on-failure/
  not-when-blocked, and two memory-authority tests),
  `Tests/AURAIntegrationTests/SP019MemoryUIStateTests.swift` (+2).
- Safety negatives are covered explicitly: secret-looking tool output is refused
  rather than retained; an answer matching several offered candidates or none is
  not treated as a confirmation; an expired question is not answered by a later
  turn.
- `swift-format lint --strict` and `swiftlint`: **no new findings** against the
  `HEAD` baseline (117 pre-existing swift-format findings, 47 pre-existing
  swiftlint errors, none in changed files).

## Falsifier

A production write path that already produced `.projectFact` or
`.verifiedToolEvidence`, or a populated `explicitlyConfirmedTargetID`, would
falsify the root-cause claim. `grep` over `Sources/` for `MemoryWriteRequest(`,
`MemoryClass.projectFact`, and `explicitlyConfirmedTargetID` shows the three
pre-change write sites and no production producer.

## Scope / privacy

Source, deterministic tests, and lint only. No raw audio, screenshots, secrets,
tokens, provider payloads, or unredacted model output were recorded.

## Limitations

Deterministic tests do not establish user-present product acceptance; the live
evidence is recorded separately under
`EV-SP-019-20260824-LIVE-PROJECT-FACT-09`,
`EV-SP-019-20260824-LIVE-DELETION-RECEIPT-10`,
`EV-SP-019-20260824-TRANSPORT-TRACE-11`, and
`EV-SP-019-20260824-MEMORY-AUTHORITY-12`. No commit, push, merge, signing,
release, deployment, provider action, or permission mutation occurred.
