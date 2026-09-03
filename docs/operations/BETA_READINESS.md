# R12 Beta Readiness Contract

## Status

The R12 readiness record is intentionally `blocked`. R11 is incomplete and
`release_candidate` remains blocked/unapproved. One local participant is
enrolled with recorded consent and all five scoped sign-offs are obtained, but
no qualifying live-beta SLO set, live scenario window, or incident review
exists. Current session authority still forbids app launch/install, beta work,
and telemetry activation.

The machine-readable contract is
`archive/runtime-completion/state/beta-readiness.json`. Validate it with:

```sh
python3 scripts/validate_beta_readiness.py \
  --record archive/runtime-completion/state/beta-readiness.json
```

## Safety boundary

The contract preserves no active telemetry transport, no raw
audio/screenshots/prompts/model outputs/private identifiers, no fabricated SLO
samples, no promoted deterministic scenario result, no invented incident
closure, and no approved release candidate. The recorded cohort, consent, and
sign-offs do not waive the remaining live gates. Local validation proves only
that this fail-closed record is internally consistent.

Before a future live-beta attempt, a user-present owner must grant the specific
execution authority and confirm the supported matrix, excluded capabilities,
content-free aggregate fields, retention, incident SLA, rollback/kill-switch
authority, privacy notice, SLO targets, and participant issue process. R11 must
first provide the applicable direct local lifecycle and clean-profile evidence.
Developer ID, notarization, and external clean-machine distribution are
permanently out of scope for this local-only product under ADR-049.
