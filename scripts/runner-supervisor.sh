#!/bin/zsh
# AURA runner supervisor (ADR-056 stage 2) — detached, Aqua-session runner
# supervision with a bounded restart circuit breaker.
#
# Contract: docs/decisions/ADR-056-self-hosted-runner-execution-mode.md
# - Never overlaps a manually started run.sh (atomic lock + foreign-listener
#   guard: an externally started runner is monitored, never duplicated).
# - Restart loop with exponential backoff and a bounded restart-count
#   circuit breaker; restart counts are logged.
# - Explicit toolchain pinning (DEVELOPER_DIR/PATH); the resolved
#   `swift --version` is recorded at start.
# - Watchdog heartbeat is written outside the repository.
# The runner process itself never runs in a launchd service session; this
# script runs inside the owner's GUI login session (login-time agent).
#
# Exit codes: 0 clean stop, 3 lock/instance error, 2 configuration error.
set -uo pipefail

RUNNER_DIR="${AURA_RUNNER_DIR:-$HOME/actions-runner}"
STATE_DIR="${AURA_SUPERVISOR_DIR:-$HOME/Library/Application Support/AURA-Runner}"
LOG_DIR="${AURA_SUPERVISOR_LOG_DIR:-$STATE_DIR/logs}"
STAMP_FILE="$STATE_DIR/watchdog-heartbeat"
MAX_RESTARTS="${AURA_SUPERVISOR_MAX_RESTARTS:-5}"
WINDOW_SECONDS="${AURA_SUPERVISOR_WINDOW_SECONDS:-1800}"
BACKOFF_BASE="${AURA_SUPERVISOR_BACKOFF_BASE:-10}"
BACKOFF_MAX="${AURA_SUPERVISOR_BACKOFF_MAX:-300}"
STABLE_SECONDS="${AURA_SUPERVISOR_STABLE_SECONDS:-300}"
DEVELOPER_DIR_DEFAULT="${AURA_SUPERVISOR_DEVELOPER_DIR:-}"
TEST_MODE="${AURA_SUPERVISOR_TEST_MODE:-0}"
TEST_MAX_ITERATIONS="${AURA_SUPERVISOR_TEST_MAX_ITERATIONS:-0}"
POLL_SECONDS="${AURA_SUPERVISOR_POLL_SECONDS:-5}"

config_fail() {
  printf 'supervisor: %s\n' "$1" >&2
  exit 2
}

[[ -n "$RUNNER_DIR" && -n "$STATE_DIR" && -n "$STAMP_FILE" ]] || config_fail "empty configuration paths"
[[ "$MAX_RESTARTS" == <-> && "$WINDOW_SECONDS" == <-> && "$BACKOFF_BASE" == <-> \
  && "$BACKOFF_MAX" == <-> && "$STABLE_SECONDS" == <-> && "$POLL_SECONDS" == <-> ]] || config_fail "numeric settings must be integers"
[[ -x "$RUNNER_DIR/run.sh" ]] || config_fail "run.sh not found/executable at ${RUNNER_DIR}"

mkdir -p "$STATE_DIR" "$LOG_DIR" 2>/dev/null || config_fail "cannot create state/log directories"

log() {
  printf '%s supervisor: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >> "$LOG_DIR/runner-supervisor.log"
}

write_heartbeat() {
  printf '%s\n' "$(date +%s)" > "$STAMP_FILE" 2>/dev/null || true
}

