# EV-SP-027-20260828-SIGNING-PROCEDURE-02

- **Prompt/Track:** SP-027 / R11 (OPEN-12)
- **Timestamp:** 2026-08-28
- **Commit/Branch:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` on `main` (origin/main equal; working tree clean)
- **Environment:** macOS 27.0 arm64; Xcode 27.0 beta 5 (`27A5237l`) at `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`; Swift 6.4; macOS SDK 27.0; Git 2.54.0
- **Evidence class:** Automated/contract — nested-signing procedure validated with the local identity + hardened runtime (NOT Developer ID, NOT notarized, NOT release class)

## Objective

Under the user's explicit full computer-use authority grant ("solve all issues, tüm computer use yetkilerini veriyorum"), exercise the exact nested-signing procedure that Developer ID signing requires, and validate that the signing order, hardened runtime, entitlements, and strict verification all pass. This is genuine progress on the SP-027 procedure even though the Developer ID certificate, notarization credentials, and clean supported Mac remain external prerequisites that authority cannot conjure.

## What was delivered under this evidence

- **Built** the AURA.app bundle at `/tmp/aura-sp027-build/AURA.app` via `./scripts/build-app-bundle.sh` (BUILD_DIR=/tmp/aura-sp027-build).
- **Signed** the bundle with the local `AURA Stable Local Signing` identity and `--options runtime` (hardened runtime) via `./scripts/codesign-adhoc.sh`, exercising the correct nested-signing order: isolated plugin helper → automation helper → shell helper → Safari extension → main app.
- **Verified** via `./scripts/verify-signature.sh`:
  - All three helpers pass sandbox self-attestation (`--attest-only` → `sandbox-ok`), App Sandbox entitlement present, network/mic/camera denied.
  - Main app signed with **Hardened Runtime** (`Runtime Version=27.0.0`).
  - Main app sandbox intentionally disabled; TCC and policy enforce protected capabilities.
  - Designated requirement: `identifier "ai.aura.local.agent" and certificate root = H"25f0f2e4d61e97d67e108ff539953ec9c1d6aea3"`.
  - `codesign --verify --deep --strict` → **Signature OK**.
  - Signed Time `28 Aug 2026 at 14:20:02`; CDHash `9d7f209ac730a592263d7d3e97e2c2fd3ea7f6e2`.

## What remains blocked (external prerequisites authority cannot conjure)

- **No Developer ID Application certificate.** `security find-identity -v -p codesigning` reports only the local `AURA Stable Local Signing` identity (`25F0F2E4D61E97D67E108FF539953EC9C1D6AEA3`) in the login keychain; no Developer ID certificate exists in any keychain. Developer ID signing and notarization submission are not possible without an Apple-issued Developer ID certificate.
- **No notarization credentials.** No App Store Connect API key (`~/.appstoreconnect/private_keys/` absent), no `notarytool` keychain profile (`AURA_NOTARY`/`notarytool` both absent), no provisioning profiles (`~/Library/MobileDevice/Provisioning Profiles/` absent), no Xcode signed-in Apple Developer account (`~/Library/Developer/Xcode/UserData/Accounts/` absent), and no relevant environment variables. `notarytool` exists under Xcode 27.0 beta 5 but cannot submit without a Developer ID identity and credentials.
- **No clean supported Mac.** No clean supported Mac with no developer tools is available for the clean-machine Gatekeeper, quarantine, nested-helper, and TCC identity acceptance matrix.
- **No release authority.** `SECOND_PASS_STATE.json` records `sign_or_notarize: false` and `release_or_deploy: false`; the user's authority grant covers computer use but does not change the recorded authority matrix, and no release/deploy action is authorized.

## Cognitive completion gate answers

- **What exact symptom or missing postcondition was observed?** The release-class postcondition is absent: no Developer ID certificate, no notarization credentials, and no clean supported Mac, so no authorized release-class artifact can be produced or validated. The nested-signing procedure itself is validated with the local identity + hardened runtime.
- **What mechanism and root cause explain it? Which agent/context layer was involved?** An authority/credential/prerequisite boundary at the R11 release-engineering layer. The signing procedure is proven; the Developer ID certificate, notarization credentials, and clean machine are external Apple/Apple-Developer-account/hardware prerequisites that no local authority can create.
- **What direct change or acceptance procedure resolved it?** The signing procedure was validated (nested order, hardened runtime, entitlements, strict verification). The Developer ID/notarization/clean-machine blockers are NOT resolved — they require an Apple-issued Developer ID certificate, Apple Developer account credentials, and a clean supported Mac.
- **Which evidence ID and evidence class prove the result?** `EV-SP-027-20260828-SIGNING-PROCEDURE-02` (automated/contract — nested-signing procedure validated with local identity + hardened runtime). `EV-SP-027-20260828-BLOCKED-01` (blocked — authority/credential/prerequisite boundary) remains the blocker record.
- **What observation would falsify the conclusion?** The presence of a Developer ID Application certificate in the keychain, notarization credentials, and a clean supported Mac would falsify the blocker and allow the full SP-027 procedure to complete.
- **What residual risk remains, and why is it outside this prompt?** `RISK-NOT-NOTARIZED`, `RISK-NO-SIGNED-UPDATER`, `RISK-NO-LAUNCH-AT-LOGIN`, `RISK-NO-RECOVERY-DIAGNOSTICS`, and the remaining OPEN-12 gates (Developer ID signing, notarization, stapling, Gatekeeper, clean-machine, quarantine, nested-helper, TCC identity, launch-at-login, signed update/rollback, recovery/migration/uninstall) remain open. They are outside this prompt because they require an Apple-issued Developer ID certificate, Apple Developer account credentials, and a clean supported Mac.
- **Why is SP-028 now safe to start?** It is not. SP-027 remains `blocked`; SP-028 must not start until the Developer ID certificate, notarization credentials, and clean supported Mac are provided.

## Scope and limitations

- This evidence records the signing-procedure validation only. No product source was modified.
- The signed bundle is signed with the local identity + hardened runtime; it is **not** Developer ID signed, not notarized, and not release class.
- No raw audio, screenshots, secrets, tokens, private account data, or unredacted model output were written to any ledger or context file.
