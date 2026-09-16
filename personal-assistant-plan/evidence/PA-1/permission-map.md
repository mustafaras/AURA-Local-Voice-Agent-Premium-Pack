# PA-1 G1-0 — Process → permission map (2026-09-16)

Method: `grep -rn` over `Sources/` for every TCC-relevant API, then the composition root
(`Sources/AURA/AuraKernel_Construction.swift`, `ProductivityRuntime.swift`) and
`Package.swift` executable targets to decide which process actually executes each call.

## Executables in the bundle (scripts/codesign-adhoc.sh:13-21)

| Executable | Bundle ID | Launched at runtime by | TCC-protected APIs it executes |
| --- | --- | --- | --- |
| `Contents/MacOS/AURA` | `ai.aura.local.agent` | LaunchServices (user) | **all six** — see below |
| `Contents/Helpers/AuraAutomationHelper.app` | `ai.aura.local.agent.automation-helper` | **nobody** — ADR-034 §7 keeps `AuraAutomation` in-process by default; ADR-044 lists "production helper wiring" as open; `grep` for `Helpers/AuraAutomationHelper`, `Process()`, `NSXPC` in `Sources/AURA`, `Sources/AuraAutomation` → no launch site | none at runtime. Its code path (`main.swift:80-109`) calls only `NSRunningApplication.activate/hide/terminate` via `ApplicationController.swift:99-150` — no `AXUIElement*`, no `CGEvent` |
| `Contents/Helpers/AuraShellHelper.app` | `ai.aura.local.agent.shell-helper` | nobody (same ADR-034 §7 status) | none |
| `Contents/Helpers/AuraPluginHost.app` | `ai.aura.local.agent.plugin-host` | nobody in the installed product path | none |
| `Contents/Helpers/AuraChromeNativeHost` | (Mach-O, no plist) | Google Chrome (native messaging), not AURA | none — depends on `AuraProductivity` for types only (`grep` for EventKit/Contacts symbols → none) |
| `Contents/PlugIns/AuraSafariExtension.appex` | (App Sandbox) | Safari | none |

## Permission → call sites (all inside the main `AURA` process)

| Permission | Request site | Status/probe sites | Consumer |
| --- | --- | --- | --- |
| Microphone | `PermissionCoordinator.swift:50-55` (`AVAudioApplication.requestRecordPermission`) | `:113` | `AuraAudio` capture (kernel) |
| Speech Recognition | `PermissionCoordinator.swift:57-62` (`SFSpeechRecognizer.requestAuthorization`) | `:122`; `AuraSTT/SystemSTTEngine_STT.swift:35` | `SystemSTTEngine` (kernel) |
| Accessibility | `PermissionCoordinator.swift:67-70` (`AXIsProcessTrustedWithOptions(prompt: true)`) | `:45`; `AuraAutomation/AccessibilityHealth.swift:40`, `AccessibilityObserver.swift:36`; `AuraComputerUse/ModalDialogDetecting.swift:99`, `UIActionExecuting.swift:156`; `AuraScreen/AccessibilitySecureFieldDetector.swift:75` | `AXCGEventActionExecutor` (`UIActionExecuting.swift:222,307-402` — `AXUIElementCreateApplication`, `CGEvent`), `AccessibilityModalDialogDetector` (`:122`), `AccessibilitySecureFieldDetector` (`:88`) — all constructed in `AuraKernel_Construction.swift:298-321` inside the main app. `AuraAutomation.observeElement` / `checkAccessibilityPermission` (`AuraAutomation.swift:140-163`) exist but have **no caller** in `Sources/AURA`, `AuraIntent`, or the helper |
| Screen Recording | `PermissionCoordinator.swift:75-76, 95-96` (`CGRequestScreenCaptureAccess`) | `:46, 75, 95` (`CGPreflightScreenCaptureAccess`) | `ScreenCaptureKitWindowSource` (`AuraKernel_Construction.swift:305`) |
| Calendars | `AuraProductivity/NativeProductivityAdapters.swift:23` (`requestFullAccessToEvents`, lazy) | `ProductivityTypes_AuthorizationProbe.swift:33`; `NativeProductivityAdapters.swift:84` | `EventKitCalendarReadAdapter` composed in `ProductivityRuntime.swift:194` (main app) |
| Contacts | `NativeProductivityAdapters.swift:113` (`CNContactStore.requestAccess`, lazy) | `ProductivityTypes_AuthorizationProbe.swift:53`; `NativeProductivityAdapters.swift:188` | `ContactsFrameworkLookupAdapter` (main app) |

Usage strings: only `Resources/AURA-Info.plist` declares them (Accessibility, CalendarsFullAccess,
Calendars, Camera, Contacts, Microphone, ScreenCapture, SpeechRecognition); the three helper plists
declare none (PlistBuddy count 0 each) — consistent with the helpers executing no TCC-protected API.

## Decision (G1-0)

- **The automation helper does not need its own Accessibility grant.** It is not launched by the
  product, and its implementation performs no AX or event-synthesis call. If a later phase wires
  ADR-034's helper path, *that* phase adds the grant as an explicit onboarding row (design §3.3).
- **macOS therefore has exactly one TCC subject to prompt for: `ai.aura.local.agent`.** Six prompts
  total, each once, all collectable in the `privilegedAccess` stage (G1-3).
- `AuraSpeechQualityProbe` (Speech Recognition, `main.swift:94-97`) is a diagnostic executable that is
  not part of the bundle; it keeps its own separate grant by design (SP-016) and is out of scope.
