from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class AuraTestRunnerTests(unittest.TestCase):
    def test_agent_bundle_has_bounded_parallelism_override(self):
        script = (ROOT / "scripts" / "aura-test.sh").read_text(encoding="utf-8")

        self.assertIn('if [[ "$name" == "AuraAgentTests" ]]; then', script)
        self.assertIn(
            'SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=${AURA_AGENT_TEST_PARALLELIZATION_WIDTH:-1}',
            script,
        )


if __name__ == "__main__":
    unittest.main()
