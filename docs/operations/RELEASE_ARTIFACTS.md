# Release Artifact and Manifest Contract

## Current status

AURA is a **local-only product** and does not use Developer ID or notarization
(ADR-049). R11 currently produces only a `development_unverified` artifact. The
exact owner-approved SP-031 package is unsigned: Developer ID and hardened
runtime are `false`, notarization is `not_submitted`, and verification is
`not_performed`. The local pipeline does not publish or deploy externally; its
documented signing design must not be read as a property of that package or as
direct launch/lifecycle acceptance.

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

The intended local-only pipeline uses full Xcode and the exact pinned toolchain,
signs nested code in dependency order with the local stable identity + hardened
runtime, verifies with `codesign --verify --deep --strict`, records artifact
SHA-256 hashes, and launch-smokes a signed bundle in an isolated home (ADR-049).
Those are planned/previously scoped pipeline steps, not properties proven for
the current `development_unverified` package. Developer ID signing,
notarization, stapling, and external clean-machine Gatekeeper evidence are
**permanently out of scope**.

ADR-046 is **Accepted for the local-only contract scope**: the local
manifest/validator/stager/rollback/recovery/safe-mode/reset source and its
deterministic tests are recorded. The remaining gap is direct operational
evidence for local update/rollback, recovery, migration, uninstall/factory
reset, and support-bundle privacy; no live update transport is configured.
External signed distribution is out of scope under ADR-049.
