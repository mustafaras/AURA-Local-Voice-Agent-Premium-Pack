# ADR-045 — Toolchain, State Projection, and Release Pipeline Baseline

- **Status:** Accepted for R0 governance; release portions remain open gates
- **Date:** 2026-08-02
- **Owners:** AURA Runtime Completion Program
- **Scope:** R0 development truth and R11 release preparation

## Context

AURA targets macOS 27 and Swift 6.4, but the observed development host has Apple CommandLineTools rather than full Xcode. Historical state files also copied commit hashes and next actions manually, allowing them to drift after state-only commits. A deterministic validator and an explicit toolchain contract are required before later runtime work can rely on repository status or release claims.

## Decisions

1. `AURA_RUNTIME_COMPLETION/state/current-state.json` is the canonical machine state. `session-handoff.json` is a concise next-session projection. `ledger/CURRENT_STATE.md` and `SESSION_STARTER.md` are historical compatibility surfaces and must point to the canonical state instead of copying active status claims.
2. `verified_head` identifies the audited code/evidence baseline. A later repository HEAD is valid only when it is a descendant and the intervening diff contains projection-only files. Product/source changes require a new audit and evidence before the state can advance.
3. The repository validator is standard-library-only and fails closed on malformed JSON, unsupported schema keywords, missing prompt dependencies, unknown evidence/risk/gate IDs, stale active prompts, capability evidence mismatches, impossible release states, stale repository claims, and unsupported toolchain profiles.
4. The supported development baseline is macOS 27+, arm64, Swift 6.4, and macOS SDK 27.0+. The observed CommandLineTools profile is valid for local development and the custom test wrapper. Full Xcode is mandatory for release packaging, Developer ID signing, notarization, and clean-machine validation.
5. The package deployment target remains macOS 27. Lowering it requires an availability audit and a new accepted decision; no compatibility claim is inferred from the macOS 26+ instruction prose.
6. Evidence classes remain ordered from unit/static through contract, integration simulated, system, live hardware, and release. Capability states may not claim `live_verified` or `release_verified` without indexed evidence of the corresponding class.
7. CI governance is configuration evidence until a workflow run is observed. The workflow must run the repository validator before production build/test; local output must never be reported as a CI run.
8. Authority is session-scoped and explicit. Metadata-only sessions cannot commit, push, merge, install, mutate TCC, launch apps, sign, notarize, release, or deploy.

## Alternatives considered

- **Require full Xcode for every local check:** rejected for the current host because the repository already has a verified CommandLineTools build/test strategy; release checks still require Xcode.
- **Generate legacy Markdown on every write:** deferred because generation would create noisy commits; compatibility pointers plus validator drift checks are safer until a CI-backed projector is available.
- **Use an external schema package in CI:** rejected for this R0 slice because the validator's supported schema surface is small and standard-library validation avoids an unpinned network dependency. The schema contract must fail closed if new unsupported keywords are introduced.
- **Treat every descendant commit as verified:** rejected; only projection-only descendants are accepted without a new code/evidence audit.

## Security and privacy impact

The validator reads local metadata, source-control status, and public toolchain versions. It does not read secrets, private documents, ambient audio, screenshots, model weights, Keychain contents, or user data. Release validation remains fail-closed without Xcode and Developer ID evidence.

## Migration

1. Add the machine-readable toolchain manifest and human-readable contract.
2. Add the repository validator and deterministic negative/positive tests.
3. Run the validator in CI before the build/test job.
4. Keep legacy files as pointers/historical context; R0 owns any future generated projection.
5. Re-audit capability states and attach only evidence IDs that exist in the evidence index.

## Verification plan

- `python3 scripts/validate_runtime_completion.py --ci`
- `python3 -m unittest discover -s scripts/tests -p 'test_*.py'`
- `git diff --check`
- repository `scripts/aura-test.sh` full suite and coverage gate where source changes occur
- observed CI workflow run recorded separately from local configuration evidence

## Consequences

The development environment remains usable on the observed CommandLineTools host while release claims are explicitly blocked until full Xcode and signing evidence exist. State-only commits can be represented without falsely claiming that an untested product commit was audited. Governance checks become repeatable and actionable for fresh sessions.
