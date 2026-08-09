# Release Artifact and Manifest Contract

## Current status

R11 currently produces only a `development_unverified` artifact. The local
pipeline does not sign, notarize, install, publish, or deploy. A local/ad-hoc
signature is not Developer ID release evidence.

Run the bounded local pipeline with:

```sh
BUILD_ROOT=/tmp/aura-r11-release-artifact \
OUTPUT_DIR=/tmp/aura-r11-release-artifact/output \
./scripts/build-release-artifact.sh
```

The output contains a reproducible ZIP, a JSON release manifest, and a minimal
bundle-file inventory used as the local SBOM scope. The manifest binds:

- bundle identifier, semantic version, build, minimum OS, and helper IPC
  protocol;
- source commit and working-tree status;
- observed Swift/Xcode-selection toolchain strings;
- sorted bundle file paths, sizes, and SHA-256 digests;
- archive path, size, and SHA-256 digest;
- explicit signature/notarization state.

`development_unverified` is the only status this local script emits. The
validator rejects `release_candidate` or `released` unless an independently
reviewed release process records Developer ID, Hardened Runtime, notarization,
stapling, and external verification proof. Boolean fields in a JSON file are
not treated as proof of Apple's services.

The CI workflow invokes this same script after the successful build/test job
and retains only the ZIP and manifest under the label
`aura-development-unverified-<commit>` for 14 days. This is an evidence
collection configuration, not a release publication; no post-change workflow
run is currently observed.

## Release boundary still required

The production release path must use full Xcode and the exact pinned toolchain,
sign nested code in dependency order with Developer ID, include a secure
timestamp, submit with the current Apple notarization path, inspect the notary
log, staple the ticket, and run `codesign`, `spctl`, and clean-machine
Gatekeeper checks. Credentials remain in the keychain/CI secret store and never
enter manifests or logs.

The selected updater must separately verify its signed update metadata and
package, compatibility, downgrade/replay rules, migration preflight, atomic
staging, rollback, and user approval. R11 does not yet implement those runtime
operations; ADR-046 remains Proposed.
