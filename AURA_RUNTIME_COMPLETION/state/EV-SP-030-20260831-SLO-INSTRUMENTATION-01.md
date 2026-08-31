# EV-SP-030-20260831-SLO-INSTRUMENTATION-01

**Evidence ID:** EV-SP-030-20260831-SLO-INSTRUMENTATION-01
**Track:** SP-030 / R12 / OPEN-13 — `ptt_ack` and `stt_partial` SLO instrumentation
**Type:** Implementation + defect correction — instrumentation exists, **no sample has been taken**
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty)
**Session:** AURA-SP-030-SLO-INSTRUMENTATION-20260831

## Why this record exists

The instrumentation described below was written on **2026-08-30** and never
recorded. `SECOND_PASS_STATE.json.last_evidence_ids` ended at
`EV-SP-030-20260830-A11Y-COVERAGE-03` / `-RECORD-INTEGRITY-01`, so for one
session the repository contained working SLO instrumentation that no evidence
file, index row, ledger entry or risk-register line mentioned. A record that
omits work does not merely lag — it misstates what the tree does. This closes
that gap and records one defect found while doing so.

Written non-contemporaneously for the 2026-08-30 portion. Every claim below was
re-verified against the working tree on 2026-08-31 rather than carried forward
from the prior session's summary.

## What did not exist before

R12's SLO contract names five metrics. Two of them — `ptt_ack`
(`push_to_talk_acknowledgement_ms`) and `stt_partial` (`first_stt_partial_ms`) —
had **no readable source in the process at all**, so they could not have been
measured even with the owner present and the app running. `stt_partial` was the
sharper case: `STTPipeline` had been computing `firstPartialLatencySeconds`
correctly for some time, but the value never left the pipeline's private
`metrics` struct. The number existed and was unreachable.

Separately, `SystemHealthSnapshot` reported only a median and a worst case. An
SLO contract asking for p50/p95/p99 cannot be satisfied from those two figures.

## What was added

| Site | Change |
|---|---|
| `Sources/AuraCore/AudioEventPayloads_LatencyMeasuredEvent.swift` | Two new `Kind` cases: `pushToTalkAck`, `sttFirstPartial`. |
| `Sources/AuraCore/PerformanceSampler.swift` | `LatencyPercentileSummary` + `percentileSummaries()` — p50/p95/p99, max, sample count, budget breaches, per kind, in milliseconds. |
| `Sources/AuraSTT/STTPipeline.swift` | Emits the already-measured first-partial latency as a `sttFirstPartial` sample. |
| `Sources/AURA/AuraAppModel_Interaction.swift` | `pushToTalk()` measures from the **button press** to the listening acknowledgement. |
| `Sources/AURA/AuraKernel_RuntimeAPI.swift` | `recordPushToTalkAcknowledgement(seconds:)` and `latencyPercentileSummaries()`. |
| `Sources/AURA/AuraMenuView.swift` | Launch-at-login toggle in Settings; latency readout in Recovery. |
| `Tests/AuraCoreTests/LatencyPercentileSummaryTests.swift` | 6 tests (new file, 2026-08-30). |

Two honesty properties are enforced in the aggregation rather than left to the
reader, and both are pinned by tests:

- **A kind with no samples is omitted, never reported as zero.** A zero would
  read as *"measured, and fast"* — the exact opposite of *"never measured"*.
  This matters immediately: both new kinds have zero samples right now.
- **A summary derived entirely from a mock engine is labelled `isMockDerived`.**
  `LatencyMeasuredEvent` resolves this from
  `turnContext.backendIDs.usesMockBackend`, so the STT pipeline does not have to
  know, and one real sample clears the flag.

`ptt_ack` is deliberately a **distinct kind from `wakeToAck`**, and the type
carries the reason in its own doc comment. `wakeToAck` fires when a response
plan arrives — after NLU, policy evaluation and a model round trip — so
substituting it for `ptt_ack` would overstate the acknowledgement by whole
seconds. Both budgets (0.5 s for `ptt_ack`, 1.0 s for `stt_partial`) are
**reporting references only**; the SLO contract asserts no target and none is
claimed here.

## Defect found and fixed on 2026-08-31: `ptt_ack` was contaminated

Reviewing the 2026-08-30 instrumentation before recording it surfaced a real
defect in it.

`pushToTalk()` starts its clock at the button press, then — if voice permissions
are not yet granted — raises the OS permission prompt, awaits it, starts the
speech engine, and only then activates push-to-talk and records the elapsed
time. The `guard permissions.speechReady else { return }` after the prompt
returns early **only on denial**. A user who **granted** access fell through to
the acknowledgement and had the modal dialog's *human reaction time* — plus
one-time speech-engine startup — recorded as machine latency.

