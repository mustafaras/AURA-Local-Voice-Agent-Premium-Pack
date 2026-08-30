# EV-SP-027-20260828-LOCAL-LAUNCH-04

- **Prompt/Track:** SP-027 / R11 (OPEN-12)
- **Timestamp:** 2026-08-28
- **Commit/Branch:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` on `main` (origin/main equal; working tree clean)
- **Environment:** macOS 27.0 arm64; Xcode 27.0 beta 5 (`27A5237l`) at `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`; Swift 6.4; macOS SDK 27.0; Git 2.54.0
- **Evidence class:** System — local launch smoke (startup behavior) on the local Mac for the local-only signed artifact

## Objective

Complete SP-027 procedure step 3 (record launch/permission behavior) for the local-only scope: launch the locally-signed AURA.app bundle in an isolated environment and record whether it starts and stays alive.

## What was performed

- **Artifact:** `/tmp/aura-sp027-build/AURA.app`, signed with the local `AURA Stable Local Signing` identity + hardened runtime (`Runtime Version=27.0.0`), in the correct nested order (plugin helper → automation helper → shell helper → Safari extension → main app).
- **Isolated launch:** `CFFIXED_USER_HOME=/tmp/aura-sp027-home` (fresh, isolated profile); ran `$APP/Contents/MacOS/AURA` and observed for 12 seconds.
- **Result:** the process was **ALIVE after 12 seconds** (pid observed), then was stopped by the harness. This is a successful startup smoke — the signed bundle launches and remains running.
- **Hash / provenance binding (procedure step 4):**
  - Main executable SHA-256: `4f043259a246aaa462f9fffdd5feba8fdcaff63d9f9440fe4eea6854a969ecd1`
  - Signed bundle ZIP SHA-256: `4beae2ec0076ee160d75cd3081d595d704649e9f0a035272a3df128ef399d764`
  - Provenance (`codesign -dv`): `Identifier=ai.aura.local.agent`, `Authority=AURA Stable Local Signing`, `Runtime Version=27.0.0`, `TeamIdentifier=not set`.

## Honest limitations

- This is a **startup smoke** on the local development Mac. It proves the signed bundle launches and stays alive; it does **not** prove full UI interaction, microphone/screen/TCC permission prompts, or real voice turns.
- The launch log contained a benign message: `sandbox_extension_issue_file_to_process failed ... (Operation not permitted)` — this is a startup-time informational message under the isolated `CFFIXED_USER_HOME`; the process remained alive and did not crash.
- Per the local-only scope decision (`EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03`), external clean-machine-with-no-developer-tools evidence and Developer ID/notarization are out of scope. This development Mac has developer tools, so no clean-machine-with-no-developer-tools claim is made.
- No raw audio, screenshots, secrets, tokens, private account data, or unredacted model output were written to any ledger or context file.
