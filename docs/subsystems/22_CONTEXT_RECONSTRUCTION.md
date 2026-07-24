> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Context Reconstruction

## Goal
Rebuild the smallest sufficient context for the current request without flooding the model or relying on stale summaries.

## Retrieval sequence
1. Current utterance and stable transcript.
2. Active conversation state.
3. Pending confirmation or task.
4. Active application/workspace.
5. Relevant project ledger entries.
6. Recent evidence-backed decisions.
7. User-approved preferences.
8. Optional semantic retrieval.

## Ranking
Prioritize scope match, recency, authority, confidence, and direct evidence.

## Guardrails
- Never resolve “it” to a destructive target on weak evidence.
- Ask or surface a focused confirmation when multiple targets remain plausible.
- Include source IDs in internal context bundles.
