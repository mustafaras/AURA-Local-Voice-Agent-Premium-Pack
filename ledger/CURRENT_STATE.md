# Current State

This file is a compact, atomically replaced projection of the append-only ledger.
Projection refreshed from live repository and command evidence on 2026-07-28.

- Phase: Phase 0–23 runtime/UI remediation implemented and locally verified; Phase 24 not started.
- Git state: runtime/UI and TCC/signing remediation is locally verified and
  awaiting its user-authorized normal commit/push. The pre-existing generated
  `.vscode/launch.json` change remains outside scope.
- Product lifecycle:
  - Native SwiftUI dashboard window, retained menu-bar control, and Settings
    scene.
  - Clean-profile `0700` Application Support bootstrap before `AuraStore`.
  - Missing Speech/microphone authorization is recoverable and never triggers a startup prompt.
  - Explicit voice onboarding, push-to-talk, status, recent tasks, runtime warnings, confirmations, settings/privacy links, and visible/global emergency stop.
  - No trained acoustic wake-word model is bundled; the UI discloses
    push-to-talk as the supported path, and production samples do not feed the
    synthetic marker detector.
- Runtime composition:
  - Core audio/STT/intent/conversation/task pipeline remains wired.
  - Implemented Screen, Computer Use, Security, Plugin, VS Code, Ollama, worktree, and multi-agent services are constructed behind existing policy, permission, trust, and configuration gates.
  - Confirmation challenges use one nonce/hash/expiry-bound UI presenter and deny on missing UI, dismissal, timeout, shutdown, or overlap.
- Security boundary:
  - `AuraPluginHost` remains a separately signed, restrictive App Sandbox helper with live self-attestation.
  - The main app is intentionally unsandboxed while Accessibility and CLI execution remain in-process. Main-process network controls are policy/allowlist controls, not OS sandbox enforcement.
  - The main app is signed with Hardened Runtime and only the audio-input
    entitlement. Accessibility and Screen Recording remain macOS TCC grants,
    not fabricated signing entitlements.
- Verified evidence:
  - Changed Swift files pass `swift format lint`.
  - `AURA` passes warnings-as-errors build.
  - All 18 test bundles pass: 580/580 tests.
  - LLVM line coverage is 70.63%; CI ratchet is 70%, with 80% retained as the next target.
  - Release app build, ad-hoc signing, strict validation, helper entitlement checks, and helper sandbox attestation pass.
  - Final app CDHash: `0fa87108af0d47aef7fc19455b64042ecac5d6b3`;
    signature flags include `adhoc,runtime`.
  - Final packaged clean-profile smoke remained alive for eight seconds until watchdog exit, created `aura.db`, and verified directory mode `0700`.
  - Installed `/Applications/AURA.app` reports Microphone, Speech Recognition,
    Accessibility, and Screen Recording all Granted. Push to Talk reached its
    bounded listening timeout without a permission failure.
  - Main/helper plists pass `plutil -lint`; repository diff passes `git diff --check`.
- Manual/release gates still open:
  - Real `CGEvent`, VoiceOver reading order, contrast, Dynamic Type, and live
    screen-content behavior still require release-hardware validation.
  - Real acoustic wake-word model, Developer ID signing/notarization, public plugin vendor PKI/catalog, and real third-party payload execution remain unavailable external-material/release gates.
  - The main-process Accessibility/CLI privileges should ultimately move behind least-privilege helpers before claiming OS-enforced network confinement.
- Release status: No release, deploy, notarization, or public marketplace
  publication was performed. The scoped remediation commit/push is explicitly
  authorized and is the current closing operation.
- Next safe action: Review, commit, and normally push the scoped remediation
  while preserving `.vscode/launch.json`; verify local/tracking/transport refs,
  then start Phase 24.
