# PA-1: One Identity, One Consent — ending the macOS permission and password loop

**Phase:** PA-1. **Effort:** M. **ADR:** ADR-065 (new) — "One identity, one consent".
**Owner instruction covered:** "tekrar tekrar izinlere gerek yok", "parola döngüsü".

---

## 1. Evidence

| Fact | Evidence |
| --- | --- |
| Six TCC subjects ship in one bundle | `Resources/AURA-Info.plist` `ai.aura.local.agent`; `AuraAutomationHelper-Info.plist` `ai.aura.local.agent.automation-helper`; `AuraShellHelper-Info.plist` `ai.aura.local.agent.shell-helper`; `AuraPluginHost-Info.plist` `ai.aura.local.agent.plugin-host`; `Contents/Helpers/AuraChromeNativeHost`; `Contents/PlugIns/AuraSafariExtension.appex` (`scripts/codesign-adhoc.sh:13-21`, `scripts/build-app-bundle.sh:61-95`) |
| Signing falls back to ad-hoc silently | `scripts/codesign-adhoc.sh:25-31`: if `AURA Stable Local Signing` is not in the keychain, `SIGNING_IDENTITY="-"`. Ad-hoc identity changes every build → TCC and Keychain treat it as a new app (ADR-030 §Context) |
| Only the main app declares usage strings | `AURA-Info.plist` has `NSAccessibilityUsageDescription`, `NSCalendars*`, `NSContacts*`, `NSMicrophone*`, `NSScreenCapture*`, `NSSpeechRecognition*`; the three helper plists declare **none** (PlistBuddy scan 2026-09-15) |
| Which processes actually touch AX | `Sources/AuraAutomation/AccessibilityObserver.swift`, `Sources/AuraComputerUse/UIActionExecuting.swift`, `ModalDialogDetecting.swift`, `Sources/AuraScreen/AccessibilitySecureFieldDetector.swift` — the phase must map each to its host process (main vs. automation helper) before deciding which executables need the Accessibility grant |
| The guided consent pass requests only mic + speech | `PermissionCoordinator.requestVoicePermissions()` (`PermissionCoordinator.swift:49-65`); accessibility and screen are separate explicit actions (`:67-79`); Calendar/Contacts are requested lazily by the productivity adapters (`NativeProductivityAdapters.swift:23,113`) and absent from `PermissionSnapshot` (`:29-38`) |
| Screen Recording grant needs a process restart | `PermissionCoordinator.swift:94-100` |
| Keychain items keyed by service name | `SecretStoring.swift:82` (`kSecClassGenericPassword`); service name from `configuration.app.serviceName` (`AuraKernel_Construction.swift:400`); shared by every build that uses the default configuration |
| No in-app admin/password request exists | grep of `Sources/` for `AuthorizationCreate`, `AuthorizationExecuteWithPrivileges`, `LAContext`, `with administrator privileges`, `kSecUseAuthenticationUI`: zero hits. The "parola" the owner sees is macOS's Keychain access dialog or a TCC dialog, never AURA code |

## 2. Problem statement

The owner grants a permission, rebuilds or runs a differently-signed binary, and macOS asks again — for each of several executables — and the Keychain asks for the login password when a foreign identity reads AURA's secrets. Each of these is macOS doing its job against an *unstable identity*. The cure is not to suppress prompts (impossible and forbidden by `AGENTS.md`) but to make the identity stable, request every permission exactly once in one place, and keep development builds out of the production identity's data.

## 3. Design

### 3.1 Identity invariant (build + verify)

- `scripts/codesign-adhoc.sh`: the ad-hoc fallback becomes **opt-in** (`AURA_ALLOW_ADHOC=1`); without it, a missing stable identity is a hard error with the provisioning instruction. Rationale: an ad-hoc bundle installed to `/Applications` is exactly what restarts the prompt cycle.
- `scripts/verify-signature.sh`: add a designated-requirement check for **each** nested executable (`codesign -d -r- <path>`), asserting the leaf certificate is `AURA Stable Local Signing`, and fail if any is ad-hoc (`Signature=adhoc`). Test the check by deliberately ad-hoc signing a copy in `$TMPDIR` and asserting failure.
- Record each executable's designated requirement string in `evidence/identity-inventory.txt`; PA-6 diff-checks it after a rebuild.

### 3.2 Keychain isolation (production vs. everything else)

