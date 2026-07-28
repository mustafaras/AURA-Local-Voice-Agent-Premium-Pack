> **Status:** Normative specification  
> **Target:** macOS 27+ on Apple Silicon, with graceful degradation where practical
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

## Implementation

`ToolRouter` (`Sources/AuraIntent/ToolRouter.swift`) implements this
subsystem for the v1 intent vocabulary (`ADR-021`).

- `ToolContract` (`Sources/AuraIntent/ToolRouter.swift`) carries every field
  listed above, plus one AURA-specific addition — `enforcesPolicyInternally`
  — capturing a real split found while wiring real backends: the CLI
  coding-agent adapters (Codex/Claude/Copilot) already call
  `PolicyEngine.evaluate` themselves before running; `AuraAutomation`/
  `AuraShell` construct a policy request but never evaluate it themselves
  (their own doc comments say so). `ToolRegistry.defaultRegistry()` is the
  concrete tool table for `.appActivate`/`.appTerminate`/`.shellExecute`/
  `.codingAgentRun`/`.converse`.
- "Evaluate policy before execution" is real for every
  `enforcesPolicyInternally == false` contract: `ToolRouter.resolvePolicy`
  calls `PolicyEngine.evaluate`, presents a `.confirm` challenge via an
  injected `IntentConfirmationPresenting`, and — regardless of how `.allow`
  was reached — applies a hard, non-bypassable mandatory-confirmation guard
  for any `IntentSemanticCategory` in `mandatoryConfirmationCategories`
  (currently `.shellDestructive`), mirroring `ComputerUseControlLoop`'s
  precedent (Phase 18).
- "Resolve application identities by bundle ID" happens one layer up, in
  `RuleBasedUtteranceClassifier`'s closed app-name lookup table (see
  `08_INTENT_ENGINE.md`) — by the time `ToolRouter` sees a `TypedIntent`,
  the bundle identifier is already resolved or the intent is `.unknown`.
- "Record proposal and result" is `IntentPlanGeneratedEvent`/
  `ToolInvokedEvent`/`ToolResultEvent`/`IntentBlockedEvent`
  (`Sources/AuraCore/IntentEventPayloads.swift`) — a full typed audit trail
  of every dispatch decision.
- A `.codingAgentRun` tool is delegated wholesale to `AgentBackendTaskRunner`
  (`Sources/AuraIntent/AgentBackendTaskRunner.swift`) via `AuraTaskEngine`,
  returning immediately rather than awaiting the run — see ADR-021 decision
  7 for why a synchronous wait is not viable, and decision 8 for why a
  single multiplexing runner (not one per backend) is structurally required.

Full design rationale: `docs/decisions/ADR-021-intent-engine-tool-router.md`.
