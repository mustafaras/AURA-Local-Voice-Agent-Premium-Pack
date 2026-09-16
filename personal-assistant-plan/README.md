# AURA Personal Assistant Plan (`PA-` track)

**Status:** Proposal — awaiting the owner's approval of scope, sequencing, and the six decisions in §7.
**Date:** 2026-09-15
**Owner instruction (verbatim, 2026-09-15):** "bence önce bu surekli izin onay parola döngüsünü kaldıralım bilgisayar açılışıyla birlikte uygulama çalışsın ve bilgisayar ztn parola ile açılıyor ve aura kişisel bi asıstan yani onaylara ve tekrar tekrar izinlere gerek yok ve yeteneklerde hiçbir YETENEK KESİNLIKLE DEVRE DIŞI OLMAMALI HER ZAMAN ETKİN HERGÖREV İÇİN ASİSTAN HAZIR OLMALI WAKE UP WORD HEY AURA VE SADECE HEY VE AURA OLMALI. GİZLİLİK VE BELLEKTE DE BİR SÜRÜ DÜZELT OGESİ VAR BUNLAR KESİN NET DOGRU ÇALIŞIR ŞEKİLDE DUZELTİLMELİ "BAĞLI DEĞİL" VEYA KISITLI HİÇBİR ÖZELLİK OLMAMALI"
**Track:** `PA-0` … `PA-6`, disjoint from the archived `UI-` track (`docs/archive/ui-improvement-plan/`) and from the closed `SP-` chain (`archive/runtime-completion/`).
**Authority basis:** direct source scan on 2026-09-15 of `Sources/AURA/*.swift`, `Sources/AuraPolicy/DefaultPolicyGrants.swift`, `Sources/AuraCore/AuraConfigurationLoading.swift`, `Sources/AuraIntent/InitialCapabilitySet*.swift`, `Sources/AuraAudio/WakeWord*.swift`, `Sources/AuraLifecycle/LaunchAtLogin*.swift`, `Resources/*-Info.plist`, `scripts/codesign-adhoc.sh`, `scripts/build-app-bundle.sh`, ADR-030/034/037/042/044/055, the Speech framework swiftinterface in the installed macOS 27 SDK (`Xcode-27.0.0-beta.5`), `AGENTS.md`, and `ledger/`. Every claim below cites `file:line` evidence from that scan.

---

## 1. Purpose

AURA today is built as a *cautious product for an unknown user*: every mutation-or-above capability either challenges the owner with a confirmation card or is denied until a grant exists; the integrations that make it useful are composed only under a test-time environment profile; the wake word is a stub; launch at login is an opt-in behind a confirmation; and the Privacy/Memory Center carries one real defect plus untranslated strings.

The owner has decided that AURA is a **personal assistant on a single, password-protected Mac**. The macOS login is the authentication boundary. Inside that boundary the assistant must be always on, always able, and never ask twice. This plan turns that decision into seven verifiable phases under the repository's phase-gate discipline (`AGENTS.md`), with one ADR per policy change, so nothing about security posture changes silently.

What this plan **does not** do: it does not remove the policy engine, the audit trail, the emergency stop, the computer-use structural guards (secure-field halt, sensitive-app exclusion, no-progress and destructive-action detection), the prompt-injection classifier, or the network allowlist. `AGENTS.md` says "Never bypass the permission engine for convenience" — this plan *reconfigures* the engine through seeded grants and ADRs (the exact route ADR-055 already used); it does not bypass it. Every call is still evaluated and audited; the *answer* the engine gives the owner changes.

## 2. What the scan established (the root causes)

