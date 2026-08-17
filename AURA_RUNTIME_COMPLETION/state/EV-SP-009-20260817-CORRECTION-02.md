# Evidence: EV-SP-009-20260817-CORRECTION-02

## Identity

- **Evidence ID:** EV-SP-009-20260817-CORRECTION-02
- **Prompt:** SP-009 — Safari Extension Packaging and Authentication
- **Gap:** OPEN-06 (R5) — Safari bridge slice
- **Class:** Correction + deterministic source-side
- **Timestamp:** 2026-08-17
- **Branch:** `main`
- **Commit at start:** `92c45f60b5b564b016122de7238e4d7f2b34a7ed` (== `origin/main`)
- **Session:** AURA-SP-009-PACKAGING-AUTH-20260817
- **Trigger:** User-requested audit of whether SP-009 was completely and
  flawlessly closed, followed by an explicit in-turn instruction to fix what
  the audit found and deliver.

## Authority

Edit-only for the corrections, plus an **explicit in-turn user go-ahead for
commit, push, and merge**. No install, launch, TCC mutation, provider contact,
beta enrollment, signing, notarization, release, or deployment. The Safari Web
Extension is still packaged as source only and is not installed or
live-verified; `browser.read` stays disabled.

## 1. Symptom — five defects in a prompt recorded as completed

`EV-SP-009-20260817-PACKAGING-AUTH-01` and every SP-009 record claimed "four
governance validators exit 0". Re-running them at the working tree showed
otherwise, and reading the packaged extension against the Swift transport
showed the two halves of the bridge never met.

| # | Defect | Class |
|---|---|---|
| 1 | `validate_runtime_completion.py` exited **1**, not 0 | False acceptance claim |
| 2 | `15_SESSION_CLOSEOUT.prompt.md` was never run for SP-009 | Missing required record |
| 3 | The packaged extension could not produce anything the transport accepts | Completion-gate gap |
| 4 | `manifest.json` declared a wider surface than the record described | Record/implementation drift |
| 5 | HMAC tag verification used non-constant-time `String ==` | Security hygiene |

### Defect 1, in detail — three separate validator breaks

`validate_runtime_completion.py` passed at clean `HEAD` and failed only against
the SP-009 working tree, so all three breaks were introduced by SP-009's own
record edits:

| Break | Rule | HEAD | SP-009 working tree |
|---|---|---|---|
| `session-handoff.active_prompt.step` | `maxLength` 500 | 485 chars, passing | **709 chars** |
| `session-handoff.completed` | `maxItems` 30, item `maxLength` 500 | 30 items, all ≤ 500 | **32 items**, two over length |
| `capability-matrix.repository_commit` | must equal `current-state.repository.verified_head` | both `e4af29ba…` | `verified_head` advanced to `92c45f60…` **alone** |

The second and third breaks were latent: the first failure masked them, so
fixing only the reported error surfaced a new one twice.

### Defect 3, in detail — the bridge had no producing half

`AuthenticatedSafariWebExtensionTransport` reads an **HMAC-signed envelope**
from the shared app-group container. The packaged extension:

- never called `runtime.sendNativeMessage` or `runtime.connectNative`;
- never signed anything (no HMAC, no `crypto.subtle`);
- never wrote any file;
- declared `AURA_APP_ID` and never used it;
- shipped a `content.js` that was an explicit no-op and sent nothing.

`background.js` only answered an in-extension `runtime.onMessage` that nothing
sent, and read `sender.tab`, which is undefined for a message from the
containing app. Nothing in the repository could produce an envelope the
transport would accept, so the "packaged bridge" was two disconnected halves.

## 2. Mechanism and root cause

The SP-009 attempt verified the **consuming** half thoroughly (7 tests over the
authenticator, secret store, and transport) and inferred that the packaged
extension satisfied the completion gate. No test crossed the extension-to-app
seam, so the missing producer was invisible to the suite. The validator claim
came from a validator run made **before** the final record edits; the records
that broke the schema were themselves written after the last validation. This
is the "verified earlier, asserted later" pattern the control contract's stop
condition exists to catch.

## 3. Direct changes

| File | Change |
|---|---|
| `Sources/AuraProductivity/ProductivityAdapters_SafariBridgeEnvelopeWriter.swift` | **New** — `SafariBridgeEnvelopeWriter`: signs an observation and writes the envelope atomically to the shared container; fails closed on profile mismatch, oversize text, missing provisioning, and any signing/write failure |
| `Sources/AuraProductivity/ProductivityAdapters_SafariBridgeNativeMessage.swift` | **New** — `SafariBridgeNativeMessage` (the wire form) and `SafariBridgeNativeMessageHandler`, which validates the untrusted native message (type, protocol version, extension identity, profile scope, size) before anything is signed |
| `Sources/AuraProductivity/ProductivityAdapters_SafariBridgeSecurity.swift` | Tag verification is now constant-time via `HMAC<SHA256>.isValidAuthenticationCode`; canonical encoding extracted to `canonicalData(for:)` |
| `Sources/AuraProductivity/ProductivityAdapters_AuthenticatedSafariTransport.swift` | Added `SafariBridgeTransportError.malformedMessage` for absent/undecodable/wrong-typed/wrong-versioned/oversize messages |
| `Sources/AURA/SafariBridgeAvailability.swift` | Maps `.malformedMessage` to a distinct user-presentable degraded reason |
| `Resources/SafariExtension/background.js` | Rewritten: user-gated `action.onClicked` → `scripting.executeScript` (bounded visible text) → `runtime.sendNativeMessage`. No polling, no queue, no background reads |
| `Resources/SafariExtension/manifest.json` | MV3-correct `service_worker`; permissions narrowed to `nativeMessaging`/`activeTab`/`scripting`; `<all_urls>` content script and the Firefox `browser_specific_settings.gecko` id removed; `action` added for user gating |
| `Resources/SafariExtension/content.js` | **Deleted** — the no-op content script and its `<all_urls>` surface are gone |
| `Resources/SafariExtension/README.md` | Documents the producer/consumer split, the wire message, and the rule that the Xcode `SafariWebExtensionHandler` stays a thin shim |
| `AURA_RUNTIME_COMPLETION/context/session-handoff.json` | `step` 709 → 450 chars; `completed` trimmed 32 → 30 items with the newest entry rewritten under 500 |
| `AURA_RUNTIME_COMPLETION/state/capability-matrix.json` | `repository_commit` advanced to `92c45f60…` to match `verified_head` |
| `Tests/AuraProductivityTests/AuraProductivityTests.swift` | 5 new tests (SP-009 total 7 → **12**) |