- `AppConfiguration.serviceName` gains a derived **runtime** value: if the running bundle is not signed by the stable identity (`SecCodeCopySelf` + `SecCodeCheckValidity` against the stable requirement, or a simpler `Bundle.main` DR probe via `SecStaticCodeCreateWithPath`), the service name is suffixed `.dev`. Debug/`swift run`/test binaries therefore never read or write the installed app's Keychain items, so macOS never shows the password dialog for them, and the installed app's items are never re-ACL'd by a foreign identity.
- Unit test: service-name derivation for (stable, ad-hoc, unsigned) inputs via an injected probe. Live: launch a `swift build` debug binary once → `security find-generic-password -s ai.aura.local.agent` count unchanged, no dialog (owner-attested).

### 3.3 One guided consent pass

- `PermissionSnapshot` gains `calendar` and `contacts` (from `EKEventStore.authorizationStatus(for: .event)` and `CNContactStore.authorizationStatus(for: .contacts)` — both already used in `ProductivityTypes_AuthorizationProbe.swift:33,53`).
- Onboarding `privilegedAccess` stage (`AuraOnboardingStage.privilegedAccess`, `ProductUIState.swift:220`) becomes the **single** place that requests, in order: Microphone, Speech Recognition, Accessibility (main app; and the automation helper if §1 mapping shows it needs its own grant — surfaced as one explicit step, not a surprise later), Screen Recording, Calendar, Contacts. Each row shows live state and a "Sistem Ayarları" fallback when macOS will no longer prompt.
- The stage stays optional only in the reducer sense (the stage machine is behavior-frozen per UI-5); its copy tells the truth: "Bir kez verilir; yeniden sorulmaz."
- Privacy tab and Recovery tab indicators (`AuraMenuView_Tabs.swift:358-376,556-566`) render the two new rows.

### 3.4 What we cannot change (and say so)

- macOS decides *when* it prompts. Screen Recording on macOS 15+ added a periodic re-approval for apps using ScreenCaptureKit outside the system picker. Whether macOS 27 does this is unknown until observed; G1-4 records what it sees. If it recurs, D-6 applies (accept + document, or move to `SCContentSharingPicker` in a later phase).
- TCC grants are per-executable. Consolidating helpers into the main process would change ADR-034/ADR-044's privilege separation and is **out of scope**; the plan minimises the count of *distinct prompts* to the set that separation genuinely requires and collects them in one pass.

## 4. Files touched

`scripts/codesign-adhoc.sh`, `scripts/verify-signature.sh`, `Sources/AuraCore/Configuration_AppConfiguration*.swift` (service-name derivation; verify exact file), a small `Sources/AuraSecurity/CodeIdentityProbe.swift` (new), `Sources/AURA/PermissionCoordinator.swift`, `Sources/AURA/AuraMenuView.swift` (onboarding privileged-access stage — presentation only), `AuraMenuView_Tabs.swift` (two indicator rows), `ProductUIState.swift` (copy keys), tests, ADR-065, ledgers.

## 5. Tests

- **New:** `CodeIdentityProbeTests` (stable / ad-hoc / unsigned), `ServiceNameDerivationTests`, `PermissionSnapshotTests` (six-field snapshot mapping), onboarding view-construction test for the extended stage, copy-table guard for new keys, a shell test for `verify-signature.sh` against an ad-hoc-signed copy (`Tests/…` shell harness or `scripts/tests/`).
- **Unchanged:** R9 onboarding stage-machine tests (behavior-frozen), a11y-ID tests (new IDs are additions).

## 6. Live acceptance

1. Fresh install of the stable-signed bundle to a fresh bundle path (Dock-cache discipline) → run onboarding privileged-access stage → each permission granted once (owner-attested).
2. Relaunch ×3 → `PermissionCoordinator.snapshot()` all `granted` (driver reads the Privacy tab indicator labels); owner attests zero dialogs.
3. Rebuild → `verify-signature.sh` passes → reinstall → relaunch → still zero dialogs; `evidence/identity-inventory.txt` diff is empty.
4. `log show --last 10m --predicate 'subsystem == "com.apple.TCC"' | grep -i aura` captured to `evidence/` (read-only; if the unified log withholds TCC entries without Full Disk Access, record that as the observation — do not request FDA).
5. Keychain: `security find-generic-password -s ai.aura.local.agent -g` (redact output) shows the items' ACL partition unchanged after a debug-binary launch; owner attests no password dialog.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| The stable certificate expires or is re-created (ADR-030 §Consequences) | G1-1 records the certificate's `notAfter`; PA-6 adds a check to the soak; re-creation is a documented one-time re-consent |
| Automation helper needs its own Accessibility grant | §1 mapping decides; if yes, it becomes an explicit onboarding row rather than an ambush |
| macOS periodic Screen Recording re-approval | D-6; recorded as `os-observed`, never hidden |

## 8. Owner decisions consumed

D-6.
