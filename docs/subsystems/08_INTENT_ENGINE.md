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

## Implementation

A new `AuraIntent` target implements steps 1–6 above for a deliberately
closed v1 vocabulary — `IntentKind`: `converse`, `appActivate`,
`appTerminate`, `shellExecute`, `codingAgentRun`, `unknown` — covering
Conversation, Application command, Coding-agent command, and Unknown from
the intent-class list above; File/workspace command, Browser task,
Observation request, System setting, Memory operation, and High-risk
external action (beyond destructive shell) remain future work.

- `TypedIntent` (`Sources/AuraIntent/TypedIntent.swift`) is the typed
  candidate from step 4: closed `kind`/`semanticCategory` enums plus named
  `IntentSlot`s — never a raw free-text command string.
- `RuleBasedUtteranceClassifier` (`Sources/AuraIntent/IntentEngine.swift`)
  implements steps 1–2 with deterministic keyword-prefix rules and two
  closed lookup tables (app name → bundle identifier; executable name →
  absolute path). An utterance naming something outside a table is
  classified `.unknown` with a low confidence score — never a guessed
  identifier or path, directly implementing this doc's "never invent a
  tool" rule at the entity-resolution level, not just the tool-selection
  level.
- `IntentEngine.classify` implements step 6: a single, configuration-driven
  confidence gate (`IntentEngineConfiguration.minimumClassificationConfidence`,
  default `0.6`) forces `.unknown`/ambiguous below threshold.
- `ToolRouter` (`Sources/AuraIntent/ToolRouter.swift`) implements steps 7–8
  — see `09_TOOL_ROUTER.md`'s Implementation section.
- `IntentSemanticCategory` (`Sources/AuraCore/IntentPolicyTypes.swift`)
  provides the pure, non-negotiable `semanticCategory → riskTier` mapping
  step 6 depends on, mirroring `ComputerUseSemanticIntent`'s precedent
  (Phase 18).

Full design rationale: `docs/decisions/ADR-021-intent-engine-tool-router.md`.
