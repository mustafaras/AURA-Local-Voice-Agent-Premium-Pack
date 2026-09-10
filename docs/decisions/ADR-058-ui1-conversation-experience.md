# ADR-058: UI-1 Conversation Experience — Level Bridge, Markdown Draft Stream, and the Orb

- Status: Accepted
- Date: 2026-09-10
- Owners: UI track (UI-1)
- Supersedes: none
- Superseded by: —

## Context

UI-1 rebuilds the highest user-time surface: the conversation tab. The verified
baseline had no per-frame level event (raw 16 kHz mono samples travel via
`AudioFrameEvent` + `AuraAudio.frame(sequenceIndex:)`; the event deliberately
carries no sample data), no markdown rendering (plain `Text` in
`AuraMessageBubble`), a partial transcript detached from the conversation flow
(a `GroupBox` below the scroll), no auto-scroll, no thinking placeholder, and no
listening instrument beyond the status pill.

Constraints that shaped the design: the transcript data structure
(`AuraConversationMessage`) is in-memory only and must not change; no token
streaming exists (Ollama replies arrive atomically as `ResponsePlanEvent.summary`);
the level stream must be transform-only rendering (never `withAnimation` on
`inputLevel`, 11-motion-system.md §5); every user-facing string goes through
`AuraCopy` with genuine Turkish; privacy posture requires the level surface to be
a scalar with zero persistence/logging (06-cross-cutting-constraints.md §6); and
the shared bus contract must not widen for a UI-only consumer.

## Decision

1. **`AudioLevelBridge` (new, read-only bus subscriber).** Mirrors
   `AudioSampleBridge`'s composition: subscribes `AudioFrameEvent` (+ a
   capture-stopped reset), fetches the real frame via
   `AuraAudio.frame(sequenceIndex:)` with exact-sequence lookup, computes
   RMS→dBFS with the identical formula as `VoiceActivityDetector.energyDB`
   (so meter and VAD cannot disagree), normalizes to 0…1 over a −60…0 dB
   window, and publishes a throttled scalar (20 Hz, inside the 15–30 Hz
   budget) as `@Published var inputLevel: Double?`. `nil` is the honest idle:
   armed only by the same status transitions the status pill renders
   (`pushToTalk` arms; `submitText` disarms; every `ConversationStateEvent`
   mirrors; capture-stop resets). No sample buffering beyond the scalar; no
   persistence; no logging. The app model owns the bridge and mirrors the
   scalar to `AuraAppModel.inputLevel`, so every surface reads one value.
   The bridge attaches to the kernel's real capture actor + bus during
   `bootstrap()` before `kernel.start()`, preserving the subscribe-before-
   publish ordering every bus subscriber obeys.

2. **Inline-only markdown (G1-2).** Assistant messages render through
   `AuraDesign.inlineMarkdownOrPlain`: `AttributedString` with
   `.inlineOnlyPreservingWhitespace` (SDK-verified member name; the prompt's
   `-Whitespace**s**` spelling does not exist in the installed Foundation),
   falling back on any parse throw to the raw text verbatim — content is
   never dropped. Bold/italic/inline-code/links carry presentation intents;
   block syntax (headings/lists/fences) degrades to plain text by design —
   no block semantics are claimed. User/system bubbles keep the existing
   `AuraMessageBubble`.

3. **Draft bubble in the stream (G1-3).** The partial transcript renders as
   `AuraDraftBubble` inside the transcript `LazyVStack` (replacing the
   detached GroupBox): user-role styling with a dashed accent, in-place text
   updates (`.animation(nil, value: text)` — no re-entry animation per 11 §4),
   one combined VoiceOver element announcing "Draft: [text]" via the new
   `a11y.draftPrefix` key ("Draft" / "Taslak").

4. **Honest auto-scroll (G1-4).** `ScrollViewReader` + a bottom anchor id;
   `onScrollGeometryChange` tracks at-bottom within a 24 pt epsilon. The
   stream scrolls the user only while they are at the bottom; scrolling up
   pauses following and shows the `conversation.jumpToLatest` affordance
   ("Jump to latest" / "En sona git"). Message arrivals and status changes
   follow only when engaged; the view never fights the user's scroll.

5. **Thinking placeholder (G1-5).** `AuraThinkingIndicator` renders only
   while the real status is `.thinking`, where the answer will land: three
   static dots at rest luminance + copy "AURA is thinking…" /
   "AURA düşünüyor…". No spinner, no fake progress (causal-motion rule).

