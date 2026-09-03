# EV-SP-026-20260828-OBSERVED-CI-COMPLETED-01

- **Prompt/Track:** SP-026 / R11 (OPEN-12)
- **Timestamp:** 2026-08-28
- **Commit/Branch:** canonical `348bb6aceb60bb387214ab5f35ad955fbad77dd7` on `main` (origin/main equal; working tree clean)
- **Environment:** macOS 27.0 arm64; Xcode 27.0 beta 5 (`27A5237l`) at `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`; Swift 6.4; macOS SDK 27.0; GitHub Actions runner 2.337.0 (temporary self-hosted `sp026-ci-runner-2`, labels `macOS, swift-6.4`)
- **Evidence class:** Observed CI run (live hosted-run evidence) + automated/contract + deterministic reproducibility

## Objective

Close SP-026's observed-CI slice: run the actual CI workflow on a self-hosted macOS/swift-6.4 runner, inspect retained artifacts, signatures, manifests, and provenance, and distinguish workflow configuration from run evidence.

## What was delivered under this evidence

- **Observed CI run:** run `33157842324` on canonical commit `348bb6a` completed with conclusion **success** for both `governance` and `build-and-test` jobs.
  - `governance`: passed `validate_runtime_completion.py --ci`, `scripts/tests` governance tests, `validate_repo_hygiene_program.py`, `validate_second_pass_program.py`, `validate_repo_hygiene_supply_chain.py`, `zsh -n scripts/*.sh`, `git diff --check`.
  - `build-and-test`: strict `swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` passed; `./scripts/aura-test.sh /tmp/aurabuild-ci` with `AURA_COVERAGE_MIN=70` passed **0 failed bundles** and **line coverage 70.69% meets 70%**; the `development_unverified` artifact step built and uploaded the artifact.
- **Retained artifact inspected:** artifact `9680431386`, name `aura-development-unverified-348bb6aceb60bb387214ab5f35ad955fbad77dd7`, 13,660,896 bytes, `expired: false`, 14-day retention. Downloaded and extracted: `AURA-development-unverified.zip` (SHA-256 `1275811456d915de4bb644a930cba269f89049d951f5fec14f73b2e3e47d0539`, 56,557,922 bytes) + `AURA-development-unverified.manifest.json`.
- **Manifest provenance verified:** `release_status: development_unverified`; `source.commit: 348bb6aceb60bb387214ab5f35ad955fbad77dd7` (matches the canonical commit); `source.working_tree: clean`; `bundle_id: ai.aura.local.agent`, `version: 0.1.0`, `build: 1`, `minimum_os: 27.0`, `helper_ipc_protocol: 2`; 17 bundle files, 17 SBOM components; `signature: {developer_id: false, hardened_runtime: false, notarization: not_submitted, stapled: false, verification: not_performed}`. `validate_release_manifest.py` PASSED against the extracted bundle and artifact.
- **Workflow configuration vs run evidence distinguished:** the CI workflow definition was already statically validated (configuration). This evidence records the *observed run* (execution) on the canonical commit, which is the run evidence.

## CI blockers surfaced by the observed run and resolved

The observed CI run surfaced four real blockers that were resolved before the passing run:

1. **First-pass schema rejected SP-* active prompt** — `program-state.schema.json` only allowed `BOOTSTRAP|R[0-9]+|FINAL` for `active_prompt.id`; added `SP-[0-9]{3}`.
2. **First-pass validator required SP-* in first-pass manifest** — `validate_runtime_completion.py` now skips first-pass-manifest membership for SP-* prompts (governed by `SECOND_PASS_PROMPT_MANIFEST.json`).
3. **Stale projections** — `current-state.json` `last_evidence_ids` exceeded 50; `capability-matrix.repository_commit` mismatched `verified_head`; `working_tree_state` was `dirty_expected` on a clean runner checkout. All synced to the canonical baseline.
4. **Coverage regression below 70%** — line coverage measured 69.57% after the SP-021–026 source additions. Added a deterministic `ConfigurationValidationTests` suite in `AuraCoreTests` covering the configuration value types' `validate()` guards, `mergedWithDefaults()` fallbacks, and Codable round-trips; line coverage restored to **70.69%** with no gate/scope/threshold weakened.
5. **Swift warnings-as-errors build failures** — `catch let error as ProductivityError` where the typed-throws error is always `ProductivityError`, and an unnecessary `await` on a non-async property; both fixed and all five production products build cleanly.

## Reproducibility evidence

The reproducible `development_unverified` artifact+manifest was also built locally at canonical commit `3e81582` (artifact SHA-256 `202bb5cd07386e119fc360a0469acf72e7f1c3347b5d613506b326180a07a1bc`), confirming deterministic-archive reproduction given identical commit+build root. The CI build at `348bb6a` produced its own `development_unverified` artifact with `source.commit` matching the canonical CI commit.

## Cognitive completion gate answers

- **What exact symptom or missing postcondition was observed?** The observed-CI postcondition was absent: no self-hosted macOS/swift-6.4 runner was registered, so pushed CI runs stayed `queued` with zero completed steps.
- **What mechanism and root cause explain it?** `.github/workflows/ci.yml` requires `runs-on: [self-hosted, macOS, swift-6.4]`; the runner inventory was empty and no temporary runner was available under SP-026's earlier authority.
- **What direct change or acceptance procedure resolved it?** Registered a temporary self-hosted GitHub Actions runner 2.337.0 (`sp026-ci-runner-2`, labels `macOS, swift-6.4`) with SHA-256-verified download, ran the actual CI workflow on canonical commit `348bb6a`, and inspected the retained artifact/manifest/provenance. The runner is temporary and will be deregistered.
- **Which evidence ID and evidence class prove the result?** This record (`EV-SP-026-20260828-OBSERVED-CI-COMPLETED-01`), observed CI run class. Run `33157842324` success; artifact `9680431386`.
- **What observation would falsify the conclusion?** A failed rerun of the same commit, a missing/expired artifact, a manifest whose `source.commit` does not match the canonical commit, or a non-`development_unverified` status.
- **What residual risk remains, and why is it outside this prompt?** This is a `development_unverified` artifact — no Developer ID signing, notarization, Gatekeeper clean-machine, nested-helper/TCC identity, or signed update/rollback evidence. Those are separate R11/ADR-046 release gates outside SP-026. The observed CI is the reproducible-build/pipeline slice; full release distribution remains blocked.
- **Why is SP-027 now safe to start?** Reproducibility and observed CI evidence are independently inspectable and match the canonical commit `348bb6a`; the SP-026 completion gate is met.

## Required records

- Evidence ID prefix `EV-SP-026-` used. Artifact paths/hashes recorded above. Scope: reproducible build + observed CI slice of OPEN-12. Limitations: development_unverified (no signing/notarization/clean-machine); deterministic-archive claim conditional on identical commit+build root.
- No raw audio, screenshots, secrets, tokens, private account data, or unredacted model output were written to any ledger or context file.
