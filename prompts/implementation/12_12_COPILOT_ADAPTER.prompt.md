# 12_COPILOT_ADAPTER — Implementation Prompt

You are the principal engineer responsible for this phase.

## Mission
Integrate supported GitHub Copilot CLI or agent workflows, repository customizations, normalized tasks, and strict separation between local and cloud execution.

## Mandatory inputs
- `AGENTS.md`
- `ledger/CURRENT_STATE.md`
- `ledger/PROJECT_LEDGER.md`
- all relevant normative specifications

## Operating procedure
1. Inspect the repository and verify the actual starting state.
2. Identify unresolved dependencies and incompatible prior decisions.
3. Produce a concise implementation plan tied to acceptance criteria.
4. Create or update an ADR for material architectural decisions.
5. Implement the smallest complete vertical slice.
6. Add failure handling and observability as part of the implementation.
7. Add unit, contract, integration, and end-to-end tests appropriate to the phase.
8. Run all relevant commands and inspect exact outputs.
9. Review the final diff for security, privacy, scope, and accidental regressions.
10. Append an evidence-backed ledger entry and atomically update current state.

## Hard constraints
- No placeholder, fake, stubbed-as-complete, or TODO-only implementation.
- No invented APIs or flags.
- No destructive action, push, deployment, or release unless explicitly authorized.
- No silent reduction of tests or acceptance criteria.
- No raw model output may become an executable action.
- Do not continue to a later phase when this phase fails its gate.

## Required response
- Starting state
- Plan
- Changes
- Verification evidence
- Risks and limitations
- Ledger update
- Next safe action
