> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Ollama and Local Model Controller

## Role
Handle low-latency routing, classification, summarization, offline tasks, and privacy-sensitive reasoning appropriate to the selected model.

## Resource management
- Maintain a model registry with memory estimates and capabilities.
- Avoid loading large STT, vision, coding, and TTS models simultaneously on 16 GB systems.
- Implement idle unload, thermal awareness, and priority preemption.
- Benchmark actual target hardware.
- Degrade to deterministic rules for simple commands.

## Trust
Local does not mean safe. Validate structured output and enforce the same policy boundaries.
