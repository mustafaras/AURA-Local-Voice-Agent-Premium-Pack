# UI-1: Conversation Experience

**Priority:** P1 — first implementation phase.
**Surfaces touched:** `AuraMenuView_Content.swift` (conversation tab, composer), `AuraDesign.swift` (`AuraMessageBubble`), `AuraAppModel_Runtime.swift` (event wiring), new `AudioLevelBridge`.
**Depends on:** nothing. Introduces the `AudioLevelBridge` reused by UI-2.

---

## 1. Current state (verified)

- The conversation tab renders messages as plain `Text` inside `AuraMessageBubble` (`AuraDesign.swift:181-255`); there is no markdown, no list/code-block rendering anywhere in the path. `AuraConversationMessage` carries only `role`, `text`, `isDegraded`, `sourceSummary`, `traceSummary` (`ProductUIState.swift:10-37`).
- Assistant responses arrive atomically as `ResponsePlanEvent.summary` (`AuraAppModel_Runtime.swift:264-274`); there is no token streaming to the UI (`IntentDispatchCoordinator.swift:183`; `OllamaAPIClient` does not use streaming).
- The STT partial transcript renders in a separate `GroupBox` *below* the transcript scroll (`AuraMenuView_Content.swift:249-256`), visually detached from the conversation flow.
- There is no auto-scroll: new messages appear wherever the scroll position happens to be.
- There is no listening indicator beyond the status pill's color change and the mic button's disabled state.
- Conversation history is capped at 40 messages, adjacent duplicates deduplicated (`AuraAppModel_Runtime.swift:341-350`).
- The composer is a single-row glass container: plain `TextField` + submit button + Push-to-Talk button (`AuraMenuView_Content.swift:269-310`).

## 2. Goals

1. Assistant answers render readable rich text (headings, bold/italic, lists, inline code, code blocks) instead of raw markdown glyphs.
2. The in-flight spoken input is visible *in* the transcript as a live draft bubble, where the eye already is.
3. The transcript always shows the newest turn without manual scrolling.
4. "Thinking" and "listening" have distinct, honest, animated presence — never a fake progress bar.
5. Push-to-talk is visually embodied: a live mic-level waveform while `.listening`.

## 3. Non-goals

- Token-by-token assistant streaming (requires new plumbing from adapter event streams; the Ollama backend cannot stream at all). Revisit after the backend layer streams; the message model below is designed so streaming can be added later without a schema break.
- Message editing, reactions, threads.
- Any change to intent/policy semantics of partial transcripts (they remain display-only per `STTPartialEvent` documentation).

## 4. Proposed design

### 4.1 Markdown rendering in `AuraMessageBubble`

- Parse `message.text` at render time with `AttributedString(markdown:options:)` using the `.inlineOnlyPreservingWhitespaces` interpretation for inline styling, falling back to plain `Text` when parsing yields nothing (i.e., input was already plain).
- Block-level structure (fenced code, lists) via a lightweight block splitter before styling; fenced blocks render as `Text` with `AuraDesign.Typography.mono` on a `panelBackground` surface with horizontal scrolling inside the bubble.
- Add a `contentKind` field (`plain | markdown`, default computed) to `AuraConversationMessage` only if per-message control is needed; start with render-time detection to avoid a persisted-schema change. `AuraConversationMessage` is not persisted (conversation lives in memory, rebuilt from events), so this is a low-risk evolution point.
- Text selection stays enabled (`AuraDesign.swift:201`); Dynamic Type is preserved because styling applies to the existing relative fonts.

### 4.2 Live draft bubble for partial transcripts

- Move the partial-transcript render from the `GroupBox` below the transcript into the transcript `LazyVStack` as a trailing "draft" bubble: user-role styling with a pulsing opacity (or trailing caret), clearly distinguishable from a finalized message.
- Keep the existing accessibility behavior: the draft is a single combined element announcing "draft: [text]" via a new `a11y.draftPrefix` key.
- The GroupBox variant is removed from the conversation tab; the existing accessibility identifier surface (none today for the partial GroupBox) is unaffected.

### 4.3 Auto-scroll and composer behavior

- Wrap the transcript `ScrollView` in `ScrollViewReader`; on append of a message or a partial-transcript update, `scrollTo` the bottom anchor — animated for new messages, unanimated (or throttled) for rapid partial updates so it does not fight the user.
- Pin the auto-scroll behind a "stick to bottom" behavior: if the user has scrolled up (detected via scroll offset threshold), auto-scroll pauses and a small "jump to latest" affordance appears; tapping it re-engages following.
- After `submitText()`, focus returns to the composer field immediately (it already clears; verify focus retention when the keyboard shortcut path is used).

