> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Error Recovery

## Strategy
Classify failures as transient, permanent, policy, user-cancelled, dependency, stale-state, or security.

## Mechanisms
- bounded exponential backoff with jitter
- circuit breakers
- durable checkpoints
- transactional tool execution
- compensating actions
- stale-reference refresh
- task resume only from verified state
- safe-mode startup after repeated crashes

Never retry destructive actions blindly.
