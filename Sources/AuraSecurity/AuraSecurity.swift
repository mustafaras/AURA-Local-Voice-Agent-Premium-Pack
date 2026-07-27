import AuraCore

/// Security hardening coordinator namespace (Phase 19): secret storage,
/// prompt-injection classification, secret scanning, and the outbound
/// network allowlist. Unlike `AuraAutomation`/`AuraAgent`, this module has
/// no single coordinating actor — its pieces (`KeychainSecretStore`,
/// `PromptInjectionClassifier`, `SecretScanner`, `NetworkAllowlist`) are
/// independently usable value types/actors, each with a narrow contract.
public enum AuraSecurity {
  /// Schema/version marker for security-related persisted state, mirroring
  /// `auraEnvelopeSchemaVersion`'s convention.
  public static let version = "1.0.0"
}
