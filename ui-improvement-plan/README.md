# AURA UI Improvement Plan

**Status:** Proposal — awaiting user approval of scope and sequencing.
**Date:** 2026-09-09
**Owners:** UI track (this plan proposes a `UI-` prefixed phase track, separate from the master roadmap numbering in `prompts/implementation/AURA_PREMIUM_UNIFIED_MASTER.prompt.md` §6).
**Authority basis:** Direct source scan of `Sources/AURA/*.swift` (all view, app-model, and design-system files), `Sources/AuraCore` / `Sources/AuraAudio` / `Sources/AuraTasks` / `Sources/AuraIntent` signal surfaces, the test suites in `Tests/AURAIntegrationTests/`, `scripts/aura-test.sh`, `scripts/sp011-acceptance/`, `AGENTS.md`, `TOOLCHAIN.md`, `ledger/`, `docs/decisions/ADR_TEMPLATE.md`, and `docs/decisions/ADR-029-swiftui-runtime-shell.md`. Every claim below cites file:line evidence gathered in that scan.

---

## 1. Purpose

AURA's product surface is structurally sound but visually and interactively conservative: it reads as a functional panel, not as the face of a premium local voice assistant. This plan defines a complete identity-and-experience program: a design identity foundation ("The Instrument" — tokens, icon, motion, sound, hero surfaces, down to the Dock icon) followed by five experience axes, each scoped so that it can be implemented phase-by-phase under the repo's existing phase-gate discipline (build + full test verification, ADR, ledger append, atomic `CURRENT_STATE.md` rewrite) without violating any pinned test contract. The quality bar: defensible at Apple Design Award shortlist level (criteria mapping in [08 §6](08-design-vision.md)).

## 1.1 Plan structure (two volumes)

| Volume | Docs | Scope |
| --- | --- | --- |
| **I — Identity & Foundations** | [08-design-vision.md](08-design-vision.md), [09-visual-language.md](09-visual-language.md), [10-icon-identity.md](10-icon-identity.md), [11-motion-system.md](11-motion-system.md), [12-sound-design.md](12-sound-design.md), [13-advanced-surfaces.md](13-advanced-surfaces.md) | The design identity: vision, tokens v2, the Iris icon (from a verified zero-icon state), motion and sound vocabularies, the Aura Orb and hero surfaces. Owns phase **UI-0**. |
| **II — Experience** | [01-conversation-experience.md](01-conversation-experience.md) … [05-settings-restructure.md](05-settings-restructure.md) + [06-cross-cutting-constraints.md](06-cross-cutting-constraints.md) + [07-rollout.md](07-rollout.md) | The five user-facing axes (UI-1…UI-5), consuming the Volume I vocabulary. |
| **III — Execution machinery** | [00-working-protocol.md](00-working-protocol.md), `prompts/UI-0…UI-5.prompt.md`, `ledger/CURRENT_PHASE.md` + `ledger/PHASE_LEDGER.md`, `validate-continuity.sh` | The anti-amnesia execution machine: one frozen prompt per phase, plan-local append-only ledger, mandatory user-approval tokens (`ONAY UI-N`) at every transition, and a mechanical cross-audit validator that proves prompt ↔ ledger coherence. Tuned to the session model (GLM 5.3 Flash). |

## 2. What the scan established (summary)

