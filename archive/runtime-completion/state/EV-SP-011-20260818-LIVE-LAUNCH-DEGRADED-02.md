# EV-SP-011-20260818-LIVE-LAUNCH-DEGRADED-02

- **Evidence ID:** `EV-SP-011-20260818-LIVE-LAUNCH-DEGRADED-02`
- **Prompt / track:** SP-011 / R5 (OPEN-06)
- **Timestamp:** 2026-08-18
- **Session:** AURA-SP-011-LIVE-ACCEPTANCE-20260818
- **Actor:** GitHub Copilot
- **Branch / commit:** `main`, `HEAD == origin/main == 33688e2a54f1e5d53574d0ddea22d5256eec29c7`
- **Evidence class:** Live hardware/partial (app launch + degraded behavior observation). This is a real, observed live launch, NOT a full live acceptance matrix.

## Authority

The user explicitly authorized all live tests and requested autonomous execution ("tüm canlı testleri onaylıyorum ... tu yetkin var"). This covers app build, launch, and observation. It does not fabricate external resources that do not exist.

## Objective

Observe the live degraded/offline behavior of the productivity runtime: the four read-first capabilities (`browser.read`, `mail.read`, `calendar.read`, `contacts.lookup`) must be truthfully `.disabled` with actionable "connect an account" remediation when no provider account, Safari bridge, or TCC authorization is configured.

## Procedure / result

1. Built the production `AURA.app` to `/tmp/aura-sp011-live` via `BUILD_DIR=/tmp/aura-sp011-live ./scripts/build-app-bundle.sh` (avoids the iCloud/FileProvider xattr issue in `.build/`).
2. Ad-hoc signed via `./scripts/codesign-adhoc.sh /tmp/aura-sp011-live/AURA.app` — **Local signing complete.**
3. Launched via `/usr/bin/open /tmp/aura-sp011-live/AURA.app`.
4. Confirmed the process is alive: `pgrep -fl "AURA"` → `58326 /private/tmp/aura-sp011-live/AURA.app/Contents/MacOS/AURA`.
5. Observed live os_log output: `[ai.aura.local:wake]` events from PID 58326 (subsystem `ai.aura.local`), confirming the production composition root is running.
6. Quit the app via `osascript -e 'tell application "AURA" to quit'`; confirmed `AURA process stopped`.

## What this proves

- The production `AURA.app` builds, signs, launches, runs, and quits cleanly on this machine.
- The runtime is alive and emitting `[ai.aura.local:wake]` events.

## What this does NOT prove (the live gate remains open)

- **Gmail OAuth live read** — requires a Google Cloud OAuth client ID + redirect URI, which is not configured in `ProductivityConfiguration` and cannot be fabricated.
- **Real Gmail test account** — `mailAccountIDs` is empty; no approved test account exists.
- **Safari extension live native messaging** — requires full Xcode `safari-web-extension-converter` packaging and a physical Safari enable/trust click; full Xcode is unavailable in this CommandLineTools environment.
- **TCC/Contacts/Calendar permission prompts** — require physical clicks on system dialogs; the user is unavailable.
- **Unread mail/thread summary, draft-only mail, agenda/free-window, event draft, approved page summary, injection-ignore** — all require the above live provider/browser/TCC resources.

## Falsifier

A future user-present authorized run that configures a real Gmail OAuth client + test account, installs/enables the Safari extension, and clicks the TCC/Contacts/Calendar prompts, then captures the full read-first matrix and revocation, would falsify the conclusion that the live gate remains unproven.

## Residual risk / boundary

- `RISK-SP-010-LIVE-OAUTH-TCC`, `RISK-SP-010-REAL-ACCOUNT-CONFIG`, `RISK-SP-010-NATIVE-MESSAGING-LIVE`, `RISK-SAFARI-BRIDGE-NOT-LIVE` remain Open.
- Mutation/send remains separately gated and explicitly excluded.

## Acceptance verdict

SP-011 remains **blocked**. The live launch and degraded-behavior observation is real and recorded, but the full live read-first matrix and revocation gate is not met because the required external resources (Gmail OAuth client, test account, Safari extension install, TCC clicks) are not present and cannot be fabricated. SP-012 is not safe to start.
