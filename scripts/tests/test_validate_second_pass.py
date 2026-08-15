import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "validate_second_pass_program.py"
SPEC = importlib.util.spec_from_file_location("second_pass_validator", MODULE_PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(VALIDATOR)


class SecondPassProgramTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(
            (ROOT / "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_MANIFEST.json").read_text()
        )
        cls.state = json.loads(
            (ROOT / "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json").read_text()
        )

    def test_control_plane_validates(self):
        self.assertEqual(VALIDATOR.validate(ROOT), [])

    def test_manifest_is_a_linear_34_prompt_chain(self):
        prompts = self.manifest["prompts"]
        self.assertEqual(len(prompts), 34)
        self.assertEqual([prompt["id"] for prompt in prompts], [f"SP-{i:03d}" for i in range(34)])
        self.assertEqual([prompt["sequence"] for prompt in prompts], list(range(34)))
        self.assertEqual(prompts[0]["depends_on"], [])
        self.assertEqual(prompts[-1]["next_prompt"], None)
        for previous, current in zip(prompts, prompts[1:]):
            self.assertEqual(current["depends_on"], [previous["id"]])
            self.assertEqual(previous["next_prompt"], current["id"])

    def test_state_and_handoff_are_locked_to_first_uncompleted_prompt(self):
        self.assertEqual(self.state["active_prompt"], "SP-001")
        self.assertEqual(self.state["active_state"], "blocked")
        self.assertEqual(self.state["completed_prompts"], ["SP-000"])
        self.assertEqual(self.state["blocked_prompts"], ["SP-001"])
        handoff = (ROOT / "AURA_RUNTIME_COMPLETION/context/session-handoff.json").read_text()
        self.assertIn('"id": "SP-001"', handoff)
        self.assertIn("SECOND_PASS_LEDGER.md", handoff)


if __name__ == "__main__":
    unittest.main()
