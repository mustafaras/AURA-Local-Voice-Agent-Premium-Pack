# EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01

- **Timestamp:** 2026-09-02T12:10:20Z (package record; source/build and test
  procedures completed during this session)
- **Prompt / gap:** SP-031 / OPEN-13 / R12
- **Branch / source commit:** `main`; `HEAD == origin/main ==
  bee334782262089fa117124ababa9b3c6dfed394` in the repository. The package was
  built from a separate detached, clean worktree at the same exact commit:
  `/tmp/aura-sp031-source-20260902`.
- **Evidence class:** automated local package, reproducibility, deterministic
  test, coverage, and governance evidence. This is not `live_user_present`,
  `live_beta_sample`, production, or release-authority evidence.
- **Environment:** macOS 27.0 arm64; Xcode 27.0 beta 5 (`27A5237l`) selected at
  `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`; Apple Swift 6.4;
  macOS SDK 27.0; Python 3.14.6; Git 2.54.0.

## Objective and procedure

The missing postcondition was a current, provenance-bound local-only
`development_unverified` artifact and evidence record. In the detached clean
worktree, the following bounded procedure was executed twice:

```text
BUILD_ROOT=/tmp/aura-sp031-local-rc-20260902 \
OUTPUT_DIR=/tmp/aura-sp031-local-rc-20260902/output \
./scripts/build-release-artifact.sh
```

The first output was copied only to a temporary comparison path, then the same
command was run again. `cmp` returned success for the two ZIP archives. The
release-manifest validator executed by the build script returned success. No
application was launched or installed by this procedure.

## Bound package

| Item | Value |
|---|---|
| Artifact | `/tmp/aura-sp031-local-rc-20260902/output/AURA-development-unverified.zip` |
| Artifact SHA-256 | `d870475cb2f8e2580afc72296f4a828a2c54977828d7f6792fe12d9b3f33e837` |
| Artifact size | `58420226` bytes |
| Manifest | `/tmp/aura-sp031-local-rc-20260902/output/AURA-development-unverified.manifest.json` |
| Manifest SHA-256 | `4c5df5552867f27a43fbbf918fb7c5e07bcaefc1f6b255d1506a4c25a4cce5e5` |
| Manifest size | `10775` bytes |
| Bundle | `ai.aura.local.agent`, version `0.1.0`, build `1`, minimum macOS `27` |
| Release label | `development_unverified` |
| Build output | `/tmp/aura-sp031-local-rc-20260902/app-build/AURA.app` |
| SBOM | `aura-bundle-inventory-v1`, `bundle-files-only`, 17 bundle-file components |
| Signature state | Developer ID `false`; hardened runtime `false`; notarization `not_submitted`; stapled `false`; verification `not_performed` |

The manifest binds the clean source commit, bundle metadata, toolchain, bundle
file inventory and hashes, archive hash/size, and SBOM inventory. The package
does not include a tracked `AURA_MODEL_MANIFEST.json` or model weights. The
external Chatterbox model provenance therefore remains unqualified and the
neural voice capability is excluded from this package's qualified scope.
The dependency/toolchain references retained for review are:

- `Runtime/chatterbox/pyproject.toml` SHA-256
  `ac2903fc4491c53d4fc2f678761bf35742c7b249f1411017c81e691931cdbc3a`;
- `Runtime/chatterbox/uv.lock` SHA-256
  `16c6623a6b6cb4ee2a64300b1d666bfbc7617798847a6ebe79e38a2f3bc04433`; and
- `AURA_RUNTIME_COMPLETION/state/toolchain-manifest.json` SHA-256
  `9fe8cda70ed9ebe19c4626fd09d42b82524bc0301f633f19128f45e4d30d3f8d`.

The package procedure intentionally did not sign, notarize, publish, deploy,
contact a provider, enable telemetry, mutate TCC, capture microphone audio, or
record raw audio/screenshots/model output.

## Deterministic supporting evidence

The current product-source suite was run with:

