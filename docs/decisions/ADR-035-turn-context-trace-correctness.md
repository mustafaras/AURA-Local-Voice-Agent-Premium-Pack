# ADR-035 - Turn Context and Trace Correctness

- Status: Accepted
- Date: 2026-08-02
- Owners: GitHub Copilot
- Supersedes: -
- Superseded by: -

## Context

AURA's event bus carries correlation and causation identifiers, but downstream audio, STT, conversation, intent, policy, and tool code previously had several paths that created unrelated UUID roots. That made one user turn difficult to reconstruct and allowed backend measurements to lose the actual engine identity. A turn also needs authority, sensitivity, timing, and pending-work provenance that cannot be inferred reliably from an individual event.

## Decision

1. `TurnContext` is the immutable metadata contract for one user turn. It carries session ID, turn ID, stable correlation ID, current causation ID, activation source, actor, authority provenance, sensitivity, language, monotonic timing origin, actual backend IDs, and pending task/confirmation references.
2. Push-to-Talk, wake activation, and text submission create the only production turn roots. Downstream stages preserve the stable correlation and advance causation with `TurnContext.advancing(causationID:)` or `TurnContext.envelope(...)`.
3. STT partial, stable, error, and cancellation events, wake activation/deactivation events, conversation events, policy requests, tool routing, latency measurements, and TTS handoff carry the active context or its derived envelope metadata.
4. Diagnostic events that occur before a turn exists may use the session ID as a stable diagnostic correlation root. They must not be presented as a user-turn trace.
5. Backend metadata is recorded from the injected/selected adapter's `engineID`, not from a production hardcoded mock flag. Mock detection remains derived from the recorded backend IDs for test evidence only.

## Alternatives considered

- Generate a new correlation ID at every subsystem boundary. Rejected because it destroys trace reconstruction.
- Put context in a global singleton. Rejected because concurrent turns would cross-contaminate and actor ownership would be unclear.
- Pass raw UUID pairs while leaving authority and backend metadata implicit. Rejected because the contract would remain incomplete and easy to bypass.

## Security and privacy impact

The context contains identifiers and bounded provenance only. It does not contain ambient audio, screenshots, secrets, or unredacted private content. Authority provenance is metadata and never replaces `PolicyEngine` authorization.

## Operational impact

Context-first APIs are preferred. Compatibility UUID overloads remain only at existing boundaries that have not yet migrated. Each compatibility path derives a context from the supplied envelope/session identifiers rather than creating a new unrelated turn root.

## Validation evidence

- `AuraCoreTests` covers context causality, envelope inheritance, Codable round trips, backend metadata, and confirmation context binding.
- `AuraAudioTests` validates wake pipeline behavior after context-aware event emission.
- `AuraSTTTests` validates STT lifecycle behavior after context-aware event payload changes.
- `AURAIntegrationTests` validates consecutive Push-to-Talk/STT turns, concrete STT failure isolation, and conversation bridging.
- The complete R1 evidence index entry will record the fresh full-suite result and its CommandLineTools limitation.

## Limitations

Audio capture lifecycle events that occur outside an active user turn remain session diagnostics. A universal postcondition verifier for every future capability is not introduced by this ADR; each adapter must still expose a truthful outcome contract before a capability can claim `verified`.

## Consequences

- Positive: one user turn can be reconstructed across activation, recognition, intent, policy, execution, verification, and response.
- Positive: concurrent turns have explicit immutable ownership and cannot inherit a global trace root.
- Negative: event payloads and compatibility adapters gain additive optional metadata until all callers are context-first.
