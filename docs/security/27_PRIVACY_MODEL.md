> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Privacy and Data Governance

## Defaults
- Ambient audio is not persisted.
- Screen capture is task-scoped.
- Cloud use is disabled unless configured.
- Remote requests show the destination and data category in settings.
- Logs are redacted.
- Memory retention is minimal.

## User rights
Inspect, export, correct, delete, pause, disable, and reset.

## Data inventory
Maintain a machine-readable record of every stored data category, purpose, location, retention, encryption, and deletion mechanism.
