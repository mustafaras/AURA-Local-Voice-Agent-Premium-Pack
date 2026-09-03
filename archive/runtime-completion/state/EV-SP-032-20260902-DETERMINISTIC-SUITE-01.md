# EV-SP-032-20260902-DETERMINISTIC-SUITE-01

- **Timestamp:** 2026-09-02 (autonomous no-operator session)
- **Prompt / gap:** SP-032 / OPEN-14 — FINAL acceptance cleanup, deterministic-evidence leg
- **Session:** `AURA-SP-032-DETERMINISTIC-EVIDENCE-20260902`
- **Repository:** `main`; `HEAD == origin/main ==`
  `bee334782262089fa117124ababa9b3c6dfed394`; worktree `dirty_expected`
  (prior SP-030/SP-031 control-plane and evidence projections only; no new
  product source/test change introduced by this attempt).
- **Evidence class:** `deterministic_harness` / automated governance. It is
  **not** clean-Mac, live-user, end-to-end, beta, release-candidate, or release
  evidence. No synthetic or deterministic result is promoted to a live or
  release class.
- **Environment:** macOS 27.0 arm64; Apple Swift 6.4; Python 3.14.6; Git 2.54.0;
  CommandLineTools active developer directory.

## Purpose

Record a fresh, fully-executed deterministic-control leg under the current
edit/test/state-only authority. This does not close SP-032; it provides
reproducible evidence for the sub-facets that CAN be exercised without
installation, launch, TCC, beta, signing, commit, push, or release authority,
and truthfully re-confirms which gates are not closable without those.

## Procedure and executed commands (all exit 0)

1. `python3 scripts/validate_second_pass_program.py` — **PASSED**.
2. `python3 scripts/validate_runtime_completion.py --ci` — **PASSED** (schema,
   state, manifest, evidence, capability, toolchain, legacy pointers).
3. SP-031 bound artifact integrity recheck on
   `/tmp/aura-sp031-local-rc-20260902/output/`:
   - `AURA-development-unverified.zip` SHA-256
     `d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837`
     (matches bound record `EV-SP-031-20260902-OWNER-LOCAL-ONLY-APPROVAL-01`);
   - `AURA-development-unverified.manifest.json` SHA-256
     `4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5`
     (matches bound record).
4. `python3 scripts/validate_release_manifest.py --manifest
   .../AURA-development-unverified.manifest.json --bundle-root
   /tmp/aura-sp031-local-rc-20260902/app-build/AURA.app --artifact
   .../AURA-development-unverified.zip` — **PASSED**.
5. `python3 scripts/validate_beta_readiness.py --record
   AURA_RUNTIME_COMPLETION/state/beta-readiness.json` — **valid; remains
   `blocked`** (telemetry disabled, no transport, no live beta evidence).
6. Full deterministic suite via `./scripts/aura-test.sh
   /tmp/aura-sp032-full-20260902` — **22 bundles PASSED, 0 failed bundles,
   1325 tests / 87 suites total, exit 0.** This includes:
   - `AuraLifecycleTests`: 48 tests / 10 suites (safe mode, crash recovery,
     update stage/rollback, export redaction, migration, factory-reset,
     launch heartbeat) — the R11 update/rollback/recovery deterministic leg;
   - `AuraAdversarialTests` / `AuraSecurityTests` / `AuraPolicyTests` /
     `AuraComputerUseTests` / `AuraProductivityTests` — security, policy,
     computer-use, and productivity deterministic legs.

## Bound evidence

| Item | Value |
|---|---|
| Deterministic suite | `/tmp/aura-sp032-full-20260902` (wrapper scratch build; not an artifact of record) |
| Suite result | 22 bundles, 0 failed, 1325 tests / 87 suites, exit 0 |
| SP-031 artifact SHA-256 | `d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837` |
| SP-031 manifest SHA-256 | `4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5` |
| Verdict | **Deterministic control green; SP-032 remains blocked.** |

## Cognitive gate (SP-032) — deterministic sub-leg only

1. **Symptom / missing postcondition:** FINAL acceptance requires direct
   clean-Mac/end-to-end (R2-R10), live lifecycle/clean-profile (R11), and live
   beta SLO/scenario/incident/sign-off (R12) evidence plus explicit authority.
2. **Mechanism / root cause / layer:** The deterministic control plane is
   healthy (validators + suite + artifact all green), but the missing gates
   are inherently live/system-authority outcomes that no deterministic or
   edit-only step can produce.
3. **Direct resolution (this leg):** Re-ran and re-recorded the green
   deterministic suite and validators under current authority; re-confirmed
   artifact integrity and beta-readiness fail-closed.
4. **Evidence ID / class:** `EV-SP-032-20260902-DETERMINISTIC-SUITE-01` =
   `deterministic_harness` / automated governance.
5. **Falsifier:** Any failed validator, non-zero suite, artifact hash mismatch,
   schema/state contradiction, or any claim that this green control leg
   constitutes clean-Mac/live/beta/RC/release acceptance would falsify the
   conclusion.
6. **Residual risk / scope:** R2-R10 direct acceptance, R11 live launch/
   clean-profile/lifecycle, R12 live SLO/scenario/incident/independent
   sign-off, and FINAL authority remain open. ADR-049 permanently excludes
   external distribution but does not waive these local postconditions.
7. **Why SP-033 is not safe:** SP-032 remains `blocked`; no `release_candidate`
   / FINAL completion authority exists.

## Authority and limitations

No app install/launch, TCC mutation, provider contact, beta enrollment or
telemetry activation, signing, notarization, release, deployment, commit,
push, or merge occurred. No raw audio, screenshot, secret, token, private
account data, or unredacted model output was collected or recorded. Per the
repository control contract and ADR-051/ADR-052, a synthetic or deterministic
result is never promoted to a live or release evidence class; this record
complies with that rule.