| # | Symptom the owner sees | Root cause (evidence) | Phase |
| --- | --- | --- | --- |
| R1 | "Sürekli onay" — a confirmation card on shell commands, coding-agent runs, cloud inference, app terminate, computer-use mutation actions, launch-at-login | `DefaultPolicyGrants.swift` seeds `.always` on `shellExec`, `agentCodexRun`, `agentClaudeRun`, `agentCopilotRun`, `agentOllamaCloudInference`; `.forRiskTier(.mutation)` on `appTerminate`, `lifecycleLaunchAtLogin`, `computerUseRun` (grep of `confirmationRequirement:` in that file, 25 grants). `PolicyEngine_Evaluation.swift:44` denies any capability in `denyByDefaultTiers` (`[.reversible, .mutation, .destructive, .network]`, `PolicyTypes_PolicyConfiguration.swift:31`) that has no grant — the repo itself has hit this twice (SP-006 filesystem, SP-030 launch-at-login: comments at `DefaultPolicyGrants.swift:108-118`). | PA-0 |
| R2 | "Tekrar tekrar izin" — macOS permission prompts reappear | Six separately signed executables each own a TCC identity: `ai.aura.local.agent`, `.automation-helper`, `.shell-helper`, `.plugin-host`, the Chrome native host, the Safari appex (`Resources/*-Info.plist`; `scripts/codesign-adhoc.sh:13-21`). Signing falls back to ad-hoc (`-`) when the stable identity is absent (`codesign-adhoc.sh:25-31`), and ad-hoc identity changes on every build (ADR-030 §Context). Screen Recording needs a process restart after a grant (`PermissionCoordinator.swift:94-100`). Calendar/Contacts are never requested in the guided consent pass (`PermissionSnapshot` has only mic/speech/accessibility/screen: `PermissionCoordinator.swift:29-38`). | PA-1 |
| R3 | "Parola" — Keychain password dialogs | Secrets live in generic-password Keychain items keyed by `configuration.app.serviceName` (`SecretStoring.swift:82`; `AuraKernel_Construction.swift:400`). A differently signed binary (a `swift build` debug run, an ad-hoc bundle) touching the same items triggers macOS's "AURA wants to use your confidential information" password dialog. No code in `Sources/` requests an admin password (grep for `Authorization*`, `LAContext`, `administrator privileges`: zero hits). | PA-1 |
| R4 | App is not running after login; must be started by hand | `LaunchAtLoginController.userPreferenceEnabled()` defaults to `false` (`LaunchAtLoginController.swift:44-49`); the capability keeps a `.confirm` challenge (ADR-055 §2; `DefaultPolicyGrants.swift:120-122`); onboarding stage `launchAtLogin` is `isOptional` (`ProductUIState.swift:230-236`). `SMAppService.mainApp` wrapper exists and is tested (`LaunchAtLoginService.swift:21-47`). | PA-2 |
| R5 | "Devre dışı" / "Bağlı değil" / "Kısıtlı" rows in Capabilities and Integrations | Real integrations are composed only under the **acceptance environment profile**: `AuraConfiguration.bootstrap` picks `liveAcceptance` only when `AURA_SP011_LIVE_ACCEPTANCE=1` (`AuraConfigurationLoading.swift:68-76`); the Gmail client secret is read only under that flag (`AuraKernel_Construction.swift:388-390`); the VS Code bridge Settings section is hidden unless `AURA_SP012_LIVE_ACCEPTANCE=1` (`AuraAppModel_Settings.swift:11-13`; `AuraMenuView.swift:575`). A normal Finder / Login Items launch has none of these variables, so `mail.read` has no client ID (`Configuration_ProductivityConfiguration.swift:119` default `""`), `vscode.*` (9 capabilities) stay `.disabled` (`InitialCapabilitySet_CapabilityDefinitions.swift:29-37`), and rows render `capabilities.disabled` = "Devre dışı" / `integrations.notConnected` = "Bağlı değil" (`AuraAppModel_ProductState.swift:148-160,191-194`). | PA-3 |
| R6 | No "Hey AURA" | The kernel composes `DisabledWakeWordDetector()` (`AuraKernel_Construction.swift:492`), which "can never detect" (`WakeWordDetector.swift:27-45`). ADR-042 §5/§72 excluded wake word because "no candidate qualified … authority forbids download/install". The pipeline, configuration (`phrase: "hey aura"`, `Configuration_WakeWordConfiguration.swift:39`), events, and metrics all exist; only the detector is missing. The installed macOS 27 SDK exposes on-device `SpeechAnalyzer` / `SpeechTranscriber` / `DictationTranscriber` (Speech.swiftmodule swiftinterface lines 228, 346, 70) — a license-free, download-free candidate. | PA-4 |
| R7 | "Düzelt" items in Privacy/Memory that must "work correctly" | "Düzelt" is `memory.correctShort` (`ProductUIState.swift:508`), the memory-correction verb rendered once per mutable memory record (`AuraMenuView.swift:120-127`). The correction sheet has a real defect: `MemoryCorrectionSheet.init` creates a **new** `AuraMemoryCorrectionDraft` on every re-init (`AuraMenuView.swift:147-156`), the draft is a `let` on a struct view, and the class property is a plain `var` with no `@Published` (`AuraMenuView.swift:190-196`) — any `@Published` change on the observed `model` re-creates the sheet and resets the editor to the original statement, losing the owner's typing. The Privacy tab also carries hardcoded English UI strings (`AuraMenuView_Tabs.swift:412,420,425,436-438,469,510-511`) — an F-005-class regression against the copy rule. | PA-5 |