### 4.4 Thinking indicator

- While `model.status == .thinking`, render a three-dot breathing indicator *inside the transcript stream* as a pending assistant bubble placeholder (aligns with where the answer will land), plus a `a11y` label from a new `a11y.thinking` key.
- Removed the moment `ResponsePlanEvent` lands (the existing event wiring already clears state via `applyConversationState`); on error the placeholder collapses into the existing degraded operation message.

### 4.5 Listening waveform (`AudioLevelBridge`) — shared prerequisite for UI-2

- **New component `AudioLevelBridge`** in `Sources/AURA/`, modeled on the existing `AudioSampleBridge` composition-root glue (`Sources/AURA/AudioSampleBridge.swift:19-67`): subscribes to `AudioFrameEvent`, fetches raw samples via `AuraAudio.frame(sequenceIndex:)` (`Sources/AuraAudio/AuraAudio_Capture.swift:146`), computes per-frame RMS and peak, and republishes a throttled UI event (target ~15–30 Hz, not per 16 kHz frame).
- **Publishes to the app model:** `@Published var inputLevel: Double?` (nil = not listening). Set only while `status == .listening`; hard-guaranteed nil at all other times. No sample data ever leaves the bridge — only a scalar level. No persistence, no logging (privacy-first posture; consistent with zero-retention defaults elsewhere).
- **Render:** the composer's Push-to-Talk glass button (and, in UI-2, the status pill) gains a level-driven bar/waveform animation (5–9 vertical bars scaled by recent level history). Marked `accessibilityHidden` — the listening state is already announced by the status pill; add a static `a11y` hint on the control.
- **Honesty rule:** the waveform renders only from real captured levels; demo/mock paths (`AURA_TEXT_DEMO_SCRIPT`) render no waveform rather than a synthetic one, mirroring the `isMockDerived` labeling discipline (`AuraMenuView_Tabs.swift:586`).
- **Alternative considered:** continuous emission from `VoiceActivityDetector`'s existing RMS→dBFS (`VoiceActivityDetector.swift:114-115`). Rejected for UI-1: VAD events fire at speech start/end granularity, and adding a continuous per-frame event to the shared bus for one consumer widens the bus contract; the bridge approach is additive and private to the UI layer.

## 5. Files to touch

| File | Change |
| --- | --- |
| `Sources/AURA/AuraDesign.swift` | `AuraMessageBubble` markdown + code-block rendering; new `AuraDraftBubble`, `AuraThinkingIndicator`, `AuraLevelMeter` components |
| `Sources/AURA/AuraMenuView_Content.swift` | Transcript: draft bubble, thinking placeholder, `ScrollViewReader` auto-scroll, jump-to-latest; remove partial `GroupBox` |
| `Sources/AURA/AudioLevelBridge.swift` | **New** — level metering bridge |
| `Sources/AURA/AuraAppModel.swift` / `_Runtime.swift` | `inputLevel` publication; wire bridge in `bootstrap()`; drop it when status leaves `.listening` |
| `Sources/AURA/ProductUIState.swift` | New `AuraCopy` keys (`a11y.draftPrefix`, `a11y.thinking`, `conversation.jumpToLatest`, etc.) |
| `Sources/AURA/AuraAccessibilityIdentifiers.swift` | New identifiers (e.g. `composerLevelMeter` if it must be addressable) |

## 6. Testing and acceptance

- New unit tests: markdown renderer (plain text passthrough, inline styling, fenced block, malformed markdown fallback), level bridge (RMS math, throttle, nil-when-not-listening invariant, no-sample-exit invariant).
- `R9ProductUIStateTests` view-construction suite extended to the new components (`constructProductSurfaces`, `R9ProductUIStateTests.swift:388-433`).
- Copy table guard stays green: every new key carries real Turkish copy (`AuraCopyTableGuardTests`).
- Live acceptance: existing `scripts/sp011-acceptance/aura-drive.applescript` flow (it reads the transcript by AXIdentifier) must keep working; composer identifiers unchanged.
- Full suite via `./scripts/aura-test.sh`, each bundle rerun 2–3× per repo discipline.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Markdown parsing of untrusted model output renders unexpected content | Render only via `AttributedString` (no HTML/links unless explicitly enabled); disable link autolinking initially |
| Auto-scroll fights user scrolling | Stick-to-bottom threshold + jump-to-latest affordance |
| Waveform perceived as recording indicator beyond session | Renders only during `.listening`; documented; nil otherwise |
| Performance: re-parsing markdown on every render | Parse once per message (cache in view model layer or key off message id) |
