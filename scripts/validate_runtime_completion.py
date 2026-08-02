#!/usr/bin/env python3
"""Validate AURA Runtime Completion state, evidence, and repository claims.

This validator intentionally uses only the Python standard library. It supports
all JSON Schema keywords used by the repository schemas and fails closed when a
schema introduces an unsupported keyword.
"""

from __future__ import annotations

import argparse
import datetime as datetime_module
import json
import re
import subprocess
import sys
from collections import deque
from pathlib import Path
from typing import Any


class ValidationFailure(Exception):
    """An actionable repository validation failure."""


class SchemaSubsetValidator:
    """Validate the JSON Schema subset used by AURA's local contracts."""

    _SUPPORTED_SCHEMA_KEYS = {
        "$defs",
        "$id",
        "$ref",
        "$schema",
        "additionalProperties",
        "const",
        "enum",
        "format",
        "items",
        "maxItems",
        "maxLength",
        "maxProperties",
        "maximum",
        "minItems",
        "minLength",
        "minimum",
        "pattern",
        "properties",
        "required",
        "title",
        "type",
        "uniqueItems",
    }

    def __init__(self, schema: dict[str, Any], source: str) -> None:
        self.schema = schema
        self.source = source

    def validate(self, value: Any) -> None:
        self._validate(value, self.schema, "$", self.schema)

    def _resolve_ref(self, reference: str, root_schema: dict[str, Any]) -> dict[str, Any]:
        if not reference.startswith("#/"):
            raise ValidationFailure(
                f"{self.source}: unsupported external schema reference {reference!r}"
            )
        resolved: Any = root_schema
        for component in reference[2:].split("/"):
            component = component.replace("~1", "/").replace("~0", "~")
            if not isinstance(resolved, dict) or component not in resolved:
                raise ValidationFailure(
                    f"{self.source}: unresolved schema reference {reference!r}"
                )
            resolved = resolved[component]
        if not isinstance(resolved, dict):
            raise ValidationFailure(
                f"{self.source}: schema reference {reference!r} is not an object"
            )
        return resolved

    @staticmethod
    def _type_matches(value: Any, expected_type: str) -> bool:
        if expected_type == "object":
            return isinstance(value, dict)
        if expected_type == "array":
            return isinstance(value, list)
        if expected_type == "string":
            return isinstance(value, str)
        if expected_type == "integer":
            return isinstance(value, int) and not isinstance(value, bool)
        if expected_type == "number":
            return isinstance(value, (int, float)) and not isinstance(value, bool)
        if expected_type == "boolean":
            return isinstance(value, bool)
        if expected_type == "null":
            return value is None
        raise ValidationFailure(f"unsupported JSON Schema type {expected_type!r}")

    @staticmethod
    def _same_json(left: Any, right: Any) -> bool:
        return json.dumps(left, sort_keys=True, separators=(",", ":")) == json.dumps(
            right, sort_keys=True, separators=(",", ":")
        )

    def _validate(
        self,
        value: Any,
        schema: dict[str, Any],
        path: str,
        root_schema: dict[str, Any],
    ) -> None:
        unsupported = set(schema) - self._SUPPORTED_SCHEMA_KEYS
        if unsupported:
            names = ", ".join(sorted(unsupported))
            raise ValidationFailure(
                f"{self.source}: unsupported schema keywords at {path}: {names}"
            )

        if "$ref" in schema:
            resolved = self._resolve_ref(schema["$ref"], root_schema)
            self._validate(value, resolved, path, root_schema)
            return

        if "const" in schema and not self._same_json(value, schema["const"]):
            raise ValidationFailure(
                f"{self.source}: {path} must equal {schema['const']!r}, got {value!r}"
            )

        if "enum" in schema and not any(
            self._same_json(value, candidate) for candidate in schema["enum"]
        ):
            raise ValidationFailure(
                f"{self.source}: {path} must be one of {schema['enum']!r}, got {value!r}"
            )

        expected_types = schema.get("type")
        if expected_types is not None:
            if isinstance(expected_types, str):
                expected_types = [expected_types]
            if not any(self._type_matches(value, item) for item in expected_types):
                raise ValidationFailure(
                    f"{self.source}: {path} has type {type(value).__name__}, "
                    f"expected {expected_types!r}"
                )

        if isinstance(value, str):
            if len(value) < schema.get("minLength", 0):
                raise ValidationFailure(f"{self.source}: {path} is shorter than minLength")
            if "maxLength" in schema and len(value) > schema["maxLength"]:
                raise ValidationFailure(f"{self.source}: {path} exceeds maxLength")
            if "pattern" in schema and re.search(schema["pattern"], value) is None:
                raise ValidationFailure(f"{self.source}: {path} does not match pattern")
            if schema.get("format") == "date-time":
                try:
                    parsed = datetime_module.datetime.fromisoformat(
                        value.replace("Z", "+00:00")
                    )
                except ValueError as error:
                    raise ValidationFailure(
                        f"{self.source}: {path} is not an ISO date-time"
                    ) from error
                if parsed.tzinfo is None:
                    raise ValidationFailure(
                        f"{self.source}: {path} must include a timezone"
                    )

        if isinstance(value, (int, float)) and not isinstance(value, bool):
            if "minimum" in schema and value < schema["minimum"]:
                raise ValidationFailure(f"{self.source}: {path} is below minimum")
            if "maximum" in schema and value > schema["maximum"]:
                raise ValidationFailure(f"{self.source}: {path} exceeds maximum")

        if isinstance(value, list):
            if len(value) < schema.get("minItems", 0):
                raise ValidationFailure(f"{self.source}: {path} has too few items")
            if "maxItems" in schema and len(value) > schema["maxItems"]:
                raise ValidationFailure(f"{self.source}: {path} has too many items")
            if schema.get("uniqueItems"):
                normalized = [
                    json.dumps(item, sort_keys=True, separators=(",", ":"))
                    for item in value
                ]
                if len(normalized) != len(set(normalized)):
                    raise ValidationFailure(f"{self.source}: {path} contains duplicates")
            if isinstance(schema.get("items"), dict):
                for index, item in enumerate(value):
                    self._validate(item, schema["items"], f"{path}[{index}]", root_schema)

        if isinstance(value, dict):
            if "maxProperties" in schema and len(value) > schema["maxProperties"]:
                raise ValidationFailure(f"{self.source}: {path} has too many properties")
            for required_name in schema.get("required", []):
                if required_name not in value:
                    raise ValidationFailure(
                        f"{self.source}: {path} is missing required property {required_name!r}"
                    )
            properties = schema.get("properties", {})
            additional = schema.get("additionalProperties", True)
            for name, child in value.items():
                child_path = f"{path}.{name}"
                if name in properties:
                    self._validate(value[name], properties[name], child_path, root_schema)
                elif additional is False:
                    raise ValidationFailure(
                        f"{self.source}: {child_path} is not an allowed property"
                    )
                elif isinstance(additional, dict):
                    self._validate(value[name], additional, child_path, root_schema)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError as error:
        raise ValidationFailure(f"missing JSON file: {path}") from error
    except json.JSONDecodeError as error:
        raise ValidationFailure(f"malformed JSON in {path}: {error}") from error


