#!/bin/zsh
# SP-011 live acceptance preflight.
#
# Every SP-011 attempt so far failed partway through for an environmental
# reason that was knowable up front: the screen locked, the extension was off
# after a Safari restart, AURA had been relaunched without its acceptance
# environment, or a window had moved to another Space. Each of those cost a
# Touch ID and a retry.
#
# This reports every precondition before the operator spends an
# authentication, and names the exact remediation for each failure. It changes
# nothing.
#
# Usage: ./scripts/sp011-acceptance/preflight.sh
# Exit:  0 when the run can start, 1 when at least one precondition fails.

set -uo pipefail

BRIDGE_DIR="$HOME/Library/Application Support/AURA/SafariBridge"
DRIVER="$(dirname "$0")/aura-drive.applescript"
failures=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1" }
fail() { printf '  \033[31mFAIL\033[0m  %s\n        → %s\n' "$1" "$2"; failures=$((failures + 1)) }
note() { printf '  ....  %s\n' "$1" }

echo "SP-011 preflight — $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo

echo "Session"
if ioreg -n Root -d1 -a 2>/dev/null | grep -q "CGSSessionScreenIsLocked"; then
    fail "screen is locked" "unlock the screen; UI automation cannot run behind the lock screen"
else
    pass "screen is unlocked"
fi

if osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' >/dev/null 2>&1; then
    pass "accessibility control is permitted"
else
    fail "accessibility control is refused" \
        "System Settings › Privacy & Security › Accessibility — enable the terminal running this script"
fi

echo
echo "AURA"
aura_pid="$(pgrep -x AURA | head -1)"
if [[ -z "$aura_pid" ]]; then
    fail "AURA is not running" "launch it with the acceptance environment (see launch-aura.sh)"
else
    pass "AURA is running (pid $aura_pid)"

    # A terminal-exec'd AURA inherits that terminal's TCC decisions instead of
    # owning its own, which reads as a truthful-but-wrong permission row rather
    # than as an error. See the comment in launch-aura.sh.
    if [[ "$(ps -o ppid= -p "$aura_pid" | tr -d ' ')" == "1" ]]; then
        pass "AURA is its own responsible process"
    else
        fail "AURA was launched by this terminal, not by LaunchServices" \
            "its calendar/contacts decisions belong to the terminal's app; relaunch with launch-aura.sh"
    fi

    aura_env="$(ps -E -p "$aura_pid" 2>/dev/null | tr ' ' '\n' | grep '^AURA_SP011_' || true)"
    if [[ -z "$aura_env" ]]; then
        fail "AURA has no acceptance environment" \
            "these variables are inherited at launch and are lost on quit; relaunch with launch-aura.sh"
    else
        pass "AURA carries the acceptance environment"
        printf '%s\n' "$aura_env" | sed 's/^/        /'
    fi

    window_state="$(osascript "$DRIVER" window 2>&1)"
    if [[ "$window_state" == OK* ]]; then
        pass "main window is reachable ($window_state)"
    else
        fail "main window is not reachable ($window_state)" \
            "the window may be on another Space — switch to it, or close and reopen it from the AURA menu bar item"
    fi

    # The composer only exists on the conversation tab, so select it before
    # probing: a control that is merely on another tab must not be reported as
    # a build that predates the identifiers.
    osascript "$DRIVER" click aura.tab.conversation >/dev/null 2>&1
    for identifier in aura.composer.input aura.composer.submit; do
        probe="$(osascript "$DRIVER" find "$identifier" 2>&1)"
        if [[ "$probe" == OK* ]]; then
            pass "control $identifier is addressable"
        else
            fail "control $identifier is missing" \
                "select the Conversation tab; if it is already selected, the installed build predates the accessibility identifiers — rebuild and reinstall"
        fi
    done
fi

echo
echo "Safari"
safari_pid="$(pgrep -x Safari | head -1)"
if [[ -z "$safari_pid" ]]; then
    fail "Safari is not running" "launch Safari, then enable the unsigned-extension setting"
else
    safari_started="$(ps -o lstart= -p "$safari_pid" | sed 's/^ *//')"
    pass "Safari is running (pid $safari_pid, started $safari_started)"
    note "the unsigned-extension setting does not survive a Safari restart — do not quit Safari during the run"
fi

if pluginkit -m -p com.apple.Safari.web-extension 2>/dev/null | grep -q "ai.aura.local.agent.SafariExtension"; then
    pass "the extension is registered at Safari's web-extension point"
else
    fail "the extension is not registered" \
        "reinstall AURA.app; without the App Sandbox entitlement Safari refuses to register it"
fi

echo
echo "Bridge"
if [[ -d "$BRIDGE_DIR" ]]; then
    pass "shared container exists"
    for name in observation.json extension-key.json; do
        if [[ -f "$BRIDGE_DIR/$name" ]]; then
            written="$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$BRIDGE_DIR/$name")"
            note "$name last written $written"
        else
            note "$name absent — the extension has not run yet"
        fi
    done
    if [[ -n "${safari_pid:-}" && -f "$BRIDGE_DIR/observation.json" ]]; then
        safari_epoch="$(ps -o lstart= -p "$safari_pid" | xargs -I{} date -j -f '%a %b %d %T %Y' {} '+%s' 2>/dev/null)"
        obs_epoch="$(stat -f '%m' "$BRIDGE_DIR/observation.json")"
        if [[ -n "$safari_epoch" && "$obs_epoch" -lt "$safari_epoch" ]]; then
            note "the last observation predates this Safari session — the extension is very likely disabled"
        fi
    fi
else
    note "shared container absent — it is created on the extension's first successful write"
fi

echo
if [[ "$failures" -eq 0 ]]; then
    echo "READY — every precondition holds."
else
    echo "NOT READY — $failures precondition(s) failed. Fix them before spending an authentication."
fi
exit $(( failures > 0 ))
