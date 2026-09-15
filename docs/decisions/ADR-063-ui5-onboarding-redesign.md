# ADR-063: UI-5 Onboarding Redesign — Guided Stages and Iris Signature

- Status: Accepted — local UI-5 plan verification complete; plan closure pending
- Date: 2026-09-15
- Owners: UI track (UI-5)
- Supersedes: none
- Superseded by: —

## Context

The existing onboarding surface exposed the correct reducer-owned 13-stage
sequence but presented it as a single progress bar with inline bilingual
strings. UI-5 requires a visual guided flow, a segmented step overview, an
Iris signature moment, and copy-table ownership without changing onboarding
behavior or persistence.

## Decision

1. **Presentation-only stage flow.** `AuraOnboardingView` renders the existing
   `AuraOnboardingStage` values in a two-column guided layout. Stage order,
   optionality, reducer actions, persistence, and existing accessibility
   identifiers remain unchanged.

2. **Segmented progress.** `AuraStepIndicator` is an additive design-system
   component with 13 segments. Optional unvisited stages use the existing
   cautious token; completed/current stages use biolume; accessibility Dynamic
   Type receives a readable text fallback. The indicator is one combined
   accessibility element with the stable identifier
   `aura.onboarding.stepIndicator`.

3. **Copy ownership.** The onboarding explanation and primary-label strings
   move into 21 genuine English/Turkish `AuraCopy` keys. No inline language
   ternary remains in the onboarding section, and no string is synthesized as
   a success result.

4. **Iris signature and motion.** The existing `AuraOrb` is reused at hero
   scale with the existing `motion.emergent` vocabulary. The existing
   Reduce Motion choke point remains authoritative; when Reduce Motion is on,
   the Orb is static and its live Iris readout remains visible.

5. **No new product state.** The step indicator and Orb presentation are
   view-local. No onboarding preference, schema field, or persistence key is
   added.

## Security and privacy impact

No remote transport, audio capture, screenshot transmission, permission
bypass, new permission state, or policy path was added. The voice permission
step still calls the existing permission coordinator, and the emergency-stop
step still uses the existing stop/re-arm behavior.

## Validation evidence

- G5-1: `PHASE_LEDGER.md` SEQ-0066 — all 13 stages construct in both
  languages; the frozen R9 stage-machine test file remains byte-for-byte
  unchanged.
- G5-2: SEQ-0067 — all 13 indicator positions construct; accessibility-size
  fallback, hidden visual segments, relative typography, and stable ID are
  asserted.
- G5-3: SEQ-0068 — all 21 migrated keys match the exact English/Turkish
  contract; onboarding contains no inline `language == .turkish` ternary.
- G5-4: the current-source temporary bundle was tested with macOS Reduce Motion
  on and off. With the switch on, AppKit reported `true`, the live driver
  found `aura.onboarding.irisReadout` with value `Iris enstrümanı. Boşta`, and
  the 13/13 completion view remained static. The switch was returned to off;
  after preference propagation, `defaults ... reduceMotion` was `0` and the
  AppKit accessor was `false`.
- G5-5: the temporary current-source bundle completed a driver-controlled
  first-run traversal through stages 0–12: required stages advanced through
  existing actions, optional stages used Skip, Emergency Stop used Stop then
  re-arm, and stage 12 closed safely. The temporary `aura.ui.state` was backed
  up and restored exactly.
- G5-6: `swift build` exited 0; full `./scripts/aura-test.sh` runs
  `/tmp/aura-ui5-g56-run1`, `/tmp/aura-ui5-g56-run2`, and
  `/tmp/aura-ui5-g56-run3` each exited 0 with `Failed bundles: 0`; each
  AURAIntegrationTests run reported 202 tests / 34 suites. `git diff --check`
  and the continuity validator are green.

## Consequences and residual risks

The onboarding flow now communicates stage position, optionality, and Iris's
real runtime readout with stronger visual hierarchy and accessibility support,
while the reducer and persistence contract remain stable. The temporary
stable-signed bundle is local evidence only; it does not establish Developer
ID signing, notarization, hosted CI, beta/RC, external publication, or release
approval. The archived runtime-completion governance mismatch remains at 96
tests / 95 passes with one frozen `verified_head` error and was not rewritten.
