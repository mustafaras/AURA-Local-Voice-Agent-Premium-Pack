# EV-SP-030-20260830-LOCAL-DEPLOY-01

**Evidence ID:** EV-SP-030-20260830-LOCAL-DEPLOY-01
**Track:** SP-030 / R12 / OPEN-13 (local-only deploy under SP-027 scope)
**Type:** System/launch — local-only deploy of the signed AURA.app bundle (build + sign + launch smoke)
**Commit:** `6ef97e8` (`main == origin/main`; clean working tree at deploy)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6, Git 2.54.0
**Session:** AURA-SP-029-BETA-CONTRACT-20260829
**Authority:** The release owner explicitly granted deploy authority ("deploya da yetki veriyorum") on top of the prior program grants. This deploy is **local-only** per the SP-027 decision; external distribution (Developer ID, notarization, public release) is out of scope and not claimed.

## What was deployed

A local-only AURA.app release bundle, built, signed with the local `AURA Stable Local Signing` identity + hardened runtime, verified, and launch-smoked in an isolated home directory:

- **Build:** `BUILD_DIR=/tmp/aura-sp030-deploy scripts/build-app-bundle.sh` → `Built /tmp/aura-sp030-deploy/AURA.app` (product + plugin host + automation/shell helpers + Safari extension).
- **Sign:** `scripts/codesign-adhoc.sh /tmp/aura-sp030-deploy/AURA.app` → nested signing (plugin helper → automation helper → shell helper → Safari extension → main app) with the local identity + hardened runtime.
- **Verify:** `codesign --verify --deep --strict AURA.app` → **SIGNATURE-OK**.
- **Launch smoke:** launched in isolated `CFFIXED_USER_HOME`; process **alive after 12 s** (pid captured, then terminated). `spctl --assess --type execute` → **rejected** (expected for a locally-signed non-Developer-ID bundle, per SP-027).

## Deployed artifact

- Path: `/tmp/aura-sp030-deploy/AURA.app`
- Main executable SHA-256: `f9d9ae8cacfcea0195b1d242fdde22d6db966abbde28d06f6af83c3d33bec8aa`
- Bundle inventory: `Contents/MacOS/AURA`; `Contents/Helpers/{AuraPluginHost.app, AuraAutomationHelper.app, AuraShellHelper.app}`.

## Honest scope and limitations

- **Local-only deploy**, not external distribution. No Developer ID signing, notarization, stapling, or public release occurred (no Apple credentials exist; SP-027 local-only scope decision makes external distribution out of scope).
- `spctl` rejects the local-signed bundle (expected); the app is launched directly for local use, not via Gatekeeper distribution.
- This is a launch smoke (`alive 12s`), not a full functional acceptance. It confirms the signed local bundle launches; it is **not** an SP-030 SLO/scenario measurement and does **not** advance `beta-readiness.json` past `blocked`.
- The sandbox-extension warning in the launch log is specific to the isolated-test-HOME capture and does not affect the local-only launch result.

## Authority reconciliation

`current-state.json` and `SECOND_PASS_STATE.json` now set `release_or_deploy: true` (local-only scope); `sign_or_notarize`, `mutate_permissions` (TCC), `install_dependencies`, `download_models`, `provider_accounts` remain `false`.

## Falsifiers

- Any claim that Developer ID signing, notarization, stapling, or external/public distribution occurred would falsify this record — none did.
- Any claim that an SLO was measured, telemetry was transmitted, participant consent was collected, a sign-off was obtained, or `beta-readiness.json` left `blocked` is false.

## Next action

SP-030 remains `in_progress`. The local-only deploy proves the signed bundle launches; the R12 SLO/scenario/incident/sign-off evidence program must still be run in a user-present session, with content-free aggregates only under explicit opt-in, keeping `beta-readiness.json` blocked until SP-030/SP-031 evidence closes the R12 direct-evidence gates.
