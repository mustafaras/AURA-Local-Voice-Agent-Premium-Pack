> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Intent Engine

## Intent classes
- Conversation
- Application command
- File/workspace command
- Coding-agent command
- Browser task
- Observation request
- System setting
- Memory operation
- High-risk external action
- Unknown or ambiguous

## Processing
1. Normalize transcript without losing original text.
2. Extract entities and references.
3. Reconstruct minimal relevant context.
4. Generate a typed intent candidate.
5. Validate against schema.
6. Calculate ambiguity and risk.
7. Select deterministic handler or planning model.
8. Produce an inspectable execution plan.

## Rule
An LLM may select among registered tools but may never invent a tool or directly emit executable shell text as the execution contract.
