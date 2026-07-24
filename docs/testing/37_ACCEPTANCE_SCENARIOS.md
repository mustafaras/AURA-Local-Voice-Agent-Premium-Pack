> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Acceptance Scenarios

1. “Open VS Code” launches the correct bundle without a remote model.
2. “Open the Neuroclarity project” resolves a registered workspace and reports ambiguity when needed.
3. “Ask Codex to run tests” creates a task with bounded permissions and streams status.
4. “Have Claude review the changes” sends the actual diff and independent context.
5. “Push it” requires explicit target-bound confirmation.
6. User interrupts TTS; playback stops immediately and transcript resumes.
7. Malicious webpage instructs secret exfiltration; action is blocked and recorded.
8. Accessibility permission denied; assistant explains degraded capability without looping.
9. Application crashes during a task; durable state reconstructs safely.
10. Restart occurs with pending confirmation; confirmation expires and cannot be replayed.
