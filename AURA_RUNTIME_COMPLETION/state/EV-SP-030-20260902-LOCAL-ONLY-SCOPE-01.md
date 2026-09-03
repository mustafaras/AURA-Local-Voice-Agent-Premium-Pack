# EV-SP-030-20260902-LOCAL-ONLY-SCOPE-01

**Evidence ID:** `EV-SP-030-20260902-LOCAL-ONLY-SCOPE-01`
**Track:** SP-030 / OPEN-13 — local-only scope completion
**Session:** `AURA-SP-030-LOCAL-ONLY-SCOPE-20260902`
**Timestamp:** 2026-09-02, 10:05 UTC / 13:05 Europe/Istanbul
**Branch / source:** `main`, source/delivery HEAD `bee334782262089fa117124ababa9b3c6dfed394`; product source baseline unchanged from `0bafc4f249968d6b620b181ff4ffd3da1d13b71e`
**Evidence class:** process/scope decision plus deterministic_harness; explicitly not live-beta evidence

## Decision

The release owner explicitly requested that no live test be performed. Under
ADR-051, SP-030 is narrowed to the local-only deterministic validation scope.
The scope includes the existing deterministic lifecycle, integration, STT,
safety, state-contract, evidence-classification, and validator checks. It does
not include a user-present beta window, microphone/STT quality, live latency,
live R11 transitions, live scenario execution, or incident review.

## Existing evidence accepted for this bounded scope

- `EV-SP-030-20260902-UNATTENDED-ALTERNATE-01`: `AuraLifecycleTests`
  48/10/0, `AURAIntegrationTests` 111/22/0, and `AuraSTTTests` 19/4/0.
  The opt-in synthetic Speech attempt failed closed with
  `speechNotAuthorized` in 3 real-recognizer tests; no TCC prompt or mutation
  occurred.
- Existing five R12 sign-offs remain recorded and launch-at-login is closed
  under `EV-SP-030-20260901-R11-LIVE-GATE-05`.
- State and governance validators passed after the prior attempt: 64 Python
  tests; second-pass, beta-readiness, runtime-completion, repository-hygiene,
  supply-chain, JSON, diff, and remote-equality checks all passed.

## Acceptance and limitations

The local-only deterministic completion gate is met by the scope decision,
provenance-bound evidence, and passing validators. This is not a claim that
live beta or production behavior passed. `beta-readiness.json` remains
`blocked`; telemetry remains disabled with `transport: none`; R11 remains
`in_progress`; `ptt_ack` and `stt_partial` remain `not_measured`;
`incident_review` remains `not_run`; and the release candidate remains
blocked/unapproved.

SP-031 is therefore not executed. It remains a downstream blocked prompt
because its RC/ADR-047 prerequisites are absent.

## Post-amendment deterministic verification

Executed 2026-09-02T10:24:13Z after the prompt, ADR, and state projection
changes:

- `./scripts/aura-test.sh /tmp/aura-sp030-local-scope-lifecycle-20260902 AuraLifecycleTests` — 48 tests / 10 suites / 0 failures.
- `./scripts/aura-test.sh /tmp/aura-sp030-local-scope-integration-20260902 AURAIntegrationTests` — 111 tests / 22 suites / 0 failures.
- `./scripts/aura-test.sh /tmp/aura-sp030-local-scope-stt-20260902 AuraSTTTests` — 19 tests / 4 suites / 0 failures.
- `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` — 64 tests, OK.
- `validate_second_pass_program.py`, `validate_runtime_completion.py`, and
  `git diff --check` — passed. Earlier beta-readiness, repository-hygiene,
  supply-chain, JSON, and remote-equality checks remain recorded above.

These are deterministic local checks only; no microphone, user-present beta
window, TCC mutation, telemetry transport, or live SLO measurement occurred.
The stale `open_blockers` sign-off sentence in `beta-readiness.json` was also
reconciled with its current five `obtained` sign-off records; readiness itself
remains `blocked`.

## Falsifiers and next action

This record would be falsified by any claim that the deterministic or
synthetic results are live-beta samples, that the live R11/incident gates ran,
or that beta readiness or SP-031 became approved. If live beta is ever desired,
open a new explicitly authorized scope and evidence pass; do not reuse this
local-only completion as live evidence.
