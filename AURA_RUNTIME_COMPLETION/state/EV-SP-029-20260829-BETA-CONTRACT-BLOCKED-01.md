# EV-SP-029-20260829-BETA-CONTRACT-BLOCKED-01

**Evidence ID:** EV-SP-029-20260829-BETA-CONTRACT-BLOCKED-01
**Track:** SP-029 / R12 / OPEN-13
**Type:** Process/contract — beta scope, consent, telemetry, kill-switch definition recorded; readiness remains blocked
**Commit:** `37805cb0e61cd4c46d7a3653c2ad8da212295a7a` (`main`; `HEAD == origin/main == 37805cb0`; working tree dirty with SP-028 source changes, SP-029 evidence, and control-plane projections)
**Environment:** macOS 27.0 arm64, Swift 6.4, Xcode 27.0 beta 5, Python 3.14.6, Git 2.54.0
**Session:** AURA-SP-029-ATTEMPT-20260829
**Authority:** User authorized execution of SP-029 with "go apply be perfect" and standing edit/test/state authority. No beta enrollment, telemetry activation, app launch/install, TCC mutation, provider contact, signing, release, deploy, commit, push, or merge authority was granted or exercised for SP-029.

## Procedure executed

1. Read the SP-029 prompt, `SECOND_PASS_READ_FIRST.md`, `SECOND_PASS_CONTROL_CONTRACT.md`, `SECOND_PASS_PROMPT_CONTRACT.md`, the archived first-pass R12 prompt, the existing `beta-readiness.json` contract, `beta-readiness.schema.json`, `validate_beta_readiness.py`, the `OPEN-13` section of `SECOND_PASS_OPEN_GAPS.md`, the R12 readiness contract evidence `EV-R12-20260809-READINESS-CONTRACT-01`, and the current control-plane state projections.
2. Validated the existing fail-closed beta-readiness contract with `python3 scripts/validate_beta_readiness.py --record AURA_RUNTIME_COMPLETION/state/beta-readiness.json`; it passed and reported `readiness_status: blocked`.
3. Determined whether SP-029 could be marked `completed` under current authority. The prompt completion gate requires *approved* cohort/consent/privacy/telemetry/kill-switch evidence. Current `SECOND_PASS_STATE.json` authority has `telemetry_or_beta: false` and `release_or_deploy: false`; `beta-readiness.json` authority has `beta_enrollment: false`, `telemetry_activation: false`, `app_install_or_launch: false`, and `release: false`. Therefore no authorized approval exists to enroll a cohort, collect consent, activate telemetry, or approve a release candidate. SP-029 is correctly `blocked` for its activation/approval scope.
4. Defined and documented the controlled beta boundary in this evidence record and in the append-only ledgers without activating any telemetry, enrolling any participant, or changing `beta-readiness.json` to a non-blocked state.

## Defined beta scope, consent, and telemetry contract

The following is the defined but not-yet-approved beta boundary for AURA local-only usage. It is a contractual definition only; implementation/activation remains blocked pending explicit authorized owner approval.

### Cohort and profile matrix

- **Type:** Internal, local-machine-only closed beta.
- **Participants:** The release owner and explicitly named local test profiles on the existing development Mac; no external distribution, no TestFlight, no public link, no remote enrollment.
- **Supported profiles:** `clean_profile` (fresh macOS user account, no prior AURA state) and `configured_profile` (existing local AURA state with memory/integrations/preferences).
- **Minimum sessions before reporting:** Not set; cannot be set without authorized cohort approval.
- **Duration:** Not started; any beta window requires a separate explicit approval record.
- **Owner:** Release owner (user); no delegated beta program manager is appointed.

### Capability inclusion/exclusion

Consistent with the existing `beta-readiness.json` `capability_scope.excluded` list and the local-only scope accepted under SP-027:

- **Included (if enabled by direct user grant during a beta session):**
  - Push-to-Talk local dialogue with system-TTS fallback (Chatterbox neural synthesis remains unqualified).
  - Text turn through the local `gemma4:latest` reasoning path.
  - VS Code authenticated bridge read-only/task observation (write-capable coding-agent turns remain separately gated).
  - Gmail read-only summary, calendar agenda read, contacts candidate lookup, approved Safari page summary (send/mutation explicitly excluded).
  - Local capability center, task center, memory export/delete, emergency stop, safe mode.
