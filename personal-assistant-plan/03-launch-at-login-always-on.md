# PA-2: Launch at Login, Always On

**Phase:** PA-2. **Effort:** S. **ADR:** ADR-066 (new) — "Launch at login by default; always-on runtime".
**Owner instruction covered:** "bilgisayar açılışıyla birlikte uygulama çalışsın … her görev için asistan hazır olmalı".

---

## 1. Evidence

| Fact | Evidence |
| --- | --- |
| Login-item machinery exists and is production-wired | `Sources/AuraLifecycle/LaunchAtLoginService.swift:21-47` (`SMAppServiceWrapper` over `SMAppService.mainApp`), `LaunchAtLoginController.swift` (persisted preference, health record, events) |
| Default is **off** | `LaunchAtLoginController.userPreferenceEnabled()` returns `false` when unset (`LaunchAtLoginController.swift:44-49`) |
| The capability still challenges | `DefaultPolicyGrants.swift:120-122` `.forRiskTier(.mutation)`; ADR-055 §2 explicitly kept it. PA-0 removes the challenge (D-1) |
| Onboarding stage is optional and last | `AuraOnboardingStage.launchAtLogin` (`ProductUIState.swift:226`), `isOptional == true` (`:230-236`) |
| Runtime starts from the app model bootstrap | `AuraAppModel.swift:230` → `bootstrap()`; configuration at `AuraAppModel_Runtime.swift:23` |
| TCC attribution requires a LaunchServices launch | `scripts/sp011-acceptance/README.md` ("a terminal-exec'd app is not the responsible process for its own TCC requests") and `launch-aura.sh:21,80` (`open -a`) — a login item launched by `SMAppService` is a LaunchServices launch, so attribution is correct |
| Onboarding is persisted with the UI state | `AuraProductUIState.onboarding` persisted under `aura.ui.state` (`ProductUIState.swift:258-270`); re-presented only through `beginOnboarding` (header wand button `AuraMenuView_Content.swift:261-269`, Settings `AuraMenuView.swift:500`) |

## 2. Problem statement

After a restart the owner must find and launch AURA. A personal assistant that must be started is not always on. The registration API, the controller, and the tests already exist; what is missing is the default, the absence of a challenge, and proof that a real login brings the runtime up ready.

## 3. Design

### 3.1 Default on, registered on first stable-signed launch

- `LaunchAtLoginController.userPreferenceEnabled()` default flips to `true` **only** when `OwnerTrustPosture.isEnabled` (import via `AuraCore`-level constant or pass through configuration — decide at implementation; keep `AuraLifecycle` free of `AuraPolicy` import if layering forbids it).
- On kernel start, if the preference is `true` and `serviceStatus() != .enabled`, call `setEnabled(true, actor: .system)` once per launch. `SMAppService.mainApp.register()` may return status `.requiresApproval` (macOS lists the item under Login Items with a switch the user must turn on); the controller already maps statuses — the Settings row and the onboarding stage show that state with a deep link to the Login Items pane (`x-apple.systempreferences:com.apple.LoginItems-Settings.extension` — **verify** this anchor against the installed macOS before use; if it does not resolve, fall back to opening System Settings generically).
- The Settings toggle stays so the owner can turn it off; turning it off persists `false` and unregisters.

### 3.2 Onboarding stage becomes informational

The `launchAtLogin` stage's copy changes from opt-in to statement: EN "AURA starts automatically when you log in. You can turn this off in Settings." / TR "AURA giriş yaptığınızda otomatik başlar. Ayarlar'dan kapatabilirsiniz." with the live status row. The stage machine is behavior-frozen (UI-5); only presentation and copy change.

### 3.3 Always-on runtime

- The kernel already starts from `bootstrap()` without user interaction; PA-2 adds a **readiness gate**: after start, the menu bar status must reach `Boşta` within 10 s on a login-item launch (evidence via the driver's `status` verb), with wake listening armed once PA-4 lands (until then, PTT-ready).
- `probeExternalAvailability()` runs post-launch (already; `AuraKernel_Productivity.swift:57-71`) so integrations reconnect without a click.
- Emergency-stop state is not persisted across launches (verify `emergencyStopActive` is in-memory only: `AuraAppModel_Interaction.swift:205-223`) — a fresh login always comes up armed and idle.

## 4. Files touched

`Sources/AuraLifecycle/LaunchAtLoginController.swift`, `Sources/AURA/AuraKernel_StartStop.swift` (post-start registration call), `Sources/AURA/AuraMenuView.swift` (onboarding `launchAtLogin` stage copy/rows; Settings row), `ProductUIState.swift` (copy keys), tests, ADR-066, ledgers.

## 5. Tests

- **New:** controller default-on under posture; idempotent registration (second launch is `changed: false`); `.requiresApproval` mapping to the Settings/onboarding row state; copy keys EN/TR present.
- **Unchanged:** existing `LaunchAtLoginController` stub tests, R9 stage-machine tests, a11y-ID tests.

## 6. Live acceptance (`os-observed` + `live-local` + `owner-attested`)

1. `sfltool dumpbtm` (read-only) or the app's own `serviceStatus()` surfaced in Settings shows `enabled` after first launch of the stable-signed bundle.
2. Real logout → login: `pgrep -x AURA` non-empty within 30 s; driver `status` → `OK AURA durumu: Boşta`; owner attests no onboarding sheet re-appeared and no prompt appeared.
3. Settings toggle off → `sfltool dumpbtm` no longer lists AURA; toggle on → listed again (proves the control is real).

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| macOS puts the item in `.requiresApproval` | Honest row + deep link; owner performs the one-time switch; recorded as `owner-attested` |
| The app is launched from a non-`/Applications` path | `SMAppService.mainApp` registers the *running* bundle; PA-6 verifies the registration points at `/Applications/AURA.app` (`sfltool dumpbtm` path field) |
| Layering: `AuraLifecycle` must not import `AuraPolicy` | Pass the posture as a configuration value at composition |
