# AURA VS Code Extension Bridge

Companion VS Code extension for the AURA macOS voice agent. It exposes a
signed, typed, local file-bridge so AURA can read editor state and issue
allowlisted commands without arbitrary shell strings.

## Provisioning

1. AURA generates a shared secret and shows it once in its UI.
2. Run **AURA Bridge: Enter Shared Secret** from the VS Code Command Palette.
3. AURA stores the same secret in its Keychain; the extension stores it in
   VS Code's encrypted `SecretStorage`.
4. AURA's composition root retrieves the secret, builds an authenticator, and
   starts reading the signed snapshot. Until this succeeds, all VS Code
   capabilities remain disabled.

## Commands

- `AURA Bridge: Enter Shared Secret`
- `AURA Bridge: Revoke Shared Secret`
- `AURA Bridge: Show Health`

## Configuration

Set absolute paths for the three bridge files:

- `auraBridge.statePath`
- `auraBridge.commandPath`
- `auraBridge.responsePath`

These must point into a directory both processes can access (e.g., a
subfolder of `~/Library/Group Containers/...` or a user-created temp path).

## Protocol

- HMAC-SHA256 over sorted-key JSON.
- 30-second envelope expiry plus 5-second clock-skew tolerance.
- Per-envelope nonce with replay rejection on the Swift side.
- One protocol version; version mismatch produces `.disabled` on the AURA side.
- Typed command enum; no raw extension command IDs or shell text.

## Packaging

```bash
npm install
npm run compile
npx vsce package
```

Produces `aura-vscode-extension-0.1.0.vsix`.

## Security

- The shared secret is never logged.
- Unsigned health envelopes are emitted when unprovisioned but carry an empty
  authentication tag; AURA only trusts signed envelopes and rejects empty tags
  on authenticated snapshot reads.
- The extension does not execute arbitrary commands; it maps the allowlisted
  `BridgeCommand` enum to specific VS Code command IDs.
- AURA policy still gates every bridge command on the Swift side.