| Area | Finding | Evidence |
| --- | --- | --- |
| UI files | The whole product surface is 8 view/design files under `Sources/AURA/` (~2,600 view lines): main window with 6 tabs, menu bar panel, Settings form, onboarding sheet, design system | `AuraMenuView.swift`, `AuraMenuView_Content.swift`, `AuraMenuView_Tabs.swift`, `AuraMenuBarPanel.swift`, `AuraDesign.swift`, `AuraSettingsView` + `AuraOnboardingView` (in `AuraMenuView.swift`) |
| Design system | Token-based (`AuraDesign`): spacing, radius, relative typography only, semantic status colors; Liquid Glass used deliberately in three places (status pill, tab bar, composer) | `AuraDesign.swift:14-124`, `AuraMenuView_Content.swift:131-144,269-310` |
| App model | Single `@MainActor ObservableObject` with ~30 `@Published` properties; single convergence point `refreshProductSnapshots()`; conversation capped at 40 messages; task summaries capped at 5 | `AuraAppModel.swift:57-130`, `AuraAppModel_Runtime.swift:341-356`, `AuraAppModel_ProductState.swift:318-356` |
| Localization | `AuraCopy` static table, ~82 keys, EN/TR inline per key; plus four *separate* ad-hoc TR mapping mechanisms for runtime-produced English strings | `ProductUIState.swift:297-736`, `AuraAppModel_ProductState.swift:20-132` |
| A11y contract | `AuraAccessibilityID` enum; identifiers unique, never localized, capability-ID-derived; pinned by dedicated tests; live AppleScript acceptance driver addresses controls by AXIdentifier | `AuraAccessibilityIdentifiers.swift:8-82`, `Tests/AURAIntegrationTests/AuraAccessibilityIdentifierTests.swift:7-14`, `scripts/sp011-acceptance/aura-drive.applescript` |
| Audio signal | No per-frame level event exists; raw 16 kHz mono samples are reachable via `AudioFrameEvent` + `AuraAudio.frame(sequenceIndex:)`; VAD already computes RMS→dBFS internally | `AudioEventPayloads_AudioFrameEvent.swift:4-28`, `AuraAudio_Capture.swift:132-146`, `VoiceActivityDetector.swift:114-115` |
| LLM streaming | None to the UI: assistant replies arrive as one atomic `ResponsePlanEvent.summary` (Ollama client has no streaming; Claude/Codex adapters have internal event streams that feed the task pipeline, not the transcript) | `IntentDispatchCoordinator.swift:183`, `AuraAppModel_Runtime.swift:264-274` |
| Task progress | Rich `TaskProgressEvent` (percent, step description) is already on the bus; the app model currently uses it only to trigger a snapshot refresh | `TaskEventPayloads.swift:53-80`, `AuraAppModel_Runtime.swift:240-252` |
| Latency | `LatencyPercentileSummary` (p50/p95/p99, sample counts, budgets, mock flag) is pull-only via `refreshLatencySummaries()`; no time-series history | `PerformanceSampler.swift:91-264`, `AuraAppModel_Interaction.swift:89-91` |
| Tests pinning UI | Reducer determinism, view construction for every surface, Dynamic-Type-only typography, copy table guard (>150 keys floor, real Turkish required), emergency-control localization (F-005), confirmation fail-closed paths, integration-row remediation matrix | `R9ProductUIStateTests.swift`, `AuraCopyTableGuardTests` etc. (details in [06](06-cross-cutting-constraints.md)) |
| Toolchain | macOS 27+ / Swift 6.4 / Xcode 27 beta 5; tests only via `./scripts/aura-test.sh` (22 targets); Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`) already in use | `TOOLCHAIN.md`, `scripts/aura-test.sh:103-110` |
| Docs | No dedicated UI/design spec exists today; closest is ADR-029 (SwiftUI runtime shell) | `docs/decisions/ADR-029-swiftui-runtime-shell.md` |

## 3. Guiding principles (non-negotiable, derived from existing code + AGENTS.md)

1. **Tokens first.** Every new value goes through `AuraDesign`; no ad-hoc padding/color/font literals in views (`AuraDesign.swift:3-13`).
2. **Glass where earned.** Liquid Glass stays on floating, interactive, state-tinted chrome — never behind dense body text (`AuraDesign.swift:57-61`).
3. **Accessibility identifiers are API.** New controls get `AuraAccessibilityID` entries: unique, never localized, derived from stable IDs (`AuraAccessibilityIdentifiers.swift:8-15`).
4. **Real Turkish copy or nothing.** New user-facing strings enter the `AuraCopy` table with genuine Turkish translations; hardcoded English literals in views are a High-severity regression (F-005 class).
5. **Fail-closed confirmations survive every layout.** All five fail-closed paths (Settings close, window close, emergency stop, expiry, supersession) must keep working in any redesign (`AuraAppModel_Settings.swift:146-149`, `AuraAppModel_Interaction.swift:199-243`, `AuraAppModel_Runtime.swift:206-225`).
6. **Honest states only.** No invented success; "no samples" never renders as zero; mock-derived data stays labeled (`AuraMenuView_Tabs.swift:570-575,586`).
7. **Relative typography only.** Fixed point sizes are a WCAG 1.4.4 failure and are pinned out by test (`R9ProductUIStateTests.swift:435-450`).
8. **No UI automation when a native integration exists** (`AGENTS.md:25-36`); the AppleScript acceptance driver is the only live UI driver.

## 4. The five axes

| # | Document | Axis | Headline outcome | Priority |
| --- | --- | --- | --- | --- |
| 1 | [01-conversation-experience.md](01-conversation-experience.md) | Conversation experience | Markdown answers, live draft bubble for partial transcripts, auto-scroll, thinking indicator, mic-level waveform while listening | **P1 — start here** |
| 2 | [02-information-architecture.md](02-information-architecture.md) | Information architecture | Sidebar navigation replacing tab pills; latency sparklines; task progress rings driven by events already on the bus | P2 |
| 3 | [03-live-status-feedback.md](03-live-status-feedback.md) | Live status feedback | Animated status transitions, speaking indicator from real TTS events, motion that respects Reduce Motion | P2 |
| 4 | [04-onboarding-redesign.md](04-onboarding-redesign.md) | Onboarding redesign | Visual 13-step flow; inline TR/EN ternaries migrated into `AuraCopy` | P3 |
| 5 | [05-settings-restructure.md](05-settings-restructure.md) | Settings restructure | Category-navigable Settings while preserving the pinned confirmation-card behavior | P3 |

Cross-cutting constraints and the verification contract that binds all five: [06-cross-cutting-constraints.md](06-cross-cutting-constraints.md).
Sequencing, per-phase deliverables, acceptance gates, and risk register: [07-rollout.md](07-rollout.md).

## 5. Recommended sequencing (summary)

```text
UI-0 Identity foundation          (tokens v2 + Iris icon + motion/sound vocabulary; icon is first landable item)
UI-1 Conversation experience      (incl. shared AudioLevelBridge prerequisite; Orb + ambient canvas)
UI-2 Live status feedback         (reuses AudioLevelBridge + TTS events)
UI-3 Information architecture     (sidebar, telemetry deck, task rings, ⌘K palette)
UI-4 Settings restructure
UI-5 Onboarding redesign          (Iris signature moment)
```

Rationale for identity-first: the token/icon/motion/sound vocabulary in Volume I is what every experience phase consumes — landing it first means each UI-1…5 phase inherits a finished design language instead of inventing one ad hoc. The icon ([10-icon-identity.md](10-icon-identity.md)) is the highest-visibility, zero-behavior-risk item in the entire plan and is recommended to land first as the identity proof-of-concept. Rationale for conversation-first within Volume II: it is where users spend most of their time, it is the axis with the strongest test coverage protecting it (lowest regression risk), and its metering bridge is a prerequisite the status-feedback axis reuses. Full reasoning and per-phase gates in [07-rollout.md](07-rollout.md).

## 6. Governance

- Each implemented axis gets its own ADR (`docs/decisions/ADR-NNN-*.md`, template per `ADR_TEMPLATE.md`) covering the visual-language decision and any new event/bridge design.
- Each phase appends evidence to `ledger/PROJECT_LEDGER.md` (append-only) and rewrites `ledger/CURRENT_STATE.md` atomically.
- Nothing is committed or pushed without an explicit go-ahead in that turn; commits go to `origin/main` with explicit file paths (`AGENTS.md:38-46`, established workflow).
- The `UI-` phase prefix is deliberately separate from the master roadmap's numeric phases to avoid the numbering collisions documented in project history.
