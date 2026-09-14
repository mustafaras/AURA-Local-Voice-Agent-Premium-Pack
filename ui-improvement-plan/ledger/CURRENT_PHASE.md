# UI Plan — Current Phase State

updated: 2026-09-13T16:36:21Z
active_phase: UI-2
phase_status: awaiting-approval
next_phase: UI-3
last_seq: 41

## Gates (mirror of prompts/UI-2.prompt.md §Gates — must match 1:1)

| Gate | Description (short) | Status | Evidence |
| --- | --- | --- | --- |
| G2-1 | Status pill transitions use AuraDesign.Motion tokens; one choreography owner per moment | passed | SEQ-0034: AuraDesign.swift:290-336 — `.smooth` on dot fill + glass tint (colour), `.standard` + `.id`/`.transition` on title/detail (geometry); view-construction loop extended for all 8 statuses; grep proves zero raw durations outside the Motion token block |
| G2-2 | Listening pulse driven by real AudioLevelBridge.inputLevel — transform-only | passed | SEQ-0035: AuraDesign.swift — nonisolated listeningPulseScale (0.9-1.15x), bare .scaleEffect, no animation keyed on level; both real call sites wired; UI2LiveStatusFeedbackTests.swift new (3 tests) |
| G2-3 | @Published isSpeakingResponse from real TTS events; ≤3-bar equalizer; no synthetic source in demo paths | passed | SEQ-0036: AuraAppModel_Runtime.swift subscribes TTSStartedEvent/TTSStoppedEvent -> setSpeakingResponse; AuraEqualizer (AuraDesign.swift) beside pill in header + menu bar panel; event-mapping test covers all 4 stop reasons; grep proves single writer, zero synthetic constructions |
| G2-4 | Emergency badge: emergent motion, instant, one pulse, static under Reduce Motion; emergency-stop path untouched | passed | SEQ-0037: AuraEmergencyBadge (AuraDesign.swift) in header (new) + panel (restyled); Motion.emergent one-shot transition; emergency-control test set + F-005 localization suite green unchanged |
| G2-5 | Confirmation card entrance per 11 §4 (sober, Deny-first tab order preserved); all five fail-closed paths re-verified | passed | SEQ-0039: AuraMenuView_Content.swift conversation-tab call site only -- .transition + Motion.emergent, no overshoot; AuraConfirmationCard body untouched (Deny-first preserved by construction); Settings-tab path deliberately left untouched (EV-SP-030-20260831-R11-LIVE-GATE-02 risk); full fail-closed test set (dismiss/supersede/window-close/emergency-stop/60s-expiry) green unedited |
| G2-6 | Full verification loop + governance: suite ×2–3, a11y IDs, live driver leg, ADR + repo ledger + CURRENT_STATE | passed | SEQ-0040: suite x2 exit 0 (176/28); a11y IDs zero-diff since UI-1 close; live driver leg confirmed the header emergency badge appears on a real ⌘⇧Esc trigger; ADR-060 + PROJECT_LEDGER + CURRENT_STATE all written |
| G2-7 | Machine coherence: validator OK, all gates passed, awaiting-approval | passed | SEQ-0041: cognitive completion gate answered fresh; all 7 gates passed; phase_status set to awaiting-approval; validator run below confirms |

## Blocked items

- none

## Next gate

None — all 7 UI-2 gates passed. Awaiting the owner's UI-2 -> UI-3 approval.
