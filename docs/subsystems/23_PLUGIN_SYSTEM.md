> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Plugin and Adapter System

## Plugin manifest
- ID and semantic version
- vendor and signature
- capabilities
- schemas
- required permissions
- supported application bundle IDs
- network domains
- executable dependencies
- migration requirements
- audit level

## Security
- Plugins are untrusted until explicitly installed and approved.
- Validate signatures and hashes.
- Run with the minimum possible process and filesystem permissions.
- No dynamic code download without user action.
- Provide disable, quarantine, and uninstall workflows.

## Implementation (Phase 19 — verification and lifecycle foundation)

This phase implements the manifest schema, cryptographic verification, and
policy-gated lifecycle registry — the foundation Phase 23 ("Verified Plugin
and Adapter Marketplace") extends into a full marketplace with
download/distribution, sandboxed XPC/helper execution, and update/rollback
flows. There is deliberately no `execute` method anywhere in this phase's
code: no plugin runtime exists yet, only verified, policy-gated bookkeeping
a future runtime would consult.

- `PluginManifest` (`Sources/AuraPlugins/PluginManifest.swift`): id, version,
  vendor name, `[Capability]`, `[ResourcePattern]` required permissions,
  supported bundle IDs, network domains, executable dependencies, migration
  notes, audit level, SHA-256 content hash, and a base64 Ed25519 signature
  over a canonical, order-independent `signedPayload`.
- `PluginVerifier` (`Sources/AuraPlugins/PluginVerifier.swift`): structural
  validity → content-hash integrity (`CryptoKit.SHA256`) → vendor trust
  (`PluginTrustRegistry`, deny-by-default) → Ed25519 signature validity
  (`CryptoKit.Curve25519.Signing`, verified via a real `swiftc -typecheck`
  probe compile before use, matching the project's established API
  verification discipline). Each stage is checked in order so a caller
  always learns the *first* real problem, not a downstream symptom.
- `PluginTrustRegistry` (`Sources/AuraPlugins/PluginTrustRegistry.swift`):
  local, operator-configured vendor-name → public-key trust list
  (`PluginConfiguration.trustedVendorPublicKeysBase64`) — not a connection
  to any external PKI or marketplace directory; that remains Phase 23 scope.
- `PluginRegistry` (`Sources/AuraPlugins/PluginRegistry.swift`): an actor
  implementing install (verify, then map each declared capability onto a
  scoped `Grant` via `PolicyEngine.issueGrant`) / enable / disable /
  quarantine (one-way; no `unquarantine`) / uninstall (revokes every issued
  grant, retains the record for audit). Every transition is itself a
  `PolicyEngine.evaluate` call against a new `Capability.pluginInstall`/
  `.pluginEnable`/`.pluginDisable`/`.pluginQuarantine`/`.pluginUninstall` —
  a plugin cannot change its own lifecycle state merely by being asked to.
  `isActionable(pluginID:)` is `true` only for `.enabled` plugins —
  `.installed` (verified but never explicitly enabled), `.disabled`,
  `.quarantined`, and `.uninstalled` are all non-actionable by construction.

**Adversarial tests** (`Tests/AuraPluginsTests/PluginVerifierTests.swift`):
vendor-name spoofing (trust registry has the vendor but under a *different*
real key), tampered/bundle-swapped content (hash mismatch), forged signature
from an attacker-controlled key, and post-signing capability escalation (a
manifest mutated to add capabilities after the vendor signed the narrower
original) are all rejected. `Tests/AuraPluginsTests/PluginRegistryTests.swift`
proves quarantine blocks re-enabling, uninstall revokes grants while
preserving the audit record, and a plugin's issued grant genuinely
authorizes its declared capability end-to-end through a real `PolicyEngine`.
