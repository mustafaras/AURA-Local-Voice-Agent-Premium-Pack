# R11 Closure Plan — Release Engineering and Continuous Operations

**Prompt lineage:** OPEN-12 (R11) → SP-026 (reproducible build + observed CI) → SP-027 (signing, local-only scope) → SP-028 (updater, lifecycle, recovery, migration) → SP-029 (beta/consent/telemetry, completed) → SP-030 (SLOs) → SP-031 (RC + ADR-047).
**Status (2026-08-30):** R11 is `in_progress`. This plan is the owner-reviewable, decision-ready disposition of every remaining R11 gate. It is **not** a claim that R11 is complete or that an RC exists.

## Authority posture

- The release owner has repeatedly granted authority for the second-pass program ("go apply be perfect", "ben tüm ama tüm yetkileri veriyorum", "ONLARI DA ONAYLIYORUM YAP ARTIK", "a go be perfect and premium" → option A).
- `current-state.json` `authority` was reset to edit/test/state-only during SP-029's blocked phase and has **not yet been re-synchronized** to reflect the subsequent owner grants. **This is a stale-authority drift that must be reconciled** before any R11 gate that needs launch/install/test or commit/push/merge is exercised.
- Canonical source of the reset: `current-state.json` (edit/test/state only). Non-canonical `SECOND_PASS_STATE.json` shows `launch_or_install_app: true`, `commit: true`, `push: true`, `merge: true`. The two disagree and must be made consistent by the owner-scoped grant.

## Gate-by-gate disposition

### A. Gates that can be closed with local evidence (owner may authorize locally)

| Gate | Local-only status | Residual to close |
|---|---|---|
| Deterministic artifact/manifest/checksum/SBOM + `validate_release_manifest.py` | **Delivered** (SP-026 `EV-SP-026-20260828-REPRODUCIBLE-ARTIFACT-BLOCKED-01`; observed CI `EV-SP-026-20260828-OBSERVED-CI-COMPLETED-01`) | None local; already evidenced for the `development_unverified` artifact. |
| Toolchain pinning (Xcode 27.0 beta 5, Swift 6.4, SDK 27.0, Python, Git) | **Delivered** (`toolchain-manifest.json`, ADR-045 accepted) | Re-run after any toolchain change. |
| Observed CI run | **Delivered** (run `33157842324` success, artifact `9680431386`, 70.69% coverage) | Hosted runner was temporary and deregistered; a re-run needs a runner again. |
| Launch-at-login (ServiceManagement) live mutation | SP-028 implemented source + mock tests only | **Needs live `SMAppService` enable/disable on this Mac** with a user-present session + `launch_or_install_app`/test authority. Locally closable with authorized launch. |
| Crash/sleep/wake recovery live | SP-028 implemented source + tests | Needs a live app session with sleep/wake/crash on the local Mac. |
| Update manifest/package validation, atomic staging, rollback, kill switch, downgrade/replay | **Delivered** (SP-028 deterministic + adversarial tests) | Real signed update download is external (no signed transport available). Rollback path logic is contract-evidenced; a live rollback needs a signed package. |
| Safe mode, support-bundle redaction, reset/uninstall/factory-reset semantics | **Delivered** (SP-028) | Live destructive execution on user data requires explicit owner authorization to proceed; safe mode/support-bundle export are locally testable now. |
| Migration (config/db/memory/plugin/model) + interrupted/failed/low-disk/corrupt recovery | **Delivered** (SP-028 migration preflight + tests) | Live migration against a real populated profile requires authorized launch. |

### B. Gates blocked by external/Apple prerequisites (cannot be fabricated)

| Gate | Reason it is genuinely open |
|---|---|
| Developer ID signing | No Developer ID Application certificate exists (`security find-identity -v -p codesigning` reports only the local `AURA Stable Local Signing` identity). |
| Notarization, stapling, `spctl`/Gatekeeper distribution | No Team ID / App Store Connect API key / Apple ID credentials; `notarytool` cannot submit without a Developer ID identity + credentials. |
| External clean-machine (no developer tools) | No such Mac is available; this development Mac has Xcode 27.0 beta 5 + developer tools. |
| Signed update transport (network distribution) | No signed/notarized update host exists; SP-028's default production manifest source returns `.noUpdateAvailable`. |

