#!/usr/bin/env python3
"""Validate the AURA second-pass gap-closure control plane.

This validator is intentionally stdlib-only.  It checks the machine manifest,
the prompt files, the active state, and the human-readable synchronized
projections without treating prose or a local test as live acceptance proof.
"""

from __future__ import annotations

import argparse
import glob
import json
import re
import sys
from pathlib import Path
from typing import Any


PROMPT_ID_RE = re.compile(r"^SP-(\d{3})$")
GAP_ID_RE = re.compile(r"^OPEN-(\d{2})$")


def _load_json(path: Path, errors: list[str]) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"missing JSON file: {path}")
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {path}: {exc}")
    return None


def _require_file(root: Path, relative: str, errors: list[str]) -> Path | None:
    path = root / relative
    if not path.is_file():
        errors.append(f"missing required control file: {relative}")
        return None
    return path


def _parse_frontmatter(text: str, path: Path, errors: list[str]) -> dict[str, str]:
    if not text.startswith("---\n"):
        errors.append(f"prompt does not start with YAML front matter: {path}")
        return {}
    end = text.find("\n---\n", 4)
    if end == -1:
        errors.append(f"prompt front matter is not closed: {path}")
        return {}
    values: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" not in line:
            errors.append(f"invalid front-matter line in {path}: {line!r}")
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()
    return values


def _csv(value: str) -> list[str]:
    if value.lower() in {"none", "null", ""}:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def _validate_manifest(root: Path, manifest: dict[str, Any], errors: list[str]) -> list[dict[str, Any]]:
    required = {
        "schema_version",
        "program_name",
        "gap_register",
        "prompt_directory",
        "prompts",
        "transition_policy",
    }
    missing = sorted(required - manifest.keys())
    if missing:
        errors.append(f"manifest missing keys: {', '.join(missing)}")
    if manifest.get("schema_version") != "1.0.0":
        errors.append("manifest schema_version must be 1.0.0")
    if not isinstance(manifest.get("transition_policy"), str) or not manifest.get("transition_policy", "").strip():
        errors.append("manifest transition_policy must be non-empty")

    prompts = manifest.get("prompts")
    if not isinstance(prompts, list) or not prompts:
        errors.append("manifest prompts must be a non-empty array")
        return []

    expected_sequences = list(range(len(prompts)))
    actual_sequences = [item.get("sequence") for item in prompts if isinstance(item, dict)]
    if actual_sequences != expected_sequences:
        errors.append(f"prompt sequences must be contiguous 0..{len(prompts) - 1}: {actual_sequences}")

    ids = [item.get("id") for item in prompts if isinstance(item, dict)]
    expected_ids = [f"SP-{sequence:03d}" for sequence in range(len(prompts))]
    if ids != expected_ids:
        errors.append(f"prompt IDs must be ordered {expected_ids[0]}..{expected_ids[-1]}")
    if len(set(ids)) != len(ids):
        errors.append("manifest contains duplicate prompt IDs")

    known_ids = set(expected_ids)
    for index, item in enumerate(prompts):
        if not isinstance(item, dict):
            errors.append(f"manifest prompt {index} is not an object")
            continue
        prompt_id = item.get("id")
        if not PROMPT_ID_RE.fullmatch(str(prompt_id)):
            errors.append(f"invalid prompt ID at sequence {index}: {prompt_id!r}")
        dependencies = item.get("depends_on", [])
        if not isinstance(dependencies, list):
            errors.append(f"{prompt_id} depends_on must be an array")
            dependencies = []
        for dependency in dependencies:
            if dependency not in known_ids:
                errors.append(f"{prompt_id} depends on unknown prompt {dependency}")
            elif int(dependency[-3:]) >= index:
                errors.append(f"{prompt_id} depends on non-predecessor {dependency}")

        expected_next = expected_ids[index + 1] if index + 1 < len(prompts) else None
        if item.get("next_prompt") != expected_next:
            errors.append(f"{prompt_id} next_prompt must be {expected_next!r}")
        for gap_id in item.get("gap_ids", []):
            if not GAP_ID_RE.fullmatch(str(gap_id)):
                errors.append(f"{prompt_id} has invalid gap ID {gap_id!r}")

        file_name = item.get("file")
        if not isinstance(file_name, str):
            errors.append(f"{prompt_id} has no prompt file path")
            continue
        prompt_path = root / file_name
        if not prompt_path.is_file():
            errors.append(f"{prompt_id} prompt file is missing: {file_name}")
            continue
        try:
            text = prompt_path.read_text(encoding="utf-8")
        except OSError as exc:
            errors.append(f"cannot read {file_name}: {exc}")
            continue
        front = _parse_frontmatter(text, prompt_path, errors)
        expected_front = {
            "id": str(prompt_id),
            "sequence": str(item.get("sequence")),
            "track": str(item.get("track")),
            "gap_ids": ", ".join(item.get("gap_ids", [])),
            "depends_on": ", ".join(item.get("depends_on", [])) or "none",
            "next_prompt": str(item.get("next_prompt")) if item.get("next_prompt") else "none",
            "state": "pending",
        }
        for key, expected in expected_front.items():
            if front.get(key) != expected:
                errors.append(f"{prompt_id} front matter {key}={front.get(key)!r}, expected {expected!r}")
        required_phrases = (
            "Cognitive completion gate",
            "Required records",
            "SECOND_PASS_LEDGER.md",
            "SECOND_PASS_OPEN_GAPS.md",
            "SESSION_CLOSEOUT",
            "Do not proceed",
        )
        for phrase in required_phrases:
            if phrase.lower() not in text.lower():
                errors.append(f"{prompt_id} missing required contract phrase: {phrase}")

    return prompts


