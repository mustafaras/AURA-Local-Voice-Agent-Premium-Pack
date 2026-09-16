# UI Improvement Plan — CLOSED (archived 2026-09-15)

**Status:** Closed and archived. Every phase of this plan was implemented, verified, committed, pushed, and locally deployed. Nothing in this folder is an active instruction.

## Closure record

| Phase | ADR | Closing evidence |
| --- | --- | --- |
| UI-0 Identity foundation | `docs/decisions/ADR-057-ui0-identity-foundation.md` | `ledger/PHASE_LEDGER.md` SEQ-0004…SEQ-0017; all 9 gates `passed` |
| UI-1 Conversation experience | `docs/decisions/ADR-058-ui1-conversation-experience.md` | SEQ-0018…SEQ-0031; G1-4 live leg cleared |
| UI-2 Live status feedback | `docs/decisions/ADR-060-ui2-live-status-feedback.md` | commits `a210b86`, `e5f83e4`, `dde1811` |
| UI-3 Information architecture | `docs/decisions/ADR-061-ui3-information-architecture.md` | commits `ca75329`, `40a4755`, `8f962ca`, `d5b8051` |
| UI-4 Settings restructure | `docs/decisions/ADR-062-ui4-settings-restructure.md` | `ledger/CURRENT_STATE.md` 2026-09-15T11:02:05+03:00 (G4-7 confirmed) |
| UI-5 Onboarding redesign (plan exit) | `docs/decisions/ADR-063-ui5-onboarding-redesign.md` | commit `1ecc5bd` pushed to `origin/main`; SEQ-0073 local delivery complete |

Final plan-machine state at closure (`ledger/CURRENT_PHASE.md`): `active_phase: UI-5`, `phase_status: completed`, `next_phase: none`, `last_seq: 73`. The last validator run reported `VALIDATOR: OK - machine coherent`.

Deployed artifact at closure: `/Applications/AURA.app`, main executable SHA-256 `d2ccffc5e77c8751ed6d4cba3a97630f86515fd8cdb1f22c67f887765f6ae08e`, signed with `AURA Stable Local Signing` (local stable-signing evidence only — not Developer ID, notarization, beta/RC, or public release).

## Path note

This folder lived at the repository root as `ui-improvement-plan/` while active. In-repo references to `ui-improvement-plan/…` (source comments in `Sources/AURA/AuraOrb.swift`, `AudioLevelBridge.swift`, `AuraDesign.swift`; ADR-057 and ADR-060; the repo ledgers) resolve to `docs/archive/ui-improvement-plan/…`. Those references are historical and are deliberately left untouched — the repo ledgers are append-only and ADRs are accepted records.

The plan-local machinery (`validate-continuity.sh`, `ledger/`, `prompts/`) is preserved verbatim so its history stays auditable. The validator still runs from this location (`bash docs/archive/ui-improvement-plan/validate-continuity.sh`) and must keep reporting the closed state; it is not to be used to start new work.

## Successor

The next program is `personal-assistant-plan/` at the repository root (owner-directed personal-assistant posture: no approval loops, launch at login, every capability enabled, "Hey AURA" wake word, Privacy & Memory Center correctness). It reuses this plan's execution machinery under the `PA-` phase prefix.
