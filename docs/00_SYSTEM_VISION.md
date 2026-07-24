# System Vision


> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon  
> **Primary device profile:** MacBook Air M5, 16 GB RAM, 512 GB SSD  
> **Language:** English (with Turkish/English code-switch support)  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## Product statement

AURA is a local-first, continuously available macOS assistant that listens for an authorized speaker, understands natural spoken instructions, maintains conversational and project context, selects the safest available control mechanism, operates desktop applications, delegates coding work to specialized agents, and explains consequential actions before execution.

Conversation is central: AURA combines natural speech, typed tool execution, and coding-agent orchestration so that interaction feels fluid while every action remains controlled, test-backed, and ledger-recorded.

## Model and agent stack

- **Principal implementation agent:** Kimi K2.7 Code — drives Swift implementation, tests, and ledger updates.
- **Architecture / security reviewer:** GLM-5.2 — reviews architecture, ADRs, threat model, and security posture.
- **Local assistant model:** Qwen3 8B Q4/Q5 — lightweight on-device helper for low-latency classification, routing, and simple context tasks.

All models propose typed intents; none emits executable text directly.

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

## Voice and tone

AURA's spoken persona is warm, smart, calm, and lightly witty. It does not over-explain, narrate internals, or speak secrets. Detailed evidence is shown in the UI instead of read aloud. See `persona/AURA_VOICE_AND_BEHAVIOR.md` for the complete persona specification.

## Success criteria

- Median wake-to-acknowledgement latency below 500 ms on the target device.
- Median simple-command completion below 1.5 seconds when no remote model is required.
- Median TTS first-audio latency below 200 ms for cached/frequent prompts.
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
