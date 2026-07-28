# ADR-029 — SwiftUI Runtime Shell and Explicit Permission Onboarding

- **Status:** Accepted
- **Date:** 2026-07-28

## Context

The Phase 0–23 implementation shipped an asynchronous executable lifecycle but
no human interface. A clean macOS profile also failed before becoming usable:
the store parent directory was absent, and native Speech authorization was
treated as a fatal startup dependency even when authorization had never been
requested. Production confirmation presentation always denied because no
challenge surface existed.

## Decision

1. `AURA` opens a standard SwiftUI dashboard window, retains a
   `MenuBarExtra`, and provides a Settings scene. The standard window keeps the
   first-run permission and safety controls visible and accessibility-testable.
2. Startup creates a private, `0700` Application Support directory before
   opening `AuraStore`.
3. TCC prompts occur only after a visible user action. Missing or denied
   microphone/Speech permissions leave the app running in a restricted state.
4. Until a trained wake-word model is supplied, the supported activation path
   is Push to Talk. Production sample bridging does not feed the synthetic
   marker detector; that detector remains test-only and is never represented as
   production acoustic wake-word support.
5. Policy and agent confirmation challenges cross one nonce-bound,
   expiry-aware presenter. Missing UI, dismissal, timeout, shutdown, or a second
   overlapping challenge denies.
6. The emergency stop is available as a visible destructive control and the
   Command-Shift-Escape local/global keyboard shortcut.
7. Implemented Screen, Computer Use, Security, Plugin, VS Code, Ollama,
   worktree, and multi-agent components are constructed in `AuraKernel`, but
   retain their existing policy, permission, trust, and configuration gates.
8. The main process remains intentionally outside App Sandbox while native
   Accessibility and CLI execution remain in-process. Network restrictions are
   documented as AURA policy controls, not kernel enforcement. The plugin
   helper retains its independent App Sandbox boundary.
9. Local packages are signed with Hardened Runtime. The main app carries only
   the Hardened Runtime audio-input entitlement. Microphone and Speech
   Recognition are requested through their native APIs and usage descriptions;
   Accessibility and Screen Recording remain user-controlled TCC services and
   are not represented by fabricated code-signing entitlements.

## Consequences

- First launch is recoverable and permission denial no longer terminates the
  product.
- Native controls provide semantic labels, keyboard access, non-color-only
  status, settings guidance, and confirmation/emergency surfaces.
- UI-level confirmation is usable without introducing an always-allow
  presenter.
- Live Microphone, Speech Recognition, Accessibility, and Screen Recording TCC
  onboarding passed on the target Mac. Full VoiceOver, contrast, and generated
  input validation still require manual release-hardware evidence.
- A real acoustic wake-word model, Developer ID/notarization, public plugin PKI,
  and remote marketplace catalog remain explicit external-material/release
  gates.

## Rejected alternatives

- Prompting for TCC permissions during startup: rejected because consent must be
  explicit and denial must remain recoverable.
- Keeping the daemon entrypoint and adding undocumented command-line switches:
  rejected because confirmations, permission health, and emergency stop require
  persistent user-visible surfaces.
- Claiming `network.client = false` without App Sandbox: rejected because the
  entitlement does not establish an OS enforcement boundary for the main app.
