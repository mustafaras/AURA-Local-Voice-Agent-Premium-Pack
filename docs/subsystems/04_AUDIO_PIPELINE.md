> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Audio Pipeline

## Requirements
- Use AVAudioEngine or the current supported macOS capture framework.
- Configure echo cancellation and automatic gain carefully; expose diagnostics.
- Resample once, at the boundary required by the selected models.
- Maintain a bounded ring buffer for wake-word pre-roll.
- Never allocate, log, block, or perform file I/O in the real-time callback.
- Tag frames with monotonic timestamps and discontinuity markers.
- Detect device changes and recover without restarting the app.
- Support headphones, built-in microphone, and external devices.
- Pause or attenuate listening during assistant speech while preserving barge-in detection.

## Privacy
Default audio retention is zero. The ring buffer is volatile. Debug capture requires explicit opt-in, expiry, encryption, and visible indication.

## Acceptance
- No buffer underruns during a 60-minute soak test.
- Device disconnect recovery.
- Echo does not repeatedly trigger the assistant.
- CPU and energy use remain within the documented budget.
