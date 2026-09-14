# ADR-061: UI-3 Information Architecture — Sidebar, Progress Rings, Telemetry Deck, and Command Palette

- Status: Accepted — local UI-3 delivery completed; UI-4 awaiting separate approval
- Date: 2026-09-14
- Owners: UI track (UI-3)
- Supersedes: none
- Superseded by: —

## Context

UI-2 left the product panel on a horizontal tab strip. Durable task progress
events were subscribed to but their payload was discarded, and Recovery showed
latency summaries without a bounded visual history or explicit provenance. The
phase also needed one keyboard-addressable command surface without creating a
second confirmation path. UI-3's named risk was navigation churn breaking the
AppleScript driver before a visual regression was obvious.

## Decision

1. **Sidebar navigation (G3-1).** Replace the pill strip with a
   `NavigationSplitView` sidebar whose `List(selection:)` keeps the existing
   `AuraProductTab` raw values, reducer selection, and
   `AuraAccessibilityID.tab(tab.rawValue)` identifiers unchanged. Tagged
   buttons retain AXButton discovery and native arrow-key traversal.

2. **Payload-backed task rings (G3-2).** Consume the complete
   `TaskProgressEvent` payload in `AuraAppModel_Runtime.swift`, clamp malformed
   step counts defensively, and project the percent, current-step description,
   and timestamp into the matching published task status. `AuraProgressRing`
   renders that state directly; it has no timer or guessed target. The existing
   linear progress view remains the Dynamic-Type-friendly textual fallback.

3. **Honest telemetry (G3-3/G3-4).** Keep latency history view-local and
   in-memory, cap it at 60 pulled summaries per latency kind, and render the
   p50/p95/p99 deck with budget ticks, breach markers, bounded sparklines, and
   visible live/mock provenance. Recovery status and permission rows use
   `AuraStatusRow`. The added violet data-viz token is appearance-aware and is
   included in the existing text and graphical contrast tests.

4. **Static command palette (G3-5).** `AuraCommandPalette` is a fixed entry
   table: it has no fuzzy search, async discovery, persistence, or alternate
   command router. Existing model owners handle each action. The mutating
   Launch-at-Login action reaches the existing `setLaunchAtLogin` confirmation
   path; no second `AuraConfirmationCard` presentation site exists. Escape,
   Cancel, and the existing keyboard-cancel behavior dismiss fail-closed.
   Emergency Stop remains an immediate local safety stop/re-arm control, not an
   external destructive authorization.

5. **Verification boundary (G3-6/G3-7/G3-8).** The phase is considered locally
   complete only after the signed temporary bundle passes the full driver tour,
   the full 22-bundle suite passes twice, this ADR and both ledgers are current,
   and the continuity validator reports machine coherence. Commit, push, and
   local deployment require the owner's separate delivery approval; this
   decision still makes no hosted-CI, notarization, beta/RC, or release claim.

## Alternatives considered

- **Keep the pill strip and add a second navigation overlay:** rejected because
  it would preserve the driver-sensitive churn rather than establish one
  keyboard-traversable navigation owner.
- **Animate a guessed progress target:** rejected because the event payload is
  authoritative and an unknown target must not be presented as measured work.
- **Persist telemetry samples:** rejected because UI-3 requires a view-local
  ring buffer and no new persistence or privacy surface.
- **Let palette entries present their own confirmation card:** rejected because
  that would create a second destructive-action path and weaken the existing
  fail-closed contract.

## Security and privacy impact

No new remote transport, ambient-audio path, screenshot path, secret store, or
policy bypass was added. Telemetry history is memory-only and carries a visible
provenance label. Palette actions remain behind existing model ownership and
confirmation behavior; Escape and Cancel do not approve a pending request.

## Operational impact

The panel has a wider sidebar layout and a static ⌘K entry point. Recovery
latency visuals update from already-published summary events and discard history
with the view. The temporary acceptance bundle used for the driver was kept
outside `/Applications/AURA.app`; the installed app was not replaced.

## Migration and rollback

No data migration is required. The sidebar, palette, telemetry components, and
payload projection are independently revertible within the UI-3 source scope.
Removing the view-local history returns Recovery to summary-only rendering and
does not affect persisted state or event contracts.

## Validation evidence

- G3-1: `SEQ-0043` — identifier-preserving sidebar construction, focused suite,
  and live AXButton click plus real System Events arrow traversal across all six
  tabs.
- G3-2: `SEQ-0044` — payload mapping, malformed-count clamping, EventBus
  consumption, and ring construction tests; focused suite green.
- G3-3/G3-4: `SEQ-0045`/`SEQ-0046` — bounded history, deck mapping, provenance,
  status-row construction, and text/graphical contrast coverage.
- G3-5: `SEQ-0047` — static palette IDs, Escape/Cancel, existing confirmation
  hand-off, and single-card-site source contract.
- G3-6: `SEQ-0048` — signed temporary bundle, six-tab driver tour, telemetry
  deck discovery, real ⌘K palette discovery, confirmation appearance on the
  existing conversation path, and real Escape dismissal.
- G3-7: `SEQ-0049` — `./scripts/aura-test.sh` exited 0 twice, each run covered
  22/22 bundles with `Failed bundles: 0`; AURAIntegrationTests reported 191
  tests / 32 suites. `git diff --check`, `swift build`, and shell validation
  were also run. The repository Python governance suite reported 95 passing
  tests and one archived-state mismatch because the frozen runtime-completion
  state still claims a clean worktree while this explicitly uncommitted UI-3
  scope is dirty; the archive was not altered.
- G3-8: `SEQ-0050` — continuity validator returned
  `VALIDATOR: OK - machine coherent` with all eight gates passed and
  `phase_status: awaiting-approval`.

## Delivery receipt

After the phase gate, the owner explicitly authorized `push commit merge deploy`.
The implementation was committed as `ca753296b4d77f89a5d22dbc263b79735dfa98c1`
(`feat(ui): close UI-3 information architecture phase`) and pushed directly to
`origin/main`; remote parity was `0/0` and no open PR existed. A release bundle
was built at `/Users/m_ras/Library/Developer/AURA/deploy-ui3-20260914/AURA.app`,
signed with `AURA Stable Local Signing`, verified by the repository signature
script plus `codesign --verify --deep --strict`, and installed at
`/Applications/AURA.app`. The prior install was preserved at
`/Users/m_ras/Library/Developer/AURA/rollback/AURA.app-20260914-191651`.
Launch Services returned exit 0; the live driver found the window and reported
`Boşta`; AppleScript quit completed and no AURA process remained. This is local
stable-signing/deployment evidence only.

The post-delivery Python governance rerun executed 96 tests with 95 passes and
one archived-state error because the frozen runtime-completion `verified_head`
predates the UI-3 source/governance commits. The archive was not rewritten; the
dedicated UI continuity validator remained green.

## Consequences and residual risks

The driver now has one native sidebar traversal surface, task rings show real
event payloads, and Recovery exposes bounded, provenance-labelled telemetry.
The existing confirmation card remains structurally owned by its existing tab
call sites; on the live leg it is visible after the palette's mutating action
when the conversation tab is selected. That pre-existing placement is not
expanded in UI-3. Pull-cadence summaries are not sample-level telemetry, and
the temporary signed bundle is not device, hosted-CI, notarization, beta, or
release acceptance. UI-4 is not started; it requires a new explicit approval.
