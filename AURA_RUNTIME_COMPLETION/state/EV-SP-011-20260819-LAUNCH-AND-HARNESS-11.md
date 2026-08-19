# EV-SP-011-20260819-LAUNCH-AND-HARNESS-11

## Record

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-19T17:20:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == 50236eaa7e9fd83d8c8fd5078f9968a5e1c2b3fd` at the start of this attempt
- **Environment:** macOS 27.0 (26A5416b), Safari 27.0, Xcode 27.0 beta 5, Apple Silicon; user-present session with computer-use authority
- **Evidence class:** direct user-present product/process-sample/UI evidence plus deterministic source-side regression
- **Authority note:** the user approved every phase of the plan and declined Apple Developer Program enrolment; `sign_or_notarize` remains `false`, so Developer ID and notarization stay outside this prompt.

## Objective

Close the SP-011 gaps that are inside the product — not the ones that need a
credential — and make the remaining live run survivable. Five earlier attempts
each lost the run to something environmental and each loss cost a Safari
authentication.

## The leg inventory that framed this attempt

Enumerating the prompt's matrix against the existing evidence showed the
remaining work was wider than the single leg the previous record named:

| Leg | State entering this attempt |
|---|---|
| unread mail / thread summary | passed live (`EV-…-CLOSEOUT-07`) |
| draft-only mail | mutation class; no product path |
| agenda | passed live (`EV-…-LEGS-08`) |
| **free-window** | **not implemented** — the adapter exposed only `agenda(from:to:calendarIDs:)` |
| event draft | mutation class; no product path |
| approved page summary | blocked |
| injection-ignore (mail) | passed live |
| **injection-ignore (browser)** | not run |
| contacts authorization | passed live |
| **contacts non-empty read** | not run |
| revocation — Gmail | passed live, two-sided |
| **revocation — browser** | not run |
| account ambiguity / offline | passed live |

## The defect that mattered most

While reinstalling the rebuilt app, AURA stopped launching. The menu bar item
sat at "Starting", no window ever appeared, and no control was reachable by any
means — including the menu bar panel, because an `LSUIElement` app with no
window cannot be activated.

A process sample named the cause exactly:

```
AuraAppModel.bootstrap()
  AuraKernel.start() → AuraKernel.construct() → constructSafetySubsystems
    SafariBridgeAvailability.availability(transport:profileID:secretStore:)
      SafariBridgeSecretStore.pinnedPublicKey(profileID:)
        KeychainSecretStore.retrieve(forKey:)
          SecItemCopyMatching → … → ClientSession::decrypt → mach_msg_trap
