> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Memory Engine

## Memory classes
- Ephemeral audio buffer
- Working conversation state
- Session summary
- Task state
- Project facts and decisions
- User-approved preferences
- Procedural knowledge
- Audit and security records

## Memory record
- immutable ID
- type
- subject
- normalized statement
- evidence references
- provenance
- confidence
- sensitivity
- created and observed timestamps
- retention policy
- supersedes/superseded-by
- project and task scope

## Rules
- Facts require evidence.
- Inference is labeled.
- New contradictory information creates a conflict record.
- Sensitive personal facts are not retained without an explicit purpose and consent.
- The user can inspect, correct, export, and delete non-audit memory.
