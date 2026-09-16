# PA-3: Integrations Always Connected — no "Devre dışı", no "Bağlı değil"

**Phase:** PA-3. **Effort:** L. **ADR:** ADR-067 (new) — "Persistent owner configuration and self-healing integrations".
**Owner instruction covered:** "yeteneklerde hiçbir yetenek kesinlikle devre dışı olmamalı … 'bağlı değil' veya kısıtlı hiçbir özellik olmamalı".

---

## 1. Evidence (the root cause is an environment profile)

| Fact | Evidence |
| --- | --- |
| Real integrations compose only under test-time env vars | `AuraConfigurationLoading.swift:68-76` (`bootstrap` → `liveAcceptance` iff `AURA_SP011_LIVE_ACCEPTANCE=1`; VS Code iff `AURA_SP012_LIVE_ACCEPTANCE=1`); the Gmail client secret is read only under that flag (`AuraKernel_Construction.swift:388-390`) and is documented as "never part of Codable application configuration" |
| A normal launch therefore cannot connect mail | `Configuration_ProductivityConfiguration.swift:113,119` defaults `mailAccountIDs: []`, `gmailOAuthClientID: ""` → snapshot reason "No mail account is approved yet." (`ProductivityRuntime.swift:297`) |
| VS Code Settings section is hidden on a normal launch | `AuraAppModel_Settings.swift:11-13`, `AuraMenuView.swift:575-596` (`settings.bridgeDisabled` shown otherwise); the 9 `vscode.*` capabilities are registered `.disabled` (`InitialCapabilitySet_CapabilityDefinitions.swift:29-37`) and only `refreshVSCodeAvailability()` can lift them (`AuraKernel_VSCodeAvailability.swift:13-23`) — and only if an adapter was constructed |
| Calendar/Contacts default **on** but need TCC | `Configuration_ProductivityConfiguration.swift:116-117` (`true`); availability reasons at `ProductivityRuntime.swift:449-478` ("access has not been granted yet" / "denied") — PA-1's consent pass grants them |
| Chrome bridge self-heals at launch, extension load is manual | `ChromeBridgeInstaller.swift:5-14` ("On every launch this installer atomically refreshes the host copy and its Chrome manifest"; "the user loads the bundled extension once through Chrome's Developer mode"); `SafariBridgeAvailability.swift:27,44` "Chrome bridge is not connected" when the native host has no live extension |
| VS Code extension is packaged and the CLI wrapper can install it | `AuraVSCodeExtension/aura-vscode-extension-0.2.0.vsix`; `VSCodeCLI.swift:158` `--install-extension` |
| Gmail token refresh and Keychain token store exist | `ProductivityTypes_KeychainOAuthTokenStore.swift`, `ProductivityTypes_OAuthTokenMaterial.swift`, `ProductivityTypes_GmailOAuthAuthorization.swift`; expired credential → `.degraded("… no longer valid")` (`ProductivityRuntime.swift:362`) and the row offers `reconnect` (`AuraAppModel_ProductState.swift:243-249`) |
| Rows render the three negative states | `AuraAppModel_ProductState.swift:148-160` (`capabilities.degraded` "Kısıtlı", `capabilities.disabled` "Devre dışı"), `:191-194` (`integrations.notConnected` "Bağlı değil") |
| A JSON configuration loader exists but nothing feeds it | `AuraConfigurationLoading.swift:104-110` ("Load configuration from JSON data, merging with defaults") — no call site loads a file at bootstrap (grep `configuration.json`, `loadConfiguration` in `Sources/AURA`: zero) |

## 2. Problem statement

Every integration was built, tested, and *live-verified* during SP-009…SP-012 — but only under an acceptance launcher that injects environment variables. The installed app, launched from Finder or as a login item, never receives them, so the product the owner uses is structurally the "neutral" build. The fix is to make owner configuration **persistent and owned by the app**, make provisioning **self-healing**, and make availability wording honest about the difference between "not provisioned" and "host app not running".

## 3. Design

### 3.1 Persistent owner configuration (replaces the env profile)

- New file `~/Library/Application Support/AURA/configuration.json` (mode 0600, directory already 0700 per `install-chrome-bridge.sh:34`), loaded by `AuraConfiguration.bootstrap` **before** the env overrides: `defaults ← file ← env`. The env profile stays as a test-only override so the acceptance harness keeps working unchanged.
- Contents are the non-secret fields already in `ProductivityConfiguration` / `VSCodeConfiguration`: `mailAccountIDs`, `gmailOAuthClientID`, `calendarReadEnabled`, `contactsReadEnabled`, `safariAllowedHosts`, `vscode.cliPath`, `vscode.extensionID`, bridge paths. **Secrets never enter this file**: the Gmail client secret and the VS Code shared secret live in Keychain (the shared secret already does — `provisionVSCodeBridge`; the Gmail secret moves from `AURA_SP011_OAUTH_CLIENT_SECRET` to a Keychain item written by a Settings `SecureField`, mirroring `AuraMenuView.swift:579-581`).
- `AuraConfigurationLoading` gains `static func fromApplicationSupport(fileManager:)` with schema validation (unknown keys ignored, malformed file → defaults + `configurationInvalid` health record, never a crash).
- Settings → Integrations category gains the owner fields (mail account, client ID, client secret SecureField, VS Code CLI path) and writes the file atomically. `isVSCodeBridgeAcceptanceEnabled` is deleted; the VS Code section is always visible.