def validate_json_against_schema(document_path: Path, schema_path: Path) -> Any:
    document = load_json(document_path)
    schema = load_json(schema_path)
    if not isinstance(schema, dict):
        raise ValidationFailure(f"schema is not an object: {schema_path}")
    SchemaSubsetValidator(schema, str(schema_path)).validate(document)
    return document


def run_git(repo_root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ValidationFailure(f"git {' '.join(arguments)} failed: {detail}")
    return result.stdout.strip()


def validate_dependency_graph(manifest: dict[str, Any]) -> None:
    entries = manifest["prompts"]
    by_id = {entry["id"]: entry for entry in entries}
    if len(by_id) != len(entries):
        raise ValidationFailure("prompt manifest contains duplicate IDs")
    orders = [entry["order"] for entry in entries]
    if orders != list(range(len(entries))):
        raise ValidationFailure("prompt manifest orders must be contiguous from zero")
    adjacency = {prompt_id: [] for prompt_id in by_id}
    indegree = {prompt_id: 0 for prompt_id in by_id}
    for entry in entries:
        for dependency in entry["dependencies"]:
            if dependency not in by_id:
                raise ValidationFailure(
                    f"prompt {entry['id']} depends on missing prompt {dependency}"
                )
            adjacency[dependency].append(entry["id"])
            indegree[entry["id"]] += 1
    queue = deque(prompt_id for prompt_id, degree in indegree.items() if degree == 0)
    visited: list[str] = []
    while queue:
        prompt_id = queue.popleft()
        visited.append(prompt_id)
        for child in adjacency[prompt_id]:
            indegree[child] -= 1
            if indegree[child] == 0:
                queue.append(child)
    if len(visited) != len(entries):
        raise ValidationFailure("prompt dependency graph contains a cycle")


def validate_prompt_contract(
    repo_root: Path,
    manifest: dict[str, Any],
    state: dict[str, Any],
    handoff: dict[str, Any],
) -> None:
    validate_dependency_graph(manifest)
    validate_manifest_prompt_files(repo_root, manifest)
    active_state = state["active_prompt"]
    active_handoff = handoff["active_prompt"]
    if active_state["id"] != active_handoff["id"] or active_state["file"] != active_handoff["file"]:
        raise ValidationFailure("active prompt differs between current-state and handoff")
    entries = manifest["prompts"]
    by_id = {entry["id"]: entry for entry in entries}
    if active_state["id"] not in by_id:
        raise ValidationFailure(f"active prompt is not in manifest: {active_state['id']}")
    for required_path in handoff["required_first_reads"]:
        if not (repo_root / required_path).exists():
            raise ValidationFailure(f"required first-read path is missing: {required_path}")
    for reference in (manifest["shared_contract"], manifest["state_file"], manifest["handoff_file"]):
        if not (repo_root / reference).exists():
            raise ValidationFailure(f"manifest reference is missing: {reference}")


def validate_manifest_prompt_files(repo_root: Path, manifest: dict[str, Any]) -> None:
    entries = manifest["prompts"]
    for entry in entries:
        prompt_path = repo_root / entry["file"]
        if not prompt_path.is_file():
            raise ValidationFailure(f"manifest prompt file is missing: {entry['file']}")
    closeout = repo_root / "AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md"
    if not closeout.is_file():
        raise ValidationFailure("mandatory session closeout prompt is missing")


def extract_ids(path: Path, prefix: str) -> set[str]:
    pattern = re.compile(rf"\b{re.escape(prefix)}-[A-Za-z0-9][A-Za-z0-9._-]*\b")
    return set(pattern.findall(path.read_text()))


def validate_references(
    repo_root: Path,
    state: dict[str, Any],
    handoff: dict[str, Any],
    capability: dict[str, Any],
) -> None:
    evidence_ids = extract_ids(
        repo_root / "AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md", "EV"
    )
    risk_ids = extract_ids(
        repo_root / "AURA_RUNTIME_COMPLETION/state/RISK_REGISTER.md", "RISK"
    )
    known_gates = {gate["id"] for gate in state["release_gates"]}

    def require_known(identifier: str, known: set[str], context: str) -> None:
        if identifier not in known:
            raise ValidationFailure(f"unknown {context} reference: {identifier}")

    for identifier in state.get("last_evidence_ids", []):
        require_known(identifier, evidence_ids, "evidence")
    for track in state["tracks"]:
        for identifier in track.get("evidence_ids", []):
            require_known(identifier, evidence_ids, "evidence")
        for identifier in track.get("open_risk_ids", []):
            require_known(identifier, risk_ids, "risk")
    for gate in state["release_gates"]:
        for identifier in gate.get("evidence_ids", []):
            require_known(identifier, evidence_ids, "evidence")
    for identifier in handoff.get("evidence_ids", []):
        require_known(identifier, evidence_ids, "evidence")
    for identifier in handoff.get("risks", []):
        require_known(identifier, risk_ids, "risk")
    validate_capability_entries(capability, evidence_ids)
    for gate in state["release_gates"]:
        if gate["id"] not in known_gates:
            raise ValidationFailure(f"invalid release gate ID: {gate['id']}")


def validate_capability_entries(capability: dict[str, Any], evidence_ids: set[str]) -> None:
    for entry in capability["capabilities"]:
        for identifier in entry.get("evidence_ids", []):
            if identifier not in evidence_ids:
                raise ValidationFailure(f"unknown evidence reference: {identifier}")
        verification_state = entry["verification_state"]
        if verification_state in {"live_verified", "release_verified"} and not entry.get("evidence_ids"):
            raise ValidationFailure(
                f"capability {entry['id']} claims {verification_state} without evidence"
            )
        if verification_state == "none" and entry.get("evidence_ids"):
            raise ValidationFailure(
                f"capability {entry['id']} has evidence but verification_state=none"
            )


def validate_completed_tracks(state: dict[str, Any]) -> None:
    for track in state["tracks"]:
        if track["state"] == "completed" and not track.get("evidence_ids"):
            raise ValidationFailure(
                f"completed track {track['id']} has no evidence IDs"
            )


def validate_release_state(state: dict[str, Any]) -> None:
    if state["program_status"] == "released":
        blocking = [
            gate["id"]
            for gate in state["release_gates"]
            if gate["required_for"] in {"external_beta", "release"}
            and gate["state"] not in {"passed", "waived", "not_applicable"}
        ]
        if blocking:
            raise ValidationFailure(
                "released state has open mandatory gates: " + ", ".join(blocking)
            )
    validate_completed_tracks(state)


def validate_worktree_claim(
    status: str, stored_state: str, user_owned_changes: list[str]
) -> None:
    expected_worktree = "clean" if not status else "dirty_expected"
    if stored_state != expected_worktree:
        raise ValidationFailure(
            f"state working_tree_state={stored_state} but live worktree is {expected_worktree}"
        )
    if status and not user_owned_changes:
        raise ValidationFailure("dirty_expected state must describe its expected changes")


def projection_only_paths(paths: list[str]) -> bool:
    allowed_prefixes = (
        "AURA_RUNTIME_COMPLETION/",
        "ledger/",
        "SESSION_STARTER.md",
        "TOOLCHAIN.md",
        "docs/decisions/ADR-045-toolchain-release-pipeline.md",
    )
    return all(path.startswith(allowed_prefixes) for path in paths)


def validate_repository_claims(repo_root: Path, state: dict[str, Any]) -> None:
    repository = state["repository"]
    head = run_git(repo_root, "rev-parse", "HEAD")
    branch = run_git(repo_root, "branch", "--show-current")
    remote_ref = f"origin/{repository['default_branch']}"
    remote_head = run_git(repo_root, "rev-parse", remote_ref)
    status = run_git(repo_root, "status", "--porcelain=v1")
    verified_head = repository["verified_head"]

    if branch != repository["active_branch"]:
        raise ValidationFailure(
            f"state branch {repository['active_branch']} disagrees with live branch {branch}"
        )
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", verified_head, head],
        cwd=repo_root,
        capture_output=True,
        check=False,
    )
    if ancestor.returncode != 0:
        raise ValidationFailure(
            f"verified_head {verified_head} is not an ancestor of live HEAD {head}"
        )
    if head != verified_head:
        changed = run_git(repo_root, "diff", "--name-only", f"{verified_head}..{head}").splitlines()
        if not projection_only_paths(changed):
            raise ValidationFailure(
                "live HEAD differs from verified_head with non-projection changes: "
                + ", ".join(changed)
            )
    if remote_head != repository["remote_head"]:
        if not projection_only_paths(
            run_git(repo_root, "diff", "--name-only", f"{repository['remote_head']}..{remote_head}").splitlines()
        ):
            raise ValidationFailure(
                f"state remote_head {repository['remote_head']} disagrees with live {remote_head}"
            )
    validate_worktree_claim(
        status, repository["working_tree_state"], repository.get("user_owned_changes", [])
    )


