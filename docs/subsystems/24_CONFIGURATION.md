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