> **Permanent local-only scope (ADR-049, 2026-08-30):** the release owner decided AURA is local-only and will **never** acquire or use Developer ID/notarization. Developer ID signing, notarization, stapling, and external clean-machine Gatekeeper are **permanently out of scope** and are NOT R11 blockers for the local-only product; they will not be re-opened by a future distribution decision unless a new ADR authorizes it. `RISK-NOT-NOTARIZED` is accepted (permanent). Box B is recorded purely as honesty about why external distribution is not attempted — it does not block R11 local completion.

### C. Owner-decision gates

| Item | Recommendation |
|---|---|
| **ADR-046** (Signed updates, rollback, recovery) | Status `Proposed`. The SP-028 implementation + adversarial tests prove the local contract/validator/stager/rollback/recovery/safe-mode/reset source. Recommendation: **Accept ADR-046 with an explicit local-only scope limitation**: the updater contract is implemented and tested for the local path; a real externally-signed update, network transport, and distribution remain out of scope by the SP-027 decision and are not claimed. This makes the local updater/rollback contract the accepted design for local operation. |
| **R11 `development_unverified` → any further label** | Must stay `development_unverified` (and never `release candidate`) until ADR-047/SP-031 produce a provenance-bound RC evidence package. Do not relabel. |
| **R12 `beta-readiness.json`** | Must stay `blocked` (fail-closed validator/schema require it). SP-029 is complete; the SLO/scenario/incident gates are SP-030's job. |

## Recommended sequence (honest, no fabrication)

1. **Reconcile authority drift**: propagate the owner grant to `current-state.json` (and make `SECOND_PASS_STATE.json`/`session-handoff.json`/`ACTIVE_CONTEXT.md` consistent) so the authority block reflects the owner's explicit grants.
2. **Close the locally-closable R11 gates** in a user-present session:
   - Live launch-at-login enable/disable/status + health.
   - Live sleep/wake/crash recovery observation.
   - Live safe-mode and support-bundle export.
   - Live migration against a populated profile.
   - (Destructive reset/uninstall/factory-reset only if the owner explicitly authorizes them on disposable data.)
3. **Advance ADR-046** to `Accepted` under the explicit local-only scope (decision item), with evidence `EV-SP-028-20260829-*`.
4. **Keep `beta-readiness.json` blocked** and do **not** relabel the artifact. Open **SP-030** (SLOs/scenarios/incidents/sign-offs) under its own authority once the R11 local gates above are evidenced — but SP-030's live SLO measurement still requires `telemetry_or_beta: true`, which only the owner can flip.
5. Only then does **SP-031** (RC package + ADR-047) become eligible.

## Falsifiers / honesty guardrails

- Any claim that Developer ID signing/notarization/clean-machine evidence exists, that R11 is `completed`, or that an RC artifact is approved would be false — none of those exist and none is claimed.
- Any relabel of the `development_unverified` artifact as a release candidate would falsify the R11/R12 gate.
- Any claim that `beta-readiness.json` advanced past `blocked` would be false.

## Evidence index (relevant)

- `EV-R11-20260809-ARTIFACT-MANIFEST-01`, `EV-SP-026-20260828-REPRODUCIBLE-ARTIFACT-BLOCKED-01`, `EV-SP-026-20260828-OBSERVED-CI-COMPLETED-01`, `EV-SP-027-20260828-LOCAL-ONLY-SCOPE-03`, `EV-SP-027-20260828-SIGNING-PROCEDURE-02`, `EV-SP-027-20260828-LOCAL-LAUNCH-04`, `EV-SP-028-20260829-LIFECYCLE-IMPLEMENTATION-01`, `EV-SP-028-20260829-RUNTIME-API-02`, `EV-SP-028-20260829-CLOSEOUT-03`.
