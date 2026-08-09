# R12 Beta Readiness Contract

## Status

The R12 readiness record is intentionally `blocked`. R11 is incomplete and no
beta cohort, telemetry, app launch/install, release candidate, or participant
activity is authorized.

The machine-readable contract is
`AURA_RUNTIME_COMPLETION/state/beta-readiness.json`. Validate it with:

```sh
python3 scripts/validate_beta_readiness.py \
  --record AURA_RUNTIME_COMPLETION/state/beta-readiness.json
```

## Safety boundary

The contract requires no enrolled cohort, no collected consent, no active
transport, no raw audio/screenshots/prompts/model outputs/private identifiers,
no fabricated SLO samples, no completed scenarios, no incident closure, no
independent sign-offs, and no approved release candidate. Local validation
proves only that these conservative defaults remain intact.

Before any beta work, an authorized owner must approve the cohort, supported
matrix, excluded capabilities, content-free aggregate fields, retention,
incident SLA, rollback/kill-switch authority, privacy notice, SLO targets, and
participant issue process. R11 must first provide a signed, notarized,
recoverable artifact with clean-machine evidence.
