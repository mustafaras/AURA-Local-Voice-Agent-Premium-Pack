import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "scripts/validate_repo_hygiene_program.py"
MANIFEST = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json"
STATE = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json"
COVERAGE_SCOPE = ROOT / "scripts/aura-coverage-scope.regex"


class RepoHygieneProgramTests(unittest.TestCase):
    def test_validator_passes(self):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("REPO-HYGIENE VALIDATION PASSED", result.stdout)

    def test_manifest_is_linear(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        prompts = manifest["prompts"]
        self.assertEqual([item["id"] for item in prompts], [f"H-{i:03d}" for i in range(11)])
        self.assertEqual([item["sequence"] for item in prompts], list(range(11)))
        self.assertEqual([item["depends_on"] for item in prompts], [None] + [f"H-{i:03d}" for i in range(10)])

    def test_exactly_approved_prompt_is_active_in_progress(self):
        state = json.loads(STATE.read_text(encoding="utf-8"))
        self.assertEqual(state["program_status"], "in_progress")
        self.assertEqual(state["active_prompt"], "H-008")
        self.assertEqual(state["active_state"], "ready")
        self.assertEqual(state["completed_prompts"], ["H-000", "H-001", "H-002", "H-003", "H-004", "H-005", "H-006", "H-007"])
        self.assertEqual(state["blocked_prompts"], [])

    def test_coverage_scope_is_explicit_and_keeps_composition_in_scope(self):
        self.assertTrue(COVERAGE_SCOPE.is_file())
        regex = "\n".join(
            line.strip()
            for line in COVERAGE_SCOPE.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        )
        for required in ("AURA", "AuraMenuView", "PermissionCoordinator", "EmergencyShortcutMonitor"):
            self.assertIn(required, regex)
        self.assertNotIn("AuraAppModel.swift", regex)
        self.assertNotIn("AuraKernel.swift", regex)


if __name__ == "__main__":
    unittest.main()
