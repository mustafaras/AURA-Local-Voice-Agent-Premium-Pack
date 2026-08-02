# AURA Toolchain Contract

Status: accepted development baseline; release verification remains open.

## Supported profiles

Development targets Apple Silicon (`arm64`) on macOS 27 or newer with Swift 6.4 and macOS SDK 27.0 or newer. The repository's active local profile uses Apple CommandLineTools and the project test wrapper at `scripts/aura-test.sh`.

Release builds require full Xcode, a supported macOS SDK, Developer ID signing, notarization, and clean-machine Gatekeeper validation. Local or ad-hoc signing is development evidence only. The package deployment target is macOS 27 and must not be lowered without an availability audit.

## Observed baseline

- macOS: 27.0, Apple Silicon arm64, 16 GiB unified-memory profile.
- Developer directory: `/Library/Developer/CommandLineTools`.
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.27.1`, `clang-2100.3.27.1`).
- macOS SDK: 27.0.
- Xcode: unavailable on the observed host; `xcodebuild` is not available under the active CommandLineTools directory.
- Python: system and repository validator environment 3.14.6; Chatterbox runtime 3.11.15.
- Git: 2.54.0; the configured GitHub remote was reachable during bootstrap.
- `swift-format`: unavailable on the observed host.

The machine-readable source is `AURA_RUNTIME_COMPLETION/state/toolchain-manifest.json`.

## Validation

Run the local governance gate before changing state or claiming a phase:

```sh
python3 scripts/validate_runtime_completion.py --ci
```

The release profile additionally requires full Xcode:

```sh
python3 scripts/validate_runtime_completion.py --release
```

The validator uses only the Python standard library. It validates the repository's JSON Schema keyword surface, prompt dependencies, evidence/risk/gate references, capability evidence constraints, repository claims, legacy pointers, and toolchain profile.

## Projection policy

`AURA_RUNTIME_COMPLETION/state/current-state.json` is canonical. `ledger/CURRENT_STATE.md` and `SESSION_STARTER.md` are compatibility/historical surfaces and must point to the canonical state rather than copying an active hash or next action. `verified_head` identifies the audited code/evidence baseline. A descendant HEAD is allowed only when the intervening diff is projection-only; product changes require a new audited baseline and evidence.

## Compatibility and deprecation

Any change to Swift, SDK, deployment target, Python, model revision, required CLI, signing, or CI runner must update the machine manifest, this document, ADR-045, and the evidence index. The validator must pass before the change is accepted. The current CommandLineTools workaround remains until an observed supported toolchain removes the SwiftPM test-bundle issue and the wrapper can be retired with evidence.

## Known limitations

No Xcode-specific or `swift-format` validation is claimed on the observed host. No CI workflow execution is claimed from local configuration validation. Chatterbox remains consent-gated and resource/latency limited; the system TTS fallback remains the guaranteed local path.
