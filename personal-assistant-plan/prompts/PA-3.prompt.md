---
id: PA-3
sequence: 3
track: PA
depends_on: PA-2
next_prompt: PA-4
state: pending
design_docs: 04-integrations-always-connected, 07-cross-cutting-constraints
adr: ADR-067
---

# PA-3 — Integrations Always Connected

## Mission

Replace the test-time environment profile with persistent, app-owned owner configuration; compose every integration on every launch; provision Chrome and VS Code bridges self-healingly; keep secrets in Keychain; and make a normal Finder / login-item launch show **zero** "Devre dışı", "Bağlı değil", or "Kısıtlı" rows — with an honest on-demand state for host apps that are simply not open (D-3).

## Read before acting

- Plan: `ledger/CURRENT_PHASE.md`, ledger tail, `00-working-protocol.md`, `04-integrations-always-connected.md`, `07-cross-cutting-constraints.md` §2
- Repo: ADR-040 (productivity/OAuth), ADR-041 (VS Code bridge), ADR-054 (Chrome bridge), ADR-055 §5/§7, `scripts/sp011-acceptance/README.md`, `scripts/install-chrome-bridge.sh`
- Code: `Sources/AuraCore/AuraConfigurationLoading.swift` (all), `Configuration_ProductivityConfiguration.swift:100-125`, `Configuration_VSCodeConfiguration.swift:35-55`, `Sources/AURA/AuraAppModel_Runtime.swift:15-40`, `AuraKernel_Construction.swift:320-420`, `AuraKernel_Productivity.swift`, `AuraKernel_VSCodeAvailability.swift`, `AuraAppModel_Settings.swift`, `AuraMenuView.swift:570-600` (Integrations category), `AuraAppModel_ProductState.swift:130-260`, `ProductivityRuntime.swift:240-480`, `ChromeBridgeInstaller.swift`, `Sources/AuraVSCode/VSCodeCLI.swift`, `Sources/AuraProductivity/ProductivityTypes_KeychainOAuthTokenStore.swift`
- Tests: `IntegrationRowRemediationTests`, `SP010*`, `SP011*`, `SP012*` deterministic tests
- Owner decision D-3 recorded; owner has the Google OAuth Desktop client ID/secret ready (never pasted into chat, entered in Settings).

## Hard boundaries

- **Allowed files:** the code files listed above, `scripts/build-app-bundle.sh` (bundle the `.vsix`), `ProductUIState.swift` (copy), `AuraAccessibilityIdentifiers.swift` (additions), tests, `docs/decisions/ADR-067-*.md`, ledgers.
- Forbidden: putting any secret in `configuration.json`, source, tests, fixtures, or ledgers; writing into Chrome's profile; changing `CapabilityAvailability` or `CapabilityRegistry`; weakening `ProductivitySecurity`, the injection classifier, or the network allowlist.
- The acceptance env profile must keep working unchanged (it is now an override layer).

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G3-1 | `[policy]` Persistent configuration: `defaults ← ~/Library/Application Support/AURA/configuration.json ← env`; malformed file → defaults + `configurationInvalid` health; secrets never serialized; Settings writes it atomically (0600) | `unit` precedence + resilience tests; `ls -l` mode |
| G3-2 | `[policy]` Composition unconditional: `isVSCodeBridgeAcceptanceEnabled` removed; VS Code adapter constructed every launch; Gmail secret read from Keychain via Settings `SecureField`; availability still live | `unit` + `grep -rn AURA_SP012_LIVE_ACCEPTANCE Sources/AURA/` = 0 |
| G3-3 | Launch provisioning: `ChromeBridgeInstaller` runs at launch with a health record; VS Code extension auto-installed from the bundled `.vsix` when missing (stubbed `VSCodeCLI` decision-table test); `.vsix` present in the bundle | `unit` + `ls AURA.app/Contents/Resources/*.vsix` + `code --list-extensions` |
| G3-4 | On-demand projection (D-3): exact reason strings mapped to `capabilities.onDemand` EN/TR; every other negative reason keeps negative wording | `unit` matrix test; copy guard |
| G3-5 | Live connect: Gmail OAuth once (owner), Calendar/Contacts from PA-1 grants, Chrome bridge with Chrome open, VS Code 9 rows with VS Code open — rows `Bağlı`/`Hazır`; real reads answered | `live-local` transcripts; `owner-attested` OAuth |
| G3-6 | Zero-restriction gate: normal launch (no env) → driver reads every `aura.integration.<id>.state` and every Capabilities row: zero `Devre dışı`, zero `Bağlı değil`, zero `Kısıtlı` (on-demand allowed only with host closed) | `live-local` label dump in `evidence/PA-3/zero-restriction.txt` |
| G3-7 | Reconnect: revoke Google access → row `reconnect` → reconnect succeeds without env | `live-local` + `owner-attested` |
| G3-8 | Full verification + governance: suite ×2–3, ADR-067, repo ledgers, `CURRENT_STATE` | `evidence/PA-3/` |
| G3-9 | Machine coherence | validator OK, `awaiting-approval` |

## Per-gate procedure

- **G3-1:** implement `fromApplicationSupport`; layer into `bootstrap`; Settings fields; tests; verify file mode.
- **G3-2:** remove the env gate; Keychain-backed secret; construct adapter unconditionally; run `AuraVSCodeTests` + `AURAIntegrationTests`.
- **G3-3:** wire installer health; `.vsix` into `build-app-bundle.sh`; CLI path probing (`/usr/local/bin/code`, `/opt/homebrew/bin/code`); decision-table test.
- **G3-4:** projection in `AuraAppModel_ProductState.swift`; enumerate reason strings from `ProductivityRuntime.swift`, `SafariBridgeAvailability.swift`, `AuraKernel_VSCodeAvailability.swift`; test.
- **G3-5–G3-7:** stable-signed bundle, `open -a`; owner performs OAuth consent and Chrome extension load once; driver captures rows and transcripts; revoke/reconnect leg.
- **G3-8/G3-9:** closing sequence.

## Evidence template

```text
## SEQ-00NN — <ISO> — PA-3 — G3-k PASSED
- evidence: …   (redact account labels; never a token, ID, or secret)
- verified: …
- adr: ADR-067   ← G3-1, G3-2
```

## Risks / reverting

A leg that cannot connect for a reason outside the code (no Chrome installed, VS Code CLI missing) is recorded `blocked` with the exact remediation; it is not hidden behind on-demand wording. Reverting is restoring the allowed files; the configuration file may be left in place (it holds no secrets).

## Session script

Protocol §5, then G3-1 → G3-9. End with `awaiting-approval`.

## Cognitive completion gate

(1) Which row would still read negative if VS Code and Chrome were both closed, and is that wording honest? (2) Where is each secret stored, and what proves it is not in the file? (3) Does the acceptance harness still work unchanged?