def _validate_state(root: Path, manifest_prompts: list[dict[str, Any]], state: dict[str, Any], errors: list[str]) -> None:
    prompt_ids = [item["id"] for item in manifest_prompts]
    known = set(prompt_ids)
    active = state.get("active_prompt")
    completed = state.get("completed_prompts", [])
    blocked = state.get("blocked_prompts", [])
    if active not in known:
        errors.append(f"second-pass active_prompt is unknown: {active!r}")
    if len(completed) > len(prompt_ids) or completed != prompt_ids[: len(completed)]:
        errors.append("completed_prompts must be an ordered prefix of the prompt chain")
    for prompt_id in completed + blocked:
        if prompt_id not in known:
            errors.append(f"state references unknown prompt: {prompt_id}")
    if active in completed:
        errors.append("active_prompt cannot also be completed")
    if blocked and blocked != [active]:
        errors.append("only the active prompt may be blocked")
    if active in known:
        active_sequence = prompt_ids.index(active)
        if active_sequence != len(completed):
            errors.append("active_prompt must be the first uncompleted prompt")
    if state.get("active_state") not in {"pending", "in_progress", "blocked", "completed"}:
        errors.append("second-pass active_state is invalid")
    if not isinstance(state.get("next_action"), str) or not state["next_action"].strip():
        errors.append("second-pass next_action must be non-empty")
    controls = state.get("control_files", {})
    required_control_keys = {
        "gap_register",
        "prompt_manifest",
        "prompt_contract",
        "context_read_first",
        "ledger",
        "first_pass_state",
        "session_handoff",
        "validator",
        "prompt_program",
    }
    missing = sorted(required_control_keys - controls.keys())
    if missing:
        errors.append(f"second-pass state missing control file keys: {', '.join(missing)}")
    for key, relative in controls.items():
        if isinstance(relative, str):
            _require_file(root, relative, errors)

    # Evidence-traceability invariant: every completed prompt must have at
    # least one matching evidence artifact file on disk (state/EV-SP-###-*.md)
    # OR a corresponding row in EVIDENCE_INDEX.md. This closes the historical
    # blind spot where a completed prompt had an index row but neither an
    # artifact file nor a dense inline record (e.g. SP-010). The active prompt
    # is exempt: it may be blocked with handoff-only evidence.
    state_dir = root / "AURA_RUNTIME_COMPLETION/state"
    on_disk_evidence = 0
    index_text = ""
    index_path = root / "AURA_RUNTIME_COMPLETION/state/EVIDENCE_INDEX.md"
    if index_path.is_file():
        index_text = index_path.read_text(encoding="utf-8")
    if state_dir.is_dir():
        on_disk_evidence = len(glob.glob(str(state_dir / "EV-SP-*.md")))
        for prompt_id in completed:
            number = prompt_id.replace("SP-", "", 1)
            file_prefix = f"EV-SP-{number}"
            has_file = bool(glob.glob(str(state_dir / f"{file_prefix}-*.md")))
            # EVIDENCE_INDEX row is present if the prefix appears as a cell
            # followed by a pipe or as an inline `EV-SP-###-...` token.
            has_index = (
                f"| {file_prefix}-" in index_text
                or f"`{file_prefix}-" in index_text
                or f"**{file_prefix}-" in index_text
            )
            if not (has_file or has_index):
                errors.append(
                    f"completed prompt {prompt_id} has no matching evidence artifact file "
                    f"(expected state/{file_prefix}-*.md) and no EVIDENCE_INDEX.md row"
                )
    else:
        errors.append(f"missing second-pass evidence directory: {state_dir}")
    if on_disk_evidence == 0:
        errors.append("no EV-SP-*.md evidence files found under state/")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    manifest_path = root / "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_MANIFEST.json"
    state_path = root / "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_STATE.json"
    manifest = _load_json(manifest_path, errors)
    state = _load_json(state_path, errors)
    active = state.get("active_prompt") if isinstance(state, dict) else None
    if not isinstance(manifest, dict):
        return errors
    prompts = _validate_manifest(root, manifest, errors)

    gaps_path = root / "AURA_RUNTIME_COMPLETION/SECOND_PASS_OPEN_GAPS.md"
    gaps_text = gaps_path.read_text(encoding="utf-8") if gaps_path.is_file() else ""
    if not gaps_text:
        errors.append("missing or empty SECOND_PASS_OPEN_GAPS.md")
    gap_headings = set(re.findall(r"^## (OPEN-\d{2})\b", gaps_text, re.MULTILINE))
    for gap_id in (f"OPEN-{index:02d}" for index in range(16)):
        if gap_id not in gap_headings:
            errors.append(f"gap register is missing heading {gap_id}")
    for item in prompts:
        for gap_id in item.get("gap_ids", []):
            if gap_id not in gap_headings:
                errors.append(f"{item['id']} references gap not present in gap register: {gap_id}")
    for control_file in (
        "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_CONTROL_CONTRACT.md",
        "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_PROMPT_CONTRACT.md",
        "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_LEDGER.md",
        "AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md",
        "AURA_RUNTIME_COMPLETION/SECOND_PASS_PROMPT_PROGRAM.md",
    ):
        _require_file(root, control_file, errors)

    read_first = root / "AURA_RUNTIME_COMPLETION/context/SECOND_PASS_READ_FIRST.md"
    if read_first.is_file():
        read_text = read_first.read_text(encoding="utf-8")
        if "Tier 0" not in read_text or "Tier 1" not in read_text:
            errors.append("SECOND_PASS_READ_FIRST.md must define Tier 0 and Tier 1")

    handoff = root / "AURA_RUNTIME_COMPLETION/context/session-handoff.json"
    if handoff.is_file():
        handoff_data = _load_json(handoff, errors)
        handoff_prompt = handoff_data.get("active_prompt", {}) if isinstance(handoff_data, dict) else {}
        if not isinstance(handoff_prompt, dict):
            errors.append("session-handoff.json active_prompt must be an object")
        else:
            if handoff_prompt.get("id") != active:
                errors.append(
                    f"session-handoff.json active_prompt must match second-pass active_prompt {active!r}"
                )
            if handoff_prompt.get("state") != state.get("active_state"):
                errors.append(
                    "session-handoff.json active_prompt state must match second-pass active_state"
                )
        handoff_text = handoff.read_text(encoding="utf-8")
        if "SECOND_PASS_LEDGER.md" not in handoff_text:
            errors.append("session-handoff.json must reference SECOND_PASS_LEDGER.md")

    active_context = root / "AURA_RUNTIME_COMPLETION/context/ACTIVE_CONTEXT.md"
    if active_context.is_file():
        active_text = active_context.read_text(encoding="utf-8")
        expected_overlay = f"{active}` / `{state.get('active_state')}"
        if "Second-pass synchronized overlay" not in active_text or expected_overlay not in active_text:
            errors.append(
                f"ACTIVE_CONTEXT.md must record the synchronized {active}/{state.get('active_state')} overlay"
            )

    ledger = root / "AURA_RUNTIME_COMPLETION/second-pass/SECOND_PASS_LEDGER.md"
    if ledger.is_file():
        ledger_text = ledger.read_text(encoding="utf-8")
        for phrase in ("append-only", "Current state", "Authority", "Next action"):
            if phrase.lower() not in ledger_text.lower():
                errors.append(f"SECOND_PASS_LEDGER.md missing synchronization field: {phrase}")

    program = root / "AURA_RUNTIME_COMPLETION/SECOND_PASS_PROMPT_PROGRAM.md"
    if program.is_file():
        program_text = program.read_text(encoding="utf-8")
        for phrase in ("scripts/validate_second_pass_program.py", "SP-000", "SP-033"):
            if phrase not in program_text:
                errors.append(f"SECOND_PASS_PROMPT_PROGRAM.md missing: {phrase}")

    if isinstance(state, dict):
        _validate_state(root, prompts, state, errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        print("SECOND-PASS VALIDATION FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print("SECOND-PASS VALIDATION PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
