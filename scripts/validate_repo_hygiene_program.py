#!/usr/bin/env python3
"""Validate the linear AURA repository-hygiene control plane.

This validator intentionally uses only the Python standard library so that the
control plane remains usable before dependency installation or full Xcode.
It validates synchronization and prompt shape; it does not claim that a gap
has been solved.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_MANIFEST.json"
STATE = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json"
PROGRAM = ROOT / "docs/operations/REPO_HYGIENE_PROGRAM.md"
READ_FIRST = ROOT / "AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_READ_FIRST.md"
CONTRACT = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_CONTROL_CONTRACT.md"
PROMPT_CONTRACT = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_PROMPT_CONTRACT.md"
LEDGER = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_LEDGER.md"
CONTEXT_SUMMARY = ROOT / "AURA_RUNTIME_COMPLETION/context/REPO_HYGIENE_CONTEXT_SUMMARY.md"
ARCHITECTURE_AUDIT = ROOT / "AURA_RUNTIME_COMPLETION/repo-hygiene/H-009_ARCHITECTURE_AUDIT.md"

REQUIRED_PROMPT_MARKERS = (
    "## Cognitive completion gate",
    "## Required records",
    "REPO_HYGIENE_STATE.json",
    "REPO_HYGIENE_LEDGER.md",
    "Do not proceed",
    "## SESSION_CLOSEOUT",
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def load_json(path: Path, errors: list[str]) -> dict:
    if not path.is_file():
        fail(errors, f"missing JSON: {path.relative_to(ROOT)}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(errors, f"invalid JSON {path.relative_to(ROOT)}: {exc}")
        return {}
    if not isinstance(value, dict):
        fail(errors, f"JSON root is not an object: {path.relative_to(ROOT)}")
        return {}
    return value


def frontmatter(path: Path, errors: list[str]) -> dict[str, str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        fail(errors, f"cannot read prompt {path}: {exc}")
        return {}
    if len(lines) < 3 or lines[0] != "---":
        fail(errors, f"prompt lacks front matter: {path.relative_to(ROOT)}")
        return {}
    try:
        end = lines.index("---", 1)
    except ValueError:
        fail(errors, f"prompt front matter is not closed: {path.relative_to(ROOT)}")
        return {}
    values: dict[str, str] = {}
    for line in lines[1:end]:
        match = re.fullmatch(r"([a-z_]+):\s*(.*)", line)
        if not match:
            fail(errors, f"invalid front matter line in {path.relative_to(ROOT)}: {line}")
            continue
        values[match.group(1)] = match.group(2)
    return values


def main() -> int:
    errors: list[str] = []
    manifest = load_json(MANIFEST, errors)
    state = load_json(STATE, errors)
    program = PROGRAM.read_text(encoding="utf-8") if PROGRAM.is_file() else ""
    read_first = READ_FIRST.read_text(encoding="utf-8") if READ_FIRST.is_file() else ""

    for path in (PROGRAM, READ_FIRST, CONTRACT, PROMPT_CONTRACT, LEDGER):
        if not path.is_file():
            fail(errors, f"missing control file: {path.relative_to(ROOT)}")

    prompts = manifest.get("prompts", [])
    if not isinstance(prompts, list) or len(prompts) != 11:
        fail(errors, "manifest must contain exactly 11 prompts")
        prompts = []

    expected_ids = [f"H-{index:03d}" for index in range(11)]
    actual_ids = [item.get("id") for item in prompts if isinstance(item, dict)]
    if actual_ids != expected_ids:
        fail(errors, f"manifest order must be {expected_ids}, got {actual_ids}")

    for index, item in enumerate(prompts):
        if not isinstance(item, dict):
            fail(errors, f"manifest item {index} is not an object")
            continue
        prompt_id = item.get("id", f"index-{index}")
        expected_dep = None if index == 0 else expected_ids[index - 1]
        expected_next = None if index == 10 else expected_ids[index + 1]
        if item.get("sequence") != index:
            fail(errors, f"{prompt_id}: sequence mismatch")
        if item.get("gap_id") != f"HYGIENE-{index:02d}":
            fail(errors, f"{prompt_id}: gap_id mismatch")
        if item.get("depends_on") != expected_dep:
            fail(errors, f"{prompt_id}: dependency must be {expected_dep}")
        if item.get("next_prompt") != expected_next:
            fail(errors, f"{prompt_id}: next_prompt must be {expected_next}")
        file_value = item.get("file", "")
        path = ROOT / file_value
        if not path.is_file():
            fail(errors, f"{prompt_id}: missing prompt file {file_value}")
            continue
        values = frontmatter(path, errors)
        if values.get("id") != prompt_id or values.get("sequence") != str(index):
            fail(errors, f"{prompt_id}: front matter identity mismatch")
        if values.get("gap_id") != item.get("gap_id"):
            fail(errors, f"{prompt_id}: front matter gap mismatch")
        if values.get("depends_on") != ("none" if expected_dep is None else expected_dep):
            fail(errors, f"{prompt_id}: front matter dependency mismatch")
        if values.get("next_prompt") != ("none" if expected_next is None else expected_next):
            fail(errors, f"{prompt_id}: front matter next prompt mismatch")
        content = path.read_text(encoding="utf-8")
        for marker in REQUIRED_PROMPT_MARKERS:
            if marker not in content:
                fail(errors, f"{prompt_id}: missing required marker {marker}")

    for index in range(11):
        gap = f"### HYGIENE-{index:02d}"
        if gap not in program:
            fail(errors, f"program document missing {gap}")
        if f"H-{index:03d}" not in program:
            fail(errors, f"program document missing H-{index:03d} reference")

    if "## Tier 0" not in read_first or "## Tier 1" not in read_first:
        fail(errors, "read-first context must define Tier 0 and Tier 1")
    for required in ("AGENTS.md", "README.md", "REPO_HYGIENE_STATE.json", "REPO_HYGIENE_PROMPT_MANIFEST.json"):
        if required not in read_first:
            fail(errors, f"read-first context missing {required}")

    active = state.get("active_prompt")
    completed = state.get("completed_prompts", [])
    blocked = state.get("blocked_prompts", [])
    if active not in expected_ids:
        fail(errors, f"state active_prompt is invalid: {active}")
    if not isinstance(completed, list) or completed != expected_ids[: len(completed)]:
        fail(errors, "state completed_prompts must be an ordered prefix")
    if not isinstance(blocked, list) or any(item not in expected_ids for item in blocked):
        fail(errors, "state blocked_prompts contains an unknown prompt")
    if completed == expected_ids:
        if active != "H-010":
            fail(errors, "completed final state must retain active_prompt H-010")
        if state.get("active_state") != "completed":
            fail(errors, "completed final state must set active_state=completed")
        if state.get("program_status") != "completed":
            fail(errors, "completed final state must set program_status=completed")
    elif completed and active != expected_ids[len(completed)]:
        fail(errors, "state active_prompt must be the first incomplete prompt")
    if not completed and active != "H-000":
        fail(errors, "initial state must activate H-000")
    if blocked and blocked != [active]:
        fail(errors, "only the active prompt may be blocked")

    if active == "H-009" or "H-009" in completed:
        for path in (CONTEXT_SUMMARY, ARCHITECTURE_AUDIT):
            if not path.is_file():
                fail(errors, f"H-009 missing required audit artifact: {path.relative_to(ROOT)}")
        if CONTEXT_SUMMARY.is_file():
            summary = CONTEXT_SUMMARY.read_text(encoding="utf-8")
            for marker in (
                "not a source of truth",
                "REPO_HYGIENE_STATE.json",
                "REPO_HYGIENE_PROMPT_MANIFEST.json",
                "REPO_HYGIENE_LEDGER.md",
                "H-009_ARCHITECTURE_AUDIT.md",
            ):
                if marker not in summary:
                    fail(errors, f"H-009 context summary missing marker: {marker}")
        if ARCHITECTURE_AUDIT.is_file():
            audit = ARCHITECTURE_AUDIT.read_text(encoding="utf-8")
            for marker in (
                "Symptom",
                "Mechanism",
                "Layer",
                "Root cause",
                "Evidence",
                "Confidence",
                "Severity",
                "Owner",
                "Falsification",
                "Residual risk",
                "Next gate",
                "ADR-034",
                "ADR-044",
            ):
                if marker not in audit:
                    fail(errors, f"H-009 architecture audit missing marker: {marker}")

    if errors:
        print("REPO-HYGIENE VALIDATION FAILED")
        for error in errors:
            print(f"- {error}")
        return 1
    print("REPO-HYGIENE VALIDATION PASSED")
    print("- 11 prompts are linear, present, and marker-complete")
    print(f"- state is synchronized at {state.get('active_prompt')}/{state.get('active_state')}")
    print("- control contracts, read-first context, gap headings, and ledger exist")
    return 0


if __name__ == "__main__":
    sys.exit(main())
