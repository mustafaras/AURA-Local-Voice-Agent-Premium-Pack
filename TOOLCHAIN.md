# AURA Toolchain Contract

Status: accepted development baseline; release verification remains open.

## Supported profiles

Development targets Apple Silicon (`arm64`) on macOS 27 or newer with Swift 6.4 and macOS SDK 27.0 or newer. The repository's active local profile supports Apple CommandLineTools and full Xcode through the project test wrapper at `scripts/aura-test.sh`.

AURA is a **local-only product** and does not use Developer ID or
notarization (ADR-049). Release verification for the local-only scope uses the
local nested-signing procedure, hardened runtime, artifact hashes, and launch
evidence; external Developer ID signing, notarization, and clean external
machine validation are permanently out of scope. The package deployment target
is macOS 27 and must not be lowered without an availability audit.

## Observed baseline

- macOS: 27.0, Apple Silicon arm64, 16 GiB unified-memory profile.
- Developer directory: `/Applications/Xcode-27.0.0-beta.5.app/Contents/Developer`.
- Swift: Apple Swift 6.4 (`swiftlang-6.4.0.30.4`, `clang-2100.3.30.1`) from Apple Command Line Tools 27.0 beta 5.
- macOS SDK: 27.0.
- Xcode: Xcode 27.0 beta 5 (`27A5237l`) is selected and `xcodebuild -version` exits 0. Release signing, notarization, and clean-machine evidence remain separate gates.
- Python: system and repository validator environment 3.14.6; Chatterbox runtime 3.11.15.
- Git: 2.54.0; the configured GitHub remote was reachable during bootstrap.
- `swift-format`: discoverable through `xcrun --find swift-format` at
  `/Library/Developer/CommandLineTools/usr/bin/swift-format`; `--version`
  reports `main` rather than an independent semantic version. The repository
  policy is pinned by `.swift-format` configuration schema `version: 1` and
  the Swift 6.4 toolchain profile.
- `swiftlint`: Homebrew-provisioned `0.65.0` at
  `/opt/homebrew/bin/swiftlint`; the repository policy is `.swiftlint.yml`.
  Its SourceKit-backed mode loads successfully under the selected Xcode
  toolchain. The current strict run is still a policy failure with 528
  serious findings across 112 files (`352 trailing_comma`, `170 opening_brace`,
  `4 function_body_length`, `2 file_length`); `--disable-sourcekit` remains only a
  partial diagnostic mode.

The machine-readable source is `archive/runtime-completion/state/toolchain-manifest.json`.

The test wrapper discovers the active Swift toolchain with `xcode-select -p`
and `xcrun --find swift`, then validates the SwiftPM helper, Testing framework,
interop library, and Testing macro plugin before running. It automatically
resolves the macOS `Testing.framework` and interop library in either the full
Xcode platform layout or the CommandLineTools layout; explicit
`AURA_TESTING_FRAMEWORK_PATH` and `AURA_TESTING_LIB_PATH` overrides remain
available. `Package.swift` receives the discovered macro path through
`AURA_TESTING_MACROS_PATH`; it does not embed a developer-directory path.
Missing support fails closed.

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
`swift test` is not the canonical runner because the wrapper supplies and
validates the Swift Testing runtime paths.

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

On the observed Xcode host, the exact command loads SourceKit and exits 2 with
528 serious policy findings across 112 files. The explicitly labeled partial
fallback is:

```sh
swiftlint lint --config .swiftlint.yml --disable-sourcekit --strict Sources Tests
```

This fallback does not constitute a full SwiftLint pass; SourceKit-dependent
rules are skipped. Neither result is a clean lint acceptance until the
528-finding policy backlog is reviewed and remediated under bounded source
authority.

## Projection policy

`archive/runtime-completion/state/current-state.json` is canonical. `ledger/CURRENT_STATE.md` and `SESSION_STARTER.md` are compatibility/historical surfaces and must point to the canonical state rather than copying an active hash or next action. `verified_head` identifies the audited code/evidence baseline. A descendant HEAD is allowed only when the intervening diff is projection-only; product changes require a new audited baseline and evidence.

## Compatibility and deprecation

Any change to Swift, SDK, deployment target, Python, model revision, required CLI, signing, or CI runner must update the machine manifest, this document, ADR-045, and the evidence index. The validator must pass before the change is accepted. The current CommandLineTools workaround remains until an observed supported toolchain removes the SwiftPM test-bundle issue and the wrapper can be retired with evidence.

## Known limitations

No release signing, notarization, or clean-machine validation is claimed on the
observed host. The provisioned SwiftLint binary and full SourceKit capability
are available, but its strict policy run remains blocked by 528 owned
findings. Chatterbox remains consent-gated and resource/latency limited; the
system TTS fallback remains the guaranteed local path.
