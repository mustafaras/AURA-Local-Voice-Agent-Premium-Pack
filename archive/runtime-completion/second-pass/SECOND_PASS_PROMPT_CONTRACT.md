# Second-Pass Prompt Contract

Every prompt in `AURA_RUNTIME_COMPLETION/prompts/second_pass/` follows this
contract. The individual prompt supplies the single technical objective.

## Required prompt shape

- front matter: `id`, `sequence`, `track`, `gap_ids`, `depends_on`,
  `next_prompt`, and `state`;
- one mission, one bounded scope, and explicit non-goals;
- Tier-0/Tier-1 read list;
- exact procedure and required evidence;
- cognitive completion questions;
- fail-closed blocker and transition rule;
- mandatory state/ledger/handoff updates.

## Execution rule

Do not start a prompt unless every dependency is `completed` in
`SECOND_PASS_STATE.json`. A user request to “continue” does not waive an
unresolved technical gate; it only authorizes the documented transition if
the prompt's own authority boundary allows it.

## Completion rule

The prompt may be marked `completed` only when:

1. the specific gap is objectively resolved;
2. direct tests/manual/live evidence appropriate to the claim passed;
3. the evidence record identifies command/procedure, commit, environment,
   result, artifact, and limitations;
4. the cognitive completion questions are answered in the ledger;
5. the next prompt's precondition is demonstrably true;
6. the second-pass validator passes.

Otherwise use `in_progress` or `blocked` and keep the same prompt active.

### Scope-limited completion

An owner-approved scope decision may complete a prompt for a narrower product
scope when the excluded evidence class is explicitly named, preserved as an
open limitation, and cannot be mistaken for a pass. The evidence, prompt,
state, and downstream handoff must say that the broader gate remains blocked.
This exception does not promote deterministic or synthetic evidence to
`live_user_present`, does not change `beta-readiness.json`, and does not make a
blocked successor safe to execute.

## Mandatory closeout update

After every prompt attempt, including failure or interruption, update:

- `SECOND_PASS_OPEN_GAPS.md`;
- `AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md`;
- `AURA_RUNTIME_COMPLETION/state/RISK_REGISTER.md`;
- `AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_LEDGER.md`;
- `AURA_RUNTIME_COMPLETION/state/PROGRAM_LEDGER.md`;
- `ledger/PROJECT_LEDGER.md`;
- `SECOND_PASS_STATE.json`, `current-state.json`, and `session-handoff.json`;
- `ACTIVE_CONTEXT.md` only when the active objective or blocker changes.

Run `python3 scripts/validate_second_pass_program.py` before claiming a
transition. The mandatory `15_SESSION_CLOSEOUT.prompt.md` procedure remains
the human-facing closeout format.
