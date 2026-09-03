# EV-SP-021-20260825-VOICE-CHATTERBOX-PRIMARY-05

- **Evidence ID:** `EV-SP-021-20260825-VOICE-CHATTERBOX-PRIMARY-05`
- **Prompt / gap:** SP-021 / OPEN-10 / R9 (voice routing correction, user direction)
- **Timestamp:** 2026-08-25T18:30:00Z
- **Branch / commit:** `main`; working tree has uncommitted voice-routing edits
- **Class:** Direct source routing change + deterministic regression + full-suite proof
- **Environment:** macOS 27 / Apple Silicon / Swift 6.4 via `scripts/aura-test.sh` (isolated `/tmp` build path)

## User direction

The user explicitly directed that **Chatterbox is the primary voice** and that
no Apple system voice (Kaan or Yelda) be used as AURA's voice. A prior change
had made the premium neural Kaan system voice the default/fallback; this
correction reverses that so the local Chatterbox adapter is primary and the
system synthesizer is only an auto-selected fail-closed last resort.

## Changes

1. `Sources/AuraCore/TTSEngine.swift` — `TTSAdapterChain()` default is now
   `["chatterbox", "system"]` (previously `["system"]`).
2. `Sources/AuraCore/Configuration_TTSConfiguration.swift` — the
   `preferredSystemVoiceIdentifier` default is now empty (was Kaan's
   identifier), so the system fallback auto-selects the best installed voice
   for the locale by platform quality; no specific system voice is hardcoded
   or preferred.
3. `Sources/AuraAudio/ChatterboxTTSEngine.swift` — fallback is now a plain
   `SystemTTSEngine()` (no hardcoded Kaan identifier).
4. `Sources/AuraAudio/ChatterboxTTSEngine_API.swift` — diagnostic strings
   changed from "Kaan fallback" to neutral "system fallback".
5. Tests: `releaseTTSDefaultIsSystemOnly` renamed to
   `releaseTTSDefaultIsChatterboxFirstSystemFallback` and asserts the new
   default; a `SystemTTSEngine` comment no longer calls Kaan "the product's
   configured fallback".
6. Docs/ADRs: `docs/subsystems/07_TURN_TAKING_AND_TTS.md`,
   `docs/decisions/ADR-031…md`, `docs/decisions/ADR-042…md`, `README.md`,
   and `ledger/CURRENT_STATE.md` updated to describe Chatterbox as primary
   with an auto-selected system last resort.

## Result

`scripts/aura-test.sh` full suite: **21/21 bundles PASSED, 0 failed**
(`AuraCoreTests`, `AuraStoreTests`, `AURAIntegrationTests`, `AuraAudioTests`,
`AuraAutomationTests`, `AuraAgentTests`, `AuraSTTTests`, `AuraPolicyTests`,
`AuraShellTests`, `AuraComputerUseTests`, `AuraSecurityTests`,
`AuraPluginsTests`, `AuraIntentTests`, `AuraConfigTests`, `AuraVSCodeTests`,
`AuraTasksTests`, `AuraMemoryTests`, `AuraContextTests`, `AuraScreenTests`,
`AuraAdversarialTests`, `AuraProductivityTests`).

`python3 scripts/validate_second_pass_program.py` → **SECOND-PASS VALIDATION
PASSED**.

## Limitations / residual risk

- The live Chatterbox neural synthesis and human-listening acceptance remain
  separate product gates (ADR-031 final acceptance is still open).
- The system fallback remains available on-device as a fail-closed last resort;
  it is not presented as the approved AURA voice.
