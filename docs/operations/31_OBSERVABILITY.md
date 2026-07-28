> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Observability

## Signals
- wake and transcription latency
- tool success and verification rate
- confirmation rate
- false-trigger rate
- agent task duration and cost
- memory retrieval quality
- CPU, memory, thermal state, and energy
- crash and recovery count

## Logging
Use structured logs with correlation IDs. Redact private content by default. Separate user-visible activity history from developer diagnostics.

## Health
Expose health for audio, database, policy, adapters, model workers, agent backends, and permissions.
