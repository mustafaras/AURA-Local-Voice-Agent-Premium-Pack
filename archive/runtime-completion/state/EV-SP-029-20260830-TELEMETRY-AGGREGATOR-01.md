# EV-SP-029-20260830-TELEMETRY-AGGREGATOR-01

**Evidence ID:** EV-SP-029-20260830-TELEMETRY-AGGREGATOR-01
**Track:** SP-029 / R12 / OPEN-13
**Type:** Source/build/test — opt-in content-free aggregate telemetry engine (Procedure step 2)
**Commit:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` (`main`; `HEAD == origin/main == 37805cb0`; working tree dirty with uncommitted SP-028/SP-029 source and control-plane projections)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6, Git 2.54.0
**Session:** AURA-SP-029-BETA-CONTRACT-20260829
**Authority:** edit/test/state only. No telemetry transport, network egress, cohort enrollment, consent collection from a participant, SLO measurement for a beta window, release-candidate approval, install, launch, TCC mutation, commit, push, or merge was performed. This evidence records a **default-off, content-free, no-transport aggregate engine** — it does not activate telemetry by itself.

## Purpose

Implement SP-029 **Procedure step 2** — "Implement explicit opt-in content-free aggregates only" — which was explicitly recorded as missing in `EV-SP-029-20260829-BETA-CONTRACT-BLOCKED-01` ("No telemetry code was implemented"). This closes the in-scope, within-authority implementation gap while preserving the prompt's hard constraint that *no telemetry is activated by this prompt alone*.

## What was implemented

### Configuration schema (`AuraConfig/ConfigurationTypes.swift`)
- `telemetry.aggregateOptInEnabled` — user opt-in (default `false`), reversible, allowed in `.userSettings`/`.sessionOverrides` only (never machine-policy or project-constrained open).
- `telemetry.aggregateRetentionDays` — retention window (default 90, bounded 1...365, `mayNotDecrease`).
- Existing `privacy.rawTelemetryEnabled` remains `immutable false` — raw telemetry is forbidden by the local-first privacy boundary.

### Store schema (`AuraStore/AuraDatabase_MigrationsAndBinding.swift`)
- New `telemetry_aggregates` table: `(id, day, field, bucket, count, UNIQUE(day, field, bucket))` indexed on `(day, field)`.
- Migration recorded as `v1_8_0_lifecycle_telemetry`.

### Content-free payload types (`AuraLifecycle/TelemetryEventPayloads.swift`)
- `TelemetrySessionOutcomeBucket`, `TelemetryConfirmationOutcomeBucket`, `TelemetryRecoveryOutcomeBucket`, `TelemetryResourcePressureClass` — closed string enums (counts only).
- `TelemetryLatencySample` — monotonic ms input (bucketed, never stored as-is).
- `TelemetryAggregateEvent` — event carrying only `field`, `bucket`, `count`, `day`.

### Runtime engine (`AuraLifecycle/TelemetryAggregator.swift`)
- Actor, fail-closed by construction: `isOptInEnabled()` defaults `false`; every `bump`/`record` path is a no-op unless opt-in is enabled.
- Recording: `bumpSessionOutcome`, `bumpConfirmationOutcome`, `bumpRecoveryOutcome`, `bumpResourcePressure`, `recordLatencyMilliseconds` — each increments the per-day/per-field/per-bucket counter via `INSERT ... ON CONFLICT DO UPDATE`.
- Latency is bucketed into coarse stable bands (`p00_lt100ms`, `p25_lt250ms`, `p50_lt500ms`, `p75_lt1000ms`, `p99_ge1000ms`) — no exact value or timestamp.
- `disableAndPurge()` — turns consent off and deletes all aggregate rows (telemetry-off / consent withdrawal path).
- `purgeRetainedRows(keepWithinDays:)` — retention cleanup; 0 deletes everything.
- **No transport**: no network, no file egress, no remote sink. Rows stay local only.
- All recording failures are non-fatal and degrade only the `telemetry.aggregator` health component — they never surface to the user or break the host loop.

### Kernel wiring (`AURA/AuraKernel.swift`, `AURA/AuraKernel_Construction.swift`)
- `telemetryAggregator` property added; constructed in `constructLifecycleSubsystems` with `configurationEngine`, `store`, `eventBus`, `healthRegistry`; health `recordReady("telemetry.aggregator", "... default off, no transport")`.

## Verification

- `swift build --build-path /tmp/aura-build` → **Build complete** (only pre-existing warnings).
- `swift test --filter AuraLifecycleTests --build-path /tmp/aura-build` → **48 tests in 10 suites passed** (39 prior lifecycle tests + 9 new `TelemetryAggregatorTests`).
- New tests confirm: opt-in defaults off; no recording when off; opt-in toggle reversible; session-outcome counts bucket correctly; confirmation/recovery outcomes record; latency buckets (not raw); `disableAndPurge` clears all rows; retention purge removes old days; config schema defaults to consent off.
- Full suite `swift test --build-path /tmp/aura-build` → **89 test suites, 0 failed**, including all telemetry tests.

## Honest limitations

- This is a **deterministic engine and schema**, not a live beta run. No cohort was enrolled, no participant consent was collected, no telemetry was transmitted, and no SLO was measured against a beta window.
- `beta-readiness.json` remains `readiness_status: blocked`; `telemetry.enabled: false`; authority `beta_enrollment/telemetry_activation/release` all `false`.
- The engine is dormant by default and requires an explicit user opt-in (and, for any outbound aggregate, a separately authorized transport that does not yet exist) to have any effect.

## Falsifiers

- Any claim that telemetry was transmitted, a participant was consented, a cohort was enrolled, an SLO was measured for a live beta, or the release candidate was approved would falsify the SP-029 blocked scope.
- Any claim that raw audio, screenshots, prompts, model outputs, secrets, tokens, or private identifiers are (or could be) collected by `TelemetryAggregator` would be false by construction.

## Residual / next action

- `RISK-NO-INDEPENDENT-BETA-EVIDENCE`, `RISK-NO-BETA-CONSENT-BOUNDARY`, and `RISK-NO-RC-EVIDENCE-PACKAGE` remain open.
- SP-029 remains `blocked` for its approval/activation scope. SP-030 must NOT start until explicit owner approval grants beta enrollment, telemetry activation, and RC authority.
