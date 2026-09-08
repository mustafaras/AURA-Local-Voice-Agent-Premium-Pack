# CI Runner Supervision Runbook (ADR-056)

Applies to `scripts/ci-runner-watchdog.sh` (stage 1) and
`scripts/runner-supervisor.sh` (stage 2). The runner itself stays in the
owner's GUI login session; neither the watchdog nor the supervisor runs a
launchd service mode (`svc.sh` is never used). The watchdog is credential-free
and alerts only through local notifications.

State directory: `~/Library/Application Support/AURA-Runner/` (outside the
repository). Log files live under `<state>/logs/`.

## Stage 1 — watchdog (active)

Heartbeat writer: the supervisor (stage 2) once active; until then the stamp
may be missing and is tolerated (`AURA_WATCHDOG_REQUIRE_STAMP=0` default).
Liveness check: `pgrep -f "$RUNNER_DIR/bin/Runner.Listener"`, bound to the
real runner directory — same-named processes in other checkouts are never
counted as healthy.

### Install

The script cannot run from the repository checkout: launchd agents cannot
read `~/Desktop` (TCC folder protection). Install a byte-identical copy in
the state directory and point the agent at it.

```sh
REPO_PATH="$HOME/Desktop/AURA-Local-Voice-Agent-Premium-Pack"
AURA_STATE="$HOME/Library/Application Support/AURA-Runner"
mkdir -p "$HOME/Library/LaunchAgents" "$AURA_STATE/logs" "$AURA_STATE/scripts"
cp "$REPO_PATH/scripts/ci-runner-watchdog.sh" "$AURA_STATE/scripts/"
shasum -a 256 "$REPO_PATH/scripts/ci-runner-watchdog.sh" \
              "$AURA_STATE/scripts/ci-runner-watchdog.sh"   # must match
sed -e "s|@HOME@|$HOME|g" -e "s|@AURA_STATE@|$AURA_STATE|g" \
  "$REPO_PATH/docs/operations/com.aura.ci-runner-watchdog.plist.template" \
  > "$HOME/Library/LaunchAgents/com.aura.ci-runner-watchdog.plist"
launchctl load "$HOME/Library/LaunchAgents/com.aura.ci-runner-watchdog.plist"
```

After each repository-side watchdog change, re-copy and verify the hash
again before reloading the agent.

### Verify

```sh
launchctl kickstart -k gui/$(id -u)/com.aura.ci-runner-watchdog
echo $?   # 0 when the runner is healthy; 1 alerts and exits unhealthy
```

Manual run:

```sh
/bin/zsh "$REPO_PATH/scripts/ci-runner-watchdog.sh"; echo $?
```

Exit codes: `0` healthy, `1` unhealthy (notification shown), `2`
configuration error. Schedule: `RunAtLoad` plus `StartInterval 300`.

### Uninstall

```sh
launchctl unload "$HOME/Library/LaunchAgents/com.aura.ci-runner-watchdog.plist"
rm "$HOME/Library/LaunchAgents/com.aura.ci-runner-watchdog.plist"
```

## Stage 2 — supervisor (GATED — not active)

Activation is blocked until the four ADR-056 validation gates pass:
(1) runner survives Cmd-Q; (2) CI fully green; (3) swift toolchain parity
with the interactive runner; (4) two clean reboot cycles. Gate evidence goes
into `ledger/PROJECT_LEDGER.md` per ADR-056.

Behavior reminders: the supervisor holds an atomic `supervisor.lock` in the
state directory; a second instance refuses (`exit 3`) and never kills the
holder's lock. If an external Runner.Listener is already running, the
supervisor is monitor-only (it writes the heartbeat but starts nothing). The
circuit breaker bounds restarts (`supervisor-breaker.flag`); the heartbeat
keeps flowing even when the breaker is tripped so the watchdog keeps
alerting.

### Install (after gates)

```sh
REPO_PATH="$HOME/Desktop/AURA-Local-Voice-Agent-Premium-Pack"
XCODE_DIR="$(xcode-select -p)"
sed -e "s|@HOME@|$HOME|g" -e "s|@REPO_PATH@|$REPO_PATH|g" \
    -e "s|@XCODE_DIR@|$XCODE_DIR|g" \
  "$REPO_PATH/docs/operations/com.aura.ci-runner-supervisor.plist.template" \
  > "$HOME/Library/LaunchAgents/com.aura.ci-runner-supervisor.plist"
launchctl load "$HOME/Library/LaunchAgents/com.aura.ci-runner-supervisor.plist"
```

### Verify

```sh
launchctl kickstart -k gui/$(id -u)/com.aura.ci-runner-supervisor
tail -n 20 "$HOME/Library/Application Support/AURA-Runner/logs/runner-supervisor.log"
test -f "$HOME/Library/Application Support/AURA-Runner/watchdog-heartbeat" && echo heartbeat-ok
```

### Uninstall

```sh
launchctl unload "$HOME/Library/LaunchAgents/com.aura.ci-runner-supervisor.plist"
rm "$HOME/Library/LaunchAgents/com.aura.ci-runner-supervisor.plist"
```

### Clear the circuit breaker

```sh
rm "$HOME/Library/Application Support/AURA-Runner/supervisor-breaker.flag"
launchctl kickstart -k gui/$(id -u)/com.aura.ci-runner-supervisor
```

### Stale lock recovery

If a crash left `supervisor.lock` behind with a dead pid, the supervisor
reclaims it automatically. To force removal manually, first confirm no
supervisor process is alive, then:

```sh
rm -rf "$HOME/Library/Application Support/AURA-Runner/supervisor.lock"
```

## Test harness hooks (not for production)

`AURA_SUPERVISOR_TEST_MODE=1`, `AURA_SUPERVISOR_TEST_MAX_ITERATIONS`,
`AURA_SUPERVISOR_POLL_SECONDS`, `AURA_WATCHDOG_TEST_MODE=1`,
`AURA_WATCHDOG_REQUIRE_STAMP`, `AURA_WATCHDOG_STALE_SECONDS` exist for the
unittest suite (`scripts/tests/test_ci_runner_watchdog.py`,
`scripts/tests/test_runner_supervisor.py`) and short manual checks. Never set
them in the LaunchAgents above.