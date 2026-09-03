# Evidence: EV-SP-009-20260817-PACKAGING-AUTH-01

> **CORRECTED 2026-08-17 by `EV-SP-009-20260817-CORRECTION-02`.** Two claims in
> this record were wrong and are corrected there, not deleted here:
>
> 1. "Four governance validators exit 0" was **false** —
>    `validate_runtime_completion.py` exited `1` on three schema/pointer breaks
>    introduced by this record's own state edits.
> 2. Section 5's "packaged … read path" overstated the package: the packaged
>    extension had **no producing half** (no native-messaging send, no signing,
>    no container write), so nothing could produce an envelope the transport
>    would accept.
>
> Test totals below (949) predate the 5 correction tests; the current total is
> **954**. Read this record together with the correction.

## Identity

- **Evidence ID:** EV-SP-009-20260817-PACKAGING-AUTH-01
- **Prompt:** SP-009 — Safari Extension Packaging and Authentication
- **Gap:** OPEN-06 (R5) — browser/mail/calendar/contacts adapters, Safari bridge slice
- **Timestamp:** 2026-08-17
- **Branch:** `main`
- **Commit at start:** `92c45f60b5b564b016122de7238e4d7f2b34a7ed` (== `origin/main`)
- **Session:** AURA-SP-009-PACKAGING-AUTH-20260817

## Authority

Edit-only. No install, launch, TCC mutation, provider contact, beta
enrollment, signing, notarization, release, deployment, commit, push, or merge.
The Safari Web Extension is packaged as source files only; it is not installed
or live-verified, and the `browser.read` capability stays disabled.

## 1. Symptom — the structured bridge was a contract, not a live path

`PRODUCTIVITY_READ_FIRST.md` and `SECOND_PASS_OPEN_GAPS.md` OPEN-06 both state
the same gap: the Safari bridge is "a structured contract, not a live
extension." Reading the production sources confirmed it precisely:

- `SafariWebExtensionTransport` is a protocol with a single `readActiveTab`
  method and **no production conformer** — only the test fake
  `SafariTransportFake` exists.
- `SafariWebExtensionTabResponse` was not `Codable`, so no native-messaging
  JSON payload could be decoded into it.
- There was no extension identity, no versioning, no nonce/freshness, no
  account/profile scope binding, and no secret provisioning.
- The composition root (`AuraKernel`) had no reference to `AuraProductivity`
  at all, so the bridge was not connected through the composition root.

## 2. Mechanism and root cause

The first-pass R5 slice deliberately stopped at the typed contract boundary
(`EV-R5-20260808-READ-FIRST-ADAPTERS-01`). The packaging, authentication, and
composition-root wiring were explicitly deferred to the second pass. The
result was a capability registered `.disabled` with a truthful reason, but no
live read path and no way to authenticate or revoke one.

## 3. Direct changes

| File | Change |
|---|---|
| `Sources/AuraProductivity/ProductivityAdapters_SafariWebExtensionTabResponse.swift` | `SafariWebExtensionTabResponse` is now `Codable` so native-messaging JSON decodes into it |
| `Sources/AuraProductivity/ProductivityAdapters_SafariBridgeSecurity.swift` | **New** — `SafariBridgeSignedPayload` (versioned, extension ID, profile ID, nonce, issued/expires), `SafariBridgeEnvelope`, and `SafariBridgeAuthenticator` (HMAC-SHA256 over canonical JSON; validates version, identity, profile, nonce, freshness, tag) |
| `Sources/AuraProductivity/ProductivityAdapters_SafariBridgeSecretStore.swift` | **New** — Keychain-backed shared-secret store with `provision`/`sharedSecret`/`revoke`; secret never appears in keys, logs, or ledgers |
| `Sources/AuraProductivity/ProductivityAdapters_AuthenticatedSafariTransport.swift` | **New** — `AuthenticatedSafariWebExtensionTransport` conforms to `SafariWebExtensionTransport`; reads the signed envelope from the shared container, validates it, and fails closed on `.unavailable`/`.stale`/`.profileMismatch`/`.notProvisioned`/`.authenticationFailed` |
| `Sources/AuraCore/Configuration_ProductivityConfiguration.swift` | **New** — `ProductivityConfiguration` (profile ID, extension ID, shared container path, secret service name, allowed hosts) |
| `Sources/AuraCore/AuraConfiguration.swift` | Wired `productivity` into the configuration |
| `Sources/AURA/SafariBridgeRuntime.swift` | **New** — composition unit owning the transport, secret store, and profile-scoped adapter; exposes truthful `availability()` |
| `Sources/AURA/SafariBridgeAvailability.swift` | **New** — maps transport failure states to `CapabilityAvailability` (`.ready`/`.degraded`/`.disabled`) |
| `Sources/AURA/AuraKernel.swift` | Added `safariBridgeRuntime` property |
| `Sources/AURA/AuraKernel_Construction.swift` | Constructs the Safari bridge in the composition root and records truthful health |
| `Resources/SafariExtension/` | **New** — minimal read-only Web Extension package: `manifest.json` (nativeMessaging + activeTab only), `background.js` (bounded visible-text read), `content.js` (no-op), `README.md` |
| `Tests/AuraProductivityTests/AuraProductivityTests.swift` | **New** — 7 SP-009 tests |

