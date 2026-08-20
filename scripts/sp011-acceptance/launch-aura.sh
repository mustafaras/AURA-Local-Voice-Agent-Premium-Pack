#!/bin/zsh
# Relaunch the installed AURA with the SP-011 acceptance environment.
#
# The acceptance profile is composed from environment variables that are
# inherited at launch, so quitting AURA discards them. Every attempt that
# relaunched the app through Finder or a bare `open` silently lost the Safari,
# calendar, and contacts legs — the app came back up with the profile absent
# and reported the capabilities as simply not configured.
#
# The obvious fix — exec the bundle's binary from this shell so it inherits the
# environment — is wrong, and it cost SP-011 two attempts. macOS attributes a
# TCC request to the *responsible* process, and a binary exec'd from a terminal
# is not responsible for itself: its ancestor is. So AURA's calendar and
# contacts prompts were recorded against the terminal's app (here Visual Studio
# Code), AURA never appeared in System Settings › Privacy & Security, and
# `tccutil reset ... ai.aura.local.agent` reported success while changing
# nothing, because there was no AURA decision to reset. The calendar row then
# read `denied` — truthfully — because the *terminal's* calendar decision was
# `denied`, and the contacts row read `ready` for the same reason inverted.
#
# `open --env` launches through LaunchServices, so AURA is its own responsible
# process and still inherits the profile. Both properties are required; neither
# alone runs the matrix.
#
# Private values (the approved test account, the OAuth client) belong in
# `acceptance.env` beside this script, which is git-ignored. Nothing private is
# defaulted here.
#
# Usage: ./scripts/sp011-acceptance/launch-aura.sh

set -uo pipefail

APP_BUNDLE="/Applications/AURA.app"
APP="$APP_BUNDLE/Contents/MacOS/AURA"
ENV_FILE="$(dirname "$0")/acceptance.env"

if [[ ! -x "$APP" ]]; then
    echo "FAILED: $APP is not installed. Run scripts/build-app-bundle.sh first." >&2
    exit 2
fi

# Non-private defaults. `example.com` is the approved read fixture host and
# `localhost` serves the injection fixture; both are deliberately explicit so
# no page outside them can be read.
export AURA_SP011_LIVE_ACCEPTANCE=1
export AURA_SP011_ENABLE_CALENDAR=1
export AURA_SP011_ENABLE_CONTACTS=1
export AURA_SP011_SAFARI_PROFILE_ID="${AURA_SP011_SAFARI_PROFILE_ID:-personal}"
export AURA_SP011_SAFARI_EXTENSION_ID="${AURA_SP011_SAFARI_EXTENSION_ID:-com.aura.safari-extension}"
export AURA_SP011_SAFARI_ALLOWED_HOSTS="${AURA_SP011_SAFARI_ALLOWED_HOSTS:-example.com,localhost}"

if [[ -f "$ENV_FILE" ]]; then
    echo "==> Loading private acceptance values from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "==> No acceptance.env; mail legs will be unconfigured (Safari/calendar/contacts still run)"
fi

if pgrep -x AURA >/dev/null; then
    echo "==> Quitting the running AURA"
    osascript -e 'tell application "AURA" to quit' >/dev/null 2>&1
    for _ in $(seq 1 20); do
        pgrep -x AURA >/dev/null || break
        sleep 0.5
    done
    pgrep -x AURA >/dev/null && { echo "FAILED: AURA did not quit" >&2; exit 1 }
fi

# Every AURA_* variable in scope is forwarded, so a value added to
# `acceptance.env` reaches the app without editing this script.
launch_args=()
for name in ${(k)parameters}; do
    [[ "$name" == AURA_* ]] || continue
    launch_args+=(--env "$name=${(P)name}")
done

echo "==> Launching AURA through LaunchServices with the acceptance environment"
open -a "$APP_BUNDLE" "${launch_args[@]}" || {
    echo "FAILED: open could not launch $APP_BUNDLE" >&2; exit 1
}
for _ in $(seq 1 20); do
    pgrep -x AURA >/dev/null && break
    sleep 0.5
done
pgrep -x AURA >/dev/null || { echo "FAILED: AURA did not start" >&2; exit 1 }

# A responsible-process regression is silent at launch and only shows up as a
# permission row that reports someone else's decision, so it is asserted here.
aura_pid="$(pgrep -x AURA | head -1)"
if [[ "$(ps -o ppid= -p "$aura_pid" | tr -d ' ')" != "1" ]]; then
    echo "FAILED: AURA was not launched by LaunchServices; its TCC decisions" >&2
    echo "        would be attributed to this terminal, not to AURA." >&2
    exit 1
fi

echo "==> AURA is running (pid $(pgrep -x AURA | head -1))"
osascript "$(dirname "$0")/aura-drive.applescript" window
