# EV-SP-030-20260830-CONTRACT-MEASURED-MODE-01

**Evidence ID:** EV-SP-030-20260830-CONTRACT-MEASURED-MODE-01
**Track:** SP-030 / R12 / OPEN-13
**Type:** Defect/implementation — the R12 readiness contract could not represent a completed beta; extended to a provenance-bound measured mode
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty with SP-030 changes)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830
**Authority:** Release owner, present in session, explicitly directed the contract fix ("Evet — kontratı düzelt, ölçülebilir kısmı ölç") after being shown the structural finding below.

## Symptom observed

SP-030 had been re-attempted and left `blocked` repeatedly (most recently
`EV-SP-030-20260830-PROGRAM-BLOCKED-01`, authored by the `deepseek-v4-flash:0731-cloud`
agent in VS Code Copilot chat session `de53c5c3-58f4-4eaf-8946-54d486f53100`). Each
attempt correctly refused to fabricate evidence, but no attempt identified that the
harness *also* had no lawful way to record a success.

## Root cause — the contract could only ever validate an unstarted program

`scripts/validate_beta_readiness.py` (pre-change) asserted, unconditionally:

- every SLO `status == "not_measured"`, `target_ms is None`, `sample_minimum is None`;
- every scenario `status == "not_run"` and `evidence_ids == []`;
- `incident_review.status == "not_run"` with all counts `None`;
- every sign-off `== "not_obtained"`;
- `telemetry.enabled is False`, cohort `not_enrolled`, consent `not_collected`.

`beta-readiness.schema.json` additionally capped `readiness_status` to
`["blocked","not_ready"]`.

The validator therefore could not distinguish a **real** measurement from a
**fabricated** one — it treated *any* recorded result as fabrication. SP-030's
completion gate ("Mandatory SLOs and scenarios pass … independent sign-offs are
complete") was consequently unreachable **by construction**, independent of
authority or evidence.

### Falsifiable demonstration (performed before the change)

A hypothetical, perfectly-executed, honest beta record — every SLO measured,
every scenario passed, every sign-off obtained, `readiness_status` held at the
most conservative allowed value `not_ready` — was submitted to the old validator:

```
exit: 2
beta readiness validation failed: SLO measurement is fabricated
```

An honest success was rejected as fabrication. That is the defect.

## Change made

`validate_beta_readiness.py` rewritten around two representable modes. The
measured mode is **not** a relaxation — every recorded result must carry its own
provenance or it fails closed:

- **Measurement class travels with every number** — `live_user_present`,
  `deterministic_harness`, or `synthetic_speech`. A harness result that sets
  `live_beta_sample: true` is rejected, so repeatable coverage can never be
  presented as a live beta sample.
- **Every measured SLO** requires a well-formed evidence ID, a measurement class,
  prose limitations, a declared `sample_minimum`, a `sample_count` that meets it,
  and a recorded value for every declared percentile.
- **Every non-`not_run` scenario** requires evidence IDs, a measurement class, and limitations.
- **A completed incident review** requires an evidence ID, integer counts, and a
  remediation record (root cause, remediation, regression test, closure owner,
  evidence ID) whenever any count is non-zero.
- **Sign-offs cannot be self-granted.** An obtained sign-off must be an object naming
  an evaluator, asserting `independent: true` and `evaluator_is_implementing_agent: false`,
  with an evidence ID. A bare string `"obtained"` is rejected.
- **Invariants preserved in every mode:** `telemetry.transport == "none"`,
  `raw_content_allowed == false`, no content-bearing aggregate field,
  `authority.release == false`, and the release candidate stays `blocked`/unapproved.
  Any enabling authority flag requires an `authority_source` evidence ID.

`beta-readiness.schema.json` updated to document the two modes (`$defs` for
evidence ID pattern, measurement class, SLO/scenario/sign-off/remediation shapes).
`readiness_status` deliberately still capped at `["blocked","not_ready"]` —
promoting past that is SP-031/ADR-047 work, never this record's.

## Second defect found and fixed — a whole test bundle was never running

`scripts/aura-test.sh` enumerates a hardcoded `TEST_TARGETS` array. **`AuraLifecycleTests`
was absent from it**, so the SP-028 updater / rollback / recovery / safe-mode /
migration bundle — precisely the evidence the R11 dependency rests on — was
silently excluded from every "full suite" run. Prior records reporting "full suite
0 failed" did not include it.

Run in isolation it passes: **48 tests in 10 suites, PASSED**. The code was never
broken; the runner was hiding it. `AuraLifecycleTests` added to `TEST_TARGETS`.
True full-suite total is **1290 tests across 22 bundles**, not 1242 across 21.

## Verification

- `scripts/tests/test_beta_readiness.py`: 6 pre-existing tests still pass unchanged
  (backward compatibility), plus 17 new provenance/independence tests — **23 pass**.
  Adversarial cases proven to fail closed: measurement without provenance, unknown
  measurement class, harness result claiming a live beta sample, sample below declared
  minimum, missing declared percentile, malformed evidence ID, scenario passed without
  evidence, sign-off by the implementing agent, bare-string sign-off, incidents without
  remediation, telemetry transport activation, release self-approval.
- Python suite: 41 → 58 tests. **Zero new failures introduced.** Three failures are
  pre-existing and unrelated, confirmed by stashing only these changes and re-running:
  `test_current_repository_state_is_valid` (environment: `swift package dump-package`
  and `uv lock --check` unavailable), `test_validator_passes_without_printing_secret_values`,
  and `test_state_and_handoff_are_locked_to_first_uncompleted_prompt` (reflects SP-030's
  own blocked state).
- `python3 scripts/validate_second_pass_program.py` → **SECOND-PASS VALIDATION PASSED** (exit 0).
- `python3 scripts/validate_beta_readiness.py --record …/beta-readiness.json` → **valid** (exit 0).

## Falsifiers

Any claim that this change permits a result to be recorded without provenance, that
a sign-off can be self-granted, that telemetry transport or release authority became
grantable here, that `readiness_status` may now exceed `not_ready`, or that SP-030's
completion gate is met, would falsify this record.

## Residual risk

The contract can now record an honest beta; it does not supply one. The live
latency SLOs, live STT/WER, a live-window scenario run, the incident review, and the
five independent sign-offs remain genuinely open — see
`EV-SP-030-20260830-HARNESS-MEASUREMENT-01`. **SP-030 remains `in_progress`; SP-031 must NOT start.**
