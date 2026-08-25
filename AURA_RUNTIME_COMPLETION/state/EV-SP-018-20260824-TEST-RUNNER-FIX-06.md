# EV-SP-018-20260824-TEST-RUNNER-FIX-06

- **Timestamp:** 2026-08-24T07:57:49Z
- **Branch / commit:** `main` / `ed55a0c8db9c63059c7639f9160efebaf44816ac`; the worktree contains this uncommitted verification correction.
- **Evidence class:** direct deterministic runner procedure plus regression-test evidence.
- **Environment:** Apple Silicon macOS host; Xcode `27.0.0-beta.5`; Swift Testing library version `2077`; target `arm64e-apple-macos14.0`.
- **Symptom:** the default full `./scripts/aura-test.sh` invocation intermittently failed `AuraAgentTests` while the same specialist-swarm test passed in isolation. The failure occurred only when the bundle's live CLI probes, real git worktree operations, and actor-backed fixtures were scheduled concurrently; the observed outcome count was two failures instead of one expected specialist failure.
- **Mechanism / root cause:** `AuraAgentTests` was left at Swift Testing's unrestricted parallelization width. Under the full bundle schedule, bounded actor/worktree fixtures were timing-sensitive and produced a false test failure. The defect was in the test-runner execution boundary, not the SP-018 production reference wiring.
- **Direct change:** `scripts/aura-test.sh` now passes `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=${AURA_AGENT_TEST_PARALLELIZATION_WIDTH:-1}` only for `AuraAgentTests`. `README.md` documents the bounded default and explicit experimental override. `scripts/tests/test_aura_test_runner.py` locks the runner contract.
- **Commands / results:**
  - `python3 -m unittest scripts.tests.test_aura_test_runner` — red before the runner change, green after it.
  - `zsh -n scripts/aura-test.sh && git diff --check` — exit 0.
  - `./scripts/aura-test.sh /tmp/aura-sp018-fixed-agent AuraAgentTests` — exit 0; 237 tests in 9 suites; `Failed bundles: 0`.
  - `./scripts/aura-test.sh /tmp/aura-sp018-fixed-full` — exit 0; all 21 bundle logs completed; `Failed bundles: 0`.
- **Artifacts:** `/tmp/aura-sp018-fixed-agent/out/Products/Debug/AuraAgentTests.log` SHA-256 `c4bc72663f31e0e41e1ee11a416e5d7337cbad6be6f3ef80f5da77a9d625c866`; the 21-log full-suite manifest digest is `3d8c84fdf312b1e64e28775e2e3be1fb78477fee5e0b31fbed5e19bcd00cc498`.
- **Scope:** stabilizes the repository's deterministic test runner for `AuraAgentTests`; no application launch, TCC, provider, external account, release, deploy, commit, push, or merge action.
- **Falsifier:** a fresh default full-matrix run with this runner still records a failed bundle or an `AuraAgentTests` log contains a failure marker despite the bounded width.
- **Limitations / residual risk:** this does not establish user-present app restart acceptance, remote/provider behavior, model quality, signing, release, or deployment. The Swift Testing environment variable is toolchain-specific and remains explicitly overrideable for controlled experiments.
