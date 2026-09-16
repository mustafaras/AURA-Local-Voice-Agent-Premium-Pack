# UI-3: Information Architecture

**Priority:** P2 (third implementation phase, sequenced as UI-3).
**Surfaces touched:** `AuraMenuView_Content.swift` (body, header, tab picker), `AuraMenuView_Tabs.swift` (all six tabs), `AuraMenuBarPanel.swift`, `AuraAppModel_Runtime.swift` / `_ProductState.swift` (event wiring), `AuraDesign.swift` (new chart/ring components).
**Depends on:** nothing hard; benefits from UI-1's design-system additions but is independent.

---

## 1. Current state (verified)

- Six destinations render as discrete pill buttons in a glass container across the top of a fixed-min-size window (`AuraMenuView_Content.swift:131-144, 30`); the comment records why pills replaced a segmented control (Turkish labels overflow).
- The non-conversation tabs scroll as whole lists of `GroupBox` cards (`AuraMenuView_Content.swift:20-26`); several tabs (Privacy, Recovery) are long, dense stacks.
- Latency summaries render as text lines (`p50 … p95 … p99 …`) behind a manual refresh button (`AuraMenuView_Tabs.swift:567-594`); data is pull-only via `refreshLatencySummaries()` (`AuraAppModel_Interaction.swift:89-91`); there is no history — `PerformanceSampler` returns percentile summaries, not samples (`PerformanceSampler.swift:230-245`).
- Task rows render percent progress as a linear `ProgressView` plus a step-count text line (`AuraMenuView_Tabs.swift:22-32`). Rich `TaskProgressEvent` data (percent, `currentStepDescription`) already flows on the bus but the app model only uses it to trigger `refreshProductSnapshots()` (`AuraAppModel_Runtime.swift:240-252`).
- Capability and integration rows are text-dense GroupBoxes with color-coded state strings (`AuraMenuView_Tabs.swift:106-151, 206-350`).

## 2. Goals

1. Navigation scales: a sidebar gives each section a stable home, removes the Turkish-label width pressure, and matches macOS app conventions.
2. Performance data becomes glanceable (sparklines) without weakening the honesty rules.
3. Durable tasks read as living progress, using data already on the bus.
4. Status-bearing rows (capabilities, integrations, backends) scan visually before they are read.

## 3. Non-goals

- Merging surfaces: the menu bar panel stays a compact summary (its role is documented at `AuraMenuBarPanel.swift:4-10`) and Settings stays a separate scene.
- Changing any remediation action logic — the integration-row remediation matrix is pinned test-for-test (`IntegrationRowRemediationTests.swift`); only its presentation may change.
- Time-series persistence of latency samples (new storage is out of scope; see §4.3 for the in-memory approach).

## 4. Proposed design

### 4.1 Sidebar navigation

- Replace the pill tab bar with `NavigationSplitView` (two-column): a `List` sidebar of the six `AuraProductTab` destinations (icon + full label, untruncated Turkish included), content pane showing the selected tab.
- **Contract preservation:** `AuraProductTab.allCases`, raw values, and `copy(tab.copyKey)` labels stay unchanged; each sidebar row keeps `.accessibilityIdentifier(AuraAccessibilityID.tab(tab.rawValue))` and the `.isSelected` trait pattern (`AuraMenuView_Content.swift:170-175`) so `AuraAccessibilityIdentifierTests` and the AppleScript driver continue to address tabs identically.
- **State:** selection continues to route through `model.selectTab(_:)` → the `AuraProductUIState` reducer (`ProductUIState.swift:261-292`) — the reducer, not the view, remains the source of truth. Sidebar visibility (`.navigationSplitViewVisibility`) defaults to visible; collapsed-by-default is a user setting only if needed later.
- The conversation tab keeps its special scroll behavior (transcript owns the window, composer anchored — `AuraMenuView_Content.swift:12-17` comment) inside the content pane.
- Window min size revisited: sidebar costs ~200 pt width; raise `minWidth` to ~820 and keep `.defaultSize` coherent with it (`AURA.swift:22-23`, `AuraMenuView_Content.swift:30`).

### 4.2 Task progress rings and richer cards

