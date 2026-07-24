> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Performance and Resource Budgets

Define measured budgets for:
- wake detection latency
- first stable transcript
- simple command completion
- TTS first audio
- memory lookup
- application activation
- CPU in passive mode
- memory in passive and active modes
- energy impact
- thermal throttling behavior

Budgets must be benchmark-derived on the target Mac, not guessed. CI stores regressions and blocks material degradation.
