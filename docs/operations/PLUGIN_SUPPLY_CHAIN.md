# Plugin Supply-Chain Trust Contract

> **Status:** Normative (SP-025, OPEN-11 / R10)
> **Owner:** AURA security/release owner
> **Applies to:** Every plugin payload, manifest, retained version, helper
> executable, and marketplace source that can influence plugin install,
> enable, update, rollback, or execution.

## Purpose

Define the deny-by-default trust chain that every plugin artifact must satisfy
before it can influence behavior, and the evidence that proves each link fails
closed under a compromised fixture. This closes the "vendor roots, signatures,
hashes, revocation, quarantine, SBOM, rollback, update, and unverified-code
rejection" leg of SP-025.

## Trust chain (each step must pass before the next runs)

1. **Structural validity.** `PluginManifest.validate()` rejects malformed
   identity, semantic version, capabilities, schemas, references, and unsafe
   entrypoints/executable-dependency paths *before* any cryptography.
2. **Content integrity (hash).** `PluginVerifier` compares the real
   SHA-256 of the bundle payload against `manifest.contentHashSHA256Hex`.
3. **Vendor root trust.** `PluginTrustRegistry` must contain a public key for
   the manifest's `vendorName` + `vendorKeyID`. This is a local,
   operator-controlled list — not an external PKI — so a vendor absent from
   the list can never pass regardless of what its manifest and signature
   claim.
4. **Signature validity.** The Ed25519 signature over the canonical
   `signedPayload` must verify against the trusted vendor key. The signature
   covers every field that can influence identity, authority, execution,
   migration, or data exchange (including capability risk tiers and required
   permissions), so post-signing escalation invalidates it.
5. **Artifact immutability.** `PluginArtifactStore` writes payloads below one
   configured root with immutable permissions and rehashes before enable,
   execute, update, or rollback. A tampered retained artifact fails closed.
6. **Helper integrity.** `PluginHelperProcessHost` pins the helper
   executable's SHA-256 and refuses to launch a compromised helper.

## Lifecycle safety valves

- **Quarantine** is a one-way valve: it revokes every grant immediately, sets
  the state to `.quarantined`, and `enable` refuses a quarantined plugin
  unconditionally. Recovery requires uninstall followed by a fresh,
  re-verified install.
- **Update** only accepts a strictly higher semantic version with the same
  ID, vendor, and key ID, and the new bundle must pass the full trust chain.
- **Rollback** only accepts a retained, locally rehashed and re-verified
  version; a tampered retained artifact blocks rollback.
- **Uninstall** revokes grants and removes runtime artifacts while retaining
  lifecycle and immutable audit records.

## SBOM / checksum scope

Each verified plugin payload is represented by its SHA-256 content hash
(`contentHashSHA256Hex`), which is signed and therefore cannot be forged
without the vendor key. `executableDependencies` are required to be relative
paths and are part of the signed payload, so a plugin cannot silently claim an
arbitrary system executable as a dependency.

The full-app SBOM remains the R11 artifact inventory
(`scripts/generate_release_manifest.py` / `validate_release_manifest.py`),
which binds bundle file paths, sizes, and SHA-256 digests. Plugin payloads are
a distinct trust domain: their SBOM is the signed per-payload hash plus the
retained-version snapshot table in the plugin registry.

## Unverified-code rejection

Runtime-loaded plugin code is rejected unless it is a verified artifact from a
trusted vendor root, rehashed and re-verified at execution time. No
unverified code is ever passed to the helper. A helper whose digest does not
match the pinned value is never launched.

## Tests and evidence

`Tests/AuraPluginsTests/PluginSupplyChainAdversarialTests.swift` covers the
compromised-fixture matrix with real cryptography:

- compromised helper digest → fail closed before launch;
- tampered installed artifact → block enable and execute;
- tampered update bundle → refuse before storage, version unchanged;
- update from an untrusted vendor root → refuse;
- tampered retained artifact → block rollback, version unchanged;
- quarantine → grants revoked, enable and execute both fail closed;
- unapproved marketplace source / unknown vendor root → never install.

## Known limitations (not claimed)

- Public marketplace/vendor PKI and a signed, notarized update transport are
  **not** implemented. The local trust registry is operator-controlled.
- No real third-party signed vendor payload has been executed end to end; the
  packaging gate builds and ad-hoc signs a nested helper, but that is not a
  release claim.
- The plugin helper's live sandbox attestation is exercised by the packaging
  gate, not by a production plugin execution on a real third-party payload.
