> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# macOS Accessibility Integration

## Responsibilities
- Enumerate trusted applications and windows.
- Read roles, titles, values, enabled state, selected state, and actions.
- Perform supported accessibility actions.
- Observe focused application and UI changes.
- Generate minimal keyboard or pointer input only when required.

## Permission handling
- Detect trust state.
- Explain why access is required before opening System Settings.
- Degrade safely when access is denied.
- Never repeatedly nag.
- Expose a permission health dashboard.

## Engineering constraints
- Run AX calls off the audio real-time path.
- Apply timeouts because target applications may hang.
- Validate element identity immediately before action.
- Treat stale accessibility references as expected failures.