## 3. Guiding principles (binding for every phase)

1. **Login is the boundary.** One owner, one Mac, one password at login. Inside the session, AURA acts for the owner without re-asking. This is recorded as an owner-instructed local risk acceptance (ADR-064), non-transferable to any other deployment — the same construction ADR-055 used.
2. **Reconfigure, never bypass.** The policy engine evaluates and audits every call. Confirmation requirements become `.none` through seeded grants; deny-by-default tiers are satisfied by grant coverage, proven mechanically (PA-0 G0-3). No code path skips `PolicyEngine`.
3. **Structural guards stay.** Emergency stop (⌘⇧-driven `EmergencyShortcutMonitor`), computer-use secure-field / modal / no-progress / destructive-action halts, screen-context sensitive-app exclusion, prompt-injection classifier, network allowlist, and audit retention are **not** prompts and are **not** touched.
4. **One identity, one consent.** Every executable in the bundle is signed with the stable local identity; the owner grants each macOS permission exactly once, in one guided pass; grants survive relaunch and rebuild.
5. **Honest states only.** "Hazır" is never invented. Where a host application (VS Code, Chrome) is simply not running, the row says so with an on-demand state rather than "Devre dışı" — but a capability whose preconditions are unmet is still shown as unmet. Decision D-3 in §7 fixes the wording.
6. **Exact wake phrase.** The wake word is "Hey AURA" — the two tokens `hey` and `aura`, nothing else. The configuration `phrase` is pinned by test.
7. **Repo discipline is unchanged.** `./scripts/aura-test.sh` full loop (22 targets, verified equal to `Package.swift` on 2026-09-15) rerun 2–3×; ADR per phase; `ledger/PROJECT_LEDGER.md` append; atomic `ledger/CURRENT_STATE.md` rewrite; commit/push only on explicit go-ahead in that turn; staged by explicit path.
8. **Real Turkish copy or nothing.** New strings enter `AuraCopy` with genuine Turkish; accessibility identifiers are API.

## 4. The seven phases

| Phase | Axis | Effort | Headline outcome | Doc |
| --- | --- | --- | --- | --- |
| **PA-0** | Owner trust posture | S–M | Zero confirmation cards for the owner; every registered capability provably allowed; ADR-064 | [01-owner-trust-posture.md](01-owner-trust-posture.md) |
| **PA-1** | One identity, one consent | M | Stable identity on all six executables, dev/prod Keychain isolation, single guided consent pass incl. Calendar/Contacts, zero OS re-prompts across relaunch and rebuild | [02-one-identity-one-consent.md](02-one-identity-one-consent.md) |
| **PA-2** | Launch at login, always on | S | `SMAppService` registered by default without a challenge; runtime auto-starts; onboarding never re-shows | [03-launch-at-login-always-on.md](03-launch-at-login-always-on.md) |
| **PA-3** | Integrations always connected | L | Persistent owner configuration replaces the env profile; Gmail/Calendar/Contacts/Chrome/VS Code provisioned and self-healing; zero "Devre dışı" / "Bağlı değil" on a normal launch | [04-integrations-always-connected.md](04-integrations-always-connected.md) |
| **PA-4** | "Hey AURA" wake word | L | Real on-device detector replacing the stub; exact phrase; anti-self-trigger; live FAR/FRR evidence; ADR-042 amended | [05-wake-word-hey-aura.md](05-wake-word-hey-aura.md) |
| **PA-5** | Privacy & Memory Center correctness | S–M | Correction-sheet defect fixed and pinned; every memory operation verified end-to-end; copy hygiene; truthful indicators | [06-privacy-memory-center.md](06-privacy-memory-center.md) |
| **PA-6** | Always-on soak & closure | S | Clean reinstall → one consent pass → login → "Hey AURA" → task, with zero prompts over a 24 h soak; program closure | [08-rollout.md](08-rollout.md) §6 |

Cross-cutting constraints that bind all seven: [07-cross-cutting-constraints.md](07-cross-cutting-constraints.md). Sequencing, acceptance gates, risks: [08-rollout.md](08-rollout.md). Execution machinery: [00-working-protocol.md](00-working-protocol.md), `prompts/PA-N.prompt.md`, `ledger/`, `validate-continuity.sh`.

