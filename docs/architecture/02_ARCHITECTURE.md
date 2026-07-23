# Reference Architecture


> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## Process topology

### AURA.app
SwiftUI menu-bar UI, onboarding, settings, consent surfaces, live status, confirmations, task views, and emergency stop.

### AuraCore service
Owns the event bus, orchestration state machine, policy decisions, memory coordination, and adapter registry.

### AuraAudio service
Runs a real-time-safe capture path, VAD, wake-word detection, speaker verification, streaming STT, and TTS scheduling.

### AuraAutomation service
Owns Accessibility access, ScreenCaptureKit sessions, Apple Events, application adapters, and input synthesis.

### AuraAgent service
Owns Codex, Claude Code, Copilot CLI, Ollama, PTYs, worktrees, budgets, cancellation, and structured task events.

### AuraStore
SQLite database, append-only event log, encrypted secrets references, migrations, and retention jobs.

## Communication

- Use versioned local IPC contracts.
- Prefer XPC for privileged or separately sandboxed macOS components.
- Use typed event envelopes with correlation ID, causation ID, timestamp, schema version, sensitivity, and actor.
- Never pass unbounded raw model output directly into execution APIs.
- Commands and events are distinct: commands request; events record facts.

## Core state machines

### Conversation
`passive → wake-detected → listening → interpreting → speaking → listening`
with interruption, timeout, cancellation, and restricted-mode transitions.

### Tool execution
`proposed → policy-evaluated → awaiting-confirmation → executing → verifying → completed|failed|rolled-back`

### Agent task
`created → preparing-worktree → running → awaiting-input → reviewing → validating → completed|failed|cancelled`

## Concurrency rules

- Audio capture and VAD must never block on network, disk, model loading, or UI work.
- One write-capable automation transaction per foreground application.
- One mutable task per worktree.
- Read-only analyses may run concurrently within resource budgets.
- TTS yields immediately to detected authorized user speech.
