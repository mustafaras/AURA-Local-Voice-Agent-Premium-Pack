# EV-SP-026-20260828-REPRODUCIBLE-ARTIFACT-BLOCKED-01

- **Prompt/Track:** SP-026 / R11 (OPEN-12)
- **Timestamp:** 2026-08-28 (build slice); observed-CI slice blocked
- **Commit/Branch:** `3e81582c5fccdd4f82eca831dd10a8ee49241ceb` on `main` (origin/main equal); SP-025 predecessor delivered at `5a664a01d25a5be998e489c84a034f0655542c2e`
- **Environment:** macOS 27.0 arm64; Xcode 27.0 beta 5 (`Build version 27A5237l`) at `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`; Swift 6.4 (`swiftlang-6.4.0.30.4 clang-2100.3.30.1`, `swift-driver 1.168.6`); macOS SDK 27.0; Git 2.54.0; Python 3.14.6; gh 2.95.0
- **Evidence class:** Automated / contract + deterministic reproducibility (no observed hosted CI run)

## Objective

Close the bounded SP-026 slice of OPEN-12: establish a reproducible release toolchain and observe CI artifact/provenance evidence before any signing/distribution action. The observed-CI slice is the blocker.

## What was delivered (reproducible build slice)

- **Toolchain pinning (Procedure step 1):** confirmed and recorded the exact observed versions in this evidence record and cross-checked them against `AURA_RUNTIME_COMPLETION/state/toolchain-manifest.json` and `TOOLCHAIN.md`. No toolchain drift from the accepted R0 baseline.
- **Reproducible development artifact + manifest (Procedure step 2):** ran `./scripts/build-release-artifact.sh` at canonical commit `3e81582` with a clean working tree. Produced `/tmp/aura-r11-release-artifact/output/AURA-development-unverified.zip` (SHA-256 `202bb5cd07386e119fc360a0469acf72e7f1c3347b5d613506b326180a07a1bc`, 56,472,706 bytes) and `AURA-development-unverified.manifest.json`. Manifest records `release_status: development_unverified`, `source.commit: 3e81582...`, `source.working_tree: clean`, `bundle_id: ai.aura.local.agent`, `version: 0.1.0`, `build: 1`, `minimum_os: 27.0`, `helper_ipc_protocol: 2`, 17 bundle files, 17 SBOM components, and `signature: {developer_id: false, hardened_runtime: false, notarization: not_submitted, stapled: false, verification: not_performed}`. `validate_release_manifest.py` PASSED.
- **Deterministic reproduction (Procedure step 2):** a second build at the same `BUILD_ROOT` and commit produced a byte-identical archive hash (`202bb5cd...`). A build at a *different* `BUILD_ROOT` produced a different hash because SwiftPM embeds the absolute build path in the 5 compiled Mach-O executables (`AURA`, `AuraPluginHost`, `AuraAutomationHelper`, `AuraShellHelper`, `AuraSafariExtensionHandler`); the ZIP container itself is deterministic (fixed 1980 timestamp, ZIP_STORED, fixed attributes). Therefore reproducibility is **deterministic given an identical canonical commit and identical build root** — this is the honest claim.
- **Provenance defect found and fixed:** `generate_release_manifest.py` mislabeled a **clean** working tree as `dirty_or_unavailable` because `run_optional` collapsed empty `git status --porcelain` output to `None`. Added `run_optional_keep_empty`, now reports `working_tree: clean` for clean trees, `dirty` for dirty trees, and `dirty_or_unavailable` only when git is unavailable. Added a regression test in `scripts/tests/test_release_manifest.py`. Commit `3e81582`. 5/5 release-manifest tests pass.
- **Governance tests:** full `scripts/tests` suite = 40 run, 1 failure + 1 error, both **pre-existing** and outside SP-026 scope: (1) `OAuthLeakageCorpusTests.swift:16` secret-shaped finding from SP-024 commit `7b425e8`; (2) `$.active_prompt.id does not match pattern` first-pass schema incompatibility with SP-* IDs (documented pre-existing, recorded in prior SP-016 closeout). `git diff --check` clean. Second-pass validator PASSED.

## Observed CI blocker (Procedure step 3 — NOT completed)

The workflow `.github/workflows/ci.yml` requires `runs-on: [self-hosted, macOS, swift-6.4]`. `gh api repos/mustafaras/AURA-Local-Voice-Agent-Premium-Pack/actions/runners` returns `{"total_count":0,"runners":[]}` — **zero self-hosted runners registered**. All pushes (SP-025 commit `5a664a0` run `33152188166`; generator fix `3e81582` run `33152568023`) queued a `governance` job that remains `queued` with zero completed steps because no runner can execute it. Provisioning a runner would require install/configuration authority that SP-026 does **not** grant (`install_dependencies: false`; the prompt forbids install without explicit authority). Therefore **no observed CI run, artifact retention, signature/manifest inspection, or workflow-vs-run distinction can be claimed**. This is the exact open evidence gate named in OPEN-12 ("no post-change CI run has been observed").

## Cognitive completion gate answers

- **What exact symptom or missing postcondition was observed?** The observed-CI postcondition is absent: the workflow cannot start because there is no self-hosted runner and SP-026 has no authority to provision one.
- **What mechanism and root cause explain it?** The CI `runs-on` requires a self-hosted runner labeled `macOS, swift-6.4`; the runner inventory is empty. Prior H-010 closure used a *temporary, separately-authorized* runner that was deregistered; that authority is not present here.
- **What direct change or acceptance procedure resolved it?** Not resolved — blocked on runner availability + authority.
- **Which evidence ID and evidence class prove the result?** This record (`EV-SP-026-20260828-REPRODUCIBLE-ARTIFACT-BLOCKED-01`), automated/contract; `gh run list` + `gh api .../actions/runners` output.
- **What observation would falsify the conclusion?** A registered runner appearing in the inventory, or a queued run transitioning to `completed` with retained artifacts.
- **What residual risk remains, and why is it outside this prompt?** Observed hosted CI, retained-artifact inspection, and signature/manifest/provenance-of-the-run remain open because they need an authorized runner. This is an external/authority boundary, not a local defect.
- **Why is SP-027 now safe to start?** **It is not.** The SP-026 completion gate ("Reproducibility and observed CI evidence are independently inspectable and match the canonical commit") is unmet because observed CI evidence is absent. Per the Stop condition, SP-026 stays `in_progress`/`blocked` and SP-027 must not start.

## Required records

- Evidence ID prefix `EV-SP-026-` used. Artifact path `/tmp/aura-r11-release-artifact/output/AURA-development-unverified.zip` (SHA-256 `202bb5cd07386e119fc360a0469acf72e7f1c3347b5d613506b326180a07a1bc`). Scope: reproducible build slice delivered; observed-CI slice blocked. Limitations: no hosted CI run; no signing/notarization/clean-machine evidence; deterministic-archive claim is conditional on identical commit+build root.
- No raw audio, screenshots, secrets, tokens, private account data, or unredacted model output were written to any ledger or context file.
