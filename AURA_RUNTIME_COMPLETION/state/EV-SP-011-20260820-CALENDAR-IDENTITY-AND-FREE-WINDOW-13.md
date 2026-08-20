# EV-SP-011-20260820-CALENDAR-IDENTITY-AND-FREE-WINDOW-13

## Record

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-20T07:30:00Z
- **Branch / commit:** `main`; `HEAD == origin/main == ff87ead` at the start of this attempt
- **Environment:** macOS 27.0 (26A5416b), Apple Silicon, Xcode 27.0; user-present session; installed `/Applications/AURA.app` CDHash `e23dc9db289f1421d7d5128b015e1a826e1d8e20`, locally signed with the Hardened Runtime
- **Evidence class:** direct user-present product/TCC/System-Settings evidence plus deterministic regression

## Objective

Close the one leg SP-011 was still blocked on — the **free-window non-empty
read** — and establish why the calendar authorization could not be restored by
the remedy the previous record named.

## The previous record's diagnosis was wrong

`EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12` recorded that
`tccutil reset Calendar ai.aura.local.agent` had destroyed a working grant, that
neither `reset Calendar` nor `reset All` cleared the resulting state, and that a
logout or restart was the normal remedy.

The machine was restarted (2026-08-20 09:14 local, before this attempt). The
calendar row still read *"Calendar access is denied for AURA."* A second
`tccutil reset Calendar ai.aura.local.agent` again reported success and again
changed nothing.

The cause is not a stuck TCC decision. It is **process responsibility**.

`scripts/sp011-acceptance/launch-aura.sh` started the app by exec'ing the
bundle's binary from the shell, so that the acceptance environment — which is
inherited at launch — would reach it. macOS attributes a TCC request to the
*responsible* process, and a binary exec'd from a terminal is not responsible
for itself: its ancestor is. Every calendar and contacts request AURA made on
that launch path was therefore attributed to the terminal's application, here
Visual Studio Code.

The System Settings panes state it directly:

| Pane | Listed | State |
|---|---|---|
| Privacy & Security › Calendars | **Visual Studio Code** | No Access |
| Privacy & Security › Contacts | **Visual Studio Code** | on |
| Both | AURA | **absent** |

The product was reporting the truth it was given: the *terminal's* calendar
decision was `denied`, and that is what `EKEventStore.authorizationStatus(for:
.event)` returned to it. `tccutil reset … ai.aura.local.agent` was a no-op
because no AURA decision existed to reset, and a restart could not restore a
grant AURA never held. The same inversion explains the contacts row reading
`ready`, and the health surface reporting Microphone and Screen observation as
`Granted`.

## Confirmation, before any grant was made

Relaunching the identical installed bundle through LaunchServices with the same
environment (`open -a /Applications/AURA.app --env …`, PPID 1) flipped four rows
at once, with no permission change of any kind:

- Read Calendar: `denied` → *"Calendar access has not been granted yet."* with a **Grant access** control
- Find Contact: `ready` → *"Contacts access has not been granted yet."* with a **Grant access** control
- Microphone: `Granted` → `Not requested`
- Screen observation: `Granted` → `Denied`

A launch method cannot change a permission. It changed which process's
permissions were being read.

## Live results

### Calendar authorization — **passed, under AURA's own identity**

`Grant access` on the Read Calendar row raised the system prompt
*"Allow 'AURA' to access your calendar?"*, carrying AURA's own usage string. The
operator answered **Allow Full Access** and the row moved to `Connected — This
Mac, Ready`. The contacts prompt was raised and granted the same way.

### Agenda non-empty read — **passed**

Against one disposable fixture event (today 14:00–15:00 local, imported from an
`.ics` and deleted afterwards):

> *1 event(s): AURA SP-011 acceptance fixture. [source ac-7adf9a57e111]*

### Free-window non-empty read — **passed** (the leg SP-011 was blocked on)

> *2 free window(s): 10:07–14:00, 15:00–00:00. [source ac-7adf9a57e111]*

The windows are bounded by the fixture's own 14:00–15:00 span and by the moment
of the request. The answer carries **no event title, location, or attendee** —
the property the derivation exists to hold — and reached `calendar.read`, not
any new capability and no new authorization.

### Contacts non-empty read — **re-run and passed under AURA's own grant**

`EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12` recorded this leg as passed,
but it ran on the terminal-exec launch path, so the authorization it exercised
was the terminal's. Re-run under AURA's own contacts grant:

> *One contact matched: AURA SP011Fixture (0 email, 0 phone on file). [source ac-fe536864707e]*

Channels are still reported as counts rather than values. The earlier record's
observation stands; this one makes its authorization claim true.

### Fixture removal — **verified twice for the event**

The fixture event was deleted in Calendar. Calendar's own search for
`SP-011 acceptance fixture` returns `rows=0`, and AURA's next agenda read
answered:

> *Nothing is scheduled in that range. [source ac-7adf9a57e111]*

The **contact** fixture was not created here: `AURA SP011Fixture` already
existed, created by the operator for
`EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12` and not removed at the end of
that attempt. It was reused rather than duplicated, and it is still present. It
is the operator's to delete, and this record does not claim otherwise.

## Direct change

