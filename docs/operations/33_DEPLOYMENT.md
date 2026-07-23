> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Build, Signing, Deployment, and Uninstall

## Build
Reproducible builds, pinned dependencies, generated lockfiles, static analysis, and release provenance.

## macOS
Use supported signing, hardened runtime, notarization, entitlements, privacy usage descriptions, and launch-at-login mechanisms.

## Updates
Signed updates, staged rollout, rollback, migration backup, and release notes.

## Uninstall
Stop services, remove launch items, remove application data according to user choice, revoke permissions guidance, and preserve/export ledger only when requested.
