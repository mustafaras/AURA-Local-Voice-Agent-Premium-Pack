#!/bin/zsh
# AURA CI runner watchdog (ADR-056 stage 1) — credential-free.
#
# Checks self-hosted runner liveness (Runner.Listener) plus the supervisor
# freshness stamp, and fires a local osascript notification on staleness.
# No GitHub API call, no `gh`, no token, no repository credential.
# Contract: docs/decisions/ADR-056-self-hosted-runner-execution-mode.md
#
# Exit codes: 0 healthy, 1 unhealthy (notification fired), 2 configuration
# error.
set -uo pipefail

RUNNER_DIR="${AURA_RUNNER_DIR:-$HOME/actions-runner}"
STATE_DIR="${AURA_RUNNER_WATCHDOG_DIR:-$HOME/Library/Application Support/AURA-Runner}"
STAMP_FILE="$STATE_DIR/watchdog-heartbeat"
STALE_SECONDS="${AURA_WATCHDOG_STALE_SECONDS:-300}"
REQUIRE_STAMP="${AURA_WATCHDOG_REQUIRE_STAMP:-0}"
TEST_MODE="${AURA_WATCHDOG_TEST_MODE:-0}"

fail() {
  printf 'watchdog: %s\n' "$1" >&2
  exit 2
}

[[ -n "$RUNNER_DIR" && -n "$STATE_DIR" ]] || fail "empty configuration paths"
[[ "$STALE_SECONDS" == <-> ]] || fail "STALE_SECONDS must be an integer"
[[ "$REQUIRE_STAMP" == "0" || "$REQUIRE_STAMP" == "1" ]] || fail "REQUIRE_STAMP must be 0 or 1"

now=$(date +%s)

# Liveness: the listener is matched by its full runner path so a stray
# process with the same name on a different checkout never satisfies this
# check.
listener_pid=""
listener_pid=$(pgrep -f "$RUNNER_DIR/bin/Runner.Listener" 2>/dev/null | head -1 || true)

stamp_state="missing"
stamp_age=""
if [[ -f "$STAMP_FILE" ]]; then
  stamp=$(head -n 1 "$STAMP_FILE" 2>/dev/null | tr -d '[:space:]' || true)
  if [[ "$stamp" == <-> ]]; then
    stamp_age=$(( now - stamp ))
    if (( stamp_age > STALE_SECONDS )); then
      stamp_state="stale"
    else
      stamp_state="fresh"
    fi
  else
    stamp_state="malformed"
  fi
fi

reason=""
if [[ -z "$listener_pid" ]]; then
  reason="Runner.Listener not running (${RUNNER_DIR})"
elif [[ "$stamp_state" == "stale" || "$stamp_state" == "malformed" ]]; then
  reason="supervisor heartbeat $stamp_state (${STAMP_FILE})"
elif [[ "$REQUIRE_STAMP" == "1" && "$stamp_state" == "missing" ]]; then
  reason="supervisor heartbeat missing (${STAMP_FILE})"
else
  printf 'watchdog: healthy (pid=%s stamp=%s)\n' "${listener_pid:-none}" "$stamp_state"
  exit 0
fi

message="AURA CI runner: $reason"
printf 'watchdog: unhealthy — %s\n' "$reason" >&2

if [[ "$TEST_MODE" != "1" ]] && command -v osascript >/dev/null 2>&1; then
  # Local notification only; never sends content anywhere.
  osascript -e "display notification \"${message//\"/}\" with title \"AURA CI runner\"" >/dev/null 2>&1 || true
fi

exit 1