- Subscribe to `TaskProgressEvent` in `AuraAppModel` and store the live progress fields (percent, step description) on the task row model instead of discarding them (`AuraAppModel_Runtime.swift:248-252`); snapshot refresh remains the fallback convergence.
- Replace the linear `ProgressView` with a compact progress ring (percent in the center) beside the objective; keep the linear bar as the Dynamic-Type / assistive fallback (ring is `accessibilityHidden`; the percent is announced in the existing progress label, `AuraMenuView_Tabs.swift:22-24`).
- State color mapping moves into `AuraDesign` (one `taskStateColor(_:)` beside `statusColor`) so task, capability, and integration states cannot disagree (`AuraDesign.swift:70-84` pattern).

### 4.3 Latency sparklines

- Add an in-memory rolling history to the app model: each `refreshLatencySummaries()` result is appended (kind, timestamp, p50/p95/p99) with a bounded ring buffer (e.g. last 60 pulls). The history lives only in the UI layer; nothing persists.
- Optionally deepen the signal: a new `LatencySampleEvent` emitted by `PerformanceSampler` per measurement (it already has every field needed, `PerformanceSampler.swift:91-123`) would make the history real instead of pull-cadence-shaped. This touches `AuraCore` and is flagged as a decision point for the phase ADR — default plan keeps it UI-only first.
- Render per kind as a 40–60 pt Swift Charts sparkline (line + budget threshold mark) beside the existing text summary; the text summary stays (it is what the honesty rules and tests lean on, including the `isMockDerived` label, `AuraMenuView_Tabs.swift:583-586`). "No samples" still renders as the honest empty-state text, never a zero line (`AuraMenuView_Tabs.swift:570-575`).
- Keep the manual refresh button and add an automatic refresh on tab appear so the chart is alive when visited.

### 4.4 Scannable status rows

- Introduce an `AuraStatusRow` design-system component: leading SF Symbol in a status-tinted disc, title + description, trailing state badge — replacing the HStack-of-plain-text heads in capabilities, backends, and integrations (`AuraMenuView_Tabs.swift:118-145, 179-196, 209-220`).
- The badge keeps the color+word pairing (never color alone, matching the `AuraStatusPill` discipline, `AuraDesign.swift:86-90`) and preserves every existing accessibility identifier and combined label on those rows.

## 5. Files to touch

| File | Change |
| --- | --- |
| `AuraMenuView_Content.swift` | `NavigationSplitView` body; sidebar rows; content-pane routing |
| `AuraMenuView_Tabs.swift` | `AuraStatusRow` adoption; task rings; latency sparklines; section headers |
| `AuraDesign.swift` | `AuraStatusRow`, `AuraProgressRing`, `AuraSparkline`; `taskStateColor(_:)` |
| `AuraAppModel_Runtime.swift` / `_ProductState.swift` | `TaskProgressEvent` field capture; latency history ring buffer |
| `AURA.swift` | Window min/default size adjustments |
| `ProductUIState.swift` | Any new copy keys (e.g. `tasks.liveProgress`, chart a11y descriptions) |
| `AuraAccessibilityIdentifiers.swift` | No identifier changes required; additions only if new addressable controls appear |

## 6. Testing and acceptance

- `R9ProductUIStateTests` reducer tests pin tab selection through the reducer — they must pass unchanged; view-construction suite extended to the sidebar and new components.
- `AuraAccessibilityIdentifierTests` tab-coverage assertions must pass unchanged (identifiers preserved by design, §4.1).
- `IntegrationRowRemediationTests` must pass unchanged (presentation-only change).
- New unit tests: latency history ring buffer (bounded, ordered), task progress mapping from `TaskProgressEvent`.
- Live acceptance via the AppleScript driver: tab navigation, integration connect flows, transcript reads.
- Full suite via `./scripts/aura-test.sh`, rerun 2–3×.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Sidebar eats horizontal space in the 460-pt default window | Raise min width; sidebar column fixed ~200 pt; conversation pane keeps priority |
| Driver regressions if AX hierarchy changes under `NavigationSplitView` | Identifiers preserved; run the SP-011 driver legs live before closing the phase |
| Swift Charts adds a framework dependency | Charts is a system framework on the pinned SDK (macOS 27); verify link in `Package.swift` during phase ADR |
| Latency history misread as time-series truth | In-app-only, bounded, labeled with refresh cadence; ADR decision recorded if `LatencySampleEvent` is added |
