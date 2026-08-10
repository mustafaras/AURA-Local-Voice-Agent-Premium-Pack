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
- `swift-format`: discoverable through `xcrun --find swift-format` at
  `/Library/Developer/CommandLineTools/usr/bin/swift-format`; `--version`
  reports `main` rather than an independent semantic version. The repository
  policy is pinned by `.swift-format` configuration schema `version: 1` and
  the Swift 6.4 toolchain profile.
- `swiftlint`: Homebrew-provisioned `0.65.0` at
  `/opt/homebrew/bin/swiftlint`; the repository policy is `.swiftlint.yml`.
  The binary is executable, but its SourceKit-backed mode cannot load
  `sourcekitdInProc` under the observed CommandLineTools-only developer
  directory. `--disable-sourcekit` is therefore a partial diagnostic mode,
  not a full SwiftLint acceptance result.

The machine-readable source is `AURA_RUNTIME_COMPLETION/state/toolchain-manifest.json`.

The test wrapper discovers the active Swift toolchain with `xcode-select -p`
and `xcrun --find swift`, then validates the SwiftPM helper, Testing framework,
interop library, and Testing macro plugin before running. `Package.swift`
receives the discovered macro path through `AURA_TESTING_MACROS_PATH`; it does
not embed a developer-directory path. Non-standard Xcode layouts may provide
`AURA_TESTING_FRAMEWORK_PATH` and `AURA_TESTING_LIB_PATH`. Missing support
fails closed.

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

For the full local Swift test matrix, use `scripts/aura-test.sh`; plain
`swift test` is not the canonical runner on the observed CommandLineTools
profile because the wrapper supplies the validated Swift Testing runtime
paths.

## H-005 quality gates

The reproducible strict production build is:

```sh
swift build -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors
```

The report-only formatter command is:

```sh
SWIFT_FORMAT="$(xcrun --find swift-format)"
"$SWIFT_FORMAT" lint --recursive --strict \
  --configuration .swift-format Sources Tests
```

The command must remain report-only until its findings are partitioned and a
bounded source change is separately reviewed. The provisioned SwiftLint
diagnostic command is:

```sh
swiftlint lint --config .swiftlint.yml --strict Sources Tests
```

On the observed CLT-only host, the exact command fails closed while loading
SourceKit. The explicitly labeled partial fallback is:

```sh
swiftlint lint --config .swiftlint.yml --disable-sourcekit --strict Sources Tests
```

This fallback does not constitute a full SwiftLint pass; SourceKit-dependent
rules are skipped and the result must remain attached to the H-005 blocker.

## Projection policy

`AURA_RUNTIME_COMPLETION/state/current-state.json` is canonical. `ledger/CURRENT_STATE.md` and `SESSION_STARTER.md` are compatibility/historical surfaces and must point to the canonical state rather than copying an active hash or next action. `verified_head` identifies the audited code/evidence baseline. A descendant HEAD is allowed only when the intervening diff is projection-only; product changes require a new audited baseline and evidence.

## Compatibility and deprecation

Any change to Swift, SDK, deployment target, Python, model revision, required CLI, signing, or CI runner must update the machine manifest, this document, ADR-045, and the evidence index. The validator must pass before the change is accepted. The current CommandLineTools workaround remains until an observed supported toolchain removes the SwiftPM test-bundle issue and the wrapper can be retired with evidence.

## Known limitations

No full-Xcode or CI workflow execution is claimed on the observed host. The
available CLT `swift-format` report previously found existing style
violations; H-005 remediation is limited to reviewed formatter batches. The
provisioned SwiftLint binary is available, but its full SourceKit-backed gate
remains blocked by the active developer directory. Chatterbox remains
consent-gated and resource/latency limited; the system TTS fallback remains
the guaranteed local path.
