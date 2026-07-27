import AuraCore

/// Plugin manifest verification and lifecycle registry (Phase 19 slice of
/// the full marketplace described in `docs/subsystems/23_PLUGIN_SYSTEM.md`).
///
/// This phase builds the verification and policy-gated lifecycle foundation:
/// manifest schema, content-hash and vendor-signature verification
/// (`PluginVerifier`), and install/enable/disable/quarantine/uninstall
/// state tracking with capability-scoped `Grant` mapping (`PluginRegistry`).
/// It deliberately does not build: a download/distribution mechanism, a
/// sandboxed XPC/helper execution process, or rollback/update flows — those
/// remain Phase 23's explicit scope ("Verified Plugin and Adapter
/// Marketplace"). Consequently `PluginRegistry` has no `execute` method at
/// all: there is no plugin *runtime* yet, only verified, policy-gated
/// bookkeeping a future runtime would consult before running anything.
public enum AuraPlugins {
  public static let manifestSchemaVersion = "1.0.0"
}