6. **The Orb (G1-6).** `AuraOrb` (Canvas-based) heads the conversation
   (13-advanced-surfaces.md §2). Inputs are exactly `status`,
   `inputLevel: Double?`, `isSpeakingResponse` (+ render args: language,
   restricted reason). `AuraOrbStateMapping.resolve` is pure logic — no
   time, no randomness, no environment — mapping all six behaviors: idle/
   starting/stopped hairline ring at rest luminance; listening ring = live
   level (span/weight/aura follow the scalar; nil → minimum arc, never a
   fake reading); thinking = single orbiting arc (120°/s pure function, 30
   fps TimelineView, Reduce Motion → static pose, never blank); speaking =
   ≤3-bar equalizer from the real TTS state; restricted = amber dashed
   segment + reason text (never color alone); error = critical segment at
   full opacity. No synthetic data path exists.

7. **Ambient canvas (G1-7).** The transcript surface sits on
   `palette.void` with a `palette.hairline` stroke (L0 base under L1
   content per the materials ladder); instrument spacing from
   `AuraDesign` tokens; the pinned Typography/Spacing/Radius tables are
   referenced, never mutated (pinned counts 1/1/1/1/1 before = after);
   `AuraConversationMessage` untouched (ProductUIState diff: 57 insertions,
   0 deletions — additive copy keys only).

## Alternatives considered

- **Continuous per-frame level event on the shared bus** (emitted from the
  VAD): rejected — it widens the bus contract for one consumer; the
  read-only bridge is additive and private to the UI layer (the documented
  doc-01 §4.5 alternative analysis).
- **Full markdown rendering (block semantics, custom block splitter)**:
  rejected for UI-1 — inline-only is the honest subset that cannot misrender
  untrusted model output as page structure; a block splitter adds a renderer
  surface without a streaming backend to feed it.
- **Animating the draft/thinking placeholders**: rejected — violates the
  causal-motion rule (11 §2); status changes are the events.
- **Publishing the level from the app model's own sampling of the ring
  buffer on a timer**: rejected — a second sampling path would drift from
  the VAD's frame accounting; observing the real event stream keeps one
  source of truth.

## Security and privacy impact

The bridge publishes a scalar level only, in-session only, in-memory only;
no sample data leaves the audio layer, nothing persists, nothing logs. The
markdown renderer applies text styling only — it never evaluates links
beyond the attributed-string link attribute and never executes anything.
Copy keys and identifiers follow the existing governance (unlocalized
identifiers, EN/TR copy pairs). The level meter reflects the same status
the pill announces — it leaks no state the UI did not already show.

## Operational impact

One extra bus subscriber at 20 Hz worst case (throttled; fetch skipped for
suppressed events). The Orb's continuous motion is the thinking arc only,
capped at 30 fps and disabled under Reduce Motion. No new subsystem, no
configuration surface, no migration.

## Migration

None. The bridge is additive (delete file + tests to roll back); view
changes revert per-file; the transcript state machine is untouched, so
reducer tests prove no behavior drift.

## Validation evidence

- `./scripts/aura-test.sh /tmp/aura-ui1-build AURAIntegrationTests` → exit 0,
  164 tests / 27 suites / 0 failures (was 137/25; +27 UI-1 tests).
- Full 22-target loop ×2 back-to-back: exit 0, 22/22 PASSED, 0 failed
  bundles (logs `/tmp/aura-ui1-full1.log`, `/tmp/aura-ui1-full2.log`).
- Bridge pins: throttle cadence (static + deterministic-clock live pass),
  nil-when-not-listening, honest-idle reset, stale-sequence skip,
  VAD-identical energy math, normalization clamps, scalar-only shape.
- Markdown pins: intents for bold/italic/code, link attribute, block-syntax
  degradation, 4-case malformed-input verbatim fallback, options pin.
- Orb matrix: all 6 statuses + level-gating + Turkish readouts + orbit
  purity (9 tests).
- View-construction smoke over all 8 statuses; a11y identifier uniqueness +
  never-localized for the 4 new IDs; copy guard green (allKeys-driven).
- Live driver leg (aura-drive.applescript): **blocked by host lock screen**
  — every AX AppleEvent timed out / reported 0 windows for every process
  (screen capture /tmp/aura-screen.png shows the login window). Bundle
  /tmp/aura-ui1-app/AURA.app built + codesign-verified with the new surface;
  the leg requires an unlocked interactive session.

## Consequences

UI-2 consumes the tested `AudioLevelBridge` and `AuraAppModel.inputLevel`
without new plumbing. The Orb's speaking bars use the binary TTS signal
until a real TTS level event exists (a recorded UI-2 decision point). The
markdown renderer stays inline-only until the backend streams; widening it
then is additive. The live driver leg remains an open obligation for the
next unlocked-session turn (recorded in the phase ledger).