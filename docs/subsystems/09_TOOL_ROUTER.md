> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Tool Router and Application Adapters

## Adapter priority
1. Native application framework.
2. Official API or extension API.
3. CLI with structured output.
4. MCP server with explicit schema.
5. Accessibility tree.
6. Apple Events or Shortcuts.
7. Screen-based computer use.

## Tool contract
Each tool declares:
- identifier and version
- input/output schema
- required permissions
- risk level
- idempotency
- preconditions
- side effects
- timeout
- rollback capability
- verification method
- sensitive fields

## Router behavior
- Reject unknown fields.
- Canonicalize paths.
- Resolve application identities by bundle ID.
- Evaluate policy before execution.
- Record proposal and result.
- Verify the real-world postcondition.
