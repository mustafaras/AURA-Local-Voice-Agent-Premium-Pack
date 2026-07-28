> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Screen Context and Redaction

## Capture policy
Screen capture is off until granted and actively needed. Prefer window-scoped capture. Exclude the assistant's own windows and configured sensitive applications.

## Redaction
Detect and mask:
- secure text fields
- password managers
- authentication codes
- financial data
- private notifications
- user-defined regions
- secrets matching configured patterns

## Context representation
Store structured summaries and hashes, not screenshots, unless diagnostic retention is explicitly enabled.

## Freshness
Every observation includes application identity, window identity, capture time, geometry, display scale, and a freshness deadline.
