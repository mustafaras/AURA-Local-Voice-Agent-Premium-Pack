---
id: PA-2
sequence: 2
track: PA
depends_on: PA-1
next_prompt: PA-3
state: pending
design_docs: 03-launch-at-login-always-on, 07-cross-cutting-constraints
adr: ADR-066
---

# PA-2 — Launch at Login, Always On

## Mission

AURA registers itself as a login item by default, without a confirmation, comes up ready after a real login without re-presenting onboarding or any prompt, and exposes an honest Settings row (including macOS's `.requiresApproval` state) with a working off switch.

## Read before acting

- Plan: `ledger/CURRENT_PHASE.md`, ledger tail, `00-working-protocol.md`, `03-launch-at-login-always-on.md`
- Repo: ADR-055 §2 (why launch-at-login kept its challenge), ADR-045/046 (lifecycle), `scripts/sp011-acceptance/launch-aura.sh` (LaunchServices launch)
- Code: `Sources/AuraLifecycle/LaunchAtLoginService.swift`, `LaunchAtLoginController.swift`, `Sources/AURA/AuraKernel_StartStop.swift`, `AuraAppModel.swift:225-235`, `AuraAppModel_Runtime.swift:15-40`, `AuraMenuView.swift` (onboarding `launchAtLogin` stage; Settings lifecycle row), `ProductUIState.swift:213-240`
- Tests: `Tests/AuraLifecycleTests/*LaunchAtLogin*`, R9 stage-machine tests (must stay unchanged)

## Hard boundaries

- **Allowed files:** `Sources/AuraLifecycle/LaunchAtLoginController.swift`, `Sources/AURA/AuraKernel_StartStop.swift` (post-start registration), `AuraMenuView.swift` (stage copy/rows, Settings row), `ProductUIState.swift` (copy), `AuraAccessibilityIdentifiers.swift` (additions), tests, `docs/decisions/ADR-066-*.md`, ledgers.
- Forbidden: importing `AuraPolicy` into `AuraLifecycle` (pass the posture as configuration), changing the stage machine, editing `SMAppServiceWrapper`.
- The System Settings deep-link anchor for Login Items must be verified on this machine before it is shipped; an unverified anchor is a defect.

## Gates

| Gate | Description | Verification |
| --- | --- | --- |
| G2-1 | `[policy]` Default-on under the owner posture; idempotent post-start registration (`changed: false` on second launch); `.requiresApproval` mapped to an honest row with a verified deep link | `unit` controller tests with stub service |
| G2-2 | Onboarding `launchAtLogin` stage is informational (EN/TR copy from `03-…md` §3.2), live status row; stage machine unchanged | `integration` view test; `git diff --stat` on R9 stage tests = empty |
| G2-3 | Readiness: LaunchServices launch → `status` = Boşta within 10 s; no onboarding sheet; `probeExternalAvailability` ran (health record) | `live-local` driver `status`; log/health line |
| G2-4 | Real logout → login: AURA running (`pgrep -x AURA`), Boşta, zero dialogs; login item listed by `sfltool dumpbtm` pointing at `/Applications/AURA.app`; Settings off switch unlists it and on relists it | `os-observed` + `live-local` + `owner-attested` |
| G2-5 | Full verification + governance: suite ×2–3, ADR-066, repo ledgers, `CURRENT_STATE` | `evidence/PA-2/` |
| G2-6 | Machine coherence | validator OK, `awaiting-approval` |

## Per-gate procedure

- **G2-1:** flip the default behind the posture flag; add the post-start call; write the stub tests; verify the deep-link anchor by opening it (`open "x-apple.systempreferences:…"`) and recording what pane opened.
- **G2-2:** presentation + copy; view test; confirm stage tests untouched.
- **G2-3:** build to a fresh path, stable-sign, verify, install to `/Applications` only if the owner authorized install in this turn (otherwise run from the fresh path and say so); `open -a`; driver `status`.
- **G2-4:** owner performs logout/login; assistant captures `pgrep`, driver `status`, `sfltool dumpbtm | grep -i aura` (redact unrelated entries); toggle test.
- **G2-5/G2-6:** closing sequence.

## Evidence template

```text
## SEQ-00NN — <ISO> — PA-2 — G2-k PASSED
- evidence: …
- verified: …
- adr: ADR-066   ← G2-1
- bundle: <path> sha256=<main executable>
```

## Risks / reverting

`.requiresApproval` is a macOS decision; it is recorded, not worked around. Reverting is restoring the allowed files and turning the login item off through the Settings switch.

## Session script

Protocol §5, then G2-1 → G2-6. End with `awaiting-approval`.

## Cognitive completion gate

(1) After a cold login, what is the first thing the owner sees, and what proves nothing was asked? (2) Where does the off switch persist, and what proves it unregistered? (3) Which bundle path is registered — the installed one or a build path?
