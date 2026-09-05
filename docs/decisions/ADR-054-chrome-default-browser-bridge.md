# ADR-054: Chrome is AURA's default browser bridge

- Status: Accepted
- Date: 2026-09-04
- Owners: AURA release owner
- Supersedes: Safari as the default browser transport in ADR-040 (transport only)
- Superseded by:

## Context

The reviewed read-first browser contract existed behind a Safari Web Extension,
but a locally signed build could not make that extension usable without Safari's
**Allow unsigned extensions** setting. Safari requires a Touch ID/password grant,
the setting does not reliably survive a Safari restart, and the extension remained
absent from Safari's Extensions list despite a valid sandboxed appex and pluginkit
registration. This made `browser.read` operationally unavailable under ADR-049's
local-only signing boundary.

Google Chrome supports a local Manifest V3 extension loaded through Developer mode
without Developer ID, notarization, or Safari's unsigned-extension gate. Chrome's
native messaging protocol is a length-prefixed JSON stream and can carry the same
validated `aura.activeTabObservation` message the Safari producer used.

## Decision

Chrome becomes AURA's default browser integration. AURA ships:

1. `Resources/ChromeExtension`, a load-unpacked MV3 extension with only
   `nativeMessaging`, `activeTab`, and `scripting` permissions; no host permissions
   or content scripts.
2. `AuraChromeNativeHost`, a Swift native messaging executable that validates the
   existing typed message through `SafariBridgeNativeMessageHandler` and writes an
   ECDSA P-256 signed envelope through `SafariBridgeEnvelopeWriter`.
3. A stable public manifest key that produces Chrome extension ID
   `ggccnafnholmbpghgljfbofapcbhkdjh`, allowing the native host manifest to pin the
   exact `chrome-extension://.../` origin.
4. `ChromeBridgeInstaller`, which refreshes the bundled host and Chrome native
   messaging manifest on each AURA launch.
5. An extension-owned bootstrap page that sends an empty pairing observation,
   plus `Command-Shift-Y` as the explicit user gesture that reads a web page once.

Existing internal type names beginning with `SafariBridge` remain temporarily.
They implement the reviewed browser-agnostic signed-envelope contract and are not
presented to users. Renaming them is a separate behavior-preserving refactor.

## Alternatives considered

- **Keep Safari and require Allow unsigned extensions.** Rejected: repeated manual
  security state, not robust across restart, and unavailable under local-only
  signing in observed runs.
- **Developer ID sign and notarize the Safari extension.** Rejected for this scope:
  ADR-049 explicitly keeps external distribution, Developer ID, and notarization
  out of scope.
- **Read Chrome through Accessibility or screen scraping.** Rejected: native
  structured data is safer and more deterministic than UI scraping.
- **Unauthenticated local HTTP bridge.** Rejected: expands network attack surface
  and weakens the existing signed-envelope boundary.

## Security and privacy impact

- The bootstrap page sends only extension URL/title metadata and empty text after
  **Connect Chrome**. Web-page content is read only after an explicit toolbar click
  or `Command-Shift-Y`.
- It reads only the active tab's URL, title, and at most 20,000 visible characters.
- It declares no host permissions and reads no cookies, passwords, hidden DOM,
  history, or background tabs.
- Chrome pins the native messaging host to one stable extension origin.
- The host validates Chrome's live code signature against Google's designated
  requirement, the exact extension origin, AURA's bundle identifier and signer,
  the exact extension-directory file set, and SHA-256 hashes of every approved
  extension file before signing.
- The host validates message type, protocol version, extension identity, profile,
  total frame size, and individual tab ID/URL/title/text bounds before signing.
- The host's private P-256 key is stored in the login Keychain under a
  Chrome-specific service namespace. Reusing Safari's data-protection Keychain
  namespace caused a cross-sandbox ACL wait; the separate namespace removes that
  conflict without moving private key material to disk.
- The app still pins only the public key; no private key enters AURA prompts,
  logs, memory, or the database.

## Operational impact

- One-time setup: Chrome Developer mode → Load unpacked → select the bundled
  `ChromeExtension` directory. **Connect Chrome** restarts Chrome and opens the
  installed extension's bootstrap page; it does not rely on `--load-extension`,
  which branded Google Chrome 152 rejects.
- AURA automatically installs/updates the native host on launch.
- An app upgrade refreshes the host binary and manifest without touching Chrome's
  profile.
- The Safari appex remains packaged for backward compatibility but is no longer
  the default or named in the product UI.

## Migration

1. Build/install the updated AURA app.
2. Install the Chrome native host (`scripts/install-chrome-bridge.sh` for source
   builds; `ChromeBridgeInstaller` for app launches).
3. Load `Resources/ChromeExtension` once in `chrome://extensions`.
4. Press **Connect Chrome** in AURA to publish the empty pairing observation and
  pin the public key.
5. Open a page and press `Command-Shift-Y` when its visible text should be shared.

## Validation evidence

- Chrome extension loaded live with stable ID
  `ggccnafnholmbpghgljfbofapcbhkdjh` (2026-09-04 screenshot).
- The native host accepted a real Chrome-framed message and returned
  `{"status":"accepted"}`, exit 0.
- A direct forged host invocation returned `{"status":"unauthorized"}`, exit 1;
  only the Google-signed Chrome parent with the pinned origin, AURA signer, and
  complete source-hash chain was accepted.
- Live `Command-Shift-Y` on `https://example.com` produced both
  `extension-key.json` and signed `observation.json` at 2026-09-04 14:59.
- `ChromeBridgeIntegrationTests` verifies the exact host manifest origin, copied
  binary path, bounded permissions, absence of host permissions, stable public
  key, and macOS shortcut.

## Consequences

AURA's browser-read capability now has a locally operable path under ADR-049.
Chrome is required for the default browser integration. Safari-specific internal
implementation names remain technical debt but do not affect behavior or user
copy. The extension remains page-content user-gated: AURA cannot silently read
web pages or claim connected before the empty signed handshake and key pinning
complete.

The local developer-mode extension has a known provenance limit: Chrome native
messaging authenticates the stable extension origin but does not disclose the
loaded unpacked filesystem path. The host separately verifies the canonical
signed bundle and all approved source files, but a same-ID substituted unpacked
extension cannot be cryptographically excluded until AURA adopts a Chrome Web
Store or enterprise-managed extension distribution.
