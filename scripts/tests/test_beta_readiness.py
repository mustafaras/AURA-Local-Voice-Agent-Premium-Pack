import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "validate_beta_readiness.py"
SPEC = importlib.util.spec_from_file_location("beta_readiness_validator", MODULE_PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(VALIDATOR)


class BetaReadinessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = json.loads(
            (ROOT / "AURA_RUNTIME_COMPLETION/state/beta-readiness.json").read_text()
        )

    def test_repository_contract_is_conservative(self):
        VALIDATOR.validate_record(self.record)

    def test_telemetry_enablement_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["telemetry"]["enabled"] = True
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_raw_content_field_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["telemetry"]["aggregate_fields"].append("raw_prompt")
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_enrolled_cohort_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["cohort"]["status"] = "enrolled"
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_measured_slo_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["slo_definitions"][0]["status"] = "passed"
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_approved_rc_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["release_candidate"]["approved"] = True
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)
