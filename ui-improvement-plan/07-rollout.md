# Rollout: Sequencing, Acceptance Gates, and Risks

---

## 1. Sequencing and rationale

| Phase | Axis | Effort | Key deliverables | Why this position |
| --- | --- | --- | --- | --- |
| **UI-0** | Identity foundation ([08](08-design-vision.md)–[13](13-advanced-surfaces.md)) | M–L | Tokens v2 (`Palette`/`Materials`/`Measure` + contrast gate), the **Iris app icon end-to-end** (verified zero-icon gap → `.icns` + pipeline + plist + bundle step), `AuraDesign.Motion` vocabulary, sound decision scaffold | Everything downstream consumes this vocabulary; the icon is the highest-visibility, zero-behavior-risk item (no Swift/test surface) and lands **first** as the identity proof-of-concept |
| **UI-1** | Conversation experience | L | Markdown bubbles, draft bubble, auto-scroll, thinking indicator, `AudioLevelBridge` + composer waveform, ambient canvas + Orb | Highest user-time surface; strongest test protection around it (lowest regression risk); produces the shared level bridge |
| **UI-2** | Live status feedback | S–M | Animated pill transitions, listening pulse, TTS-driven equalizer, emergency badge, Reduce Motion helper | Consumes `AudioLevelBridge` from UI-1 immediately; small, self-contained |
| **UI-3** | Information architecture | L | Sidebar navigation, task progress rings, latency sparklines + **telemetry deck**, `AuraStatusRow`, **⌘K command palette** | Bigger structural change; benefits from stabilized component library after UI-1/2; the AppleScript driver re-validation is safest once visual churn settles |
| **UI-4** | Settings restructure | S | Category switcher, permission grouping, live confirmation re-test (+ sound preference if adopted) | Small; the live confirmation acceptance is meaningful only after the driver work in UI-3 |
| **UI-5** | Onboarding redesign | M | Visual stage flow, segmented indicator, copy migration (~26 keys), Iris signature moment | Pure presentation; last so it inherits the final component language |

Effort scale: S ≈ one focused session; M ≈ a few sessions; L ≈ phased work with its own internal checkpoints. Estimates assume the repo's verification discipline (full suite reruns) is followed for each phase.

**UI-0 internal order:** (1) icon pipeline ([10 §4](10-icon-identity.md)) — shippable independently, no Swift changes; (2) tokens v2 + contrast unit-test gate ([09 §6](09-visual-language.md)); (3) `Motion` tokens + Reduce Motion helper ([11](11-motion-system.md)); (4) sound decision point ([12 §8](12-sound-design.md)) — vocabulary and preference scaffold only, adoption decided by the ADR.

## 2. Per-phase acceptance gate (definition of done)

A phase is complete when **all** of the following hold:

1. `./scripts/aura-test.sh` full loop green, each bundle rerun 2–3×, evidence (pass counts, failed-bundle grep output) captured for the ledger.
2. New unit tests for every new component/logic path land in the matching test target (`Tests/AURAIntegrationTests/` for view-level work).
3. All pinned suites named in [06 §7](06-cross-cutting-constraints.md) pass **unchanged**, or a deliberate, ADR-documented test update accompanies the change.
4. Live acceptance performed via `scripts/sp011-acceptance/aura-drive.applescript` for touched interactive surfaces (plus the manual visual checks each phase doc specifies), recorded in `ledger/PROJECT_LEDGER.md`.
5. ADR written to `docs/decisions/ADR-NNN-*.md` per template.
6. `ledger/CURRENT_STATE.md` atomically rewritten.
7. Commit/push only on explicit go-ahead in that turn; staged by explicit file path; direct to `origin/main`.

**UI-0 additions to the gate** (per [10 §5](10-icon-identity.md) and [09 §6](09-visual-language.md)):

- Icon: `.icns` present at `AURA.app/Contents/Resources/`, `CFBundleIconFile` in the plist, app relaunches with the icon via a *fresh bundle path* (Dock cache discipline), 16 px legibility on light and dark desktops, tinted-mode survival, screenshots at 16/32/128/512 as ledger evidence.
- Tokens: the WCAG contrast unit-test gate (body ≥ 7:1, meta ≥ 4.5:1, graphical ≥ 3:1, both color-scheme variants) is green and part of the standing suite.
- Motion: every new animation names its physical cause in review; Reduce Motion renders the Orb as a still readout, never blank.

## 3. Dependency notes

- **Volume I → Volume II:** UI-1…UI-5 consume the UI-0 vocabulary (tokens, motion, Orb, hero surfaces). Phases may still be implemented independently, but each inherits whatever vocabulary exists at its start — landing UI-0 first avoids re-skinning the same surfaces twice.
- `AudioLevelBridge` (UI-1 §4.5) is the only cross-phase hard dependency. If UI-2 is pulled before UI-1, the bridge migrates into UI-2 and UI-1 consumes it — one or the other must own it; do not build two metering paths.
- `AuraStepIndicator` (UI-5) and `AuraStatusRow`/`AuraSparkline` (UI-3) are independent additions to `AuraDesign`; no ordering constraint beyond aesthetic convergence.
- The icon pipeline ([10 §4](10-icon-identity.md)) has **no dependency on any Swift or test work** and can land before, with, or after UI-0's token work.
- No phase touches the master roadmap's numbered phases (18+, computer-use track); the `UI-` prefix keeps the two tracks disjoint.

## 4. Risk register (cross-phase)

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| AppleScript driver breaks on restructured view hierarchies | Medium | High (acceptance track blocked) | Identifiers preserved by contract ([06 §1](06-cross-cutting-constraints.md)); run driver legs at the end of every phase, not just UI-3 |
| Copy table growth invalidates the 150-key guard assumptions | Low | Low | Guard is a floor, not a ceiling; new keys come with tests |
| `NavigationSplitView` changes keyboard/tab order | Medium | Medium | Verify full keyboard traversal live; the fail-closed confirmation shortcuts (`.cancelAction`/`.defaultAction`) re-tested in UI-4 |
| Motion work introduces performance cost on high-frequency signals | Medium | Medium | Animate only on discrete flags; `inputLevel` drives transform effects only ([03 §7](03-live-status-feedback.md), [11 §5](11-motion-system.md)) |
| Dock icon cache shows a stale glyph after the icon lands | Medium | Low (cosmetic) | Verify via a fresh bundle path, not an in-place rebuild ([10 §5](10-icon-identity.md)) |
| Owned palette (biolume) diverges from user expectations across appearances | Medium | Medium | System accent retained for interactive controls ([09 §3.2](09-visual-language.md) decision); contrast gate in both variants |
| Sound adoption annoys long-term users | Medium | Medium | Default off; ≤ 120 ms wake grain; kill switch ([12 §7](12-sound-design.md)) |
| Scope creep toward token streaming | High | Medium | Explicitly out of scope ([06 §8](06-cross-cutting-constraints.md)); revisit as its own backend-phase proposal |
| Two tracks (roadmap phase 18 computer-use and UI track) touching `AuraAppModel` concurrently | Medium | Medium | Sequence UI phases within one track; rebase discipline per commit; `CURRENT_STATE.md` names the active track |

## 5. Immediate next step

Awaiting user decision: approve the sequencing above as-is (recommended: UI-0 starting with the icon), reorder, or descope. On approval, implementation begins with the phase-gate startup sequence from `AGENTS.md` (read `ledger/CURRENT_STATE.md` and `ledger/PROJECT_LEDGER.md` fresh, state objective/risks/acceptance criteria, then implement).
