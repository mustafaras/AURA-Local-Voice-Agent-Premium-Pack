#!/bin/zsh
# Relaunch the installed AURA with the SP-011 acceptance environment.
#
# The acceptance profile is composed from environment variables that are
# inherited at launch, so quitting AURA discards them. Every attempt that
# relaunched the app through Finder or `open` silently lost the Safari,
# calendar, and contacts legs — the app came back up with the profile absent
# and reported the capabilities as simply not configured.
#
# Private values (the approved test account, the OAuth client) belong in
# `acceptance.env` beside this script, which is git-ignored. Nothing private is
# defaulted here.
#
# Usage: ./scripts/sp011-acceptance/launch-aura.sh

set -uo pipefail

APP="/Applications/AURA.app/Contents/MacOS/AURA"
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

echo "==> Launching AURA with the acceptance environment"
"$APP" >/dev/null 2>&1 &
for _ in $(seq 1 20); do
    pgrep -x AURA >/dev/null && break
    sleep 0.5
done
pgrep -x AURA >/dev/null || { echo "FAILED: AURA did not start" >&2; exit 1 }

echo "==> AURA is running (pid $(pgrep -x AURA | head -1))"
osascript "$(dirname "$0")/aura-drive.applescript" window
