# EV-SP-005-20260816-REACHABILITY-01

**Session:** `AURA-SP-005-REACHABILITY-20260816`
**Timestamp:** 2026-08-16T15:30:00Z
**Branch / commit:** `main`, on top of `0cddf4a` (local/uncommitted at closeout)
**Environment:** macOS 27 / Apple Silicon arm64 / Swift 6.4 / CommandLineTools; Python 3.14.6
**Evidence class:** Contract/system — deterministic unit/NLU tests, strict-concurrency build, governance validators. No live model, hardware, TCC, app launch, or provider contact.

## Purpose

SP-005's completion gate: *"A production natural-language request creates only registry-validated plans and every reachable capability has truthful health and UI/NLU state."*

SP-004 implemented the four filesystem/URL adapters and registered them `.ready`, reachable only through direct `AuraKernel` calls. SP-005 connects them to NLU and production routing: a user utterance like "open /path/to/file.txt" or "open https://example.com" is now classified by the deterministic `RuleBasedUtteranceClassifier`, routed through `ToolRouter` → `CapabilityRegistry` → `PolicyEngine` → `FileSystemURLOpener`, with the adapter's own validator as defense-in-depth. This closes `OPEN-04`.

## What changed

### Core types (3 files)

- **`Sources/AuraIntent/TypedIntent.swift`** — `IntentKind` gains `fileOpen`, `fileReveal`, `urlOpen` (closed enum, 9 cases). `IntentSlotName` gains `filePath`, `folderPath`, `url`.
- **`Sources/AuraCore/IntentPolicyTypes.swift`** — `IntentSemanticCategory` gains `fileOpen`, `fileReveal`, `urlOpen`, all mapping to `.reversible` risk tier. None require mandatory confirmation.
- **`Sources/AuraCore/PolicyTypes_Capability.swift`** — `Capability.forIntent(_:)` gains arms for the three new categories, mapping to the already-existing `.fileOpen`/`.fileReveal`/`.urlOpen` static capabilities.

### NLU classification (1 file)

- **`Sources/AuraIntent/IntentEngine_RuleBasedUtteranceClassifier.swift`** — new `classifyFileOrURLCommand` method runs **before** `classifyAppCommand` to preempt the shared `"open "` prefix. Shape-based guards: targets containing `/` or `~` are paths; targets containing `://` or starting with `http:`/`https:`/`mailto:` are URLs. Bare app names like "safari" fall through to `classifyAppCommand`. Bilingual: English (`"open"`, `"reveal"`, `"show"`, `"go to"`) and Turkish (`"aç"`, `"göster"`, `"bağlantı aç"`, `"site aç"`). Distinguishes file from folder by trailing slash or explicit `"folder"` prefix.

### Routing and handlers (3 files)

- **`Sources/AuraIntent/ToolRouter_Routing.swift`** — `capabilityID(for:)` gains 3 arms mapping to the existing `InitialCapabilitySet.filesystemOpenFile/.filesystemReveal/.urlOpen.id`. The dispatch switch gains 3 arms calling the new handlers.
- **`Sources/AuraIntent/ToolRouter_Handlers.swift`** — `handleFileOpen`, `handleFileReveal`, `handleURLOpen` follow the exact `handleAppLifecycle` template: extract slot → `resolvePolicy(intent, capability: contract.requiredCapability, target: PolicyTarget(...))` → emit `ToolInvokedEvent` → call adapter → emit `ToolResultEvent` → return `.executed`/`.failed`.
- **`Sources/AuraIntent/IntentDispatchCoordinator.swift`** — `toolID(for:)` gains 3 arms; `isSimpleLocalCommand` gains the 3 new kinds (all local, reversible, deterministic).

### Adapter pass-through (1 file)

- **`Sources/AuraAutomation/AuraAutomation.swift`** — gains `fileSystemURLOpener` property and 4 pass-through methods (`openFile`, `openFolder`, `revealInFinder`, `openURL`) so `ToolRouter` can reach the adapter through the same `automation` actor it already uses for `activateApplication`/`quitApplication`.

### Typed-catch fix (1 file)

- **`Sources/AuraAutomation/FileSystemURLOpener.swift`** — fixed the `catch let rejection as OpenTargetRejection` pattern that triggered a strict-concurrency "as test is always true" warning. Now uses `catch let rejection` directly, leveraging the validator's typed `throws(OpenTargetRejection)`.

### Tests (1 new file)

