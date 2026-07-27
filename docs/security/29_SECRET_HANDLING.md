> **Status:** Normative specification  
> **Target:** macOS 26+ on Apple Silicon, with graceful degradation where practical  
> **Primary device profile:** Apple Silicon, 16 GB unified memory  
> **Language:** English  
> **Priority order:** Safety → Correctness → Recoverability → Latency → Convenience


# Secret Handling

- Store credentials in macOS Keychain or backend-native secure stores.
- Pass secrets through narrowly scoped environment injection.
- Redact known patterns and registered secret values from logs.
- Never read `.env`, SSH keys, browser stores, or password managers unless the task explicitly requires and permits it.
- Never include secrets in model prompts when a local token exchange or broker can perform the action.
- Rotate and revoke after suspected exposure.

## Implementation (Phase 19)

`KeychainSecretStore` (`Sources/AuraSecurity/SecretStoring.swift`) is the real
macOS Keychain integration: `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`
against `kSecClassGenericPassword`, with
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — never iCloud-synced,
never accessible before first unlock. Verified against the real Keychain in
this development environment (a standalone probe's add/retrieve/delete all
returned `errSecSuccess`) before the production code was written, and again
via `Tests/AuraSecurityTests/SecretStoreTests.swift`'s live round-trip tests.
`SecretStoring` is a protocol so callers can substitute `InMemorySecretStore`
in unit tests without touching the real Keychain.

New `Capability.secretStore`/`.secretRetrieve`/`.secretDelete`
(`Sources/AuraCore/PolicyTypes.swift`) route secret access through the same
policy engine as every other capability — reading or writing a credential is
`.destructive`-tier ("sensitive-data access"), matching
`PermissionRiskTier.destructive`'s own definition.

`SecretScanner` and the consolidated `SecretPatternLibrary`
(`Sources/AuraCore/SecretPatternLibrary.swift`) implement "redact known
patterns and registered secret values from logs" as pre-flight scanning
before content reaches a ledger entry, event, or model prompt — one shared
pattern list, not three independently maintained ones.

**Known limitation:** `KeychainSecretStore` is not yet wired into a real
caller that evaluates `.secretStore`/`.secretRetrieve`/`.secretDelete`
through `PolicyEngine` before calling it — matching the established
protocol-plus-production-implementation pattern (`OllamaAPIClient`), the
storage seam is built and tested; the policy-gated caller is a follow-up
integration once a real consumer (e.g. an agent adapter's API token) exists.