The code comment at that site asserted the opposite invariant, in these words:

> *"A permission prompt or a failure is not an acknowledgement, and including
> those turns would silently mix a human reaction time into a machine latency
> metric."*

That was the intent. The control flow did not implement it on the grant path.

This was not theoretical. `ptt_ack` currently holds **zero samples**, and the
first live measurement is scheduled with the owner present on a machine whose
TCC state may well require the prompt. **The very first `ptt_ack` sample ever
taken would have been the contaminated one**, and across a handful of samples a
single multi-second outlier dominates p95 and p99 outright.

*Fixed* by moving the decision out of control flow into a named, pure,
`nonisolated` seam —
`AuraAppModel.pushToTalkAckSample(pressedAt:acknowledgedAt:promptedForPermissions:)`
— returning `Double?`, where `nil` means *"this turn is not a sample"*. A turn
that raised the prompt is excluded outright rather than re-baselined: its window
also contains one-time engine startup, so it is not a representative turn even
after discounting the human.

### The fix is falsifiable, and was falsified

`Tests/AURAIntegrationTests/PushToTalkAckSampleTests.swift` (4 tests, new). The
suite was verified to be non-vacuous by neutering the guard and re-running:

| Test | Guard present | Guard neutered |
|---|---|---|
| a turn that raised the permission prompt is not a sample | pass | **fail** |
| exclusion depends on the prompt, not on how fast the turn was | pass | **fail** |
| an ordinary turn is a sample, reported in seconds | pass | pass |
| ptt_ack is a distinct kind and is never conflated with wakeToAck | pass | pass |

Exactly the two exclusion tests fail while the two control tests continue to
pass, which is what separates a test that pins the invariant from one that
merely runs. The source file was restored from a checksummed copy afterwards and
the guard re-verified in place.

## Measurement status — nothing is measured

| SLO | Instrumentation | Samples | Status |
|---|---|---|---|
| `ptt_ack` | present, contamination fixed | **0** | `not_measured` |
| `stt_partial` | present | **0** | `not_measured` |

**No SLO moved from `not_measured` as a result of this work.** An instrumented
metric with no samples is not a measured metric, and `beta-readiness.json` is
deliberately not touched by this record.

`ptt_ack` is obtainable by automation. `stt_partial` is **not**: it requires a
real first partial transcript, and automation does not produce sound at the
microphone. It needs the owner to speak. Below roughly 20 samples, p95/p99 must
not be written at all — record *insufficient samples* instead, because a p99
over 5 points is an arithmetic result, not a measurement.

## Known limitation in the mock labelling

`recordPushToTalkAcknowledgement(seconds:)` passes `isMockEngine: false`
explicitly, because at button-press time no turn context exists yet to resolve
it from. That is defensible — `ptt_ack` measures the UI-to-kernel activation
leg, not a model backend — but it is an **assertion, not an observation**, and
it would be wrong if the whole runtime were running mock. `sttFirstPartial`
does not share this: it passes `turnContext`, so `usesMockBackend` resolves
normally, falling back to `false` only when the context is absent.

## Verification

Run on 2026-08-31, outside the agent sandbox (`swift build` and `aura-test.sh`
do not run inside it):

| Check | Result |
|---|---|
| `./scripts/aura-test.sh /tmp/aurabuild` | **1317 tests / 86 suites / 22 bundles, 0 failures** (1313 / 85 before this record's fix) |
| `swift test --filter PushToTalkAckSampleTests` | 4 tests, 1 suite, passed |
| Same, with the guard neutered | 2 of 4 failed, as intended |

Measurement class: `deterministic_harness`. No live microphone, no live turn, no
telemetry enabled or transmitted.

## What this does NOT change

No SLO was measured. No scenario was re-run. No sign-off was obtained. No gate
moved. SP-030's four human-dependent blockers are untouched, and SP-031 must not
start. `accessibility_localization` stays REFUSED. The launch-at-login toggle
listed above **does not function** — it is the subject of a separate finding,
`EV-SP-030-20260831-R11-POLICY-BLOCK-01`; recording it as a delivered control
would be false.

## Falsifiers

Any of the following would falsify this record: that `ptt_ack` or `stt_partial`
holds a sample; that either SLO is measured, or that a percentile has been
computed from real data; that the permission-prompt turn is still recorded as a
`ptt_ack` sample; that `wakeToAck` may be reported in place of `ptt_ack`; that
the 0.5 s / 1.0 s budgets constitute asserted SLO targets; that the
launch-at-login toggle works; or that any SP-030 gate advanced because of this
work.
