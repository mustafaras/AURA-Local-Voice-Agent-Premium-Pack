# EV-SP-015-20260822-WAKE-EXCLUSION-01

| Field | Value |
|---|---|
| Evidence ID | `EV-SP-015-20260822-WAKE-EXCLUSION-01` |
| Prompt | SP-015 — Wake-Word Decision and Evaluation (`OPEN-08/R7`) |
| Gap | OPEN-08 (R7: Wake Word, STT/TTS Routing, and Resource Governor) — wake-word qualification/exclusion decision |
| Timestamp | 2026-08-22T17:30:00Z |
| Session ID | `AURA-SP-015-WAKE-EXCLUSION-20260822` |
| Commit | `389ea344652d3d1d8211e6ce244f909eff42bc6e` (clean, `HEAD == origin/main`) |
| Branch | `main` |
| Environment | macOS 27 / Apple Silicon arm64, Swift 6.4, Git 2.54.0 |

## Class

Manual review + system test + static inventory audit. The decision is an
**explicit exclusion** because the authority available to this pass cannot
lawfully obtain or evaluate a licensed local wake-word candidate.

## Objective

Make one evidence-backed decision (SP-015 Procedure step 3): qualify a real
local wake word, or explicitly exclude it from the release scope with truthful
UI and no wake-word claim.

## Authority

- `edit: true`
- `download_models: false` — a licensed local candidate **cannot** be downloaded.
- `install_dependencies: false` — no engine/runtime can be installed.
- `provider_accounts: false`
- `commit/push/merge/release_or_deploy: false`
- `mutate_permissions: false`

## Direct evidence collected

1. **No wake model inventory existed** before this prompt; one is now created at
   `AURA_RUNTIME_COMPLETION/context/WAKE_MODEL_INVENTORY.md`.
2. **No wake-word model artifact is bundled.** `find . \( -name '*.mlmodel' -o
   -name '*.mlmodelc' -o -name '*.tflite' -o -name '*.onnx' -o -name '*.bin' \)`
   returns only Chatterbox ONNX library conformance fixtures (operator tests),
   not wake-word models.
3. **No `ADR-042` file exists** anywhere in the repository; the decision register
   references `docs/decisions/ADR-042-voice-routing-resource-governor.md`, which
   is absent. ADR-042 remains `Proposed` and cannot be accepted in this pass.
4. **Production detector is `DisabledWakeWordDetector`** wired in
   `Sources/AURA/AuraKernel_Construction.swift`; it cannot detect. `MarkerWakeWordDetector`
   is explicitly test-only (ADR-003, capability-matrix notes).
5. **Truthful UI already present:**
   - `AuraMenuView.swift` "Activation: Push to Talk"; "A trained acoustic
     wake-word model is not installed."
   - Onboarding stage `.wakeWord`: "no acoustic model is installed in this
     configuration, so Push to Talk remains available."
   - `AuraAppModel_Runtime.swift` warning: "Acoustic wake-word model unavailable;
     use Push to Talk."
6. **Baseline tests pass:** `python3 scripts/validate_second_pass_program.py` →
   `SECOND-PASS VALIDATION PASSED`; `AuraAudioTests` 35/35 (includes
   `disabledWakeDetectorNeverClaimsProductionActivation`), 0 failed bundles.

## Result

**Wake word is explicitly excluded from the release scope.** No licensed local
candidate is provisioned or bundled, and the active authority forbids
`download_models`/`install_dependencies`, so qualification is not lawfully
possible in this pass. Production remains Push-to-Talk-only, the UI truthfully
states no acoustic model is installed, and no wake-word claim is made.

## Verdict

`passed` (the exclusion decision is made and truthfully recorded).

## Limitations

- This is an **exclusion**, not a qualification. If the user later grants
  `download_models`/`install_dependencies` and supplies a licensed local
  candidate with Turkish support, FAR/FRR, noise/distance, self-trigger,
  license/hash, and soak evidence, wake word may be re-evaluated and enabled.
- No live microphone/hardware wake evaluation was performed (none possible
  without a model asset).
- ADR-042 remains `Proposed`; this exclusion does not accept it.

## Falsification

The conclusion "wake word is excluded" would be falsified if a licensed local
wake-word model artifact were found in the repo and wired to a detector, or if
the UI claimed wake-word activation was available when no detector can fire.