notify() {
  if [[ "$TEST_MODE" != "1" ]] && command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${1//\"/}\" with title \"AURA runner supervisor\"" >/dev/null 2>&1 || true
  fi
}

# Atomic instance lock: a supervised runner must never overlap a manual
# run.sh (ledger race evidence). Stale locks (dead holder) are reclaimed.
acquire_lock() {
  local lock_dir="$STATE_DIR/supervisor.lock"
  local holder_file="$lock_dir/pid"
  if ! mkdir "$lock_dir" 2>/dev/null; then
    local holder=""
    holder=$(head -n 1 "$holder_file" 2>/dev/null | tr -d '[:space:]' || true)
    if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$lock_dir"
      mkdir "$lock_dir" 2>/dev/null || return 1
    else
      return 1
    fi
  fi
  printf '%s\n' "$$" > "$lock_dir/pid"
  lock_acquired=1
  return 0
}

lock_acquired=0
cleanup() {
  if (( lock_acquired == 1 )); then
    rm -rf "$STATE_DIR/supervisor.lock" 2>/dev/null
  fi
  if [[ -n "${child_pid:-}" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill "$child_pid" 2>/dev/null
  fi
}
trap cleanup TERM INT EXIT

if ! acquire_lock; then
  printf 'supervisor: another supervisor instance holds the lock; exiting\n' >&2
  exit 3
fi

# Toolchain pinning: resolve once at start, record the baseline.
if [[ -z "$DEVELOPER_DIR_DEFAULT" ]]; then
  DEVELOPER_DIR_DEFAULT=$(xcode-select -p 2>/dev/null || true)
fi
[[ -n "$DEVELOPER_DIR_DEFAULT" ]] || config_fail "cannot resolve DEVELOPER_DIR (set AURA_SUPERVISOR_DEVELOPER_DIR)"
export DEVELOPER_DIR="$DEVELOPER_DIR_DEFAULT"
# DEVELOPER_DIR is the pin: /usr/bin/{swift,xcodebuild,xcrun} honor it.
# Deliberately NOT prepended to PATH — the toolchain's usr/bin would shadow
# system tools the CI jobs need (e.g. python3 >= 3.11 for tomllib) and
# diverge from the interactive baseline that was green.
if "$DEVELOPER_DIR/usr/bin/swift" --version > "$STATE_DIR/toolchain-baseline.txt" 2>&1; then
  log "toolchain pinned: DEVELOPER_DIR=$DEVELOPER_DIR baseline recorded"
else
  log "toolchain pinning: swift --version failed at start (recorded verbatim)"
fi

# Keep the watchdog stamp fresh across long sleeps: a supervisor that is
# alive must never let the stamp go stale (the watchdog alerts on
# staleness). Sleeps longer than POLL_SECONDS go through this helper.
fresh_sleep() {
  local until_epoch=$(( $(date +%s) + $1 ))
  while (( $(date +%s) < until_epoch )); do
    write_heartbeat
    sleep "$POLL_SECONDS"
  done
}

restart_times=()
breaker_tripped=0
iteration=0

log "supervisor starting (pid $$, runner dir $RUNNER_DIR)"

while true; do
  write_heartbeat
  (( TEST_MAX_ITERATIONS > 0 && iteration >= TEST_MAX_ITERATIONS )) && break
  (( iteration += 1 ))

  # Foreign-listener guard: if a Runner.Listener is running that we did not
  # start, monitor it instead of starting a competing one.
  foreign=$(pgrep -f "$RUNNER_DIR/bin/Runner.Listener" 2>/dev/null || true)
  if [[ -n "$foreign" ]]; then
    log "monitor-only: external Listener present (pids: ${foreign//$'\n'/ }), not starting a competing runner"
    sleep "$POLL_SECONDS"
    continue
  fi

  if (( breaker_tripped == 1 )); then
    # Circuit breaker tripped: keep supervising (heartbeat stays live) but
    # never restart. Owner clears this via the runbook.
    sleep "$POLL_SECONDS"
    continue
  fi

  start_epoch=$(date +%s)
  log "starting runner (attempt window count: ${#restart_times})"
  "$RUNNER_DIR/run.sh" >> "$LOG_DIR/runner.log" 2>&1 &
  child_pid=$!
  # Refresh the watchdog stamp while the runner runs: a healthy supervised
  # runner is exactly the state the stamp must stay fresh in (a blocking
  # wait here would freeze the stamp and fire false watchdog alerts).
  while kill -0 "$child_pid" 2>/dev/null; do
    write_heartbeat
    sleep "$POLL_SECONDS"
  done
  wait "$child_pid"
  run_rc=$?
  child_pid=""
  end_epoch=$(date +%s)
  duration=$(( end_epoch - start_epoch ))
  write_heartbeat

  if (( duration >= STABLE_SECONDS )); then
    if (( ${#restart_times} > 0 )); then
      log "run survived ${duration}s; restart window cleared"
    fi
    restart_times=()
    continue
  fi

  # Short-lived run: count it as a restart attempt.
  restart_times+=("$end_epoch")
  recent=0
  for t in "${restart_times[@]}"; do
    (( end_epoch - t < WINDOW_SECONDS )) && (( recent += 1 ))
  done
  log "runner exited rc=$run_rc after ${duration}s; restarts in window: $recent/$MAX_RESTARTS"
  notify "AURA runner exited (rc=$run_rc) after ${duration}s"

  if (( recent >= MAX_RESTARTS )); then
    breaker_tripped=1
    printf '%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$STATE_DIR/supervisor-breaker.flag"
    log "CIRCUIT BREAKER TRIPPED: $recent restarts within ${WINDOW_SECONDS}s; stopping restarts (heartbeat continues)"
    notify "AURA runner supervisor: circuit breaker tripped ($recent restarts)"
    continue
  fi

  backoff=$(( BACKOFF_BASE * (1 << (recent - 1)) ))
  (( backoff > BACKOFF_MAX )) && backoff=$BACKOFF_MAX
  log "backing off ${backoff}s before restart"
  fresh_sleep "$backoff"
done

exit 0