```

`construct()` probed external availability inline. Each probe reads the
Keychain, `SecItemCopyMatching` blocks until securityd answers, and securityd
may first need to authorize the calling binary — which it cannot do while the
app is still launching and has no window to host the request. `SecurityAgent`
was running throughout, with no window of its own.

This is not a test-harness inconvenience. Any user whose Keychain prompts —
after an app update, for instance — would have got an application that never
starts and offers no way in.

**Fix:** `construct()` no longer probes. It records `safari-bridge` and
`productivity` as `.loading`, and `start()` dispatches
`probeExternalAvailability()` detached once the runtime is up. Nothing can
route against the unresolved placeholder, because `submitText` already
re-derives availability before every turn. Launch is now bounded by
construction alone; the window appears immediately.

The "the window cannot be reopened" symptom investigated alongside it was the
same defect: SwiftUI never presented the `Window` scene because `bootstrap()`
never returned. It resolved with the launch fix and needed no product change.

## Four further defects, each found by running the thing

1. **The section pills and the composer buttons had no accessible name.** They
   surfaced as bare `AXButton` with no label, so the live matrix had been driven
   as "button 3 of group 2 of group 1" — an address that selects the wrong
   control instead of failing when a row appears. `AuraAccessibilityID` now
   supplies stable, deliberately unlocalized identifiers for the six tabs, the
   composer, and every integration row control, keyed by capability ID.

2. **The conversation transcript was invisible to assistive technology.**
   `AuraMessageBubble` combined its children into one element, which this
   SwiftUI version exposes as an unlabelled `AXUnknown` once the bubble is
   inside a lazy stack: no value, no description, no children. Every message in
   the conversation was an anonymous blank node to VoiceOver. `.contain` keeps
   the role, the text, and the provenance lines individually reachable.

3. **Free windows were not implemented.** `agenda/free-window` is named in the
   prompt's procedure, but `CalendarReadAdapter` had one method. Added
   `CalendarFreeWindows`, a pure derivation over the agenda the capability
   already returns, reached through a `freeWindows` slot on `calendar.read` —
   the same pattern `threadSummary` uses on `mail.read`. No new capability, no
   new authorization, and a free-window answer carries no titles, so it is
   strictly less revealing than the agenda it comes from.

4. **`codesign` failed intermittently on a synced checkout.** iCloud writes
   extended attributes onto the bundle while it is being assembled, and
   codesign refuses them partway through — leaving some nested code signed and
   the rest not. `codesign-adhoc.sh` now strips immediately before each nested
   signature rather than once up front, because sync can re-add attributes
   between the first and the last.

## Live results

- **Launch:** the rebuilt app reaches `Idle` and presents its window
  immediately. Before the fix it never left "Starting".
- **A typed turn runs end to end under automation.** "when am i free" was
  submitted through the product's own composer, classified to `calendar.read`
  with the free-window slot, routed, and answered. The answer was read back out
  of the transcript by accessibility — impossible before defect 2 was fixed.
- **That turn also proved the availability path is truthful.** Calendar
  authorization had been reset to `denied` during the failed-launch episode, and
  the product said so: *"Calendar access is denied for AURA. Allow AURA in
  System Settings › Privacy & Security › Calendars."* — a blocked capability
  with an actionable remediation, not an empty agenda. The decision was reset to
  `notDetermined` with `tccutil` so the product's own grant control can raise
  the prompt during the live run.
- **Contacts remained `Connected`** across the rebuild; the Safari row remained
  `Degraded — observation is stale`, correctly, since Safari has been restarted
  since the last write.
- **Measured, not assumed:** an accessibility identifier hit costs ~1 s and a
  miss ~30 s bounded; `entire contents` intermittently returns an empty list for
  this window and is retried once. The 27-second traversal that earlier records
  described as the "Computer Use bridge closing" was a timeout, not a closure —
  no crash report exists for any of it.

## The acceptance harness

`scripts/sp011-acceptance/` — `preflight.sh` (reports every precondition and
its exact remediation, changes nothing), `launch-aura.sh` (relaunches with the
acceptance environment, which is inherited at launch and lost on quit),
`aura-drive.applescript` (addresses controls by identifier; bounded scans;
reads the transcript and the runtime status), `run-browser-legs.sh` (resumable
across interruption, so a locked screen costs time but not another
authentication), and two page fixtures served on `127.0.0.1`.

The harness deliberately does not judge whether a leg passed. It records the
answers and says where they are; the injection and post-revocation legs pass
only on a refusal, and only a person reading the answer can tell a refusal from
a summary that happens to sound cautious.

A correctness bug in the orchestration was found and fixed before use: it
waited for the transcript to change, which happens the moment the *user's* line
is appended — before the assistant has said anything. It now watches the
runtime status leave and re-enter `Idle`.

## Deterministic verification

- `./scripts/aura-test.sh /tmp/aura-sp011-final` — **21/21 bundles,
  1068/1068 tests, 0 failed**. Log SHA-256
  `e1b73b5a9c69ee075e817658e06891740c21faf2d1c65a3652a472ef6ab31364`.
- New coverage: nine cases pinning the free-window derivation (unsorted,
  overlapping, nested, all-day, out-of-range, minimum duration, inverted range,
  disjointness), four classification cases including the Turkish trigger and the
  assertion that an agenda request never acquires the slot, two routing cases
  proving the slot selects a different adapter method on the same capability,
  four accessibility-identifier cases (uniqueness, and that no identifier
  carries localized text), five launch-path cases asserting construction
  contains no external probe, and four cases turning "mutation and send are
  excluded" from prose into an assertion that fails if a send path appears.
- All four governance validators exit 0; 38/38 governance unit tests pass.

## Artifacts

- `/Applications/AURA.app/Contents/MacOS/AURA` — SHA-256 `d1c854a3d20f5cfe712bb62c6da63679991f16cd403b8a4a77b54af7173c2235` (superseded by the transcript-accessibility rebuild in the same session)
- Locally signed with the stable local identity; **not** Developer ID signed, notarized, or release class.

## Falsifier

Falsified if `AuraKernel.construct()` regains a call that reads the Keychain;
if a capability reports `.ready` before its probe has resolved; if a free-window
answer contains an event title, location, or attendee; if the free-window slot
reaches any capability other than `calendar.read`; if a transcript message is
again unreachable by accessibility; or if any accessibility identifier changes
with the interface language.

## Scope, limitations, and verdict

- **Closed here:** the launch-blocking Keychain probe, the free-window leg's
  implementation and routing, the transcript accessibility defect, the
  unaddressable controls, the signing flake, and the explicit-exclusion evidence
  for mutation and send.
- **Not closed:** the approved-page summary, the browser injection-ignore leg,
  the browser revocation leg, and the contacts non-empty read. The first three
  need Safari's `Allow Unsigned Extensions`, which requires a credential and
  resets on every Safari restart; the fourth needs a disposable contact created
  by hand, since three programmatic routes were refused by TCC in an earlier
  attempt.
- **Free-window live proof is partial.** The turn ran end to end and the
  capability answered truthfully, but with calendar authorization denied at the
  time the answer was a refusal rather than a list of windows. A non-empty
  free-window read is owed by the live run.
- **The extension's ~13 s click-to-write latency is instrumented, not yet
  measured.** `SafariWebExtensionHandler` now logs `sign-and-write` and
  `accept-total` durations; the numbers need one live click to collect. No fix
  has been made on the strength of a guess.
- **Mutation/send:** still explicitly excluded, and now asserted.
- **Canonical SP-011 verdict:** **blocked, not completed.** SP-012 is not safe
  to start.
- **Next safe action:** run `preflight.sh`, then `run-browser-legs.sh`, with the
  operator supplying the Safari authentication, the extension enablement, the
  toolbar clicks, the calendar grant, and one disposable contact.