- **Excluded (must remain disabled during any local beta):**
  - `real_wake_word`
  - `neural_voice`
  - `computer_use` (live beta app list not yet approved)
  - `mail_send`
  - `plugins`
  - `remote_agents`
  - `signed_updates`
  - `launch_at_login`

### Privacy notice and consent

- **Privacy notice:** AURA is local-first by design. No raw audio, screenshots, prompts, model outputs, mail/document contents, secrets, tokens, private account data, or personal memory contents are collected as telemetry.
- **Opt-in:** Any telemetry collection requires a separate explicit opt-in toggle; default is off.
- **Consent withdrawal:** The user can revoke telemetry consent at any time via the Privacy panel; revocation immediately stops collection and schedules any buffered aggregates for deletion.
- **Data retention:** Telemetry aggregates, if ever enabled, are retained for no longer than 90 days; raw events are not retained.
- **Access/deletion:** The user can request an export of their own local data and can delete local memory/state through the existing memory delete/factory reset paths.

### Telemetry schema (content-free aggregates only)

If and only if explicit opt-in consent is approved and enabled, AURA may transmit only the following content-free aggregate fields:

- `session_outcome` — counts of `completed`, `degraded`, `blocked`, `user_stopped` outcomes (no transcript/content).
- `latency_percentiles` — aggregated P50/P95/P99 latency buckets for PTT acknowledgement, first STT partial, and first local-dialogue token (no audio/content).
- `confirmation_outcome` — counts of `allowed`, `denied`, `expired`, `dismissed` (no target/content).
- `recovery_outcome` — counts of `clean_shutdown`, `crash_detected`, `recovered`, `safe_mode_entered`.
- `resource_pressure_class` — thermal/memory/circuit-breaker state class (e.g., `nominal`, `light`, `heavy`, `critical`).

Prohibited fields: raw audio, screenshots, prompts, model outputs, secrets, tokens, private identifiers, mail/document contents, personal memory contents, exact transcripts, or anything that can reconstruct user activity.

### Kill switch, rollback, and telemetry-off

- **Kill switch:** AURA exposes an Emergency Stop (Cmd+Shift+Esc) that immediately halts active assistants, cancels durable tasks, and sets runtime health to `stopped`. Any beta telemetry, if enabled, is suspended while stopped.
- **Telemetry-off:** The Privacy panel contains a master telemetry toggle defaulting to `off`. Changing it to `on` requires explicit opt-in confirmation. Changing it to `off` takes effect immediately and purges the local telemetry staging buffer.
- **Rollback:** The `AuraLifecycle` rollback controller can restore the previous application version from a retained backup if an update causes failure. Rollback requires user approval for the local-only scope; remote signed rollback is outside current authority.
- **Incident containment:** A severity-1/2 incident during any beta session triggers automatic suspension of the affected capability, a local-only incident marker, and a required manual review before the capability can be re-enabled.

## Verified state

- `python3 scripts/validate_beta_readiness.py --record AURA_RUNTIME_COMPLETION/state/beta-readiness.json` — PASSED; contract is valid and `blocked`.
- No telemetry implementation was added; no cohort was enrolled; no consent was collected; no SLO was measured; no RC was approved.
- No source, test, or product change outside control-plane projections and this evidence file.

## Acceptance verdict

SP-029 is **blocked** for its activation/approval scope because current authority does not grant beta enrollment, telemetry activation, release approval, or RC approval. The beta scope/consent/telemetry/kill-switch contract is **defined and recorded** in this evidence file and in the append-only ledgers. SP-029 cannot advance to `completed` without explicit authorized owner approval and the corresponding evidence records.

## Residual risks and next action

- `RISK-NO-INDEPENDENT-BETA-EVIDENCE` remains **Open**.
- `RISK-NO-BETA-CONSENT-BOUNDARY` remains **Open** but is now documented/defined; closure requires authorized approval and implementation evidence.
- `RISK-NO-RC-EVIDENCE-PACKAGE` remains **Open**.
- ADR-047 remains absent; no release-candidate authority is claimed.
- SP-030 is **not safe to start** because SP-029's completion gate (approved cohort/consent/telemetry/kill-switch evidence) is not met.

**Next safe action:** Obtain explicit authorized owner approval for the defined beta scope/consent/telemetry/kill-switch contract, or keep SP-029 blocked and do not proceed to SP-030.
