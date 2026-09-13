# UI Plan — Current Phase State

updated: 2026-09-13T12:52:19Z
active_phase: UI-2
phase_status: in-progress
next_phase: UI-3
last_seq: 33

## Gates (mirror of prompts/UI-2.prompt.md §Gates — must match 1:1)

| Gate | Description (short) | Status | Evidence |
| --- | --- | --- | --- |
| G2-1 | Status pill transitions use AuraDesign.Motion tokens; one choreography owner per moment | pending | — |
| G2-2 | Listening pulse driven by real AudioLevelBridge.inputLevel — transform-only | pending | — |
| G2-3 | @Published isSpeakingResponse from real TTS events; ≤3-bar equalizer; no synthetic source in demo paths | pending | — |
| G2-4 | Emergency badge: emergent motion, instant, one pulse, static under Reduce Motion; emergency-stop path untouched | pending | — |
| G2-5 | Confirmation card entrance per 11 §4 (sober, Deny-first tab order preserved); all five fail-closed paths re-verified | pending | — |
| G2-6 | Full verification loop + governance: suite ×2–3, a11y IDs, live driver leg, ADR + repo ledger + CURRENT_STATE | pending | — |
| G2-7 | Machine coherence: validator OK, all gates passed, awaiting-approval | pending | — |

## Blocked items

- none

## Next gate

G2-1 (status pill motion adoption).
