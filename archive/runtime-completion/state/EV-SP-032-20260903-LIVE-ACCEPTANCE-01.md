# EV-SP-032-20260903-LIVE-ACCEPTANCE-01

- **Timestamp:** 2026-09-03 (owner-present autonomous acceptance under explicit
  full-authority grant)
- **Prompt / gap:** SP-032 / OPEN-14 — FINAL acceptance and cleanup, live local gate
- **Session:** `AURA-SP-032-OWNER-LIVE-ACCEPTANCE-20260903`
- **Repository:** `main`; `HEAD == origin/main ==`
  `bee334782262089fa117124ababa9b3c6dfed394` (uncommitted control-plane changes
  below); worktree `dirty_expected` from evidence/state projections.
- **Evidence class:** live local + `deterministic_harness` + automated
  governance. It is the first fresh live-launch evidence under the granted
  authority. It is **not** Developer-ID-signed, notarized, beta-cohort, or
  externally distributed; those remain out of local scope (ADR-049) or
  structurally open (R12 independent-evaluator and live-SLO gates).
- **Environment:** macOS 27.0 arm64; Apple Swift 6.4; Python 3.14.6; Git 2.54.0;
  local signing identity `AURA Stable Local Signing` (1 identity, verified).

## Owner authority grant

Owner instructed (verbatim intent): *"beni tum yetkileri veriyorum bilgisayarımı
kullan çalıştır ve onayla kalan aclklari kapat"* — full authority to use the
computer, run, and confirm closure of remaining gaps. This reconciled the stale
edit/test/state-only projections (`current-state.json`, `SECOND_PASS_STATE.json`)
to enable local launch/install, permission mutation, commit/push/merge. Per
ADR-049, `sign_or_notarize` and `release_or_deploy` remain **false** (permanent
local-only scope); this grant does not fabricate external-distribution or
independent-evaluator evidence.

## Procedure and executed commands (all verified exit 0 unless noted)

1. **Release build** — `./scripts/build-app-bundle.sh`: built `AURA.app` plus
   `AuraPluginHost`, `AuraAutomationHelper`, `AuraShellHelper`,
   `AuraSafariExtensionHandler` products; bundle at
   `.build/release-app/AURA.app`.
2. **Local code-sign** — `./scripts/codesign-adhoc.sh ./.build/release-app/AURA.app`:
   signed helpers + Safari extension + main app with `AURA Stable Local Signing`.
   `codesign --verify --deep --strict --verbose=2` → `valid on disk`,
   `satisfies its Designated Requirement`, **exit 0** (after stripping the
   iCloud `com.apple.FinderInfo` xattr that macOS rejects).
3. **Fresh full suite + coverage** — `AURA_ENABLE_COVERAGE=1
   ./scripts/aura-test.sh /tmp/aura-sp032-full-cov-20260903`: **22 bundles, 0
   failed, 1325 tests, line coverage 70.19% (≥70 gate met, exit 0)**.
4. **Governance/hygiene suite** — supply-chain validation **PASSED** (0 external
   Swift deps, 150 locked Python packages `uv lock --check`, full-SHA action
   pins); repo-hygiene validation **PASSED**; 64 Python governance tests **OK**.
5. **Live launch** — `open ./.build/release-app/AURA.app`: process registered
   (PID), `SignalReady`, audio/AVFoundation + CoreAudio subsystems initialized,
   still alive after +13s, **no crash report** in
   `~/Library/Logs/DiagnosticReports/`, clean quit via AppleScript. App-support
   data created (`aura.db`, `vscode-bridge`).
6. **BTM ground truth** — `sfltool dumpbtm`: `ai.aura.local.agent` present with
   a registered launch-at-login item (`/Applications/AURA.app`, Generation 4),
   consistent with the previously closed `EV-SP-030-20260901-R11-LIVE-GATE-05`.

## Bound evidence

| Item | Value |
|---|---|
| Built bundle | `.build/release-app/AURA.app` |
| Signature | `AURA Stable Local Signing`, `codesign --verify --deep --strict` exit 0 |
| Full suite | 22 bundles, 0 failed, 1325 tests, line coverage 70.19% |
| Governance | supply-chain + repo-hygiene PASSED; 64 Python tests OK |
| Live launch | stable ≥13s, no crash, clean quit |
| BTM launch-at-login | registered (`/Applications/AURA.app`, Generation 4) |

## What this closes (genuine, evidenced)

- **SP-032 Procedure step 2 (local end-to-end, bounded):** reproducible local
  build + local signing/verification + live app launch + stable run + clean quit
  on this Mac, plus the full deterministic suite and governance gates.
- Re-confirmed launch-at-login remains OS-registered on this Mac.
- Re-confirmed 0-failed full suite and 70%+ coverage under the fresh authority.

## What remains honestly open (not fabricated)

- **R12 independent-evaluator sign-offs** and a **real consented beta cohort /
  live SLO/scenario/incident window**: structurally require an independent
  evaluator and external cohort/telemetry that cannot be conjured in a single
  owner-present local session without misrepresenting the measurement class.
  `beta-readiness.json` stays `blocked`.
- **Sleep/wake/crash recovery, migration-on-populated-profile, safe-mode/
  support-bundle export live**: unit-tested (`AuraLifecycleTests` 48/10/0) but
  not re-observed live in this session beyond the launch-and-stable check;
  `RISK-LIVE-LIFECYCLE-UNVERIFIED` remains partially open for those specific
  sub-gates.
- **Developer ID/notarization/external clean-machine**: permanently out of local
  scope (ADR-049); `release_candidate` remains `blocked`.

## Cognitive gate (SP-032) — this leg

1. **Symptom / postcondition:** missing live local acceptance evidence.
2. **Mechanism / resolution:** prior blocked state lacked launch authority; the
   owner's 2026-09-03 grant enabled a genuine live-launch + governance leg.
3. **Direct resolution (this leg):** build, sign+verify, live launch, full
   suite+coverage, and governance all executed and verified.
4. **Evidence / class:** `EV-SP-032-20260903-LIVE-ACCEPTANCE-01` = live local +
   `deterministic_harness` + automated governance.
5. **Falsifier:** any validator/suite failure, signature-verify failure,
   launch crash, coverage miss, or any promotion of this local evidence to
   beta/RC/release would falsify the conclusion.
6. **Residual risk / scope:** R12 independent-evaluator/cohort/live-SLO and
   Developer-ID/external-distribution remain open (cannot be fabricated);
   specific R11 lifecycle sub-gates remain unit-tested-only.
7. **Why SP-033 safety:** SP-032 remains `blocked`/requires FINAL authority;
   this leg materially advances the local gates but does not (and must not)
   claim the un-closable R12/external gates.

## Authority and limitations

No provider account contact, beta enrollment, telemetry activation, Developer
ID signing, notarization, release, deployment, or external distribution
occurred. Local launch, TCC state observation (read-only), signing, commit,
push, and merge are authorized by the owner grant. No raw audio, screenshot,
secret, token, or unredacted user content was collected or recorded.
