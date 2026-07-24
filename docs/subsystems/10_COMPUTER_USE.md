> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Computer-Use Fallback

## Scope
Computer use is a fallback for interfaces without reliable structured control.

## Observation loop
1. Capture only the approved display, window, or region.
2. Redact protected zones.
3. Produce a structured UI observation.
4. Generate one bounded action or a short atomic sequence.
5. Re-check policy.
6. Execute.
7. Capture the resulting state.
8. Verify progress or stop.

## Safety
- Never interact with password fields.
- Never approve security dialogs automatically.
- Never send, publish, purchase, delete, deploy, or accept legal terms without explicit confirmation.
- Limit action rate and coordinates to the approved target.
- Stop on unexpected modal dialogs, identity changes, or repeated no-progress cycles.
- Maintain an emergency stop that disables generated input immediately.

## Reliability
Prefer accessibility identifiers and text anchors over absolute coordinates.
