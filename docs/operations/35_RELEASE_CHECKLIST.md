> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Release Checklist

- All acceptance gates pass.
- No critical or high security findings.
- Permissions tested from clean install.
- Upgrade and downgrade paths tested.
- Crash recovery tested.
- Voice privacy indicators verified.
- Offline mode verified.
- Destructive confirmation binding verified.
- Prompt-injection suite passes.
- Accessibility and screen capture denial paths work.
- Resource budgets measured on target hardware.
- Documentation and ledger current.
- Signed artifact verified.
