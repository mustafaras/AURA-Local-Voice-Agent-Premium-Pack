# EV-SP-030-20260830-PRIVACY-REVIEW-01

**Evidence ID:** EV-SP-030-20260830-PRIVACY-REVIEW-01
**Track:** SP-030 / R12 / OPEN-13 — `privacy` sign-off
**Type:** Independent review (privacy / data retention / integrations) — **sign-off SUPPORTED**
**Commit:** `8b16142e508294ecce9fd64477ac35bb2c4c1393` (`main`; working tree dirty)
**Session:** AURA-SP-030-BETA-EVIDENCE-20260830

## Independence / COI

Reviewer: Claude Code (Opus 5). Every artifact reviewed below was authored by
`deepseek-v4-flash:0731-cloud` (SP-024 secret redaction and network egress, SP-028
support bundle, SP-029 telemetry aggregator). The reviewer authored **none** of
them and opened none of those commits — independent per ADR-050 §1.

**Disclosed:** the reviewer authored the `telemetry` entries in
`beta-readiness.json` (the *record*, not the mechanism), the SP-030 contract, the
F-001 remediation and the F-005 localization fix. It is **not** independent of
those and does not sign them off. LLM agent, **not a human privacy auditor**: no
DPIA, no legal review, no third-party assessment.

## Claims checked, and how

**1. Telemetry is genuinely content-free — VERIFIED.**
`TelemetryAggregator` persists only bucketed enum cases: `sessionOutcome`,
`confirmationOutcome`, `recoveryOutcome`, `resourcePressure`, and `latency`.
Latency is coarsened into bands (`p00_lt100ms`, `p25_lt250ms`, `p50_lt500ms`,
`p75_lt1000ms`) rather than stored raw. No case carries transcript, prompt, model
output, document, audio, screenshot, or token material.

**2. The latency `field` is not a content injection path — VERIFIED.**
`case latency(field: String, milliseconds: Double)` takes a `String`, which would
be a hole if callers supplied it. They do not: `recordLatencyMilliseconds`
constructs it internally as `Self.latencyFieldPrefix + "sample"`. No caller-supplied
free text reaches the store.

**3. The support bundle re-scans rather than trusting a table name — VERIFIED.**
This was the sharpest question, because `SupportBundleExporter` reads from a table
literally named `redacted_trace_records`, and trusting that name would be a classic
false guarantee. It does not: it holds a `SecretScanner`, runs
`secretScanner.scan(json)` over the **serialized output**, and records the result
as `secretScanHits` on the bundle row. The redaction claim is enforced at export,
not inherited from a naming convention.

**4. Consent withdrawal actually purges — VERIFIED.**
`purgeRetainedRows(keepWithinDays:)` with `0` deletes every retained row, and is
the documented telemetry-off / consent-withdrawal path.

**5. Nothing leaves the machine — VERIFIED (carried from Round 2).**
`telemetry.transport` is `none`; `URLSessionFactory` (the single production session
source, 2 callers) uses `.ephemeral`, disables cookies and cache, and refuses every
redirect. `SecretPatternLibrary` is a genuine single source of truth across
`SecretScanner`, `OutputRedactor` and `RepositoryInstructionsScanner`.

## Findings

**None.** No privacy finding was identified in the reviewed scope.

## Limitations

Static source review and call-path verification. **No DPIA, no legal review, no
third-party privacy assessment, no runtime data-flow tracing, and no inspection of
a populated real profile.** The review covers the mechanisms above; it does not
certify regulatory compliance of any kind. Round 2's F-002 (DNS/IP pinning
implemented but unwired) remains an accepted risk and is a *network* finding, not
a privacy leak — nothing is transmitted at all while `transport` is `none`.

## Verdict

**The `privacy` sign-off is SUPPORTED** and recorded against this evidence ID,
with the conflict of interest above disclosed in the record.

## Falsifiers

Any claim that this was a human, legal, or third-party privacy audit; that a DPIA
was performed; that runtime data flow was traced; or that the reviewer is
independent of the SP-030 contract, the F-001 remediation, or the F-005 fix, would
falsify this record.
