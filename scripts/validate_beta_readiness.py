#!/usr/bin/env python3
"""Fail-closed validation for the local R12 beta-readiness contract.

The contract has two representable modes and this validator enforces both:

* **Unstarted** — nothing has been measured, run, or obtained. Every field must
  say so explicitly.
* **Measured** — a result is recorded. Every recorded result must carry its own
  provenance: an evidence ID, a measurement class that states how the number was
  produced, and the limitations of that class.

The second mode is what makes an honest beta recordable at all. It is not a
relaxation: a result without provenance fails, an unknown status fails, a
sign-off that does not name an independent evaluator fails, and a measurement
class that is not live-user-present can never be presented as one. This
validator never enrolls users, enables telemetry, measures SLOs, or authorizes a
release; it only proves the record is internally honest about what happened.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


class ValidationFailure(Exception):
    """The readiness contract is unsafe, incomplete, or unprovenanced."""


ALLOWED_STATUSES = {"blocked", "not_ready"}

EVIDENCE_ID_RE = re.compile(r"^EV-[A-Z0-9][A-Z0-9-]{4,}$")
# Same character class as EVIDENCE_ID_RE, without the anchors: used to scan an
# arbitrary block of text (the evidence index) for every ID it names, rather
# than to validate one candidate string in isolation.
_EVIDENCE_ID_SCAN_RE = re.compile(r"EV-[A-Z0-9][A-Z0-9-]{4,}")

EVIDENCE_INDEX_RELATIVE_PATH = Path("archive/runtime-completion/state/EVIDENCE_INDEX.md")


def _load_known_evidence_ids(repo_root: Path | None = None) -> frozenset[str]:
    """Every evidence ID mentioned anywhere in the committed evidence index.

    A well-formed evidence ID is not provenance by itself — it is a plausible-
    looking string until something can confirm it names a real record. This
    scans `EVIDENCE_INDEX.md` (the append-only ledger every evidence ID is
    required to appear in, per SECOND_PASS_CONTROL_CONTRACT.md) for every
    substring shaped like an evidence ID, rather than parsing its table
    structure — a scan cannot be fooled by a malformed row, and a fabricated ID
    cannot appear in the file's text without actually being added to it.
    """
    root = repo_root if repo_root is not None else Path(__file__).resolve().parents[1]
    index_path = root / EVIDENCE_INDEX_RELATIVE_PATH
    if not index_path.is_file():
        # Fails closed: an unreadable index makes every evidence ID unverifiable,
        # so nothing should be accepted rather than everything.
        return frozenset()
    text = index_path.read_text(encoding="utf-8")
    return frozenset(_EVIDENCE_ID_SCAN_RE.findall(text))

# How a number was produced. The class travels with the number so a repeatable
# harness result can never be read as a live beta sample.
MEASUREMENT_CLASSES = {
    # A real, user-present beta window with a consented participant.
    "live_user_present",
    # A deterministic test harness. Repeatable, but not a live beta sample.
    "deterministic_harness",
    # The documented synthetic-speech accommodation. Not live-microphone WER.
    "synthetic_speech",
}

SLO_STATUSES = {"not_measured", "measured"}
SCENARIO_STATUSES = {"not_run", "passed", "failed"}
INCIDENT_STATUSES = {"not_run", "completed"}

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


def _require_evidence_id(value: Any, where: str, known_ids: frozenset[str]) -> None:
    require(
        isinstance(value, str) and bool(EVIDENCE_ID_RE.fullmatch(value)),
        f"{where} must carry a well-formed evidence ID, got {value!r}",
    )
    # A well-formed ID is a plausible-looking string, not provenance. It must
    # actually name a record in EVIDENCE_INDEX.md, or a fabricated but
    # correctly-shaped ID would pass every other check in this validator.
    require(
        value in known_ids,
        f"{where} names {value!r}, which does not exist in EVIDENCE_INDEX.md",
    )


def _require_limitations(value: Any, where: str) -> None:
    require(
        isinstance(value, str) and len(value.strip()) >= 12,
        f"{where} must state its limitations in prose",
    )


def _require_class(value: Any, where: str) -> str:
    require(
        value in MEASUREMENT_CLASSES,
        f"{where} has an unknown measurement class {value!r}; "
        f"allowed: {sorted(MEASUREMENT_CLASSES)}",
    )
    return str(value)


def _require_positive_int(value: Any, where: str) -> int:
    require(isinstance(value, int) and not isinstance(value, bool) and value > 0, f"{where} must be a positive integer")
    return int(value)


def _require_non_negative_int(value: Any, where: str) -> int:
    require(
        isinstance(value, int) and not isinstance(value, bool) and value >= 0,
        f"{where} must be a non-negative integer",
    )
    return int(value)


def _validate_authority(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    authority = record.get("authority", {})
    require(isinstance(authority, dict), "authority must be an object")
    # Release authority is SP-031/ADR-047 territory and is never granted here.
    require(authority.get("release") is False, "authority unexpectedly enables release")
    # Any enabling flag must name the grant that produced it.
    for field in ("beta_enrollment", "telemetry_activation", "app_install_or_launch"):
        value = authority.get(field)
        require(isinstance(value, bool), f"authority.{field} must be a boolean")
        if value is True:
            _require_evidence_id(
                authority.get("authority_source"),
                f"authority.{field} is enabled, so authority.authority_source",
                known_ids,
            )


def _validate_dependency(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    dependency = record.get("dependency_gate", {})
    require(isinstance(dependency, dict), "dependency_gate must be an object")
    state = dependency.get("r11_state")
    require(state in {"in_progress", "completed"}, f"unknown r11_state {state!r}")
    if state == "completed":
        _require_evidence_id(dependency.get("r11_evidence_id"), "a completed R11 gate", known_ids)
    require(
        dependency.get("r11_release_status") == "development_unverified",
        "R11 release status is unsafe",
    )
    require(dependency.get("r11_completion_required") is True, "R11 dependency gate is missing")


def _validate_cohort(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    cohort = record.get("cohort", {})
    require(isinstance(cohort, dict), "cohort must be an object")
    status = cohort.get("status")
    require(status in {"not_enrolled", "enrolled"}, f"unknown cohort status {status!r}")
    if status == "not_enrolled":
        require(cohort.get("consent") == "not_collected", "beta consent is present without enrollment")
        require(cohort.get("minimum_sessions") is None, "beta sample size is fabricated")
        return
    require(cohort.get("consent") == "collected", "an enrolled cohort must record collected consent")
    _require_evidence_id(cohort.get("consent_evidence_id"), "collected beta consent", known_ids)
    require(
        isinstance(cohort.get("type"), str) and cohort["type"] not in ("", "none"),
        "an enrolled cohort must name its type",
    )
    _require_positive_int(cohort.get("participants"), "cohort.participants")


def _validate_telemetry(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    telemetry = record.get("telemetry", {})
    require(isinstance(telemetry, dict), "telemetry must be an object")
    require(telemetry.get("consent_required") is True, "telemetry consent gate is missing")
    # Privacy invariants that hold in every mode.
    require(telemetry.get("raw_content_allowed") is False, "raw content is allowed")
    require(telemetry.get("transport") == "none", "telemetry transport is active")
    for field in telemetry.get("aggregate_fields", []):
        lowered = str(field).lower()
        require(
            not any(term in lowered for term in FORBIDDEN_CONTENT_TERMS),
            f"content field is present: {field}",
        )
    enabled = telemetry.get("enabled")
    require(isinstance(enabled, bool), "telemetry.enabled must be a boolean")
    if enabled is False:
        require(telemetry.get("retention_days") is None, "telemetry retention is fabricated")
        return
    _require_evidence_id(telemetry.get("consent_evidence_id"), "enabled telemetry", known_ids)
    _require_positive_int(telemetry.get("retention_days"), "telemetry.retention_days")


def _validate_slos(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    for definition in record.get("slo_definitions", []):
        require(isinstance(definition, dict), "each SLO definition must be an object")
        slo_id = definition.get("id", "<unnamed>")
        where = f"SLO {slo_id!r}"
        status = definition.get("status")
        require(status in SLO_STATUSES, f"{where} has unknown status {status!r}")

        if status == "not_measured":
            require(definition.get("target_ms") is None, f"{where} presents a target without a measurement")
            require(
                definition.get("sample_minimum") is None,
                f"{where} presents a sample minimum without a measurement",
            )
            require(
                definition.get("measurement") is None,
                f"{where} carries a measurement while claiming not_measured",
            )
            continue

        measurement = definition.get("measurement")
        require(isinstance(measurement, dict), f"{where} is measured but carries no measurement block")
        _require_evidence_id(measurement.get("evidence_id"), f"{where} measurement", known_ids)
        measurement_class = _require_class(measurement.get("measurement_class"), f"{where} measurement")
        _require_limitations(measurement.get("limitations"), f"{where} measurement")

        sample_minimum = _require_positive_int(definition.get("sample_minimum"), f"{where}.sample_minimum")
        sample_count = _require_positive_int(measurement.get("sample_count"), f"{where} sample_count")
        require(
            sample_count >= sample_minimum,
            f"{where} reports {sample_count} samples below its declared minimum {sample_minimum}",
        )

        percentiles = definition.get("percentiles") or []
        if percentiles:
            values = measurement.get("percentiles_ms")
            require(isinstance(values, dict) and values, f"{where} declares percentiles but records none")
            for percentile in percentiles:
                key = str(percentile)
                require(key in values, f"{where} is missing recorded percentile p{key}")
                require(
                    isinstance(values[key], (int, float)) and not isinstance(values[key], bool),
                    f"{where} percentile p{key} must be numeric",
                )
        else:
            value = measurement.get("value")
            require(
                isinstance(value, (int, float)) and not isinstance(value, bool),
                f"{where} is a scalar metric and must record a numeric value",
            )

        # A target may only be presented once a real measurement exists to compare it to.
        target = definition.get("target_ms")
        if target is not None:
            require(
                isinstance(target, (int, float)) and not isinstance(target, bool),
                f"{where}.target_ms must be numeric",
            )
            require(
                isinstance(measurement.get("meets_target"), bool),
                f"{where} declares a target but does not state whether it was met",
            )
        # A harness result must never be dressed up as a live beta sample.
        if measurement_class != "live_user_present":
            require(
                measurement.get("live_beta_sample") is not True,
                f"{where} claims a live beta sample from a {measurement_class} measurement",
            )


def _validate_scenarios(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    for scenario in record.get("scenario_matrix", []):
        require(isinstance(scenario, dict), "each scenario must be an object")
        scenario_id = scenario.get("id", "<unnamed>")
        where = f"scenario {scenario_id!r}"
        status = scenario.get("status")
        require(status in SCENARIO_STATUSES, f"{where} has unknown status {status!r}")
        evidence_ids = scenario.get("evidence_ids")
        require(isinstance(evidence_ids, list), f"{where} evidence_ids must be an array")

        if status == "not_run":
            require(evidence_ids == [], f"{where} carries evidence while claiming not_run")
            require(scenario.get("measurement_class") is None, f"{where} carries a class while claiming not_run")
            continue

        require(bool(evidence_ids), f"{where} is {status} but cites no evidence")
        for evidence_id in evidence_ids:
            _require_evidence_id(evidence_id, f"{where} evidence", known_ids)
        _require_class(scenario.get("measurement_class"), where)
        _require_limitations(scenario.get("limitations"), where)


def _validate_incidents(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    incident = record.get("incident_review", {})
    require(isinstance(incident, dict), "incident_review must be an object")
    status = incident.get("status")
    require(status in INCIDENT_STATUSES, f"incident_review has unknown status {status!r}")
    counts = ("severity_1_2_count", "false_success_count", "unauthorized_action_count")
    records = incident.get("remediation_records")
    require(isinstance(records, list), "incident_review.remediation_records must be an array")

    if status == "not_run":
        for field in counts:
            require(incident.get(field) is None, f"incident count is fabricated: {field}")
        require(records == [], "incident remediation is fabricated")
        return

    _require_evidence_id(incident.get("evidence_id"), "a completed incident review", known_ids)
    total = 0
    for field in counts:
        total += _require_non_negative_int(incident.get(field), f"incident_review.{field}")
    require(
        total == 0 or bool(records),
        "a completed incident review reports incidents but records no remediation",
    )
    for entry in records:
        require(isinstance(entry, dict), "each remediation record must be an object")
        for field in ("root_cause", "remediation", "regression_test", "closure_owner"):
            require(
                isinstance(entry.get(field), str) and entry[field].strip(),
                f"remediation record is missing {field}",
            )
        _require_evidence_id(entry.get("evidence_id"), "a remediation record", known_ids)


def _validate_signoffs(record: dict[str, Any], known_ids: frozenset[str]) -> None:
    signoffs = record.get("signoffs", {})
    require(isinstance(signoffs, dict) and signoffs, "signoffs must be a non-empty object")
    for name, value in signoffs.items():
        where = f"sign-off {name!r}"
        if value == "not_obtained":
            continue
        require(
            isinstance(value, dict),
            f"{where} must be either 'not_obtained' or an object recording who signed",
        )
        require(value.get("status") == "obtained", f"{where} has unknown status {value.get('status')!r}")
        # Independence is the whole point of this gate: it cannot be self-granted.
        require(
            isinstance(value.get("evaluator"), str) and value["evaluator"].strip(),
            f"{where} is obtained but names no evaluator",
        )
        require(
            value.get("independent") is True,
            f"{where} must assert evaluator independence",
        )
        require(
            value.get("evaluator_is_implementing_agent") is False,
            f"{where} cannot be signed by the implementing agent",
        )
        _require_evidence_id(value.get("evidence_id"), where, known_ids)


def _validate_release_candidate(record: dict[str, Any]) -> None:
    # Unchanged: promoting a release candidate is SP-031/ADR-047 work, never this record's.
    release_candidate = record.get("release_candidate", {})
    require(isinstance(release_candidate, dict), "release_candidate must be an object")
    require(release_candidate.get("status") == "blocked", "release candidate is not blocked")
    require(release_candidate.get("approved") is False, "release candidate approval is fabricated")
    for field in ("commit", "artifact_path", "artifact_sha256"):
        require(release_candidate.get(field) is None, f"release candidate field is fabricated: {field}")


def validate_record(
    record: dict[str, Any], known_evidence_ids: frozenset[str] | None = None
) -> None:
    """`known_evidence_ids` overrides the default `EVIDENCE_INDEX.md` scan —
    intended for tests, which reference synthetic IDs no production index
    should ever actually contain. Production callers (`main`) always use the
    default, which is the real committed index."""
    known_ids = (
        known_evidence_ids if known_evidence_ids is not None else _load_known_evidence_ids()
    )
    require(record.get("schema_version") == "1.0.0", "unsupported readiness schema")
    require(record.get("readiness_status") in ALLOWED_STATUSES, "readiness must be blocked")
    _validate_authority(record, known_ids)
    _validate_dependency(record, known_ids)
    _validate_cohort(record, known_ids)
    _validate_telemetry(record, known_ids)
    _validate_slos(record, known_ids)
    _validate_scenarios(record, known_ids)
    _validate_incidents(record, known_ids)
    _validate_signoffs(record, known_ids)
    _validate_release_candidate(record)


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
    print(f"beta readiness contract valid: {args.record}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
