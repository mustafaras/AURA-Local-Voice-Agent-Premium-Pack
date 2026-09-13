# UI Plan — Current Phase State

updated: 2026-09-13T14:39:25Z
active_phase: UI-2
phase_status: in-progress
next_phase: UI-3
last_seq: 38

## Gates (mirror of prompts/UI-2.prompt.md §Gates — must match 1:1)

| Gate | Description (short) | Status | Evidence |
| --- | --- | --- | --- |
| G2-1 | Status pill transitions use AuraDesign.Motion tokens; one choreography owner per moment | passed | SEQ-0034: AuraDesign.swift:290-336 — `.smooth` on dot fill + glass tint (colour), `.standard` + `.id`/`.transition` on title/detail (geometry); view-construction loop extended for all 8 statuses; grep proves zero raw durations outside the Motion token block |
| G2-2 | Listening pulse driven by real AudioLevelBridge.inputLevel — transform-only | passed | SEQ-0035: AuraDesign.swift — nonisolated listeningPulseScale (0.9-1.15x), bare .scaleEffect, no animation keyed on level; both real call sites wired; UI2LiveStatusFeedbackTests.swift new (3 tests) |
| G2-3 | @Published isSpeakingResponse from real TTS events; ≤3-bar equalizer; no synthetic source in demo paths | passed | SEQ-0036: AuraAppModel_Runtime.swift subscribes TTSStartedEvent/TTSStoppedEvent -> setSpeakingResponse; AuraEqualizer (AuraDesign.swift) beside pill in header + menu bar panel; event-mapping test covers all 4 stop reasons; grep proves single writer, zero synthetic constructions |
| G2-4 | Emergency badge: emergent motion, instant, one pulse, static under Reduce Motion; emergency-stop path untouched | passed | SEQ-0037: AuraEmergencyBadge (AuraDesign.swift) in header (new) + panel (restyled); Motion.emergent one-shot transition; emergency-control test set + F-005 localization suite green unchanged |
| G2-5 | Confirmation card entrance per 11 §4 (sober, Deny-first tab order preserved); all five fail-closed paths re-verified | pending | — |
| G2-6 | Full verification loop + governance: suite ×2–3, a11y IDs, live driver leg, ADR + repo ledger + CURRENT_STATE | pending | — |
| G2-7 | Machine coherence: validator OK, all gates passed, awaiting-approval | pending | — |

## Blocked items

- none

## Next gate

G2-5 (confirmation card entrance per 11 §4; all five fail-closed paths re-verified).
