import json
import subprocess
import unittest
from pathlib import Path

from scripts import validate_repo_hygiene_supply_chain as supply_chain


ROOT = Path(__file__).resolve().parents[2]
POLICY = json.loads(
    (ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_SUPPLY_CHAIN_POLICY.json").read_text(
        encoding="utf-8"
    )
)


class RepoHygieneSupplyChainTests(unittest.TestCase):
    def test_validator_passes_without_printing_secret_values(self):
        result = subprocess.run(
            ["python3", "scripts/validate_repo_hygiene_supply_chain.py"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("AURA SUPPLY-CHAIN VALIDATION PASSED", result.stdout)
        self.assertNotIn("MIIC", result.stdout)
        self.assertNotIn("eyJhbGciOiJIUzI1NiJ9", result.stdout)

    def test_unallowlisted_detection_exposes_only_location_and_pattern(self):
        token = "sk-" + "a" * 48
        findings = supply_chain.secret_findings("synthetic.txt", f"token={token}", POLICY)
        self.assertEqual([(item.path, item.line, item.pattern) for item in findings], [("synthetic.txt", 1, "openai_style_key")])
        self.assertNotIn(token, repr(findings))
        self.assertFalse(supply_chain.fixture_is_allowed(findings[0], f"token={token}", POLICY))

    def test_fixture_allowlist_requires_exact_path_pattern_and_marker(self):
        path = "Tests/AuraSecurityTests/SecretScannerTests.swift"
        text = "// REPO_HYGIENE_SECRET_FIXTURE: jwt\n"
        finding = supply_chain.SecretFinding(path, 1, "jwt")
        self.assertTrue(supply_chain.fixture_is_allowed(finding, text, POLICY))
        self.assertFalse(supply_chain.fixture_is_allowed(finding, text.replace("jwt", "other"), POLICY))
        self.assertFalse(
            supply_chain.fixture_is_allowed(
                supply_chain.SecretFinding("other.swift", 1, "jwt"), text, POLICY
            )
        )

    def test_workflow_references_are_parsed_as_provenance_records(self):
        references = supply_chain.workflow_action_references(
            "uses: actions/checkout@" + "a" * 40 + " # v4.2.2\n"
        )
        self.assertEqual(references, [("actions/checkout", "a" * 40, "v4.2.2")])

    def test_policy_has_no_external_swift_dependencies_and_pins_python_sources(self):
        self.assertEqual(POLICY["swift"]["expected_external_dependencies"], [])
        for source in POLICY["python"]["direct_git_sources"]:
            self.assertRegex(source["rev"], r"^[0-9a-f]{40}$")
        self.assertEqual(POLICY["python"]["direct_registry_dependencies"], ["torchcodec==0.15.0"])


if __name__ == "__main__":
    unittest.main()
