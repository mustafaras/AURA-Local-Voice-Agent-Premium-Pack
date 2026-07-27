> **Status:** Design document — implementation pending
> **Target:** macOS 26+ on Apple Silicon
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience

# AURA Update Mechanism

This document describes the planned software-update design for AURA. The current repository contains build and code-sign placeholder scripts only; the in-app update engine is intentionally deferred until after the first signed release exists.

## Goals

1. **Privacy first:** update metadata never reveals user identity, installed commands, or memory contents.
2. **Fail closed:** a failed or untrusted update leaves the previous version runnable.
3. **User in control:** no automatic installation without explicit approval; the agent can only *notify* that an update is available.
4. **Least privilege:** the updater runs as a separate, short-lived helper with no Accessibility, microphone, or screen-recording access.

## Non-goals

- Auto-installation in the background.
- Delta / incremental patching for v1.
- App Store distribution (requires further ADR).

## Architecture

```
┌─────────────────────────────────────┐
│           AURA agent                │
│  (no network client entitlement)    │
└──────────────┬──────────────────────┘
               │ 1. poll availability
               │    via XPC to helper
               v
┌─────────────────────────────────────┐
│      ai.aura.update.helper          │
│  (network.client = true only)       │
│  - fetches release metadata         │
│  - downloads signed .dmg/.zip       │
│  - verifies signature / notarization│
└──────────────┬──────────────────────┘
               │ 2. notify user + verify
               v
┌─────────────────────────────────────┐
│   system install assistant (future) │
│  - replaces app bundle atomically     │
│  - keeps previous bundle as backup    │
└───────────────────────────────────────┘
```

## Trust model

1. Release artifacts are signed with a Developer ID certificate and notarized by Apple.
2. The helper verifies:
   - Code signature of the downloaded bundle matches the hardcoded team identifier.
   - Notarization staple is present (for offline installs).
   - Bundle identifier is `ai.aura.local.agent`.
   - Version string is strictly newer than the running version (semantic-version compare).
3. If any check fails, the artifact is discarded and the event is recorded in the ledger.

## Update flow

| Step | Actor | Action | Evidence |
|---|---|---|---|
| 1 | Agent | User asks "check for updates" or weekly poll fires | `UpdateCheckRequestedEvent` |
| 2 | Helper | Fetch metadata from `https://updates.aura.ai/macos/releases.json` (placeholder) | `UpdateMetadataEvent` |
| 3 | Helper | Validate metadata signature | `UpdateSignatureValidEvent` or `UpdateSignatureInvalidEvent` |
| 4 | Agent | Speak summary and ask for approval | `UpdateApprovalRequestedEvent` |
| 5 | User | Approves or denies | `UpdateApprovedEvent` / `UpdateDeniedEvent` |
| 6 | Helper | Download, verify, stage replacement | `UpdateStagedEvent` |
| 7 | System | Atomic swap on next relaunch | `UpdateInstalledEvent` |

## Placeholder scripts

- `scripts/build-app-bundle.sh` — builds `AURA.app` from SwiftPM release.
- `scripts/codesign-adhoc.sh` — ad-hoc signs the bundle for local testing.
- `scripts/verify-signature.sh` — verifies signature and entitlements.

These scripts intentionally do not perform network operations, do not distribute anything, and do not touch user data.

## Security considerations

- The helper must run with no Accessibility, microphone, or screen-recording entitlements.
- The agent itself must retain `network.client = false` so a prompt-injection or compromised model cannot exfiltrate data or pull arbitrary updates.
- Downloaded artifacts are staged in `~/Library/Caches/ai.aura.local.agent/updates/` with `O_EXCL`/`0700` permissions and validated before any installation step.
- Rollback: the install assistant keeps the previous bundle at `AURA.app.previous` until the new version launches successfully.

## Deferred work

- [ ] Implement `ai.aura.update.helper` XPC service target.
- [ ] Add release metadata endpoint and signature format.
- [ ] Add `UpdateCheckRequestedEvent` and related event payloads.
- [ ] Add update approval UI/voice flow.
- [ ] Add atomic install assistant.
- [ ] ADR for update signing, key rotation, and rollback.
