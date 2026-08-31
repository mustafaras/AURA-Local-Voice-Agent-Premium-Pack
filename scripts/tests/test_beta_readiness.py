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

    def test_enrolled_cohort_without_consent_evidence_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["cohort"]["status"] = "enrolled"
        record["cohort"]["consent"] = "collected"
        record["cohort"].pop("consent_evidence_id", None)
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_enrolled_cohort_without_collected_consent_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["cohort"]["status"] = "enrolled"
        record["cohort"]["consent"] = "not_collected"
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_unknown_slo_status_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["slo_definitions"][0]["status"] = "passed"
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_approved_rc_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["release_candidate"]["approved"] = True
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)


def _measured_slo(**overrides):
    """A well-formed measured SLO; overrides mutate the measurement block."""
    measurement = {
        "evidence_id": "EV-SP-030-20260830-SLO-01",
        "measurement_class": "deterministic_harness",
        "sample_count": 50,
        "percentiles_ms": {"50": 120, "95": 300, "99": 410},
        "meets_target": True,
        "limitations": "Deterministic harness result, not a live beta window.",
    }
    measurement.update(overrides)
    return {"status": "measured", "target_ms": 1500, "sample_minimum": 30, "measurement": measurement}


class MeasuredModeTests(unittest.TestCase):
    """The contract must be able to record a real result without being able to record a fake one."""

    @classmethod
    def setUpClass(cls):
        cls.record = json.loads(
            (ROOT / "AURA_RUNTIME_COMPLETION/state/beta-readiness.json").read_text()
        )

    def _with_slo(self, **overrides):
        record = copy.deepcopy(self.record)
        slo = _measured_slo(**overrides)
        slo["id"] = record["slo_definitions"][0]["id"]
        slo["metric"] = record["slo_definitions"][0]["metric"]
        slo["percentiles"] = record["slo_definitions"][0]["percentiles"]
        record["slo_definitions"][0] = slo
        return record

    def test_measured_slo_with_full_provenance_is_accepted(self):
        VALIDATOR.validate_record(self._with_slo())

    def test_measured_slo_without_provenance_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["slo_definitions"][0].update({"status": "measured", "target_ms": 1500, "sample_minimum": 30})
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_unknown_measurement_class_is_rejected(self):
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(self._with_slo(measurement_class="vibes"))

    def test_harness_result_cannot_claim_a_live_beta_sample(self):
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(self._with_slo(live_beta_sample=True))

    def test_sample_count_below_declared_minimum_is_rejected(self):
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(self._with_slo(sample_count=5))

    def test_missing_declared_percentile_is_rejected(self):
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(self._with_slo(percentiles_ms={"50": 120}))

    def test_malformed_evidence_id_is_rejected(self):
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(self._with_slo(evidence_id="see the ledger"))

    def test_scenario_marked_passed_without_evidence_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["scenario_matrix"][0]["status"] = "passed"
        record["scenario_matrix"][0]["evidence_ids"] = []
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_scenario_passed_with_evidence_and_class_is_accepted(self):
        record = copy.deepcopy(self.record)
        record["scenario_matrix"][0].update(
            {
                "status": "passed",
                "evidence_ids": ["EV-SP-030-20260830-SCENARIO-01"],
                "measurement_class": "deterministic_harness",
                "limitations": "Deterministic harness coverage, not a live beta window.",
            }
        )
        VALIDATOR.validate_record(record)

    def test_signoff_by_the_implementing_agent_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["signoffs"]["security"] = {
            "status": "obtained",
            "evaluator": "the implementing agent",
            "independent": True,
            "evaluator_is_implementing_agent": True,
            "evidence_id": "EV-SP-030-20260830-SIGNOFF-01",
        }
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_bare_string_signoff_is_rejected(self):
        record = copy.deepcopy(self.record)
        record["signoffs"]["privacy"] = "obtained"
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_named_independent_signoff_is_accepted(self):
        record = copy.deepcopy(self.record)
        record["signoffs"]["security"] = {
            "status": "obtained",
            "evaluator": "named non-implementing reviewer",
            "independent": True,
            "evaluator_is_implementing_agent": False,
            "evidence_id": "EV-SP-030-20260830-SIGNOFF-01",
        }
        VALIDATOR.validate_record(record)

    def test_incidents_without_remediation_are_rejected(self):
        record = copy.deepcopy(self.record)
        record["incident_review"] = {
            "status": "completed",
            "evidence_id": "EV-SP-030-20260830-INCIDENT-01",
            "severity_1_2_count": 2,
            "false_success_count": 0,
            "unauthorized_action_count": 0,
            "remediation_records": [],
        }
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_clean_incident_review_is_accepted(self):
        record = copy.deepcopy(self.record)
        record["incident_review"] = {
            "status": "completed",
            "evidence_id": "EV-SP-030-20260830-INCIDENT-01",
            "severity_1_2_count": 0,
            "false_success_count": 0,
            "unauthorized_action_count": 0,
            "remediation_records": [],
        }
        VALIDATOR.validate_record(record)

    def test_telemetry_transport_remains_forbidden_in_every_mode(self):
        record = copy.deepcopy(self.record)
        record["telemetry"].update(
            {
                "enabled": True,
                "transport": "https",
                "consent_evidence_id": "EV-SP-030-20260830-CONSENT-01",
                "retention_days": 30,
            }
        )
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)

    def test_release_authority_is_never_grantable_here(self):
        record = copy.deepcopy(self.record)
        record["authority"]["release"] = True
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_record(record)


if __name__ == "__main__":
    unittest.main()