## 4. Acceptance procedure and results

| Check | Result |
|---|---|
| `swift build --target AuraProductivity` | Clean |
| `node --check Resources/SafariExtension/background.js` | OK |
| `manifest.json` JSON parse | OK |
| Full regression `./scripts/aura-test.sh` | **21/21 bundles, 954/954 tests, 0 failed** |
| `validate_second_pass_program.py` | exit 0 |
| `validate_runtime_completion.py` | exit 0 **(was exit 1)** |
| `validate_repo_hygiene_program.py` | exit 0 |
| `validate_repo_hygiene_supply_chain.py` | exit 0 |

- **Artifact:** `AURA_RUNTIME_COMPLETION/state/EV-SP-009-20260817-CORRECTION-02.regression.log`
- **SHA-256:** `b21b55e557c7bc3dd7202ef81f401fbeffa00a97e7d9328cee894c344703ac09`
- **Environment:** macOS Darwin 27.0.0, repository runner building into `/tmp/aurabuild`
  (a raw `swift test` fails codesign in the iCloud-synced working directory —
  an environment limitation, not a product defect).

Test totals were recomputed by summing the 21 per-bundle `Test run with N
tests` lines from the log, not read off a summary line. 949 → 954 is exactly
the 5 added tests.

New tests, by what they falsify:

| Test | Falsifies |
|---|---|
| `safariBridgeEnvelopeWriterSignsObservationTheTransportAccepts` | the producing and consuming halves not meeting — the writer's envelope not being accepted by the transport |
| `safariBridgeEnvelopeWriterFailsClosedOnMismatchOversizeAndRevocation` | a cross-profile, oversize, or post-revocation observation being signed |
| `safariBridgeNativeMessageCompletesTheExtensionToAdapterPath` | the literal JSON `background.js` emits failing to travel handler → writer → transport → adapter |
| `safariBridgeNativeMessageHandlerRejectsUntrustedMessages` | an undecodable, wrong-typed, wrong-versioned, impersonating, or out-of-scope message being accepted, or a refused message still reaching the container |
| `safariBridgeAuthenticatorRejectsMalformedTags` | an empty, non-base64, or truncated tag being accepted by the constant-time path |

## 5. Effect on OPEN-06

The Safari bridge slice now has a **complete, tested, deterministic path** from
the extension's user gesture to the policy-checked adapter snapshot:

```
toolbar click → background.js → aura.activeTabObservation (native message)
  → SafariBridgeNativeMessageHandler (identity/version/profile/size)
  → SafariBridgeEnvelopeWriter (HMAC sign, atomic write)
  → AuthenticatedSafariWebExtensionTransport (version/identity/profile/nonce/freshness/tag)
  → SafariBrowserReadAdapter (allowlist + injection classifier)
```

Every hop fails closed, and the whole chain is exercised by the regression
suite from the real wire format. The capability **remains disabled** until the
live package and trust path are verified (SP-010/SP-011).

## 6. Falsification

- any of the four governance validators exiting non-zero at this tree;
- the writer producing an envelope the transport rejects, or vice versa;
- a message with a wrong type, version, extension identity, or profile being
  signed or written;
- a refused message leaving a file in the shared container;
- an empty, non-base64, or truncated tag validating;
- the packaged extension reading anything without a user click.

## 7. Limitations

- Deterministic evidence only. The extension is **not** installed, converted,
  signed, or live-verified; the real Safari native-messaging round trip, the
  real app-group container, and the real `KeychainSecretStore` path are not
  exercised. `RISK-SAFARI-BRIDGE-NOT-LIVE` stays open and owns that leg.
- No Xcode app-extension target exists, so the `SafariWebExtensionHandler`
  shim is documented but not built. The logic it must call is under test; the
  shim itself is not.
- `background.js` is syntax-checked, not executed. No browser ran in this
  session.
- The transport reuses `clockSkewSeconds` as the container freshness window
  (5 s) while the envelope's own lifetime is 30 s. Both are fail-closed and the
  tighter bound wins, but the two windows are deliberately not unified here;
  SP-010/SP-011 should settle the real freshness budget against live timing
  rather than a guess.
