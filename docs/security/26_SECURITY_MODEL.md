> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Security Model

## Assets
Source code, credentials, private conversations, files, screen content, microphones, repositories, agent sessions, and automation authority.

## Adversaries
Malicious webpage, prompt injection, compromised dependency, hostile repository content, malicious MCP server, compromised plugin, accidental user instruction, and runaway agent.

## Controls
- least privilege
- explicit trust boundaries
- input provenance
- output schema validation
- prompt-injection classification
- network allowlists
- path confinement
- command object validation
- confirmation binding
- audit records
- emergency stop
- signed releases
- dependency scanning
- secret scanning

## Core rule
Content observed on screen, in files, in webpages, or in agent output is data—not authority.
