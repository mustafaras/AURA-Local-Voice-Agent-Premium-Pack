# EV-SP-023-20260827-AUTHENTICATED-IPC-01

- **Prompt/Track:** SP-023 / R10 (OPEN-11)
- **Timestamp:** 2026-08-27
- **Commit/Branch:** working tree on `main` (HEAD `ec41e7814f34922cdd9e9a7f168b2d3fb2ba4d40`; origin/main equal)
- **Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0.0-beta.5 toolchain, CommandLineTools developer dir
- **Evidence class:** Automated / contract + adversarial (deterministic; no live signed-helper launch)

## Objective

Close the bounded SP-023 slice of OPEN-11: replace the application-only echo
helpers with an authenticated, least-privilege execution boundary. Specifically:

1. Add authenticated peer identity (HMAC-SHA256 shared-secret tag over exact
   transmitted bytes + `SecCode` designated-requirement process verification)
   as the reviewed equivalent to XPC peer identity.
2. Move real shell and app-lifecycle execution into the correctly entitled,
   sandboxed helpers and constrain the main process to send typed,
   capability-scoped, authenticated requests.
3. Test compromised parent/helper, replay, downgrade, identity mismatch,
   emergency-stop-adjacent fail-closed, and helper crash containment.

## Changes delivered

- `Sources/AuraCore/HelperIPCAuthentication.swift` — `HelperIPCAuthenticator`
  (HMAC-SHA256), `HelperIPCAuthenticatedRequest`/`HelperIPCAuthenticatedResponse`
  (tag over exact transmitted bytes), `HelperIPCPeerVerifying` protocol,
  `SecCodeHelperIPCPeerVerifier` (SecCode designated-requirement), and
  `StaticHelperIPCPeerVerifier` test seam.
- `Sources/AuraCore/HelperIPCClient.swift` — `HelperIPCClient` actor: verifies
  helper SHA-256 digest, verifies launched process code-signature identity,
  signs requests, enforces replay/freshness/capability allowlist, bounds output
  and time (helper crash containment).
- `Sources/AuraShell/AuthenticatedShellHelperClient.swift` — typed shell client
  sending `Command` and receiving `ProcessResult`.
- `Sources/AuraAutomation/AuthenticatedAutomationHelperClient.swift` and
  `Sources/AuraAutomation/AutomationHelperTypes.swift` — typed app-lifecycle
  client and closed `AutomationHelperOperation`/`AutomationHelperResult`.
- `Sources/AuraShellHelper/main.swift` — now executes real typed `Command`s
  (no longer echo-only), verifies request HMAC tag, signs response.
- `Sources/AuraAutomationHelper/main.swift` — now executes real app-lifecycle
  operations (launch/activate/hide/quit), verifies request HMAC tag, signs
  response. Accessibility/generated-input execution is intentionally absent
  (requires a per-executable TCC grant outside this prompt's authority).
- `Sources/AuraShell/ProcessRunner.swift` — `ProcessResult` is now `Codable`.
- `Package.swift` — helper targets now depend on `AuraShell`/`AuraAutomation`/
  `AuraSecurity`.
- Tests: `Tests/AuraCoreTests/HelperIPCAuthenticationTests.swift`,
  `Tests/AuraCoreTests/HelperIPCAdversarialTests.swift`,
  `Tests/AuraAutomationTests/AutomationHelperTypesTests.swift`.

## Verification

- `swift build` — product targets compile (test-bundle codesign xattr issue is
  the known iCloud issue handled by `aura-test.sh`).
- `./scripts/aura-test.sh /tmp/aurabuild-sp023 "AuraCoreTests"` — PASSED, 0 failed bundles.
- `./scripts/aura-test.sh /tmp/aurabuild-sp023 "AuraAutomationTests"` — PASSED, 0 failed bundles.
- `./scripts/aura-test.sh /tmp/aurabuild-sp023 "AuraShellTests"` — PASSED, 0 failed bundles.
- `./scripts/aura-test.sh /tmp/aurabuild-sp023` (full suite) — PASSED, 0 failed bundles.
- `python3 scripts/validate_second_pass_program.py` — SECOND-PASS VALIDATION PASSED.
- Helper executables fail closed without the App Sandbox entitlement:
  `AuraShellHelper --attest-only` exits 137 (killed by sandbox check),
  `AuraAutomationHelper --attest-only` exits 1 with
  "refuses to run without the App Sandbox entitlement".

## Adversarial coverage

- `clientRejectsMissingExecutable` — fail-closed on unreadable helper.
- `clientRejectsInvalidSHA256` — fail-closed on invalid digest.
- `replayGuardRejectsReplayedNonce` — one-time nonce.
- `validatorRejectsDowngradedProtocolVersion` — protocol downgrade rejected.
- `clientRejectsPeerIdentityMismatch` — SecCode identity mismatch rejected
  before any exchange.
- `clientFailsClosedWhenHelperCrashes` — non-zero helper exit produces a
  fail-closed security error, no hang.
- `validatorRejectsCapabilityEscalationAcrossHelperKinds` — capability
  allowlist enforced.
- `authenticatorRejectsForgedResponseTag` / `authenticatorRejectsResponseBoundToDifferentRequest` — response authentication and request binding.

## Scope and limitations

- This is a **deterministic/contract + adversarial** slice. It does **not**
  claim OS-enforced confinement of a live signed helper, a real XPC connection,
  or a live end-to-end helper round trip with a provisioned Keychain secret.
- The helpers are sandboxed and network/mic/camera-denied by their entitlements
  (`Resources/AuraAutomationHelper.entitlements`,
  `Resources/AuraShellHelper.entitlements`), but the live signed-bundle launch
  and Keychain secret provisioning are not exercised here (no signing/install
  authority).
- Accessibility/generated-input execution in the automation helper is
  intentionally not implemented (requires a per-executable TCC grant outside
  this prompt's authority).
- The main process still retains broad authority; full privilege separation
  (moving every privileged path into a helper) and the remaining OPEN-11
  residuals (network enforcement, OAuth lifecycle, plugin trust, injection
  corpus, incident response, independent review, ADR-044 acceptance) remain
  open and are owned by SP-024 and later R10 work.
- No raw audio, screenshots, secrets, tokens, private account data, or
  unredacted model output were written to any ledger or context file.
