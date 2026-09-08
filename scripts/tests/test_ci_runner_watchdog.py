"""Tests for scripts/ci-runner-watchdog.sh (ADR-056 stage 1).

Deterministic: pgrep and osascript are shadowed by PATH-injected fakes; all
state lives in temporary directories; nothing networked, no keychain, no
real runner interaction.
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "ci-runner-watchdog.sh"

FAKE_PGREP = """#!/bin/sh
if [ -f "$PGREP_FAKE_FILE" ] && grep -q alive "$PGREP_FAKE_FILE"; then
  echo "4242 /fake-runner/bin/Runner.Listener run"
  exit 0
fi
exit 1
"""

FAKE_OSASCRIPT = """#!/bin/sh
printf '%s\\n' "$@" >> "$OSASCRIPT_LOG"
exit 0
"""


class WatchdogBehaviorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="aura-watchdog-test-")
        self.base = Path(self.tmp.name)
        self.fake_dir = self.base / "fake-bin"
        self.fake_dir.mkdir()
        (self.fake_dir / "pgrep").write_text(FAKE_PGREP)
        (self.fake_dir / "osascript").write_text(FAKE_OSASCRIPT)
        for name in ("pgrep", "osascript"):
            path = self.fake_dir / name
            path.chmod(0o755)
        self.state = self.base / "state"
        self.state.mkdir()
        self.osascript_log = self.base / "osascript.log"
        self._env = os.environ.copy()
        self._env.update(
            {
                "AURA_RUNNER_DIR": str(self.base / "runner"),
                "AURA_RUNNER_WATCHDOG_DIR": str(self.state),
                "AURA_WATCHDOG_STALE_SECONDS": "300",
                "AURA_WATCHDOG_TEST_MODE": "0",
                "OSASCRIPT_LOG": str(self.osascript_log),
                "PGREP_FAKE_FILE": str(self.base / "pgrep-result"),
                "PATH": f"{self.fake_dir}:/usr/bin:/bin:/usr/sbin:/sbin",
            }
        )
        self._env.pop("AURA_WATCHDOG_REQUIRE_STAMP", None)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _set_alive(self, alive: bool) -> None:
        pgrep_file = self.base / "pgrep-result"
        pgrep_file.write_text("alive\n" if alive else "dead\n")

    def _stamp(self, age: int | None) -> None:
        if age is None:
            return
        self.state.mkdir(parents=True, exist_ok=True)
        (self.state / "watchdog-heartbeat").write_text(f"{int(time.time()) - age}\n")

    def _run(self, extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
        env = dict(self._env)
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["/bin/zsh", str(SCRIPT)],
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    def test_healthy_listener_without_stamp_exits_zero(self):
        self._set_alive(True)
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("healthy", result.stdout)
        self.assertFalse(self.osascript_log.exists())

    def test_dead_listener_alerts_and_exits_one(self):
        self._set_alive(False)
        result = self._run()
        self.assertEqual(result.returncode, 1)
        self.assertIn("not running", result.stderr)
        self.assertTrue(self.osascript_log.exists())
        self.assertIn("AURA CI runner", self.osascript_log.read_text())

    def test_stale_stamp_alerts_even_when_alive(self):
        self._set_alive(True)
        self._stamp(age=1000)
        result = self._run()
        self.assertEqual(result.returncode, 1)
        self.assertIn("stale", result.stderr)

    def test_malformed_stamp_alerts_even_when_alive(self):
        self._set_alive(True)
        (self.state / "watchdog-heartbeat").write_text("not-a-number\n")
        result = self._run()
        self.assertEqual(result.returncode, 1)
        self.assertIn("malformed", result.stderr)

    def test_missing_stamp_only_alerts_when_required(self):
        self._set_alive(True)
        tolerated = self._run({"AURA_WATCHDOG_REQUIRE_STAMP": "0"})
        self.assertEqual(tolerated.returncode, 0, tolerated.stderr)
        required = self._run({"AURA_WATCHDOG_REQUIRE_STAMP": "1"})
        self.assertEqual(required.returncode, 1)
        self.assertIn("missing", required.stderr)

    def test_fresh_stamp_with_alive_listener_is_healthy(self):
        self._set_alive(True)
        self._stamp(age=10)
        result = self._run({"AURA_WATCHDOG_REQUIRE_STAMP": "1"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_non_integer_stale_seconds_is_configuration_error(self):
        self._set_alive(True)
        result = self._run({"AURA_WATCHDOG_STALE_SECONDS": "soon"})
        self.assertEqual(result.returncode, 2)


class WatchdogContractTests(unittest.TestCase):
    """Static contract: credential-free v1, local-only notification."""

    def setUp(self) -> None:
        self.script = SCRIPT.read_text(encoding="utf-8")

    def test_is_zsh(self):
        self.assertTrue(SCRIPT.read_text(encoding="utf-8").startswith("#!/bin/zsh"))

    def test_has_no_gh_or_token_surface(self):
        self.assertNotIn("gh ", self.script)
        self.assertNotIn("GITHUB_TOKEN", self.script)
        self.assertNotIn("api.github.com", self.script)

    def test_notification_is_local_osascript_only(self):
        self.assertIn("osascript", self.script)
        self.assertIn("display notification", self.script)

    def test_liveness_is_path_bound_to_runner_dir(self):
        self.assertIn('pgrep -f "$RUNNER_DIR/bin/Runner.Listener"', self.script)

    def test_default_staleness_is_five_minutes(self):
        self.assertIn('AURA_WATCHDOG_STALE_SECONDS:-300', self.script)

    def test_heartbeat_path_lives_outside_repository(self):
        self.assertIn("AURA-Runner", self.script)


if __name__ == "__main__":
    unittest.main()