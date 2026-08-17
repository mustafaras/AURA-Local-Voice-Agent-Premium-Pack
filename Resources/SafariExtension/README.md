# AURA Safari Read Bridge — minimal read-only extension

This directory is the **minimal read-only Safari Web Extension** that SP-009
packages. It is the structured boundary between Safari and the AURA containing
app. It is **not** yet installed, signed, or live-verified; the `browser.read`
capability stays disabled until the live package and trust path are verified.

## What it does

- On an explicit user click of the toolbar button, reads the active tab's
  `url`, `title`, and bounded visible text (≤ 20 000 characters) and sends it
  to the containing app through Safari native messaging.
- Reads nothing without that click: no polling, no queue, no background reads.
- Never reads cookies, passwords, or hidden page state, and never executes
  arbitrary page scripts on the model's behalf.

## Files

| File | Purpose |
|---|---|
| `manifest.json` | Web Extension manifest v3; declares `nativeMessaging`, `activeTab`, and `scripting` only — no host permissions and no content scripts |
| `background.js` | Service worker; on toolbar click reads visible text via `scripting.executeScript` and sends one `aura.activeTabObservation` native message |

## The two halves of the bridge

The extension does **not** sign anything. It sends a plain observation; the
native half signs and the containing app validates. Both native halves live in
`AuraProductivity` so the whole path is covered by the regression suite:

| Half | Type | Role |
|---|---|---|
| Producer | `SafariBridgeNativeMessageHandler` | Validates the untrusted native message (type, protocol version, extension identity, profile scope, size) |
| Producer | `SafariBridgeEnvelopeWriter` | Signs the observation (HMAC-SHA256) and writes the envelope atomically to the shared app-group container |
| Consumer | `AuthenticatedSafariWebExtensionTransport` | Reads the envelope and validates version, identity, profile, nonce, freshness, and tag before anything is accepted |

Native message the extension sends:

```json
{
  "type": "aura.activeTabObservation",
  "protocolVersion": 1,
  "extensionID": "com.aura.safari-extension",
  "profileID": "personal",
  "tab": {
    "tabID": "1",
    "profileID": "personal",
    "url": "https://example.com/page",
    "title": "Example",
    "visibleText": "…bounded visible text…"
  }
}
```

## Packaging

A Safari Web Extension is packaged as a macOS app extension and distributed
with the containing app. Per Apple's current documentation, use Xcode's
`xcodebuild`/`safari-web-extension-converter` tooling to convert and package
this folder, then enable the app group so the extension and the containing app
share the signed observation envelope.

This repository has no Xcode project for the extension yet; packaging is a
separate, explicitly authorized step. When that target is added, its
`SafariWebExtensionHandler` must stay a thin shim: decode the message body to
`Data` and call `SafariBridgeNativeMessageHandler.handle(messageData:)`. Keep
validation and signing in `AuraProductivity` rather than in the shim, so the
trust path stays under test.

## Trust path

The containing app validates a signed envelope (version, extension identity,
profile identity, nonce, freshness, HMAC) before accepting any observation.
Tag verification is constant-time. The shared secret is provisioned into the
Keychain-backed secret store and is never embedded in source, fixtures, or
ledgers; revoking it makes the bridge fail closed and the capability degrade to
`.disabled`.
