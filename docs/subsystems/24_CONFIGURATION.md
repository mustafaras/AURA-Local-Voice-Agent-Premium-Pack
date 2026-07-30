> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Configuration and Feature Flags

## Layers
1. Secure defaults
2. Machine policy
3. User settings
4. Project settings
5. Session overrides

Higher-risk capabilities may not be weakened by project configuration.

## Requirements
- Typed configuration schema.
- Validation at startup.
- Atomic writes.
- Migration history.
- Unknown-key warnings.
- Sensitive values stored in Keychain, not configuration files.
- Feature flags include owner, purpose, expiry, and rollback plan.

## Implemented Phase 24 contract

`AuraConfig` implements the normative layer order with a registry-owned schema.
Each key declares its type, permitted layers, numeric bounds, and the direction
in which lower-trust settings may change a security value. Machine policy is an
enforced bound. Project and session layers may strengthen security, but cannot
raise allow-by-default risk, lower confirmation requirements, widen network
access, enable raw telemetry, or increase a machine-bounded local-model limit.

The engine persists one versioned state envelope through `AuraStore`. A
candidate becomes effective only after the single SQLite upsert succeeds.
Accepted mutations retain rollback snapshots; session overrides are cleared on
restart. Unknown keys reject the patch and remain visible as warnings. Secret
configuration keys are rejected because secrets belong in Keychain.

Feature flags require complete governance metadata, a future expiry, rollback
plan, bounded deterministic rollout, and a kill switch. Expiry and kill switch
win over every override. A project may enable an off-by-default flag only when
the trusted registry definition explicitly permits ordinary project opt-in.

Local tuning retains only aggregate numeric counts and sums for latency, error,
energy, and correction metrics. It is disabled until the user opts in.
Recommendations include their numeric evidence and explanation and remain
pending until the user accepts or rejects them. No remote telemetry path exists.

The Settings scene exposes effective changed values, source layers, audit
count, refresh, and recommendation opt-in. Programmatic inspection also returns
the full effective configuration, default diff, warnings, audit, snapshots,
flags, and recommendations.

See `docs/decisions/ADR-032-self-tuning-configuration-governance.md`.
