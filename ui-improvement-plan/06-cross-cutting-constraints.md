# Cross-Cutting Constraints and Verification Contract

Applies to every phase in this plan. These are the contracts the existing code and test suites already enforce; each phase's implementation must satisfy them as a whole.

---

## 1. Accessibility identifier contract

- Source of truth: `AuraAccessibilityIdentifiers.swift:8-82` (`AuraAccessibilityID` enum).
- Rules (pinned by `AuraAccessibilityIdentifierTests.swift:7-14`): identifiers are **unique**, **never localized**, and derived from stable IDs (tab raw values, capability IDs, permission anchors). A `copy(...)` string used as an identifier is the named failure mode.
- The live acceptance driver (`scripts/sp011-acceptance/aura-drive.applescript`) addresses controls exclusively by AXIdentifier — every identifier is also automation API. Any view restructure must preserve identifier attachment points or the driver's legs break silently.
- New controls: add to `AuraAccessibilityID` with the `aura.<area>.<control>` scheme; extend the uniqueness test.

## 2. Copy governance

- All user-facing strings go through `AuraCopy` (`ProductUIState.swift:297-736`): a static EN/TR table with fallback-to-English, then fallback-to-key.
- `AuraCopyTableGuardTests` enforces: table size above its 150-key floor, every key resolving in both languages, genuine translation except the two-entry identical-by-design allowlist (`app.name`, `confirmation.riskPrefix`), and non-stale allowlist membership.
- Hardcoded English literals in views are the F-005 regression class — `EmergencyControlLocalizationTests` exists precisely because such literals once shipped (`AuraAccessibilityIdentifierTests.swift:106-147`).
- **Known debt this plan pays down:** four separate ad-hoc TR mapping mechanisms exist outside `AuraCopy` — `AuraAppStatus.title(for:)`, `displayStatusDetail`, `localizedReason`/`localizedOperationMessage`, and ~16 inline view ternaries (`AuraAppModel.swift:22-33,145-169`; `AuraAppModel_ProductState.swift:20-132,610-625`). UI-5 migrates the onboarding ternaries; the runtime-string mappers are a separate, optional refactor (they map *runtime-produced* English keys, not view copy, and are covered by their own tests).

## 3. Typography and Dynamic Type

- `AuraDesign.Typography` uses only relative text styles; `R9ProductUIStateTests.swift:435-450` fails on any fixed `Font.system(size:)`. All new components inherit this rule.
- Bubble max width (420 pt, `AuraDesign.swift:203`) is the only measured layout constant in the transcript; keep it tokenized if UI-1 touches it.

## 4. Confirmation fail-closed paths

Five paths, all currently pinned, all must survive every layout change:

| Path | Location |
| --- | --- |
| Settings window close denies pending challenge | `AuraMenuView.swift:425`, `AuraAppModel_Interaction.swift:240-243` |
| Main window close dismisses | `AURA.swift:18-20`, `AuraAppModel_Settings.swift:146-149` |
| Emergency stop cancels with `.cancelled` | `AuraAppModel_Interaction.swift:199-207` |
| 60 s expiry timer resolves `.expired` | `AuraAppModel_Runtime.swift:206-225` |
| Supersession of an older challenge | same |

- The Settings confirmation card's inline-first-row + scroll-into-view behavior carries live incident evidence (`EV-SP-030-20260831-R11-LIVE-GATE-02`, `AuraMenuView.swift:305-328`) — UI-4 must live-test it again.

## 5. Honesty rules (product-correct, not just style)

- Degraded/mock-derived data stays visibly labeled (`recovery.mockDerived`, `AuraMenuView_Tabs.swift:583-586`).
- Empty data renders honest empty states, never zeros ("no samples" rule, `AuraMenuView_Tabs.swift:570-575`).
- No invented success anywhere — onboarding stages state what is real (`AuraMenuView.swift:216-276` explanations follow this); animation plan (UI-2) renders nothing synthetic.
- Deletion receipts prove deletion without preserving content, and stay fully VoiceOver-readable (`SP019MemoryUIStateTests`, receipt label comment `AuraMenuView_Tabs.swift:485-493`).

## 6. Privacy posture

- New UI signals must not widen the data surface: the `AudioLevelBridge` (UI-1) publishes a scalar level only, in-session only, no persistence, no logging — mirroring the existing zero-retention defaults (`AuraAudioFrameEvent` deliberately omits sample data, `AudioEventPayloads_AudioFrameEvent.swift:4-28`).
- Transient inputs (VS Code secret, mail approval address) are never persisted or logged (`AuraAppModel.swift:93-94,128-130`); any new text field follows the same rule.
- Latency history (UI-3) is in-memory only.

## 7. Verification contract (every phase)

1. **Build + targeted new tests**, then the full suite via `./scripts/aura-test.sh` (the only supported test path in this toolchain — `swift test` is broken here, `TOOLCHAIN.md`), each bundle rerun 2–3× to catch flakiness; redirect to a file and grep (`grep -c '^PASSED:'`, `grep 'Failed bundles'`) — never pipe through `tail`.
2. **Test-target coverage check:** confirm the 22-target loop in `scripts/aura-test.sh:103-110` still matches `Package.swift`'s test targets (the loop is hand-maintained; a new target can silently miss it).
3. **Live acceptance** through the AppleScript driver for any touched interactive surface, recorded in the ledger.
4. **ADR** per phase (`docs/decisions/ADR-NNN-*.md`, `ADR_TEMPLATE.md` fields: Status/Date/Owners/Supersedes… Context, Decision, Alternatives, Security & privacy impact, Operational impact, Migration, Validation evidence, Consequences).
5. **Ledger discipline:** append-only `PROJECT_LEDGER.md` entry with evidence; atomic `CURRENT_STATE.md` rewrite; no commit/push without an explicit go-ahead in that turn (`AGENTS.md:38-46`).

## 8. Out-of-scope for this plan (explicit)

- Assistant token streaming (backend plumbing; blocked on Ollama client streaming).
- Localizable-string extraction from runtime reason keys (the `localizedReason` mechanism) — works today, tested, only worth touching if the runtime starts producing new reason strings.
- Multi-window or iPad-adjacent layout work.
- Any change to `AuraProductUIState` persistence schema (additive fields only, never a breaking `aura.ui.state` change).
