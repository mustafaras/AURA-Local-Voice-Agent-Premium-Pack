> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Permission System

## Risk tiers
- Tier 0: observation of non-sensitive metadata.
- Tier 1: reversible local action.
- Tier 2: file or environment mutation.
- Tier 3: external communication, push, deployment, purchase, deletion, privilege change, or sensitive-data access.

## Grant model
Permissions are capability-specific, target-specific, action-specific, and time-bounded.

## Confirmation
A confirmation displays:
- intended action
- target
- expected side effects
- reversibility
- data leaving the device
- requesting agent
- expiry

A generic “yes” applies only to the single currently displayed confirmation.