```text
AURA_ENABLE_COVERAGE=1 ./scripts/aura-test.sh /tmp/aura-sp031-tests-20260902
```

Result: **1325 tests / 87 suites / 22 bundles / 0 failures**. The coverage
report met the 70% threshold at **70.20% line coverage**; report SHA-256 is
`1428b00d0b679094f6f3259c6ac085d04b28762650436760fd1540aca1209298`.
The logs and report remain under `/tmp/aura-sp031-tests-20260902` and contain
diagnostic output that is not copied into the ledger. Existing observed CI
evidence remains historical and commit-bound to its own source revision; no
hosted CI result for `bee334782262089fa117124ababa9b3c6dfed394` is inferred.

The following local governance checks also passed before this record was
written and are required to be rerun at closeout:

- `python3 scripts/validate_second_pass_program.py`;
- `python3 scripts/validate_runtime_completion.py --ci`;
- `python3 scripts/validate_beta_readiness.py --record AURA_RUNTIME_COMPLETION/state/beta-readiness.json`;
- `python3 -m unittest discover -s scripts/tests`; and
- `git diff --check`.

## SLO, scenario, incident, sign-off, and recovery limitations

The package carries, without promotion, the existing deterministic and
synthetic evidence classes. `ptt_ack`, `stt_partial`, and live dialogue
latency have no qualifying live-beta sample set; the five scenario entries are
`deterministic_harness`, not a beta-window run; and `incident_review` remains
`not_run`. The existing five sign-off records are preserved as their declared
review evidence and do not prove live beta, R11 completion, or release
authority. R11 remains `in_progress`; sleep/wake/crash recovery, safe-mode
export, populated-profile migration, and the broader live gates remain open.

Rollback/kill-switch scope is limited to the existing local contract and its
deterministic evidence. There is no external signed update transport, no
release-candidate approval, and no beta activation. `beta-readiness.json`
remains `blocked`; `release_candidate.status` remains `blocked` with
`approved: false`, null commit, and null artifact fields.

## Cognitive completion gate

1. **Symptom / missing postcondition:** SP-031 had been opened, but no current
   provenance-bound local package or ADR-047 decision record existed; previous
   records only documented the opening and the missing package.
2. **Mechanism / root cause / layer:** The control-plane evidence/package layer
   had no current clean-source build bound to the active commit. This was a
   provenance and state-projection gap, not a product-runtime assertion or
   agent-model failure.
3. **Direct change / acceptance procedure:** Built the unsigned local artifact
   twice from a clean detached worktree at the exact commit, validated the
   manifest, compared the resulting archives byte-for-byte, ran the full
   deterministic suite with coverage, and recorded the limitations. Drafted
   ADR-047 as `Proposed`; no approval was inferred.
4. **Evidence ID and class:** This record,
   `EV-SP-031-20260902-LOCAL-ONLY-PACKAGE-01`, is automated local package /
   reproducibility / deterministic-test / coverage evidence. It does not close
   live-beta or release gates.
5. **Falsifier:** A source/manifest/archive hash mismatch, a dirty or different
   source commit, a failed independent reproduction, a failed validator/test,
   or any projection that labels this artifact signed, beta, production, or
   approved would falsify the conclusion.
6. **Residual risk and scope:** Explicit local-only package approval,
   independent review of this declared package scope, ADR-047 acceptance,
   live beta SLO/scenario/incident evidence, live R11 evidence, external
   signing/notarization, and model-manifest qualification remain open. The
   live and external items are outside this local-only attempt and belong to a
   separately authorized gate.
7. **SP-032 safety:** SP-032 is **not safe to start**. SP-031 remains
   `in_progress` because the package is assembled but explicit local-only
   owner approval, independent declared-scope review, and ADR-047 acceptance
   are absent. `beta-readiness.json` and `release_candidate` remain blocked.

## Disposition

The package is reproducible and recoverable as a local temporary artifact, but
it is not independently approved and is not a release candidate. SP-031 stays
`in_progress`; the next required decision is an explicit owner decision on the
local-only package scope after independent review, not a release approval.
