---
id: UI-5
sequence: 5
track: UI
depends_on: UI-4
next_prompt: none
state: pending
design_docs: 04-onboarding-redesign, 11-motion-system (§4)
---

# UI-5 — Onboarding Redesign (plan exit)

## Mission

Visual 13-step onboarding flow with the segmented step indicator and the Iris signature moment; migrate ~26 inline TR/EN ternaries into `AuraCopy`. Pure presentation — the stage machine's behavior is frozen. This is the plan's final phase; its close is a **plan-completion turn**, not a next-phase approval.

## Read before acting (anti-amnesia context)

- CURRENT_PHASE + ledger tail + `00-working-protocol.md` §3–§5
- `04-onboarding-redesign.md`, `11-motion-system.md` §4 (choreography, signature moments)
- Code: `AuraMenuView.swift` (AuraOnboardingView section, ternaries at lines 212-286), `AuraDesign.swift`, `AuraOrb.swift` (the existing Orb component), `ProductUIState.swift` (copy table)
- Verified baseline: card-first Settings invariant tested (UI-4); driver leg green; Motion tokens + Reduce Motion helper (UI-0); copy-table floor (>150 keys); `aura.ui.state` persistence.

## Hard boundaries

- Scope guard (allowed files): `AuraMenuView.swift` (onboarding section), `AuraDesign.swift` (`AuraStepIndicator` addition), `ProductUIState.swift` (copy keys), `AuraOrb.swift` (signature via the existing Orb component), integration tests, plan ledger. **Nothing else.**
- The 13-step stage machine is **behavior-frozen**: pure presentation change; stage machine tests run unchanged — editing them is a defect.
- Iris signature moment: hero-scale Orb on the onboarding entry, animated per 11 §4; **Reduce Motion renders a still readout** (the G0-5 helper makes this automatic — verify, don't assume).
- Copy migration is mechanical: every migrated key keeps its exact EN/TR strings; no copy rewriting smuggled in as refactoring.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G5-1 | Visual stage flow for the existing stage machine (behavior unchanged — pure presentation) | stage machine tests green unchanged; `git diff --stat` on their file |
| G5-2 | `AuraStepIndicator` in `AuraDesign.swift`: segmented, 13 steps, relative typography only, a11y ID per contract | view-construction test green |
| G5-3 | Copy migration: ~26 inline `language == .turkish` ternaries (AuraMenuView.swift:212-286) into `AuraCopy` keys; table floor stays satisfied | copy-table guard green; grep: zero inline ternaries remain in the onboarding section |
| G5-4 | Iris signature moment: hero-scale Orb entry per 11 §4; Reduce Motion still-readout verified live | view-construction test; Reduce Motion path test |
| G5-5 | Full verification loop + governance: suite green ×2–3; live onboarding pass via driver (first-run → 13 steps → done); ADR + repo ledger + `CURRENT_STATE.md` | suite exit 0 ×2–3; driver leg evidence in plan ledger |
| G5-6 | Machine coherence + **plan completion**: validator OK, all gates `passed`, `phase_status: completed`; plan-completion turn | validator OK; completion summary in ledger |

## Per-gate procedure

**G5-1:** re-style each stage view; before touching anything, run the stage machine tests and record their names + counts — they must be byte-identical green at G5-5.

**G5-2:** `AuraStepIndicator` as an `AuraDesign` component (13 segments, relative typography, VoiceOver announces "step N of 13"); view-construction test for all 13 positions.

**G5-3:** migration loop: extract each ternary at 212-286 into an `AuraCopy` key with the exact existing strings; copy-table floor guard proves the table grew and stayed valid; final grep returns zero `language == .turkish` ternaries in the onboarding section.

**G5-4:** Orb hero entry with `motion.emergent`; under Reduce Motion the helper yields a static readout — test both paths.

**G5-5:** full loop + governance; driver leg covers a real first-run tour through all 13 steps.

**G5-6:** validator; flip `phase_status: completed`; write the plan-completion summary (phases landed, artifacts produced, ADRs, residual risks) into the ledger; ask *"Faz UI-5 tamamlandı; plan tamamlandı. Kapanış onayı?"* — and stop.

## Evidence templates (minimum per SEQ entry)

- G5-1: stage machine test names + counts (recorded before edits); `git diff --stat` on that test file (zero)
- G5-2: view-construction test results (13 positions)
- G5-3: copy-guard pass counts; migration diff stat; final zero-ternary grep output
- G5-4: Reduce Motion path test result; live still-readout check
- G5-5: rerun counts ×2–3; driver leg excerpt; ADR path; repo ledger range; CURRENT_STATE timestamp
- G5-6: validator output; plan-completion summary location

## Risks and rollback

| Risk | Mitigation |
| --- | --- |
| Presentation refactor mutates stage behavior | Frozen stage-machine tests recorded before edits; identical green at G5-5 |
| Copy migration rewrites Turkish wording | Exact-string rule; copy guard + spot diff review |
| Signature moment breaks Reduce Motion | G0-5 helper is the single source; both paths tested at G5-4 |

Rollback: onboarding section + one `AuraDesign` component + copy keys; each independently revertible; stage machine tests prove zero behavior drift after any rollback.

## Session script (anti-amnesia)

1. Parallel reads (CURRENT_PHASE, ledger tail, this prompt, `04`/`11` docs, onboarding section).
2. Validator; on FAIL repair first.
3. Restate: "Aktif faz UI-5; tamamlanan: [gates]; sıradaki kapı G5-N."
4. One gate per checkpoint.
5. On G5-6: `phase_status: completed`; ask *"Faz UI-5 tamamlandı; plan tamamlandı. Kapanış onayı?"*; **stop**.

## Cognitive completion gate (answer in ledger before the completion turn)

1. What exactly changed? (files + line ranges)
2. What evidence proves each gate?
3. What observation would falsify "onboarding redesigned, behavior frozen"?
4. Is the plan exit honest? (all six phases landed with evidence, not narrative)
5. What residual risk remains, and why is it outside UI-5?