def validate_legacy_pointers(repo_root: Path) -> None:
    for relative_path in ("ledger/CURRENT_STATE.md", "SESSION_STARTER.md"):
        text = (repo_root / relative_path).read_text()
        if "AURA_RUNTIME_COMPLETION/state/current-state.json" not in text:
            raise ValidationFailure(f"legacy state file lacks canonical pointer: {relative_path}")
        if "historical" not in text.lower() and "compatibility" not in text.lower():
            raise ValidationFailure(f"legacy state file is not marked historical: {relative_path}")


def validate_toolchain_environment(repo_root: Path, toolchain: dict[str, Any], release: bool) -> None:
    observed = toolchain["observed"]
    swift_version = observed["swift_version"]
    if "Swift 6.4" not in swift_version:
        raise ValidationFailure(
            f"unsupported Swift toolchain {swift_version}; expected the pinned 6.4 development baseline"
        )
    if observed["architecture"] != "arm64":
        raise ValidationFailure("unsupported architecture; AURA requires arm64")
    if release and not observed["xcodebuild_available"]:
        raise ValidationFailure("release validation requires full Xcode/xcodebuild")
    if not (repo_root / toolchain["validation"]["script"]).exists():
        raise ValidationFailure("toolchain validation script is missing")


def validate_repository(repo_root: Path, release: bool = False) -> None:
    runtime_root = repo_root / "AURA_RUNTIME_COMPLETION"
    document_checks = [
        ("state/current-state.json", "schemas/program-state.schema.json"),
        ("context/session-handoff.json", "schemas/session-handoff.schema.json"),
        ("prompts/prompt-manifest.json", "schemas/prompt-manifest.schema.json"),
        ("context/context-index.json", "schemas/context-index.schema.json"),
        ("state/capability-matrix.json", "schemas/capability-matrix.schema.json"),
        ("state/toolchain-manifest.json", "schemas/toolchain-manifest.schema.json"),
    ]
    documents: dict[str, Any] = {}
    for document, schema in document_checks:
        documents[document] = validate_json_against_schema(
            runtime_root / document, runtime_root / schema
        )
    state = documents["state/current-state.json"]
    handoff = documents["context/session-handoff.json"]
    manifest = documents["prompts/prompt-manifest.json"]
    capability = documents["state/capability-matrix.json"]
    toolchain = documents["state/toolchain-manifest.json"]
    validate_prompt_contract(repo_root, manifest, state, handoff)
    validate_references(repo_root, state, handoff, capability)
    validate_release_state(state)
    validate_repository_claims(repo_root, state)
    validate_legacy_pointers(repo_root)
    validate_toolchain_environment(repo_root, toolchain, release)
    if capability["repository_commit"] != state["repository"]["verified_head"]:
        raise ValidationFailure(
            "capability matrix repository_commit does not match state verified_head"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--release", action="store_true", help="Require full Xcode for release validation")
    parser.add_argument("--ci", action="store_true", help="Run the CI governance validation profile")
    arguments = parser.parse_args()
    try:
        validate_repository(arguments.repo_root.resolve(), release=arguments.release)
    except ValidationFailure as error:
        print(f"VALIDATION FAILED: {error}", file=sys.stderr)
        return 1
    print("AURA runtime-completion validation passed")
    if arguments.ci:
        print("CI governance checks: schema, state, manifest, evidence, capability, toolchain, and legacy pointers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
