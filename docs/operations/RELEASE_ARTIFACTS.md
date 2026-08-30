# Release Artifact and Manifest Contract

## Current status

AURA is a **local-only product** and does not use Developer ID or notarization
(ADR-049). R11 currently produces only a `development_unverified` artifact. The
local pipeline does not publish or deploy externally; it signs nested bundles
with the local stable identity + hardened runtime, records artifact hashes, and
launches the signed bundle for verification. A local/ad-hoc signature is not
external distribution evidence.

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
validator rejects `release_candidate` or `released` unless a release process
records the local nested-signing procedure, hardened runtime, artifact hashes,
and launch evidence as bound in ADR-049. Boolean fields in a JSON file are not
treated as proof of external distribution services (which are out of scope).

The CI workflow invokes this same script after the successful build/test job
and retains only the ZIP and manifest under the label
`aura-development-unverified-<commit>` for 14 days. This is an evidence
collection configuration, not a release publication; no post-change workflow
run is currently observed.

## Release boundary (local-only scope)

The local-only release path uses full Xcode and the exact pinned toolchain,
signs nested code in dependency order with the local stable identity + hardened
runtime, verifies with `codesign --verify --deep --strict`, records artifact
SHA-256 hashes, and launch-smokes the signed bundle in an isolated home
(ADR-049). Developer ID signing, notarization, stapling, and external
clean-machine Gatekeeper evidence are **permanently out of scope**.

The selected updater must separately verify its signed update metadata and
package, compatibility, downgrade/replay rules, migration preflight, atomic
staging, rollback, and user approval. R11 does not yet implement those runtime
operations; ADR-046 remains Proposed (the local contract/validator/stager/
rollback/recovery/safe-mode/reset source is implemented; a real signed external
update is out of the local-only scope).