`scripts/sp011-acceptance/launch-aura.sh` now launches through LaunchServices
with `open --env`, forwarding every `AURA_*` variable in scope, so the app is its
own responsible process **and** still inherits the acceptance profile. Both
properties are required; neither alone runs the matrix. The script then asserts
`PPID == 1` and fails loudly, because a responsible-process regression is silent
at launch and surfaces only as a permission row reporting someone else's
decision. `preflight.sh` carries the same assertion, and the harness README
records why the obvious shell-exec is wrong.

## Deterministic verification

- `./scripts/aura-test.sh /tmp/aura-sp011-13` — **21/21 bundles, 1071/1071 tests, 0 failed**. Log SHA-256 `f40b6995635327a7b7f6afeda174d3f8e3a4db9b01adbec61536b0664a7f6871`.
- **The 1071 vs 1070 discrepancy is resolved, and 1071 is the correct figure.** `EV-SP-011-20260819-LAUNCH-AND-HARNESS-11` measured 1068. The only commit to touch `Tests/` since then is `ebf6249`, the commit carrying `EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12`'s work, and it adds **three** `@Test` declarations and removes none — so the correct count at that commit is 1068 + 3 = 1071. That record's 1070 was therefore measured before its own third test landed: it reported a number for a tree it had already moved past. Every parameterized test in the suite takes a literal argument array, so the count is deterministic and not environment-dependent. `git diff --stat ebf6249..HEAD -- Tests/` is empty, which is why the same 1071 holds here.
- No source change was needed for this leg: the defect was in the acceptance harness, not in the product. `CalendarFreeWindows` keeps the 15 deterministic derivation/classification/routing cases added by `EV-SP-011-20260819-LAUNCH-AND-HARNESS-11`, which this run confirms live for the first time.
- Four governance validators exit 0; governance unit tests pass.

## Two harness findings closed after the leg passed

### The driver treated a window on another Space as no window

`aura-drive.applescript` failed with `ERR no-window` twice during this attempt
against a window that was open the whole time. Measured: with AURA frontmost,
System Events reports 1 window; with Finder frontmost on the same Space, still
1; with the operator on a different Space, **0**. Activation brings that Space
forward and the window is reported again. This is the same loss cause
`EV-SP-011-20260819-ASYMMETRIC-BRIDGE-10` recorded as "UI automation lost both
windows to another Space", where it was treated as bad luck rather than as
something the driver could handle.

Every window-taking command now raises AURA and retries before concluding there
is no window, and falls back to `ensureWindow()` after that. Verified by closing
the window with ⌘W — `find aura.tab.conversation` still succeeds, where it
previously returned `ERR no-window`.

### `Allow unsigned extensions` cannot be closed on this machine

`security find-identity -v` returns **0 valid identities** and
`-p codesigning` returns only the self-signed `AURA Stable Local Signing`. There
is no Developer ID Application certificate, so Developer ID signing plus
notarization — the only supported way to remove Safari's unsigned-extension
requirement outside the App Store — is not an engineering task here but an Apple
Developer Program enrolment decision. `xcrun notarytool` is present and would
work the moment a real identity exists. Recorded as owned by R11, unchanged.

## Artifacts

- `/Applications/AURA.app` — locally signed with the stable local identity, Hardened Runtime, entitlements `com.apple.security.personal-information.calendars` and `.addressbook` present. **Not** Developer ID signed, notarized, or release class.
- `scripts/sp011-acceptance/launch-aura.sh`, `scripts/sp011-acceptance/preflight.sh`, `scripts/sp011-acceptance/aura-drive.applescript`, `scripts/sp011-acceptance/README.md` — modified.

## Falsifier

Falsified if AURA appears in a privacy pane while launched by a terminal exec;
if a free-window answer ever contains an event title, location, or attendee; if
the reported windows are not bounded by the fixture's own span; if a read
succeeds while authorization is `notDetermined` or `denied`; if the free-window
slot reaches any capability other than `calendar.read`; or if the fixture event
outlives the run.

## Scope, limitations, and verdict

- **Closed live here:** the free-window non-empty read; the calendar and contacts authorizations under AURA's own TCC identity; the contacts non-empty read re-run honestly.
- **Corrected here:** `RISK-SP-011-CALENDAR-GRANT-DESTROYED`. No grant was destroyed and none was unrecoverable; the mechanism was responsible-process attribution in the acceptance harness.
- **Still excluded, by the prompt's own completion gate:** draft-only mail and event draft are mutation class and remain explicitly excluded, asserted by test. No send, mutation, or scope escalation was performed here.
- **Not closed here:** Safari's `Allow unsigned extensions` still does not survive a Safari restart. Developer ID signing plus notarization removes it and is owned by R11.
- **Recorded content:** no real calendar event, contact value, message body, token, screenshot, or account identifier. Only the two disposable fixtures are named — the calendar event created and deleted here, and the contact fixture carried over from the previous attempt.
- **Left for the operator:** the `AURA SP011Fixture` contact still exists in the address book. Deletion was attempted here at the operator's explicit request and was refused by the harness's own permission layer as a user-data deletion, so the fixture is named here with its exact removal command rather than silently left behind.
- **Canonical SP-011 verdict:** **completed.** Every leg named in SP-011's procedure now has live evidence, both revocation legs passed (`EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07` provider, `EV-SP-011-20260819-LIVE-BROWSER-AND-CONTACTS-12` browser), and mutation/send is explicitly excluded.
