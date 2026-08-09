#!/usr/bin/env python3
"""Fail-closed validation for the local R12 beta-readiness contract.

This validator proves only that the readiness record is conservative. It never
enrolls users, enables telemetry, measures SLOs, or authorizes a release.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


class ValidationFailure(Exception):
    """The readiness contract is unsafe or incomplete."""


ALLOWED_STATUSES = {"blocked", "not_ready"}
FORBIDDEN_CONTENT_TERMS = (
    "audio",
    "document",
    "mail",
    "model_output",
    "prompt",
    "screenshot",
    "secret",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationFailure(message)


def validate_record(record: dict[str, Any]) -> None:
    require(record.get("schema_version") == "1.0.0", "unsupported readiness schema")
    require(record.get("readiness_status") in ALLOWED_STATUSES, "readiness must be blocked")

    authority = record.get("authority", {})
    for field in ("beta_enrollment", "telemetry_activation", "app_install_or_launch", "release"):
        require(authority.get(field) is False, f"authority unexpectedly enables {field}")

    dependency = record.get("dependency_gate", {})
    require(dependency.get("r11_state") != "completed", "R11 completion was fabricated")
    require(dependency.get("r11_release_status") == "development_unverified", "R11 release status is unsafe")
    require(dependency.get("r11_completion_required") is True, "R11 dependency gate is missing")

    cohort = record.get("cohort", {})
    require(cohort.get("status") == "not_enrolled", "beta cohort is enrolled")
    require(cohort.get("consent") == "not_collected", "beta consent is present")
    require(cohort.get("minimum_sessions") is None, "beta sample size is fabricated")

    telemetry = record.get("telemetry", {})
    require(telemetry.get("enabled") is False, "telemetry is enabled")
    require(telemetry.get("consent_required") is True, "telemetry consent gate is missing")
    require(telemetry.get("raw_content_allowed") is False, "raw content is allowed")
    require(telemetry.get("transport") == "none", "telemetry transport is active")
    require(telemetry.get("retention_days") is None, "telemetry retention is fabricated")
    for field in telemetry.get("aggregate_fields", []):
        lowered = str(field).lower()
        require(not any(term in lowered for term in FORBIDDEN_CONTENT_TERMS), f"content field is present: {field}")

    for definition in record.get("slo_definitions", []):
        require(definition.get("status") == "not_measured", "SLO measurement is fabricated")
        require(definition.get("target_ms") is None, "SLO target is presented as accepted")
        require(definition.get("sample_minimum") is None, "SLO sample minimum is presented as met")

    for scenario in record.get("scenario_matrix", []):
        require(scenario.get("status") == "not_run", f"scenario is presented as run: {scenario.get('id')}")
        require(scenario.get("evidence_ids") == [], f"scenario evidence is fabricated: {scenario.get('id')}")

    incident = record.get("incident_review", {})
    require(incident.get("status") == "not_run", "incident review is presented as complete")
    for field in ("severity_1_2_count", "false_success_count", "unauthorized_action_count"):
        require(incident.get(field) is None, f"incident count is fabricated: {field}")
    require(incident.get("remediation_records") == [], "incident remediation is fabricated")

    require(
        all(value == "not_obtained" for value in record.get("signoffs", {}).values()),
        "an independent sign-off is fabricated",
    )

    release_candidate = record.get("release_candidate", {})
    require(release_candidate.get("status") == "blocked", "release candidate is not blocked")
    require(release_candidate.get("approved") is False, "release candidate approval is fabricated")
    for field in ("commit", "artifact_path", "artifact_sha256"):
        require(release_candidate.get(field) is None, f"release candidate field is fabricated: {field}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    try:
        record = json.loads(args.record.read_text(encoding="utf-8"))
        require(isinstance(record, dict), "readiness record must be an object")
        validate_record(record)
    except (OSError, json.JSONDecodeError, ValidationFailure) as exc:
        print(f"beta readiness validation failed: {exc}", file=sys.stderr)
        return 2
    print(f"beta readiness contract valid and blocked: {args.record}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
