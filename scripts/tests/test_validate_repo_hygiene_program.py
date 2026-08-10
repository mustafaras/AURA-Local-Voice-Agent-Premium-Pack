import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "scripts/validate_repo_hygiene_program.py"
MANIFEST = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json"
STATE = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json"


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

    def test_ready_state_keeps_first_uncompleted_prompt_active_until_user_approval(self):
        state = json.loads(STATE.read_text(encoding="utf-8"))
        self.assertEqual(state["program_status"], "in_progress")
        self.assertEqual(state["active_prompt"], "H-005")
        self.assertEqual(state["active_state"], "ready")
        self.assertEqual(state["completed_prompts"], ["H-000", "H-001", "H-002", "H-003", "H-004"])
        self.assertEqual(state["blocked_prompts"], [])


if __name__ == "__main__":
    unittest.main()
