> **Status:** Design document — R11 artifact/manifest slice verified; runtime updater pending
> **Target:** macOS 27+ on Apple Silicon
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience

# AURA Update Mechanism

This document describes the planned software-update design for AURA. R11 now provides a local, `development_unverified` artifact/manifest/checksum slice; it does not constitute a signed release or an update engine. The in-app update engine remains intentionally deferred until separately authorized direct local lifecycle evidence exists; external signing, notarization, and distribution are out of scope under ADR-049.

> **Current scope correction (2026-09-02):** ADR-046 is accepted only for
> the local contract/source scope. The architecture and remote URL below are
> historical design material, not an implemented transport or lifecycle
> acceptance claim. Direct local evidence is still required for update,
> rollback, migration, safe-mode, support-bundle, reset, and uninstall
> postconditions. Launch-at-login has later direct local evidence, but does
> not prove that wider recovery matrix. ADR-049 permanently excludes Developer
> ID, notarization, and external clean-machine distribution from the local
> product; it does not turn missing local lifecycle evidence into a pass.

## Goals

1. **Privacy first:** update metadata never reveals user identity, installed commands, or memory contents.
2. **Fail closed:** a failed or untrusted update leaves the previous version runnable.
3. **User in control:** no automatic installation without explicit approval; the agent can only *notify* that an update is available.
4. **Least privilege:** the updater runs as a separate, short-lived helper with no Accessibility, microphone, or screen-recording access.

## Non-goals

- Auto-installation in the background.
- Delta / incremental patching for v1.
- App Store distribution (requires further ADR).

## Historical planned architecture

```
┌─────────────────────────────────────┐
│           AURA agent                │
│  (policy-gated network access)      │
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

## Historical planned trust model

1. Release artifacts are signed with the local stable identity + hardened runtime and verified locally; the product is local-only and does not use Developer ID or notarization (ADR-049).
2. The helper verifies:
   - Code signature of the downloaded bundle matches the expected local signing identity / pinned requirement.
   - Bundle identifier is `ai.aura.local.agent`.
   - Version string is strictly newer than the running version (semantic-version compare).
3. If any check fails, the artifact is discarded and the event is recorded in the ledger.

## Historical planned update flow

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
- `scripts/build-release-artifact.sh` — produces a deterministic, explicitly
  unverified local ZIP and manifest; it does not sign, notarize, install, or
  publish.
- `scripts/generate_release_manifest.py` and
  `scripts/validate_release_manifest.py` — generate and fail closed on the
  local bundle inventory, SBOM, checksums, and release-status boundary.

These scripts intentionally do not perform network operations, do not distribute anything, and do not touch user data.

## Security considerations

- The helper must run with no Accessibility, microphone, or screen-recording entitlements.
- The current main process is intentionally not App Sandbox enabled because
  native Accessibility and CLI integrations have not yet moved behind
  structured helpers. Its network restrictions are policy/allowlist controls,
  not kernel enforcement. A future update helper must be separately sandboxed,
  domain-pinned, and incapable of widening the main process's grants.
- Downloaded artifacts are staged in `~/Library/Caches/ai.aura.local.agent/updates/` with `O_EXCL`/`0700` permissions and validated before any installation step.
- Rollback: the install assistant keeps the previous bundle at `AURA.app.previous` until the new version launches successfully.

## Deferred work

- [ ] Implement `ai.aura.update.helper` XPC service target.
- [ ] Add release metadata endpoint and signature format.
- [ ] Add `UpdateCheckRequestedEvent` and related event payloads.
- [ ] Add update approval UI/voice flow.
- [ ] Add atomic install assistant.
- [ ] Turn the accepted local-only updater design in
  `docs/decisions/ADR-046-signed-update-recovery.md` into direct lifecycle
  evidence only under separate, explicit authority. This is not an external
  release or transport authorization.
- [ ] Add a ServiceManagement launch-at-login implementation with explicit
  user consent and lifecycle evidence.
- [ ] Add safe mode, support-bundle, migration, uninstall, and factory-reset
  recovery flows with restart/rollback evidence.
