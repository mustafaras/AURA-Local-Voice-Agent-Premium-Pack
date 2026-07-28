# Event System and Contracts


> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


## Event envelope

Every event includes:
- `event_id`
- `event_type`
- `schema_version`
- `occurred_at`
- `recorded_at`
- `correlation_id`
- `causation_id`
- `session_id`
- `task_id`
- `actor`
- `sensitivity`
- `payload`
- `integrity_hash`

## Event categories
- Audio lifecycle
- Conversation lifecycle
- Intent and plan
- Policy decision
- Confirmation
- Tool invocation
- UI observation
- Agent lifecycle
- Test and verification
- Memory mutation
- Security event
- Recovery event

## Delivery semantics
- At-least-once delivery internally.
- Idempotent consumers.
- Per-aggregate ordering.
- Durable checkpoints.
- Poison-event quarantine.
- Schema migration and backward compatibility tests.

## Prohibited event content
- Raw passwords.
- Authentication tokens.
- Full unredacted screenshots by default.
- Ambient audio recordings unless the user explicitly enables diagnostic capture.
- Entire private documents when a reference and hash are sufficient.

## Audit distinction
Operational telemetry may be sampled. Security, confirmation, permission, destructive-action, and ledger events must never be sampled.
