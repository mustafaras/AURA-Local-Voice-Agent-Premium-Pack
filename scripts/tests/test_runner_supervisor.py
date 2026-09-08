"""Tests for scripts/runner-supervisor.sh (ADR-056 stage 2).

Deterministic: pgrep, osascript, and swift are shadowed by PATH-injected
fakes; the supervised run.sh is a fake recording script; all state lives in
temporary directories. No real runner, no launchd, no keychain.
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "runner-supervisor.sh"

FAKE_PGREP = """#!/bin/sh
if [ -f "$PGREP_FAKE_FILE" ] && grep -q alive "$PGREP_FAKE_FILE"; then
  echo "9001 /fake-runner/bin/Runner.Listener run"
  exit 0
fi
exit 1
"""

FAKE_OSASCRIPT = """#!/bin/sh
printf '%s\\n' "$@" >> "$OSASCRIPT_LOG"
exit 0
"""

FAKE_SWIFT = """#!/bin/sh
echo "Apple Swift version 6.4 (fake-baseline)"
"""


class SupervisorBehaviorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="aura-supervisor-test-")
        self.base = Path(self.tmp.name)
        self.fake_dir = self.base / "fake-bin"
        self.fake_dir.mkdir()
        # Fake toolchain: the supervisor resolves swift through the
        # AURA_SUPERVISOR_SWIFT_BIN override (production default is the
        # stable absolute /usr/bin/swift shim, which honors DEVELOPER_DIR).
        fake_xcode_bin = (
            self.base / "fake-xcode" / "Contents" / "Developer" / "usr" / "bin"
        )
        fake_xcode_bin.mkdir(parents=True)
        for name, content in (
            ("pgrep", FAKE_PGREP),
            ("osascript", FAKE_OSASCRIPT),
            ("swift", FAKE_SWIFT),
        ):
            target = fake_xcode_bin if name == "swift" else self.fake_dir
            (target / name).write_text(content)
            (target / name).chmod(0o755)
        self.state = self.base / "state"
        self.logs = self.base / "state" / "logs"
        self.logs.mkdir(parents=True)
        self.osascript_log = self.base / "osascript.log"
        self.run_calls = self.base / "run-calls"
        self._env = os.environ.copy()
        self._env.update(
            {
                "AURA_RUNNER_DIR": str(self.base / "runner"),
                "AURA_SUPERVISOR_DIR": str(self.state),
                "AURA_SUPERVISOR_MAX_RESTARTS": "2",
                "AURA_SUPERVISOR_WINDOW_SECONDS": "600",
                "AURA_SUPERVISOR_BACKOFF_BASE": "1",
                "AURA_SUPERVISOR_BACKOFF_MAX": "2",
                "AURA_SUPERVISOR_STABLE_SECONDS": "300",
                "AURA_SUPERVISOR_POLL_SECONDS": "1",
                "AURA_SUPERVISOR_TEST_MODE": "1",
                "AURA_SUPERVISOR_DEVELOPER_DIR": str(
                    self.base / "fake-xcode" / "Contents" / "Developer"
                ),
                "AURA_SUPERVISOR_SWIFT_BIN": str(
                    self.base
                    / "fake-xcode"
                    / "Contents"
                    / "Developer"
                    / "usr"
                    / "bin"
                    / "swift"
                ),
                "OSASCRIPT_LOG": str(self.osascript_log),
                "PGREP_FAKE_FILE": str(self.base / "pgrep-result"),
                "RUN_CALLS": str(self.run_calls),
                "PATH": f"{self.fake_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
            }
        )
        self._env.pop("AURA_SUPERVISOR_TEST_MAX_ITERATIONS", None)
        # The supervised runner: a fake that records each start and exits
        # quickly (short-lived run -> counted as a restart attempt).
        runner_dir = self.base / "runner"
        runner_dir.mkdir()
        (runner_dir / "run.sh").write_text(
            '#!/bin/sh\nprintf "start\\n" >> "$RUN_CALLS"\nsleep 0.2\nexit 7\n'
        )
        (runner_dir / "run.sh").chmod(0o755)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _run(self, extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        env = dict(self._env)
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["/bin/zsh", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )

    def _log(self) -> str:
        return (self.logs / "runner-supervisor.log").read_text()

    def test_second_instance_refuses_lock_and_never_starts_runner(self):
        lock = self.state / "supervisor.lock"
        lock.mkdir(parents=True)
        (lock / "pid").write_text(f"{os.getpid()}\n")
        result = self._run({"AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "1"})
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("holds the lock", result.stderr)
        self.assertFalse(self.run_calls.exists())
        # A refused instance must not destroy the holder's lock.
        self.assertTrue(lock.exists())

    def test_stale_lock_is_reclaimed_and_runner_starts_once(self):
        lock = self.state / "supervisor.lock"
        lock.mkdir(parents=True)
        (lock / "pid").write_text("999999999\n")
        result = self._run({"AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "1"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.run_calls.read_text().count("start"), 1)

    def test_circuit_breaker_bounds_restarts_and_keeps_heartbeat(self):
        self._set_dead()
        result = self._run({"AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "6"})
        self.assertEqual(result.returncode, 0, result.stderr)
        # Two short-lived starts, then the breaker trips and restarts stop.
        self.assertEqual(self.run_calls.read_text().count("start"), 2)
        self.assertTrue((self.state / "supervisor-breaker.flag").exists())
        log_text = self._log()
        self.assertIn("CIRCUIT BREAKER TRIPPED", log_text)
        self.assertIn("restarts in window: 2/2", log_text)
        # Heartbeat stays live so the watchdog liveness check keeps working.
        self.assertTrue((self.state / "watchdog-heartbeat").exists())

    def test_foreign_listener_is_monitored_not_duplicated(self):
        self._set_alive()
        result = self._run({"AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "3"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.run_calls.exists())
        self.assertIn("monitor-only", self._log())
        self.assertTrue((self.state / "watchdog-heartbeat").exists())

    def test_toolchain_pin_recorded_at_start(self):
        self._set_dead()
        self._run({"AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "1"})
        baseline = (self.state / "toolchain-baseline.txt").read_text()
        self.assertIn("Apple Swift version 6.4 (fake-baseline)", baseline)
        self.assertIn("toolchain pinned", self._log())

    def test_stamp_refreshed_while_runner_runs(self):
        runner_dir = self.base / "runner"
        (runner_dir / "run.sh").write_text(
            '#!/bin/sh\nprintf "start\\n" >> "$RUN_CALLS"\nsleep 4\nexit 0\n'
        )
        (runner_dir / "run.sh").chmod(0o755)
        proc = subprocess.Popen(
            ["/bin/zsh", str(SCRIPT)],
            env={**self._env, "AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "1"},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            for _ in range(50):
                if self.run_calls.exists() and "start" in self.run_calls.read_text():
                    break
                time.sleep(0.1)
            stamp = self.state / "watchdog-heartbeat"
            first = int(stamp.read_text())
            time.sleep(1.5)
            self.assertIsNone(proc.poll(), "runner should still be running")
            second = int(stamp.read_text())
            # POLL_SECONDS=1: at least one refresh must land in 1.5s.
            self.assertGreaterEqual(second, first + 1)
        finally:
            proc.terminate()
            proc.wait(timeout=10)

    def test_heartbeat_lives_outside_repository(self):
        self._set_dead()
        self._run({"AURA_SUPERVISOR_TEST_MAX_ITERATIONS": "1"})
        self.assertEqual(self.state.parent, self.base)

    def _set_alive(self) -> None:
        (self.base / "pgrep-result").write_text("alive\n")

    def _set_dead(self) -> None:
        (self.base / "pgrep-result").write_text("dead\n")


class SupervisorContractTests(unittest.TestCase):
    """Static contract: ADR-056 stage 2 invariants."""

    def setUp(self) -> None:
        self.script = SCRIPT.read_text(encoding="utf-8")

    def test_never_uses_launchd_service_mode(self):
        self.assertNotIn("svc.sh", self.script)
        self.assertNotIn("launchctl", self.script)

    def test_instance_lock_is_atomic_mkdir(self):
        self.assertIn('mkdir "$lock_dir"', self.script)
        self.assertIn("supervisor.lock", self.script)

    def test_circuit_breaker_is_bounded_and_logged(self):
        self.assertIn("MAX_RESTARTS", self.script)
        self.assertIn("CIRCUIT BREAKER TRIPPED", self.script)
        self.assertIn("restarts in window", self.script)

    def test_toolchain_pin_exports_developer_dir(self):
        self.assertIn("export DEVELOPER_DIR=", self.script)
        self.assertIn('AURA_SUPERVISOR_SWIFT_BIN:-/usr/bin/swift', self.script)
        self.assertIn('"$SWIFT_BIN" --version', self.script)
        self.assertIn("toolchain-baseline.txt", self.script)

    def test_toolchain_is_not_prepended_to_path(self):
        # Regression: prepending the toolchain to PATH made CI jobs resolve
        # python3 (and other system tools) from Xcode's bundled toolchain
        # instead of the interactive-baseline environment (tomllib missing
        # under Xcode's Python 3.9). DEVELOPER_DIR alone is the pin.
        self.assertNotIn('export PATH="$DEVELOPER_DIR/usr/bin:$PATH"', self.script)
        self.assertNotIn("PATH=\"$DEVELOPER_DIR/usr/bin:$PATH\"", self.script)

    def test_term_trap_terminates_supervisor(self):
        # Regression: a trap handler that only cleans up lets the main loop
        # resume after the interrupted wait, so TERM failed to stop the
        # supervisor (observed live 2026-09-08: it kept monitor-looping).
        # The handler must end with an explicit exit that preserves the
        # pending status (the lock-refusal path exits 3 through it).
        cleanup = self.script.split("cleanup() {", 1)[1].split("\n}", 1)[0]
        self.assertIn("cleanup_rc=$?", cleanup)
        self.assertIn('exit "$cleanup_rc"', cleanup)

    def test_heartbeat_refreshed_while_runner_alive(self):
        # A blocking wait on a healthy runner must not freeze the stamp.
        self.assertIn(
            'while kill -0 "$child_pid" 2>/dev/null; do\n'
            '    write_heartbeat\n'
            '    sleep "$POLL_SECONDS"',
            self.script,
        )

    def test_backoff_is_exponential_with_cap(self):
        self.assertIn("BACKOFF_BASE * (1 << (recent - 1))", self.script)
        self.assertIn("BACKOFF_MAX", self.script)
        self.assertIn("fresh_sleep \"$backoff\"", self.script)

    def test_heartbeat_written_outside_repo(self):
        self.assertIn("watchdog-heartbeat", self.script)


if __name__ == "__main__":
    unittest.main()