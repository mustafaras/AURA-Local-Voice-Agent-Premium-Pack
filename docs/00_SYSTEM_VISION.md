# System Vision


> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## Product statement

AURA is a local-first, continuously available macOS assistant that listens for an authorized speaker, understands natural spoken instructions, maintains conversational and project context, selects the safest available control mechanism, operates desktop applications, delegates coding work to specialized agents, and explains consequential actions before execution.

## Experience goals

The assistant should feel present without being intrusive:

- Ambient audio is processed locally.
- A wake phrase or deliberate conversational continuation activates the assistant.
- The user may interrupt spoken output at any time.
- Short deterministic commands execute quickly.
- Longer tasks are delegated and tracked.
- The assistant reports meaningful progress rather than narrating every internal step.
- The assistant understands references such as “that project,” “the previous fix,” or “ask Claude to review it” by reconstructing evidence-backed context.
- The user can inspect and revoke every permission.

## Success criteria

- Median wake-to-acknowledgement latency below 500 ms on the target device.
- Median simple-command completion below 1.5 seconds when no remote model is required.
- No destructive or externally consequential action without the required confirmation.
- No false success reports.
- Durable recovery after process crash or system restart.
- Clear separation between local processing and optional remote agent calls.
- Reliable operation with Turkish speech, English technical terms, and code-switching.

## Product modes

### Passive
Only local wake-word, VAD, speaker authorization, and privacy controls operate.

### Conversational
Streaming STT, local intent handling, context tracking, and TTS operate.

### Task execution
The assistant invokes deterministic tools or coding agents and tracks a durable task.

### Observation
The assistant may inspect the active application or a user-approved screen region.

### Restricted
Sensitive applications, secure fields, or privacy policies block observation and automation.

## Trust model

The user remains the authority. Models propose; policy decides; tools execute; evidence verifies; the ledger records.
