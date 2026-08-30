> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Build, Signing, Deployment, and Uninstall

## Build
Reproducible builds, pinned dependencies, generated lockfiles, static analysis, and release provenance.

## macOS
Use supported signing, hardened runtime, notarization, entitlements, privacy usage descriptions, and launch-at-login mechanisms.

The local development bundle is signed with the local stable identity +
hardened runtime (ADR-049). `AuraPluginHost` is separately
App Sandbox confined and self-attests its sandbox at runtime. The main
application is intentionally unsandboxed until Accessibility and CLI execution
move into least-privilege helpers; therefore its network allowlist is an AURA
policy boundary, not an OS sandbox boundary. Developer ID signing and
notarization are permanently out of scope for the local-only product (ADR-049).

## Updates
Signed updates, staged rollout, rollback, migration backup, and release notes.

## Uninstall
Stop services, remove launch items, remove application data according to user choice, revoke permissions guidance, and preserve/export ledger only when requested.
