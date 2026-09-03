import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "scripts/validate_repo_hygiene_program.py"
MANIFEST = ROOT / "archive/runtime-completion/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json"
STATE = ROOT / "archive/runtime-completion/repo-hygiene/REPO_HYGIENE_STATE.json"
COVERAGE_SCOPE = ROOT / "scripts/aura-coverage-scope.regex"
CONTEXT_SUMMARY = ROOT / "archive/runtime-completion/context/REPO_HYGIENE_CONTEXT_SUMMARY.md"
ARCHITECTURE_AUDIT = ROOT / "archive/runtime-completion/repo-hygiene/H-009_ARCHITECTURE_AUDIT.md"


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

    def test_final_gate_is_complete_without_a_next_prompt(self):
        state = json.loads(STATE.read_text(encoding="utf-8"))
        self.assertEqual(state["program_status"], "completed")
        self.assertEqual(state["active_prompt"], "H-010")
        self.assertEqual(state["active_state"], "completed")
        self.assertEqual(state["completed_prompts"], [f"H-{i:03d}" for i in range(11)])
        self.assertEqual(state["blocked_prompts"], [])

    def test_h009_bounded_audit_artifacts_exist(self):
        self.assertTrue(CONTEXT_SUMMARY.is_file())
        self.assertTrue(ARCHITECTURE_AUDIT.is_file())
        summary = CONTEXT_SUMMARY.read_text(encoding="utf-8")
        audit = ARCHITECTURE_AUDIT.read_text(encoding="utf-8")
        self.assertIn("not a source of truth", summary)
        self.assertIn("Source-of-truth map", summary)
        for marker in ("Symptom", "Mechanism", "Falsification", "Residual risk", "Next gate"):
            self.assertIn(marker, audit)

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
