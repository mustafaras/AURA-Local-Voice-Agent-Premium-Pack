# EV-SP-016-20260822-RECOVERY-MATRIX-04 — SP-016 voice recovery matrix: correction and closure

## Record

- **Evidence ID:** `EV-SP-016-20260822-RECOVERY-MATRIX-04`
- **Timestamp:** 2026-08-22T23:10:00Z
- **Branch / commit:** `main`; parent `e2ddcaff352c523560e661625e0072befc9df0b6`.
- **Prompt / gap:** `SP-016` / `OPEN-08` (R7).
- **Evidence class:** Deterministic system tests against the real `AuraAudio` actor with live audio hardware, plus a coverage audit of the named recovery legs.
- **Trigger:** operator re-verification request ("tam ve kusursuz olduğundan emin ol"). This record exists because that audit found two real defects in the immediately preceding closure.

## Correction 1 — the prior record's blocker was false

`EV-SP-016-20260822-BILINGUAL-QUALITY-03` states that
`AuraAudio.handleConfigurationChange` could not be tested because reaching
`state == .running` "requires a real `AVAudioEngine` input node and therefore a
**Microphone** grant for the test host, which this attempt's authority
deliberately excludes (Speech only)".

**That is wrong.** It was asserted from the shape of the code rather than
checked. A one-line diagnostic showed `AuraAudio.start()` reaching `.running`
in the SwiftPM test host on this machine, so the recovery path was ordinary,
deterministically testable code the whole time. No additional TCC authority was
needed, and none was taken.

The mistake has the same shape as the one that record itself corrected — an
"unverifiable" verdict inferred instead of executed. The pre-existing
permissive test at `Tests/AuraAudioTests/AuraAudioTests.swift` concealed it by
accepting either `.running` or `.idle`, so nothing in the suite ever asserted
which one actually happened.

## Correction 2 — sleep/wake recovery did not exist

SP-016's Procedure step 2 names sleep/wake explicitly. A search for
`willSleep` / `didWake` / `NSWorkspace.*[Ss]leep` across `Sources/` returned
**nothing**: there was no sleep/wake handling anywhere in the product.
`NSWorkspace` was used only by automation and computer-use code.

The previous pass marked SP-016 `completed` while this leg was neither
implemented, nor tested, nor excluded — which the prompt's Stop condition
forbids. That verdict was not adequately supported.

## Direct change

- **`Sources/AuraAudio/AuraAudio.swift`:** added `sleepWakeTask` and
  `shouldResumeAfterWake`.
- **`Sources/AuraAudio/AuraAudio_Capture.swift`:** added `observeSleepWake()`,
  `handleSystemWillSleep()`, and `handleSystemDidWake()`, started alongside the
  existing configuration-change observer and torn down in `stop()`.
  - On sleep, capture is deliberately suspended: the engine is stopped, the tap
    removed, the privacy indicator cleared, and a **recoverable** capture error
    emitted. Without this, sleep tears the hardware down underneath a running
    engine and the tap comes back dead while the actor still reports
    `.running` — the user presses Push to Talk, gets silence, and concludes the
    agent ignored them.
  - On wake, capture resumes **only** if `shouldResumeAfterWake` was set by an
    actual sleep suspension. `stop()` clears the flag and cancels the observer,
    so an explicit user stop can never be undone by a later wake.
- **`Tests/AuraAudioTests/SP016DeviceRecoveryTests.swift`** (new, 4 tests).

## Recovery matrix status — every leg named by Procedure step 2

| Leg | Status | Where |
|---|---|---|
| Barge-in | Covered | `ConversationTests` (incl. grace-window suppression) |
| Assistant self-trigger protection | **Not applicable in shipped scope** | Production is Push-to-Talk only (SP-015 excluded wake word), so the microphone opens only on an explicit press and the assistant cannot self-trigger. The wake path's `enableAntiTriggerProtection` exists but is excluded from release. |
| Headset / device switching | **Covered this pass** | `SP016DeviceRecoveryTests` — recovers to `.running` and reports the change as recoverable; and never reopens capture after an explicit stop |
| Sleep / wake | **Implemented + covered this pass** | `SP016DeviceRecoveryTests` — suspends on sleep, resumes on wake, and never reopens after a user stop |
| Interruption | Covered | `ConversationTests`, `SystemTTSEngineTests`, `ChatterboxTTSEngineTests` |
| Cancellation | Covered | `ConversationTests`, TTS engine suites |
| TCC revocation | Covered (fail-closed) | `SystemSTTEngineTests` — `denied`/`restricted`/`notDetermined` all refuse to start rather than degrade silently |
| Helper crash recovery | Covered | `ChatterboxTTSEngineTests` — bounded timeout with system-voice fallback |

## Command / procedure

- `swift test --filter SP016DeviceRecoveryTests` → **4/4 PASS**.
- `./scripts/aura-test.sh` → **21/21 bundles, Failed bundles: 0**, run **twice** with identical results (flakiness check). Output redirected to a file and grepped, never piped through `tail`.
- All four governance validators exit 0; `python3 -m unittest discover -s scripts/tests` → **38 tests OK**.

## Falsification test

- Removing the sleep/wake observer makes `sleepSuspendsAndWakeResumesCapture`
  fail: without it the actor stays `.running` across a sleep notification.
- Removing the `shouldResumeAfterWake` reset in `stop()` makes
  `wakeAfterUserStopNeverReopensCapture` fail — the microphone would reopen
  after a user stop, which is the privacy failure this leg exists to prevent.
- Removing the configuration-change handler makes
  `configurationChangeRecoversCapture` fail.

## Residual risk — what is still genuinely open

`RISK-VOICE-RECOVERY-LIVE` **remains Open**, but its content is now narrower
and precise. Every named leg is implemented and deterministically covered; what
is missing is **physical** verification:

- No headset is actually unplugged and no real CoreAudio route change occurs —
  the tests post `AVAudioEngineConfigurationChange` directly, exercising AURA's
  reaction to the notification, not CoreAudio's decision to send it.
- The machine is not actually put to sleep; `NSWorkspace` sleep/wake
  notifications are posted directly.
- Acoustic barge-in and echo/self-transcription over a real speaker-to-mic path
  are not exercised, and cannot be without a speech-capable operator.

Closing that requires a user-present session with physical acts, not more
authority.

## Artifact paths

- `Sources/AuraAudio/AuraAudio.swift`, `Sources/AuraAudio/AuraAudio_Capture.swift`
- `Tests/AuraAudioTests/SP016DeviceRecoveryTests.swift`

## Limitations

Notification-driven, not hardware-driven (see residual risk). The sleep/wake
implementation is new in this pass and has never run through a real sleep cycle
on this machine.