### 3.2 Composition is unconditional; availability is live

- The VS Code adapter is constructed on every launch (`constructVSCodeAdapter`, `AuraKernel_Construction.swift:329`) from the persisted configuration; its availability continues to come from `bridgeHealth()` — no invented readiness.
- Gmail: `ProductivityRuntime.make(... gmailOAuthClientSecret:)` receives the Keychain-stored secret; the OAuth PKCE flow is started from the Integrations row's `connect` control (exists: `integrationConnect`); refresh runs automatically on `credential` degradation and on launch (`probeExternalAvailability`).
- Calendar/Contacts: authorization is granted in PA-1's consent pass; the adapters' lazy request (`NativeProductivityAdapters.swift:23,113`) remains as a fallback.

### 3.3 Self-healing provisioning at launch

- `ChromeBridgeInstaller.install` already runs at launch — verify the call site in `AURA.swift`/`AuraAppModel` and add the launch-health record. The extension itself is loaded once by the owner (Chrome Developer mode) — recorded as an `owner-attested` one-time step; the Integrations row's `settings`/`connect` control opens `chrome://extensions` guidance. If Chrome exposes a supported non-interactive install for unpacked extensions on this machine, use it; do **not** write into Chrome's profile (the installer's own rule).
- VS Code: at launch, if `code --list-extensions` (via `VSCodeCLI`) lacks `ai.aura.vscode-bridge`, run `--install-extension <bundled .vsix path>`; the `.vsix` is copied into the bundle by `build-app-bundle.sh`. The shared secret is provisioned once through the existing SecureField flow.

### 3.4 Availability wording (D-3)

Introduce a fourth availability projection **in the UI layer only** (the `CapabilityAvailability` enum and registry stay unchanged): when a capability is `.disabled`/`.degraded` *because its host application is not running* (VS Code bridge `disconnected`, Chrome bridge "not connected"), the row shows `capabilities.onDemand` = EN "Ready — connects on demand" / TR "Hazır — istek üzerine bağlanır" in the ready color, and the detail names the host app. The registry's truth is unchanged; the *reading* the owner gets is accurate: nothing is disabled, the host simply is not open. All other disabled reasons (not provisioned, TCC denied) keep their negative wording and remain a gate failure.

### 3.5 Zero-restriction gate

On a normal launch (Finder / login item, no env vars), the driver reads every `aura.integration.<id>.state` label and every Capabilities row's state and asserts: zero `Devre dışı`, zero `Bağlı değil`, zero `Kısıtlı`. On-demand rows count as pass only when the host app is not running; with VS Code and Chrome open they must read `Hazır` / `Bağlı`.

## 4. Files touched

`Sources/AuraCore/AuraConfigurationLoading.swift`, `Sources/AURA/AuraAppModel_Runtime.swift:23` (bootstrap path), `AuraKernel_Construction.swift` (secret from Keychain; unconditional VS Code adapter), `AuraAppModel_Settings.swift` (delete env gate; owner fields), `AuraMenuView.swift` (Settings Integrations category), `AuraAppModel_ProductState.swift` (on-demand projection), `ProductUIState.swift` (copy), `AuraKernel_StartStop.swift` or `AURA.swift` (launch provisioning), `scripts/build-app-bundle.sh` (bundle the `.vsix`), tests, ADR-067, ledgers.

## 5. Tests

- **New:** configuration precedence (defaults ← file ← env) with malformed-file resilience; secret-never-in-file assertion (encode → decode → no secret keys); on-demand projection matrix (reason × host-running → wording); VS Code launch-provisioning decision table with a stubbed `VSCodeCLI`; Gmail reconnect-on-credential-degraded path.
- **Updated (ADR-cited):** `IntegrationRowRemediationTests` (8 tests) for the new projection; `SP010`/`SP011`/`SP012` deterministic tests that assumed env gating.
- **Unchanged:** `ProductivitySecurity`, injection-classifier, network-allowlist, Safari/Chrome bridge security tests.

## 6. Live acceptance

1. Quit AURA; launch from Finder (no env) → Integrations: `mail.read` `Bağlı` (after one OAuth consent, owner-attested), `calendar.read` `Bağlı`, `contacts.lookup` `Bağlı`, `browser.read` `Bağlı` with Chrome open / on-demand with Chrome closed, VS Code 9 rows `Hazır` with VS Code open / on-demand closed.
2. Real reads: "bugün takvimimde ne var", "son e-postam ne", a Chrome page read, a VS Code diagnostics read — each answered (transcript captured by the driver).
3. Token expiry simulation (revoke in Google account) → row `reconnect` → reconnect succeeds without env vars.
4. Zero-restriction gate output (§3.5) captured to `evidence/`.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Google OAuth client requires the owner's own Cloud project credentials | One-time owner provisioning through Settings; documented; never committed |
| `code` CLI path differs (`/usr/local/bin/code` default) | Configurable; launch provisioning probes `/usr/local/bin/code`, `/opt/homebrew/bin/code`, and the app-bundle CLI path, recording which resolved |
| Chrome unpacked-extension load cannot be automated | Owner-attested one-time step; the row's guidance makes it a 30-second task; never write into Chrome's profile |
| On-demand wording drifts into dishonesty | The projection is unit-tested against the registry reason strings; non-host-related reasons keep negative wording |

## 8. Owner decisions consumed

D-3.
