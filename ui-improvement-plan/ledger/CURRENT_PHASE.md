# UI Plan — Current Phase State

updated: 2026-09-12T16:20:00Z
active_phase: UI-1
phase_status: in-progress
next_phase: UI-2
last_seq: 29

## Gates (mirror of prompts/UI-1.prompt.md §Gates — must match 1:1)

| Gate | Description (short) | Status | Evidence |
| --- | --- | --- | --- |
| G1-1 | AudioLevelBridge: subscribes AudioFrameEvent, fetches via AuraAudio.frame(sequenceIndex:), throttled 15–30 Hz, @Published inputLevel nil-when-not-listening, scalar-only | passed | SEQ-0018: AudioLevelBridge.swift:38/:50/:82/:98/:112/:132; 8 tests green (164/27 suites, exit 0) |
| G1-2 | Markdown rendering: AttributedString inline-only primary path, plain-text fallback | passed | SEQ-0019: AuraDesign.swift:435-452 + AuraMarkdownMessageBubble :463; 6 tests green; SDK-verified .inlineOnlyPreservingWhitespace |
| G1-3 | Draft bubble in transcript stream; single combined a11y element via a11y.draftPrefix (EN/TR) | passed | SEQ-0020: AuraDesign.swift:518; AuraMenuView_Content.swift:356; copy ProductUIState.swift:348; a11y ID test green |
| G1-4 | Auto-scroll: stick-to-bottom + jump-to-latest, honest (no scroll while user scrolled up) | blocked | SEQ-0028: lock-screen blocker gone (driver drove a full live turn); reader repaired (positional path → `aura.conversation.transcript` identifier; 1 line → 78 lines / 5,779 chars); stick-to-bottom evidenced and affordance correctly absent while following. Still blocked on the other half: AX scroll-bar manipulation does not trigger SwiftUI `onScrollGeometryChange`, so `showJumpToLatest` never flips — a harness limitation, not a feature failure |
| G1-5 | Thinking placeholder in transcript (copy keys EN/TR) | passed | SEQ-0021: AuraDesign.swift:560; AuraMenuView_Content.swift:361; copy ProductUIState.swift:351; copy guard green |
| G1-6 | AuraOrb: Canvas-based; status/inputLevel/isSpeakingResponse; pure state→layer mapping; honesty contract | passed | SEQ-0022: AuraOrb.swift:148/:158/:203/:253/:275/:330; 9-test matrix green (all 6 statuses) |
| G1-7 | Ambient canvas: conversation surface on observatory canvas + L1 panels + instrument spacing; transcript data unchanged | passed | SEQ-0024: palette.void+hairline; pinned typography 1/1/1/1/1 unchanged; ProductUIState 57+/0-; full suite exit 0 22/22 |
| G1-8 | Full verification loop + governance: suite ×2–3, a11y IDs, live driver leg, ADR + repo ledger + CURRENT_STATE | passed | SEQ-0025: suite ×2 back-to-back (exit 0, 22/22, 0 failed); 4 a11y IDs pinned; ADR-058; PROJECT_LEDGER 276→277; CURRENT_STATE atomic rewrite; live-leg exception recorded per SEQ-0023 |
| G1-9 | Machine coherence: validator exit 0, all gates passed, phase_status: awaiting-approval | blocked | SEQ-0026: held open because G1-4 is blocked (host lock screen); validator itself OK; resolves when the leg runs, then awaiting-approval |

## Blocked items

- none

## Next gate

G1-1 (AudioLevelBridge + tests).