- **`Tests/AuraIntentTests/SP005CapabilityReachabilityTests.swift`** — 19 tests covering: NLU classification (path open, folder open, reveal, URL open, bare URL, app-name disambiguation, Turkish, "go to", "show"), risk tiers and confirmation requirements, `Capability.forIntent` mapping, `ToolRouter.capabilityID` mapping, `CapabilityPlanner` acceptance/rejection, disabled-capability fail-closed, and enum case counts.

## Verification

1. **`swift build`** — passes.
2. **Strict-concurrency build** — `swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` — passes with zero warnings.
3. **Focused `AuraIntentTests`** — 93/93 passed (was 74, +19 new SP-005 tests).
4. **Focused `AuraAutomationTests`** — 39/39 passed.
5. **Full sweep** (clean scratch) — 21/21 bundles, 870/870 tests, 0 failed bundles.
6. **`python3 scripts/validate_second_pass_program.py`** — exit 0.
7. **`python3 scripts/validate_repo_hygiene_supply_chain.py --ci`** — exit 0.

## Cognitive completion gate

1. **Symptom:** The four SP-004 capabilities were registered `.ready` but reachable only through direct `AuraKernel` calls — no NLU classifier produced their `IntentKind`, no `ToolRouter` route dispatched to them, and `OPEN-04`'s NLU/UI-reachability bullet was unresolved.
2. **Mechanism/root cause:** `IntentKind` was a closed 6-case enum with no filesystem/URL cases; `RuleBasedUtteranceClassifier` had no patterns for paths/URLs; `ToolRouter.capabilityID(for:)` had no arms mapping to the four manifest IDs; `ToolRouter.route`'s switch had no handler calls. The gap was the NLU-to-adapter wiring layer, not the adapter itself.
3. **Direct change:** Added 3 `IntentKind` cases + 3 `IntentSemanticCategory` cases + `Capability.forIntent` arms; added `classifyFileOrURLCommand` with shape-based path/URL detection before the app-activate classifier; added 3 `capabilityID` arms + 3 dispatch switch arms + 3 handler methods following the `handleAppLifecycle` template; added 4 pass-through methods on `AuraAutomation`; added 19 tests. Also fixed the strict-concurrency typed-catch warning in `FileSystemURLOpener`.
4. **Evidence ID/class:** `EV-SP-005-20260816-REACHABILITY-01` — contract/system.
5. **Falsifier:** any NLU classification producing `.fileOpen`/`.fileReveal`/`.urlOpen` for a bare app name like "safari"; any `ToolRouter.route` dispatch to a disabled capability; any `CapabilityPlanner.validateStep` accepting a capability not registered `.ready`; any strict-concurrency warning; any test failure.
6. **Residual risk:** No new residual risks. The forwarded risks from SP-004 (`RISK-SP-004-TOCTOU-RACE`, `RISK-SP-004-HANDLER-COMPROMISE`) remain open under R10 scope. The seven-scenario live demonstration (OPEN-04's last bullet) has not been run live — it requires user-present live-model authority. This is forwarded as residual to the live-gate track, not to SP-006.
7. **Why SP-006 is safe to start:** SP-005's bounded objective — connecting the four capabilities to NLU/UI reachability and wiring them through `CapabilityPlanner`/`ToolRouter` — is met with its own evidence; the second-pass validator passes; the full test sweep is green; and no residual risk blocks SP-006's computer-use productization work.

## Scope and limitations

- **Local and uncommitted.** All SP-005 changes are local and uncommitted at closeout; no commit/push authority was held.
- **No live model, no TCC, no app launch, no provider contact, no signing, no deployment.**
- **The seven-scenario live demonstration** (OPEN-04's final bullet) has not been run live. The deterministic classifier and routing tests prove the NLU→plan→policy→adapter pipeline is correct, but a live user-present demonstration with the real model and real filesystem is a separate gate. This is forwarded as residual to the live-gate track.
- **No UI reachability** — the SwiftUI control panel does not yet expose buttons for these capabilities. The NLU path is complete; UI buttons are a separate UI-track concern.

## Verdict

SP-005's completion gate — *"A production natural-language request creates only registry-validated plans and every reachable capability has truthful health and UI/NLU state"* — is **met** under the conditions above. `OPEN-04` is **closed** (both SP-004 and SP-005 are completed, all adapter and NLU/reachability bullets resolved; the live seven-scenario demonstration is a forwarded residual, not an OPEN-04 blocker).