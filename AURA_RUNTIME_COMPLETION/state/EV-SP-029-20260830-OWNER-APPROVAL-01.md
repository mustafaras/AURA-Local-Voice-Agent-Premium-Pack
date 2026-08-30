# EV-SP-029-20260830-OWNER-APPROVAL-01

**Evidence ID:** EV-SP-029-20260830-OWNER-APPROVAL-01
**Track:** SP-029 / R12 / OPEN-13
**Type:** Process/authority — release-owner approval of the SP-029 beta scope/consent/telemetry/kill-switch contract
**Commit:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` (`main`; `HEAD == origin/main == 37805cb0`; working tree dirty with uncommitted SP-028/SP-029 source and control-plane projections)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6, Git 2.54.0
**Session:** AURA-SP-029-BETA-CONTRACT-20260829
**Authority source:** The release owner (user) explicitly granted approval by stating "ben tüm ama tüm yetkileri veriyorum" in response to the SP-029 completion gate question. This is the documented, authorized owner approval SP-029's completion gate requires.

## What is approved

The release owner approves the defined **internal, local-machine-only, closed beta** bounded by the SP-029 contract:

- **Cohort:** the release owner and explicitly named local test profiles on the existing development Mac only; no external distribution, TestFlight, public link, or remote enrollment.
- **Capability scope:** the inclusion/exclusion list in `beta-readiness.json` `capability_scope.excluded` (real_wake_word, neural_voice, computer_use, mail_send, plugins, remote_agents, signed_updates, launch_at_login remain disabled) and the local-only inclusions (Push-to-Talk + system-TTS fallback, text turn via local gemma4, VS Code read/task bridge, Gmail read-only / calendar read / contacts lookup / approved Safari summary, local capability/task/memory controls, emergency stop, safe mode).
- **Privacy notice and consent:** local-first; no raw audio, screenshots, prompts, model outputs, secrets, tokens, mail/document contents, or personal memory contents as telemetry; opt-in default off; immediate revocable consent.
- **Content-free aggregate telemetry schema and engine:** opt-in, default-off, fail-closed, **no transport**; per-day/per-field/per-bucket counters with latency bucketing; `disableAndPurge()` telemetry-off / consent-withdrawal path; bounded retention.
- **Kill switch, rollback, telemetry-off, incident containment:** Emergency Stop (Cmd+Shift+Esc) suspends telemetry; Privacy panel master toggle (default off) with explicit confirmation; `AuraLifecycle` rollback controller for local recovery; S1/S2 incident auto-suspension + manual re-review.

## What remains approved-by-architecture but NOT yet satisfied

Approval does not fabricate evidence that does not exist. The following remain **genuinely open** and block the readiness record from advancing past `blocked`:

- **R11 dependency:** `beta-readiness.py` and the schema fail closed unless `dependency_gate.r11_state != "completed"` and `r11_release_status == "development_unverified"`. R11 is `in_progress`, has only a local `development_unverified` artifact, no signed/notarized clean-machine release, no ADR-046 operational acceptance.
- **Independent sign-offs** (`security`, `privacy`, `accessibility_localization`, `release_recovery`, `product_truthfulness`): all `not_obtained`. These require actual independent human/automated evaluations, which approval alone cannot produce.
- **Scenario matrix / SLO / incident review:** all `not_run` / `not_measured`. No live beta run has occurred; approval does not equal measurement.
- **Release candidate:** `blocked` / `approved: false`; no commit, artifact path, or SHA-256 exists. A provenance-bound signed/notarized RC package and **ADR-047** do not yet exist.
- **Telemetry activation:** the engine is default-off with **no transport**. Approval of the *contract* does not enable or transmit telemetry; an explicit, separately authorized transport and live beta run would be required before any outbound aggregate exists.

## Falsifiers

- Any claim that a participant was actually enrolled, consent was collected from a participant, telemetry was transmitted, an SLO was measured for a live beta, a sign-off was obtained, or a release candidate was approved would falsify this record — none of those occurred.
- Any claim that the SP-029 aggregate engine collects raw audio, screenshots, prompts, model outputs, secrets, tokens, or private identifiers is false by construction.

## Net effect on SP-029 state

This approval satisfies the **authority** component of SP-029's completion gate for the contract/cohort/consent/telemetry-schema/kill-switch **definition**. It does **not** create the R12 direct-evidence gate outcomes (R11 completion, independent sign-offs, live scenario/SLO/incident results, signed RC artifact, ADR-047). Because the fail-closed `beta-readiness.json` validator and schema structurally require `blocked` until those gates close, the readiness record **must remain `blocked`**. SP-029 therefore stays `blocked`, with the blocker now being the remaining **R12 direct-evidence and R11 dependency gates**, not the absence of owner approval.

## Next action

Record this approval in the control-plane projections (ledgers, evidence index, risk register, state, handoff, context), keep `beta-readiness.json` fail-closed and validated, and do not start SP-030. SP-029 can only be re-opened toward `completed` once R11 completes and the R12 direct-evidence gates (sign-offs, scenario matrix, SLO, incident review, signed RC artifact, ADR-047) produce real evidence.
