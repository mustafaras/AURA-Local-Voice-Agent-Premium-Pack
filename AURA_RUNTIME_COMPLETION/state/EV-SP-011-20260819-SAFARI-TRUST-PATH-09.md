# EV-SP-011-20260819-SAFARI-TRUST-PATH-09

## Record

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-19T13:05:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 6d5e57786a793153798a000bdf8f1434e874837a` at the start of this attempt
- **Environment:** macOS 27.0 (26A5416b), Safari 27.0, Xcode 27.0 beta 5, Apple Silicon; user-present session with full computer-use authority
- **Evidence class:** direct user-present UI/system-log evidence plus deterministic source-side regression

## Objective

Close the remaining SP-011 legs — approved-page summary, browser injection-ignore, browser revocation — by enabling the packaged Safari Web Extension and driving one real observation through it.

## What was achieved live

1. **`Allow unsigned extensions` is enabled.** The Touch ID / password sheet recorded as the blocker in `EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08` has been answered; Safari's Developer pane shows the toggle checked. That blocker is closed.
2. **The extension loads and runs.** "AURA Safari Read Bridge" appears under Safari Settings › Extensions, was enabled (checkbox `0 → 1`), and its toolbar button — "Send this tab's visible text to AURA" — is present on a real browser window.
3. **Native messaging works end to end.** Pressing that button on `https://example.com` launches the extension's native half: `AuraSafariExtensionHandler[72972]` appears in the process table, and its own log shows `Identity resolved as xpcservice<ai.aura.local.agent.SafariExtension([app<application.com.apple.Safari…>])>`. The JavaScript → appex path is proven.
4. **The bridge secret provisions from the product's own control.** Clicking `Connect Safari profile` moved the row from "not provisioned" to `personal / Degraded — Safari extension or shared container is unavailable`, with a `Disconnect` action. That is the truthful state for a provisioned bridge that has not yet received an observation.

## The blocker, now diagnosed exactly

No envelope is ever written, and the cause is architectural rather than a missing click.

1. **Safari requires the extension to be App Sandbox confined.** Proven both ways: `pluginkit -m -p com.apple.Safari.web-extension` returns `(no matches)` without `com.apple.security.app-sandbox` and lists `ai.aura.local.agent.SafariExtension(0.1.0)` with it.
2. **A sandboxed process reads a different keychain.** The appex's own log records `(Security) SecItemCopyMatching_ios` — the data-protection keychain. `KeychainSecretStore` in the unsandboxed containing app uses the file-based login keychain (`security find-generic-password` confirms the item exists there, class `genp`). The two halves are looking in different stores, so `SafariBridgeEnvelopeWriter` fails at `notProvisioned` and writes nothing.
3. **Bridging them needs a restricted entitlement.** Adding `keychain-access-groups` plus `com.apple.application-identifier` to both executables made the app refuse to start: `RBSRequestErrorDomain Code=5 "Launch failed" … NSPOSIXErrorDomain Code=163 "Launchd job spawn failed"`. Those keys, and `com.apple.security.application-groups` (the App Group alternative for a shared file), all require a provisioning profile.
4. **This machine has no Team ID.** `security find-identity -v -p codesigning` lists only the self-signed `AURA Stable Local Signing`; there is no `~/Library/MobileDevice/Provisioning Profiles` directory and no provisioning profile anywhere.

**Therefore the SP-009 shared-secret bridge design cannot be exercised on a locally signed build.** The earlier records attributed this leg to an unanswered Touch ID prompt; that was true but not the whole cause, and it is no longer the binding one.

## Direct changes retained

- `Resources/AuraSafariExtension.entitlements` — App Sandbox (required by Safari) plus a `com.apple.security.temporary-exception.files.home-relative-path.read-write` scoped to exactly `/Library/Application Support/AURA/SafariBridge/`. Without it the sandbox redirects the extension's writes into its own container, which macOS protects from every other process — including the containing app that has to read the envelope.
- `Sources/AuraCore/Configuration_ProductivityConfiguration.swift` — `safariSharedContainerRelativePath` and `defaultSafariSharedContainerPath` now name that Application Support file, which both halves can reach. The previous default pointed into the extension's sandbox container, which the app cannot read.
- The `SP011LiveAcceptanceReadinessTests` case for the container path now asserts that the extension's `AURASharedContainerPath`, the app's default, and the sandbox exception's directory all agree.

A `keychain-access-groups` implementation was written, tested against a real launch, shown to break startup on this signing identity, and **reverted** rather than left in the tree as unusable code. The finding is recorded here instead.

## Two ways forward

1. **Apple Developer Program enrollment.** A Team ID makes the intended design work as written: an App Group for the shared file and a keychain access group for the shared secret, plus Developer ID signing and notarization that also remove the `Allow unsigned extensions` requirement. This is R11 territory.
2. **Remove the shared secret.** Have the extension generate a signing key pair, keep the private key in its own keychain (no sharing needed), publish only its public key to the shared directory, and have the app pin that key when the user connects the profile. Envelopes are then signed asymmetrically. This needs no Team ID and is strictly stronger than a shared HMAC key — but it replaces the `SafariBridgeAuthenticator` design that SP-009 delivered under its own ADR and evidence, so it is a security-architecture decision rather than a mechanical fix.

## Deterministic verification

- `./scripts/aura-test.sh /tmp/aura-sp011-final4` — **21/21 bundles, 1035/1035 tests, 0 failed**.
- All four governance validators exit 0; 38/38 governance unit tests pass.

## Falsifier

This conclusion is falsified if the extension can read the containing app's keychain item without a provisioning profile, if the app launches with `keychain-access-groups` under a self-signed identity, if an unsandboxed process can read `~/Library/Containers/<extension-id>/Data` without Full Disk Access, or if Safari registers a web extension that is not App Sandbox confined.

## Verdict

**SP-011 remains `blocked`.** The Touch ID blocker is closed and the extension now loads, runs, and reaches its native half. The approved-page summary, browser injection-ignore, and browser revocation legs remain unproven, blocked on a decision between Developer Program enrollment and an asymmetric bridge redesign. SP-012 is not safe to start.
