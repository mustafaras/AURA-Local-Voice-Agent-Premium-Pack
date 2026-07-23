> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Delivery Roadmap

## Milestone 0 — Repository foundation
Schemas, event bus, ledger, CI, formatting, and test infrastructure.

## Milestone 1 — Local voice loop
Audio capture, VAD, wake word, streaming STT, and system TTS.

## Milestone 2 — Deterministic desktop control
Application launch, Finder, VS Code, typed shell commands, permissions.

## Milestone 3 — Agent orchestration
Codex, Claude, Copilot, Ollama, worktrees, structured events.

## Milestone 4 — Memory and context
Durable task state, decisions, reconstruction, inspection, deletion.

## Milestone 5 — Computer-use fallback
Screen capture, redaction, accessibility fusion, bounded action loop.

## Milestone 6 — Production hardening
Threat model, adversarial tests, signing, update, recovery, energy tuning.

Each milestone has an acceptance gate and must be independently usable.
