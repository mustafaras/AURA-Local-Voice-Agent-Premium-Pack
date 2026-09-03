# EV-SP-024-20260827-NETWORK-OAUTH-INJECTION-01

- **Prompt/Track:** SP-024 / R10 (OPEN-11)
- **Timestamp:** 2026-08-27
- **Commit/Branch:** working tree on `main` (HEAD `ec41e7814f34922cdd9e9a7f168b2d3fb2ba4d40`; origin/main equal)
- **Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0.0-beta.5 toolchain, CommandLineTools developer dir
- **Evidence class:** Automated / contract + adversarial (deterministic; no live provider or signed-helper launch)

## Objective

Close the bounded SP-024 slice of OPEN-11: prove every production
network/provider/subprocess path is policy-enforced and externally influenced
content remains non-authoritative. Specifically:

1. Route every production `URLSession` through a mandatory factory with
   cookie/cache/redirect/offline bounds.
2. Add a deterministic resolved-IP validator for DNS/IP pinning.
3. Complete the OAuth redacted-leakage corpus (token material never reaches
   logs/events/env/args/crashes/support).
4. Run web/mail/file/terminal/model tool-spoof and indirect-injection
   adversarial cases.

## Changes delivered

- `Sources/AuraSecurity/URLSessionFactory.swift` — the single deny-by-default
  `URLSession` factory: disables cookies (`httpShouldSetCookies = false`,
  `httpCookieAcceptPolicy = .never`, `httpCookieStorage = nil`), disables the
  shared cache (`urlCache = nil`,
  `requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData`), and refuses
  redirects by default through a shared `RedirectRejectingDelegate`.
- `Sources/AuraSecurity/ResolvedIPValidator.swift` — deterministic resolved-IP
  allowlist validator (DNS answers are not trusted authority; a single
  unexpected candidate IP fails the whole set, defending against DNS rebinding).
- `Sources/AuraProductivity/ProductivityAdapters_HTTPProviderTransport.swift` —
  `URLSessionProviderFetcher` now builds its session through
  `URLSessionFactory.makeSession()` (no ungoverned session).
- `Sources/AuraAgent/OllamaAPIClient.swift` — `URLSessionOllamaAPIClient` now
  builds its session through `URLSessionFactory.makeSession()`; removed the
  now-unused private redirect-rejecting delegate.
- `Sources/AuraCore/SecretPatternLibrary.swift` — added
  `googleOAuthAccessToken` (`ya29\.…`) and `googleOAuthRefreshToken` (`1//…`)
  patterns to the canonical library, so a Google OAuth token pasted into a
  mail body, command output, or support bundle is redacted/flagged by the same
  boundary as every other secret.
- Tests:
  - `Tests/AuraSecurityTests/URLSessionFactoryTests.swift` — factory disables
    cookies/cache, installs the redirect-rejecting delegate; `ResolvedIPValidator`
    deny-by-default, exact match, IPv6 zone normalization, all-candidates gate.
  - `Tests/AuraProductivityTests/OAuthLeakageCorpusTests.swift` — token
    reference/Keychain key carry no secret; OAuth diagnostics never echo token
    material or provider free text; bounded text redacts an embedded token;
    `SecretScanner` flags OAuth-shaped tokens; Keychain store keeps material
    behind the boundary and revocation deletes it.
  - `Tests/AuraAdversarialTests/PromptInjectionAdversarialTests.swift` — added
    model tool-spoof (system-message and fake-tool-call), indirect injection
    through mail body / repository file / terminal output, and
    `PromptInjectionScreen` withhold/pass-through cases.

## Verification

- `swift build` — production targets compile (test-bundle codesign xattr issue
  is the known iCloud issue handled by `aura-test.sh`).
- `./scripts/aura-test.sh /tmp/aurabuild-sp024 "AuraSecurityTests"` — PASSED, 0 failed bundles (44 tests).
- `./scripts/aura-test.sh /tmp/aurabuild-sp024 "AuraProductivityTests"` — PASSED, 0 failed bundles (75 tests).
- `./scripts/aura-test.sh /tmp/aurabuild-sp024 "AuraAdversarialTests"` — PASSED, 0 failed bundles (68 tests).
- `./scripts/aura-test.sh /tmp/aurabuild-sp024` (full suite) — PASSED, 0 failed bundles.
- `python3 scripts/validate_second_pass_program.py` — SECOND-PASS VALIDATION PASSED.

## Adversarial coverage

- `factorySessionDisablesCookiesAndCache` — no cookie/cache carryover.
- `factorySessionRefusesRedirectsByDefault` — redirect-rejecting delegate wired.
- `emptyIPAllowlistDeniesEverything` / `exactIPMatchIsAllowed` /
  `ipv6ZoneIdentifierIsNormalizedAway` / `allAllowedRequiresEveryCandidateToPass`
  — resolved-IP pinning deny-by-default and DNS-rebinding defense.
- `tokenReferenceCarriesNoSecret` / `oauthDiagnosticsCarryNoSecret` /
  `boundedTextRedactsEmbeddedToken` / `secretScannerFlagsOAuthToken` /
  `keychainStoreKeepsMaterialBehindBoundary` — OAuth leakage corpus.
- `modelToolSpoofSystemMessageBlockedInAgentToolOutput` /
  `modelToolSpoofFakeToolCallBlockedInWebContent` /
  `indirectInjectionMailBodyBlocked` / `indirectInjectionRepositoryFileBlocked` /
  `indirectInjectionTerminalOutputBlocked` / `injectionScreenWithholdsBlockedContent` /
  `injectionScreenPassesCleanContent` — tool-spoof and indirect-injection corpus.

## Scope and limitations

- This is a **deterministic/contract + adversarial** slice. It does **not**
  claim a live provider round trip, a live signed-helper launch, or OS-enforced
  confinement of a real signed bundle.
- The mandatory factory now governs the two production `URLSession` call sites
  (`URLSessionProviderFetcher`, `URLSessionOllamaAPIClient`). A future client
  that constructs its own `URLSession` would bypass the factory; the
  `ResolvedIPValidator` is the deterministic primitive, and a live resolver
  seam that calls it remains to be wired for any non-loopback capability.
- OAuth leakage is proven against the typed boundaries (reference, diagnostic,
  bounded text, scanner, Keychain store); live provider token exchange and
  live revocation remain open (no provider-contact authority).
- Plugin trust, incident response, independent review, and ADR-044 acceptance
  remain open and are owned by SP-025 and later R10 work.
- No raw audio, screenshots, secrets, tokens, private account data, or
  unredacted model output were written to any ledger or context file.