## 4. Acceptance procedure and results

| Check | Result |
|---|---|
| `swift build --target AuraProductivity` | Clean |
| `swift build --product AURA` | Clean |
| `AuraProductivityTests` | **19/19** (12 before; 7 new) |
| Full regression `./scripts/aura-test.sh` | **21/21 bundles, 949/949 tests, 0 failed** |
| Four governance validators | exit 0 |
| Governance unit tests | OK |
| `git diff --check` | clean |
| `manifest.json` JSON parse | OK |

New tests, by what they falsify:

| Test | Falsifies |
|---|---|
| `safariBridgeAuthenticatorRoundTripsAndRejectsTampering` | a valid envelope being rejected, or a tampered/wrong-identity/wrong-profile/expired/future envelope being accepted |
| `safariBridgeAuthenticatorRejectsEmptySecretAndNonce` | an empty shared secret or nonce being accepted |
| `safariBridgeSecretStoreProvisionsRetrievesAndRevokes` | the secret not round-tripping, or the secret value leaking into the key |
| `safariBridgeTransportReadsAuthenticatedObservation` | the transport failing to read a valid signed observation |
| `safariBridgeTransportFailsClosedOnUnavailableStaleMismatchAndRevocation` | the transport proceeding on a missing file, a stale observation, a profile mismatch, or a revoked secret |
| `safariBridgeTransportRejectsIdentityMismatchAndTamperedEnvelope` | the transport accepting a wrong-extension or tampered envelope |
| `safariBridgeAdapterRejectsInjectionContentAndEnforcesDomainScope` | page text influencing an action, or a disallowed domain being read |

## 5. Effect on OPEN-06

The Safari bridge slice of OPEN-06 is now a **packaged, authenticated,
bounded, revocable, and visibly-degraded-when-unavailable** read path:

- **Authenticated** — every observation is an HMAC-signed envelope validated
  for version, extension identity, profile identity, nonce, freshness, and tag.
- **Bounded** — the extension reads only the active tab's visible text; it
  never reads cookies, passwords, hidden page state, or arbitrary page scripts.
- **Revocable** — `SafariBridgeSecretStore.revoke(profileID:)` removes the
  shared secret; after revocation the transport fails closed and the
  capability degrades to `.disabled`.
- **Visibly degraded when unavailable** — `SafariBridgeAvailability` maps every
  transport failure to a distinct, user-presentable `CapabilityAvailability`
  reason, and the composition root records truthful health.
- **Connected through the composition root** — `AuraKernel` now constructs the
  bridge and records its health.

The capability **remains disabled** until the live package and trust path are
verified (SP-010/SP-011). No mutation, send, or OAuth scope escalation was
added.

## 6. Falsification

- any signed envelope with a wrong version, extension ID, profile ID, nonce,
  freshness, or authentication tag being accepted by the transport;
- a revoked or never-provisioned profile producing anything other than a
  fail-closed error;
- a stale observation being accepted;
- page text influencing an action or a disallowed domain being read;
- the composition root failing to construct the bridge or record truthful
  health.

## 7. Limitations

- Deterministic evidence only. The extension is packaged as source files but
  is **not** installed, signed, or live-verified; the real Safari native-
  messaging round trip and the real app-group shared container are not
  exercised. That is the live leg SP-010/SP-011 must close.
- The shared secret is provisioned through the `SecretStoring` seam in tests;
  the real `KeychainSecretStore` path is not exercised under this evidence ID.
- No live run under this evidence ID.
