# SP-011 live acceptance harness

These scripts exist because SP-011's remaining legs are **live** legs: they
cannot be closed by a test, only by running the product against real Safari,
real EventKit, and a real authentication. Five earlier attempts each got part
of the way and then lost the run to something environmental — a locked screen,
a Safari restart that discarded the unsigned-extension setting, a window that
moved to another Space, or an AURA relaunch that dropped its acceptance
environment. Each loss cost an authentication and a retry.

The harness does not make the run automatic. It makes the run **resumable**,
and it fails loudly and early instead of clicking the wrong thing.

## What each piece does

| Script | Purpose |
|---|---|
| `preflight.sh` | Reports every precondition and its exact remediation. Changes nothing. Run it before spending an authentication. |
| `launch-aura.sh` | Relaunches the installed AURA through LaunchServices with the acceptance environment, which is inherited at launch and lost on quit. It must not be exec'd from a shell: a terminal-exec'd app is not the responsible process for its own TCC requests, so its calendar and contacts decisions get recorded against the terminal's app instead. |
| `serve-fixtures.sh` | Serves the two page fixtures on `127.0.0.1` for the browser legs. |
| `aura-drive.applescript` | Addresses AURA's controls by accessibility identifier and reads the transcript. |
| `run-browser-legs.sh` | Runs the approved-page, injection-ignore, and revocation legs, recording each completed step so a re-run resumes. |

## Order

```
./scripts/build-app-bundle.sh && ./scripts/codesign-adhoc.sh   # if sources changed
./scripts/sp011-acceptance/launch-aura.sh
./scripts/sp011-acceptance/serve-fixtures.sh &                 # separate shell
./scripts/sp011-acceptance/preflight.sh
./scripts/sp011-acceptance/run-browser-legs.sh
```

## What the harness deliberately does not do

- **It does not decide whether a leg passed.** It records the answers and says
  where they are. The injection and post-revocation legs pass only on a
  refusal, and only a person reading the answer can tell a refusal from a
  summary that happens to sound cautious.
- **It does not supply the Safari authentication.** The unsigned-extension
  setting requires a credential and resets on every Safari restart. Developer
  ID signing plus notarization removes it entirely and is the production
  answer; that is owned by R11, not by this harness.
- **It does not create fixtures in Contacts or Calendar.** Those are made by
  hand, under the operator's own authorization, and deleted afterwards.

## Private values

`acceptance.env` beside this file is git-ignored and is the only place the
approved test account and OAuth client belong. Nothing private is defaulted in
any script here, and nothing private is written to any log this harness
produces.
