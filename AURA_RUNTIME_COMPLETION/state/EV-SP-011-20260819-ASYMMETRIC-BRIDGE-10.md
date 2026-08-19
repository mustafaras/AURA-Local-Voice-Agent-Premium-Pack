# EV-SP-011-20260819-ASYMMETRIC-BRIDGE-10

## Record

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-19T15:31:13Z
- **Branch / commit:** `main`; `HEAD == origin/main == b469c908cfa9fee259e91ec7639340f5f84fd716` at the start of this attempt
- **Environment:** macOS 27.0 (26A5416b), Safari 27.0, Xcode 27.0 beta 5, Apple Silicon; user-present session, full computer-use authority
- **Evidence class:** direct user-present UI/system-log/filesystem evidence plus deterministic source-side regression
- **Authority note:** the user chose the asymmetric redesign over Apple Developer Program enrolment when both were put to them.

## Objective

Remove the Team ID dependency `EV-SP-011-20260819-SAFARI-TRUST-PATH-09` identified, then drive one real observation from the live Safari extension into AURA.

## The redesign

SP-009 authenticated the bridge with an HMAC over a secret both halves held. That is unbuildable on a locally signed Mac: Safari refuses a web extension that is not App Sandbox confined, a sandboxed process's keychain queries are routed to the data-protection keychain while the unsandboxed containing app uses the file-based login keychain, and sharing an item across that boundary needs `keychain-access-groups` — a restricted entitlement that made the app fail to launch (`RBSRequestErrorDomain Code=5`, POSIX 163) under a self-signed identity.

`SafariBridgeAuthenticator` is therefore replaced by a signer/verifier pair:

- The extension generates a P-256 signing key on first use and keeps it in **its own** keychain. Nothing crosses the sandbox boundary, so no shared entitlement is needed.
- It publishes only its **public** key, beside the envelope, as `extension-key.json`.
- The app pins that public key when the user clicks **Connect Safari profile** — trust on first use, where the "first use" is deliberately the user's click. A later key is refused as impersonation until they disconnect and reconnect.
- Envelopes carry an ECDSA signature instead of an HMAC tag. Revocation clears the app's pin; the extension keeps signing, because an unpinned signature is exactly as untrusted as none, and the user cannot be expected to reach into the extension's keychain.

This is strictly stronger than the design it replaces: there is no shared secret to leak, publish, or provision.

## Five further defects found by running it

1. **Sandbox container is unreadable by the app.** A sandboxed extension writing through `NSHomeDirectory()` lands in `~/Library/Containers/<id>/Data`, which macOS protects from every other process. The bridge now uses one Application Support directory, reached by a `temporary-exception.files.home-relative-path.read-write` scoped to exactly that directory.
2. **`NSHomeDirectory()` is the container, the entitlement grants the real home.** The extension resolved its relative path against the container and wrote where nothing reads and the exception did not cover. It now resolves against the real home via `getpwuid`.
3. **The file-freshness bound contradicted the envelope's own expiry.** The reader refused any file older than `clockSkewSeconds` (5 s) while the writer stamped a 30-second envelope, so a user who clicked the toolbar button and then asked AURA to read the page always missed the window. `maxObservationAge` is now a separate parameter matching the writer's lifetime; `clockSkewSeconds` is clock tolerance only. The envelope's `expiresAt` is still checked during signature validation, so the effective bound is unchanged.
4. **Capability availability was refreshed only by onboarding actions.** The Safari bridge's readiness expires with its last observation, so the registry was stale by the time any real request arrived. `submitText` now re-derives productivity availability before the turn is routed, and the health refresh does the same.
5. **`noToolRegistered` masked "registered but unavailable".** `resolveContract` returned an optional, so a capability that was merely not ready right now was reported as a tool AURA does not have. It now returns `ready` / `unavailable(reason:)` / `unknown`, and the router surfaces the availability reason — which already carries the remediation — instead of a false "no tool registered".

## Live result

1. **Extension enabled and running.** "AURA Safari Read Bridge" appears in Safari Settings › Extensions, was enabled (`0 → 1`), and its toolbar button — "Send this tab's visible text to AURA" — is present on a real browser window.
2. **Native messaging reaches the appex.** Pressing the button starts `AuraSafariExtensionHandler`; its log records `Identity resolved as xpcservice<ai.aura.local.agent.SafariExtension([app<application.com.apple.Safari…>])>`.
3. **The extension signs and writes.** Both `observation.json` and `extension-key.json` are written to `~/Library/Application Support/AURA/SafariBridge/`. The envelope carries `protocolVersion 1`, `extensionID com.aura.safari-extension`, `profileID personal`, a DER ECDSA signature, and a bounded 129-character observation from the approved host `example.com`. The published key is the public half only.
4. **The pin matches.** The value AURA stored under `…personal.pinned-public-key` is byte-identical to the extension's published `publicKey`.
5. **The health surface tracks reality.** The Read Browser Page row moved from "not provisioned" → `personal / Degraded — Safari bridge observation is stale` → `Connected`, with `Connect Safari profile` and `Disconnect` controls behaving as designed.
6. **Timing measured.** The extension takes roughly 13 seconds from click to write, spent in the keychain; earlier read attempts submitted before that write completed, which is why they saw a stale observation.

## What is still not observed

The final end-to-end turn — AURA answering "summarize this page" from the live envelope — was not captured. Two environmental reasons, neither a product defect:

- **`Allow unsigned extensions` does not survive a Safari restart.** Re-enabling it raises a Touch ID / password sheet ("Safari is trying to allow unsigned extensions") that was deliberately not answered. Safari was restarted during this session to recover its accessibility tree, which disabled the extension again.
- **UI automation lost both windows to another Space** while the user was working on the machine, and the screen locked twice during the session.

Developer ID signing plus notarization removes the toggle entirely and is the production answer, owned by R11.

## Deterministic verification

- `./scripts/aura-test.sh /tmp/aura-sp011-final6` — **21/21 bundles, 1041/1041 tests, 0 failed**. Log SHA-256 `441d1274fe44abd991df99aa3e880d42b4f0333e653804fb131a9bb0a4b977f0`.
- New coverage: pin enforcement against an impostor key, verifying-key publication (public half only), mismatched-profile refusal, signing-key stability across reads, full-lifetime observation acceptance with expiry beyond it, and real-home path resolution.
- A test-isolation defect was also fixed: every Safari fixture shared one temporary directory, so the published `extension-key.json` was overwritten between tests.
- All four governance validators exit 0; 38/38 governance unit tests pass.

## Artifacts

- `/Applications/AURA.app/Contents/MacOS/AURA` — SHA-256 `7dcece2575e5cbae1e31306dedb22c608ac42f8f92deabf130cd845a6194882d`
- Extension handler — SHA-256 `56ffa4191311dab2e82daf8f0218121f1436d1c6f17fd0503c9e97a423b7f027`
- Locally signed, **not** notarized or release-class.

## Falsifier

Falsified if the app accepts an envelope signed by an unpinned key; if the published key file ever contains private key material; if revocation leaves a readable bridge; if an observation is accepted past its envelope expiry; if a capability that is merely unavailable is again reported as unregistered; or if the extension writes outside the one directory its sandbox exception names.

## Verdict

**SP-011 remains `blocked`.** The Team ID dependency is removed and the bridge now runs end to end as far as the shared file — signed by the live extension, pinned by the app, with the health surface tracking it truthfully. The single remaining leg is the observed conversational summary, blocked on Safari's unsigned-extension authentication, which recurs on every Safari restart until the app is Developer ID signed and notarized. SP-012 is not safe to start.
