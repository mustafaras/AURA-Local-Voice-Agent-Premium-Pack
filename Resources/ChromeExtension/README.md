# AURA Chrome Read Bridge — minimal read-only extension

This directory is the **minimal read-only Chrome Web Extension** that replaces
the Safari bridge as AURA's default browser transport. Chrome loads a local
extension with **"Load unpacked"** and no Developer ID / notarization / Touch ID
gate, which removes the Safari-only blocker that kept `browser.read` from ever
reaching `.ready` on a locally signed Mac.

## What it does

- When the user chooses **Connect Chrome** in AURA, the extension-owned
  `bootstrap.html` page sends one empty observation to establish the local
  signing-key handshake. It reads no web-page content.
- On an explicit user click of the toolbar button, reads the active tab's
  `url`, `title`, and bounded visible text (≤ 20 000 characters) and sends it
  to the AURA native messaging host.
- Reads no web-page content without that click: no polling, no queue, and no
  background page reads.
- Never reads cookies, passwords, or hidden page state, and never executes
  arbitrary page scripts on the model's behalf.

## Files

| File | Purpose |
|---|---|
| `manifest.json` | MV3 manifest; declares `nativeMessaging`, `activeTab`, and `scripting` only — no host permissions and no content scripts |
| `background.js` | Service worker; on toolbar click reads visible text via `chrome.scripting.executeScript` and sends one `aura.activeTabObservation` native message |
| `bootstrap.html`, `bootstrap.js`, `bootstrap.css` | Extension-owned connection page; sends one empty native handshake and displays the truthful host result |

## The two halves of the bridge

The extension does **not** sign anything. It sends a plain observation; the
native host signs and the containing app validates. Both native halves live in
`AuraProductivity` so the whole path is covered by the regression suite:

| Half | Type | Role |
|---|---|---|
| Producer | `SafariBridgeNativeMessageHandler` | Validates the untrusted native message (type, protocol version, extension identity, profile scope, size) |
| Producer | `SafariBridgeEnvelopeWriter` | Signs the observation (ECDSA P-256) and writes the envelope atomically to the shared Application Support container |
| Consumer | `AuthenticatedSafariWebExtensionTransport` | Reads the envelope and validates version, identity, profile, nonce, freshness, and signature before anything is accepted |

The native message format is identical to the Safari bridge's, so the same
`SafariBridgeNativeMessageHandler` and `SafariBridgeEnvelopeWriter` are reused
unchanged. The only new piece is the Chrome native messaging host
(`Sources/AuraChromeNativeHost/`), which reads the message from stdin and
delegates to the same handler.

## Install (one-time, no signing gate)

1. Open Chrome → `chrome://extensions`
2. Enable **Developer mode** (top-right)
3. Click **Load unpacked** → select this `Resources/ChromeExtension` directory
4. In AURA, press **Connect Chrome**. Chrome opens the extension-owned bootstrap
  page and provisions the key through the signed shared-container contract.
5. Open any HTTPS page and click the AURA toolbar button when page text should
  be shared with AURA.

## Local developer-mode boundary

This local-only build uses Chrome's **Load unpacked** workflow. The native host
pins the stable extension origin, Google-signed Chrome parent, AURA app identity
and signer, complete extension-directory file set and hashes, message bounds,
and signed envelope. Chrome's native-messaging protocol does not expose the
loaded extension's filesystem path, so unpacked mode cannot cryptographically
bind the stable ID to the canonical bundle path. A Chrome Web Store or managed
enterprise installation is required to close that distribution-provenance gap.

The native messaging host manifest is installed to
`~/Library/Application Support/Google/Chrome/NativeMessagingHosts/ai.aura.local.agent.json`
by `scripts/install-chrome-bridge.sh`.