## 5. What already exists and is reused (no re-invention)

- `PolicyEngine` + `DefaultPolicyGrants` reconcile-not-append seeding (`AuraKernel_Grants.swift:23-37`) — PA-0 changes the seed list, not the mechanism.
- `AutoAllowConfirmationPresenter` (`UIConfirmationPresenter.swift:21-31`) is a *demo* hook gated by `AURA_TEXT_DEMO_SCRIPT`; it is **not** the mechanism this plan uses (auto-accepting challenges would leave "challenge issued" audit noise for decisions that should simply be `.allow`).
- `AURA Stable Local Signing` identity and `scripts/verify-signature.sh` (ADR-030) — PA-1 extends verification to every nested executable.
- `LaunchAtLoginController` / `SMAppServiceWrapper` with stub-injected tests — PA-2 changes defaults and the grant, not the controller.
- `AuraConfiguration` JSON loader ("Load configuration from JSON data, merging with defaults", `AuraConfigurationLoading.swift:104-110`) — PA-3 gives it a persistent file to load.
- `ChromeBridgeInstaller` (self-healing host/manifest refresh at launch, `ChromeBridgeInstaller.swift:5-14`) and the bundled `.vsix` (`AuraVSCodeExtension/aura-vscode-extension-0.2.0.vsix`) — PA-3 wires them into the normal launch path.
- `WakeWordPipeline`, `WakeWordDetector`, `WakeWordConfiguration`, wake events/metrics, `MarkerWakeWordDetector` test double — PA-4 adds one production detector.
- The AppleScript acceptance driver `scripts/sp011-acceptance/aura-drive.applescript` and the `AuraAccessibilityID` contract — every live gate in this plan is driven through it.

## 6. Out of scope (explicitly)

- External distribution, Developer ID, notarization, beta/RC (ADR-049 stays in force).
- Removing the emergency stop or any computer-use structural guard.
- Token streaming, new UI surfaces, sound adoption (those belong to a future UI plan).
- Writing to the TCC database, `tccutil` resets in production, or any consent that macOS itself must collect from the user.

## 7. Decisions the owner must make before PA-0 starts

| ID | Decision | Recommendation |
| --- | --- | --- |
| D-1 | Confirmation semantics: `.none` for **all** owner-actor capabilities, including coding agents (`agent.*Run`), cloud inference, `shell.exec`, and computer-use mutation actions | **Yes** — this is the literal instruction; ADR-064 records it as a non-transferable local waiver with falsifiers. |
| D-2 | Emergency stop and the structural computer-use guards remain | **Keep** — they are halts, not prompts; removing them contradicts `AGENTS.md` priority order (Safety first). |
| D-3 | Wording for a capability whose host app is not running (VS Code closed, Chrome closed): "Hazır — istek üzerine bağlanır" (on-demand) instead of "Devre dışı" | **Adopt on-demand state** with EN/TR copy; keeps the honesty rule while eliminating the "disabled" reading. |
| D-4 | Wake-word engine: Apple on-device `SpeechAnalyzer`/`SpeechTranscriber` keyword spotting (no download, no license) vs. a licensed acoustic model (Porcupine/openWakeWord — requires download; ADR-042 forbade this) | **Apple on-device** — verified present in the installed SDK; falls back to PTT only if PA-4 G4-1 typecheck fails. |
| D-5 | "Düzelt" button label: keep ("Correct") or rename to "Düzenle" ("Edit") to stop it reading as a defect flag | **Rename to "Düzenle"**, keep the `memory.correctShort` key semantics and ADR-043 behavior (append-and-link correction). |
| D-6 | If macOS 27 enforces a periodic Screen Recording re-approval prompt (it did on macOS 15+), accept it as OS behavior or move capture to the system picker | **Accept and document** unless observed live in PA-1 G1-4; revisit only with evidence. |

## 8. Immediate next step

Awaiting the owner's decisions on D-1…D-6 and the approval token `ONAY PA-0`. On approval, PA-0 begins with the phase-gate startup sequence from `AGENTS.md` (fresh read of `ledger/CURRENT_STATE.md` and `ledger/PROJECT_LEDGER.md`, objective / risks / acceptance criteria stated in the ledger) and `prompts/PA-0.prompt.md`.
