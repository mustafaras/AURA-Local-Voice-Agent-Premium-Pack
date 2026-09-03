# EV-SP-030-20260902-CUA-SERVICE-CRASH-01

**Evidence ID:** `EV-SP-030-20260902-CUA-SERVICE-CRASH-01`  
**Track:** SP-030 / OPEN-13 — owner-present Computer Use recovery-surface attempt  
**Session:** `AURA-SP-030-CUA-DIAGNOSTIC-20260902`  
**Timestamp:** 2026-09-02, Europe/Istanbul  
**Branch / source:** `main`, `0bafc4f249968d6b620b181ff4ffd3da1d13b71e`; source tree clean after the attempt  
**Evidence class:** `live_observation` for the process/tool boundary; not beta SLO, scenario, or release evidence

## Objective and authority

The owner asked for the next SP-030 operation to be completed through
Computer Use. The bounded objective was to open AURA, inspect Settings, select
Recovery, and continue only while the product remained user-present and the
accessibility state was observable. No TCC state, microphone permission,
telemetry transport, signing, notarization, provider account, or release state
was changed.

## Procedure and result

1. `sky.get_app_state({app: "/Applications/AURA.app"})` initially returned the
   live AURA accessibility tree. Settings opened and closed successfully.
2. Selecting AURA's `Kurtarma` / Recovery tab caused
   `Sky Computer Use native pipe closed before response`.
3. The AURA process remained alive after the pipe failure. Read-only process
   inspection found `/Applications/AURA.app/Contents/MacOS/AURA` still running.
4. The diagnostic reports identify the failing component as
   `SkyComputerUseService` (`com.openai.sky.CUAService`, version
   `26.817.1000761`), not AURA. The reports record `EXC_BREAKPOINT` / `SIGTRAP`
   on the service's faulting thread at Swift `Array.remove(at:)` while an
   `AXNotificationObserver` watched the AURA process. The same failure was
   reproduced against a newly built local AURA bundle at
   `/tmp/aura-cu-fix-app/AURA.app` (target process PID 78103), after an earlier
   failure against the installed bundle (target process PID 64768).
5. A source-side experiment flattened the Recovery dynamic AX readout and
   added stable identifiers. It did not prevent the service crash on the new
   bundle, so that experiment was reverted. No speculative UI regression was
   retained.

## Verification

- `./scripts/aura-test.sh /tmp/aura-cu-fix-final AURAIntegrationTests` —
  **111 tests / 22 suites, 0 failures**.
- `git diff --check` — passed.
- `git status --short --branch` — clean `main` at `0bafc4f`; no source change
  remains from the experiment.
- The failing service reports are retained by macOS outside the repository at
  `/Users/m_ras/Library/Logs/DiagnosticReports/SkyComputerUseService-20260902-110912.ips`
  and
  `/Users/m_ras/Library/Logs/DiagnosticReports/SkyComputerUseService-20260902-111732.ips`.
  Only their redacted component/type/path facts are recorded here; no private
  UI content or screenshot is retained.

## Cognitive gate

- **Symptom:** Computer Use could observe AURA until Recovery was selected, then
  its native pipe closed.
- **Mechanism / root cause:** the external Computer Use service crashed while
  reconciling AURA's AX notification stream; AURA itself stayed alive. The
  source-side Recovery flattening experiment did not alter that outcome.
- **Direct change / procedure:** no product change was retained; the failure was
  reproduced with the installed and newly built bundles and diagnosed from the
  service crash reports.
- **Falsifier:** a later `get_app_state` / Recovery selection succeeds without a
  new `SkyComputerUseService` crash report, or an AURA crash report/process exit
  appears for the same action.
- **Residual risk:** the owner-present Computer Use path cannot currently supply
  direct Recovery-window evidence. This is distinct from the still-open product
  gates: live sleep/wake/crash recovery, safe-mode export, populated-profile
  migration, qualifying voice SLO samples, live scenario execution, and
  incident review.
- **Acceptance verdict:** SP-030 remains **blocked**; `beta-readiness.json`
  remains blocked and SP-031 must not start. This evidence does not claim a
  beta window, an SLO sample, a scenario pass, an incident review, or a release.

**Next safe action:** update/restart the Computer Use service or perform the
remaining owner-present Recovery checks manually while preserving the same
fail-closed evidence boundary; do not treat a deterministic or tool-recovery
pass as live-beta evidence.
