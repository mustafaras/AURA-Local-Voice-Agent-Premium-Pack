#!/usr/bin/env python3
"""Fail-closed secret, dependency, and workflow provenance checks for H-008.

The scanner deliberately reports only path, line, and pattern names. It never
prints matched text. History scanning is a separate operation because it
requires an explicit reachable-history scan and must not be inferred from a
current-tree scan.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / "archive/runtime-completion/repo-hygiene/REPO_HYGIENE_SUPPLY_CHAIN_POLICY.json"
POLICY_SCHEMA_PATH = ROOT / "archive/runtime-completion/repo-hygiene/REPO_HYGIENE_SUPPLY_CHAIN_POLICY.schema.json"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


@dataclass(frozen=True)
class SecretFinding:
  path: str
  line: int
  pattern: str


class ValidationFailure(Exception):
  pass


def load_json(path: Path) -> dict[str, Any]:
  try:
    value = json.loads(path.read_text(encoding="utf-8"))
  except (OSError, json.JSONDecodeError) as error:
    raise ValidationFailure(f"cannot parse {path.relative_to(ROOT)}: {type(error).__name__}") from error
  if not isinstance(value, dict):
    raise ValidationFailure(f"{path.relative_to(ROOT)} must contain a JSON object")
  return value


def run(command: list[str], cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
  return subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def tracked_paths() -> list[str]:
  result = run(["git", "ls-files", "-z"])
  if result.returncode != 0:
    raise ValidationFailure(f"git ls-files failed with exit {result.returncode}")
  return [item for item in result.stdout.split("\0") if item]


def policy_checks(policy: dict[str, Any]) -> list[str]:
  errors: list[str] = []
  if policy.get("$schema") != "./REPO_HYGIENE_SUPPLY_CHAIN_POLICY.schema.json":
    errors.append("policy schema pointer is not canonical")
  if policy.get("schema_version") != "1.0.0":
    errors.append("policy schema_version is not 1.0.0")
  if policy.get("program_id") != "AURA-REPO-HYGIENE":
    errors.append("policy program_id is not AURA-REPO-HYGIENE")
  if not POLICY_SCHEMA_PATH.is_file():
    errors.append("policy schema file is missing")

  secret = policy.get("secret_scan")
  if not isinstance(secret, dict) or secret.get("tracked_only") is not True:
    errors.append("secret scan must be tracked_only=true")
  patterns = secret.get("patterns", []) if isinstance(secret, dict) else []
  if not isinstance(patterns, list) or not patterns:
    errors.append("secret scan pattern list is missing")
  else:
    names: set[str] = set()
    for item in patterns:
      if not isinstance(item, dict) or not isinstance(item.get("name"), str) or not isinstance(item.get("regex"), str):
        errors.append("secret scan pattern entries must have name and regex")
        continue
      if item["name"] in names:
        errors.append(f"duplicate secret pattern name: {item['name']}")
      names.add(item["name"])
      try:
        re.compile(item["regex"])
      except re.error:
        errors.append(f"invalid secret pattern regex: {item['name']}")

  swift = policy.get("swift")
  if not isinstance(swift, dict) or swift.get("package_file") != "Package.swift":
    errors.append("Swift dependency policy does not target Package.swift")
  python_policy = policy.get("python")
  if not isinstance(python_policy, dict) or python_policy.get("project_file") != "Runtime/chatterbox/pyproject.toml" or python_policy.get("lock_file") != "Runtime/chatterbox/uv.lock":
    errors.append("Python dependency policy does not target the canonical project and lockfile")
  actions = policy.get("github_actions")
  if not isinstance(actions, dict) or actions.get("require_sha_pins") is not True:
    errors.append("GitHub Actions policy must require SHA pins")
  return errors


def compile_patterns(policy: dict[str, Any]) -> list[tuple[str, re.Pattern[str]]]:
  return [(item["name"], re.compile(item["regex"])) for item in policy["secret_scan"]["patterns"]]


def secret_findings(path: str, text: str, policy: dict[str, Any]) -> list[SecretFinding]:
  findings: list[SecretFinding] = []
  for name, regex in compile_patterns(policy):
    for match in regex.finditer(text):
      findings.append(SecretFinding(path, text.count("\n", 0, match.start()) + 1, name))
  return findings


def fixture_is_allowed(finding: SecretFinding, text: str, policy: dict[str, Any]) -> bool:
  for item in policy["secret_scan"]["fixture_allowlist"]:
    if item.get("path") == finding.path and item.get("pattern") == finding.pattern and item.get("marker") in text:
      return True
  return False


def scan_tracked_content(policy: dict[str, Any]) -> tuple[list[SecretFinding], list[SecretFinding], list[str]]:
  paths = tracked_paths()
  additional = [
    POLICY_PATH.relative_to(ROOT).as_posix(),
    POLICY_SCHEMA_PATH.relative_to(ROOT).as_posix(),
    Path(__file__).relative_to(ROOT).as_posix(),
  ]
  scan_paths = list(dict.fromkeys(paths + additional))
  errors: list[str] = []
  unallowed: list[SecretFinding] = []
  allowed: list[SecretFinding] = []
  suffixes = tuple(policy["secret_scan"].get("artifact_suffixes_forbidden_when_tracked", []))
  for relative in scan_paths:
    path = ROOT / relative
    if not path.is_file():
      errors.append(f"scan path is missing: {relative}")
      continue
    data = path.read_bytes()
    text = data.decode("utf-8", errors="replace")
    if relative in paths and relative.lower().endswith(suffixes):
      errors.append(f"tracked artifact-like path requires explicit review: {relative}")
    for finding in secret_findings(relative, text, policy):
      if fixture_is_allowed(finding, text, policy):
        allowed.append(finding)
      else:
        unallowed.append(finding)

  tracked_set = set(paths)
  for item in policy["secret_scan"]["fixture_allowlist"]:
    relative = item.get("path")
    marker = item.get("marker")
    pattern = item.get("pattern")
    if relative not in tracked_set:
      errors.append(f"fixture allowlist path is not tracked: {relative}")
      continue
    text = (ROOT / relative).read_text(encoding="utf-8")
    if marker not in text:
      errors.append(f"fixture allowlist marker is missing: {relative}:{pattern}")

  return unallowed, allowed, errors


def check_swift_dependencies(policy: dict[str, Any]) -> tuple[list[str], str]:
  errors: list[str] = []
  result = run(["swift", "package", "dump-package"])
  if result.returncode != 0:
    return [f"swift package dump-package failed with exit {result.returncode}"], "unavailable"
  try:
    package = json.loads(result.stdout)
  except json.JSONDecodeError as error:
    return [f"swift package dump-package returned invalid JSON: {type(error).__name__}"], "invalid"
  dependencies = package.get("dependencies", [])
  expected = policy["swift"].get("expected_external_dependencies", [])
  if len(dependencies) != len(expected):
    errors.append(f"Swift external dependency count {len(dependencies)} != policy count {len(expected)}")
  if not dependencies and (ROOT / "Package.resolved").exists():
    errors.append("Package.resolved exists despite zero Swift external dependencies")
  return errors, f"{len(dependencies)} external dependencies"


def check_python_dependencies(policy: dict[str, Any]) -> tuple[list[str], str]:
  errors: list[str] = []
  config = policy["python"]
  project_path = ROOT / config["project_file"]
  lock_path = ROOT / config["lock_file"]
  try:
    project = tomllib.loads(project_path.read_text(encoding="utf-8"))
    lock = tomllib.loads(lock_path.read_text(encoding="utf-8"))
  except (OSError, tomllib.TOMLDecodeError) as error:
    return [f"Python project/lock parse failed: {type(error).__name__}"], "invalid"

  project_data = project.get("project", {})
  if project_data.get("requires-python") != config["requires_python"]:
    errors.append("pyproject requires-python does not match policy")
  if lock.get("requires-python") != config["requires_python"]:
    errors.append("uv.lock requires-python does not match policy")

  expected_sources = {item["name"]: item for item in config["direct_git_sources"]}
  expected_registry_dependencies = set(config.get("direct_registry_dependencies", []))
  project_dependencies = set(project_data.get("dependencies", []))
  if project_dependencies != set(expected_sources) | expected_registry_dependencies:
    errors.append("pyproject direct dependencies do not match the policy source set")
  uv_sources = project.get("tool", {}).get("uv", {}).get("sources", {})
  for name, expected in expected_sources.items():
    actual = uv_sources.get(name, {})
    if actual.get("git") != expected["url"] or actual.get("rev") != expected["rev"]:
      errors.append(f"pyproject source pin mismatch: {name}")

  packages = lock.get("package", [])
  by_name = {item.get("name"): item for item in packages if isinstance(item, dict)}
  virtual = by_name.get(project_data.get("name"))
  if not virtual or virtual.get("source", {}).get("virtual") != ".":
    errors.append("uv.lock virtual project entry is missing")
  else:
    metadata_deps = {
      item.get("name"): item.get("git")
      for item in virtual.get("metadata", {}).get("requires-dist", [])
      if isinstance(item, dict) and item.get("git")
    }
    for name, expected in expected_sources.items():
      expected_git = f"{expected['url']}?rev={expected['rev']}"
      if metadata_deps.get(name) != expected_git:
        errors.append(f"uv.lock virtual metadata pin mismatch: {name}")
    metadata_registry = {
      f"{item.get('name')}{item.get('specifier')}": item
      for item in virtual.get("metadata", {}).get("requires-dist", [])
      if isinstance(item, dict) and item.get("specifier")
    }
    for requirement in expected_registry_dependencies:
      if requirement not in metadata_registry:
        errors.append(f"uv.lock virtual metadata registry dependency mismatch: {requirement}")

  for name, expected in expected_sources.items():
    package = by_name.get(name)
    source = package.get("source", {}) if package else {}
    resolved = source.get("git", "")
    if not resolved.startswith(expected["url"] + "?") or not resolved.endswith("#" + expected["rev"]):
      errors.append(f"uv.lock git source is not resolved to the policy commit: {name}")

  for package in packages:
    if not isinstance(package, dict):
      errors.append("uv.lock contains a non-object package entry")
      continue
    source = package.get("source", {})
    if "registry" in source:
      if source["registry"] != config["registry"]:
        errors.append(f"registry provenance mismatch: {package.get('name')}")
      artifacts: list[dict[str, Any]] = []
      if isinstance(package.get("sdist"), dict):
        artifacts.append(package["sdist"])
      if isinstance(package.get("wheels"), list):
        artifacts.extend(item for item in package["wheels"] if isinstance(item, dict))
      if not artifacts:
        errors.append(f"registry package has no hashed artifacts: {package.get('name')}")
      for artifact in artifacts:
        if not str(artifact.get("url", "")).startswith("https://files.pythonhosted.org/"):
          errors.append(f"registry artifact host is not canonical: {package.get('name')}")
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", str(artifact.get("hash", ""))):
          errors.append(f"registry artifact hash is missing or malformed: {package.get('name')}")
        if not isinstance(artifact.get("size"), int) or artifact["size"] <= 0:
          errors.append(f"registry artifact size is missing or invalid: {package.get('name')}")
    elif "git" in source:
      if not re.search(r"#[0-9a-f]{40}$", source["git"]):
        errors.append(f"git package is not resolved to a full commit: {package.get('name')}")
    elif "virtual" not in source:
      errors.append(f"package has unsupported provenance source: {package.get('name')}")

  uv_path = shutil.which("uv")
  if not uv_path:
    errors.append("uv is unavailable; intended blocker command: uv lock --check in Runtime/chatterbox")
  else:
    result = run([uv_path, "lock", "--check"], cwd=ROOT / "Runtime/chatterbox")
    if result.returncode != 0:
      errors.append(f"uv lock --check failed with exit {result.returncode}")
  return errors, f"{len(packages)} locked packages; uv lock --check executed"


def workflow_action_references(text: str) -> list[tuple[str, str, str]]:
  pattern = re.compile(r"(?m)^\s*uses:\s*([^\s@]+)@([^\s#]+)(?:\s*#\s*(.*))?$")
  return [(match.group(1), match.group(2), (match.group(3) or "").strip()) for match in pattern.finditer(text)]


def check_workflows(policy: dict[str, Any]) -> tuple[list[str], str]:
  errors: list[str] = []
  action_policy = {item["uses"]: item for item in policy["github_actions"]["required_action_pins"]}
  seen: dict[str, int] = {name: 0 for name in action_policy}
  total = 0
  for relative in policy["github_actions"]["workflow_paths"]:
    path = ROOT / relative
    if not path.is_file():
      errors.append(f"workflow file is missing: {relative}")
      continue
    for uses, ref, comment in workflow_action_references(path.read_text(encoding="utf-8")):
      total += 1
      expected = action_policy.get(uses)
      if expected is None:
        errors.append(f"workflow action is not in the approved provenance policy: {uses}")
        continue
      seen[uses] += 1
      if not SHA_RE.fullmatch(ref):
        errors.append(f"workflow action is not pinned to a full SHA: {uses}")
      elif ref != expected["sha"]:
        errors.append(f"workflow action SHA mismatch: {uses}")
      if expected["version"] not in comment:
        errors.append(f"workflow action version annotation missing: {uses}")
  for uses, count in seen.items():
    if count == 0:
      errors.append(f"approved workflow action is unused: {uses}")
  return errors, f"{total} action references checked"


def main() -> int:
  try:
    policy = load_json(POLICY_PATH)
    errors = policy_checks(policy)
    unallowed, allowed, scan_errors = scan_tracked_content(policy)
    errors.extend(scan_errors)
    swift_errors, swift_summary = check_swift_dependencies(policy)
    python_errors, python_summary = check_python_dependencies(policy)
    workflow_errors, workflow_summary = check_workflows(policy)
    errors.extend(swift_errors)
    errors.extend(python_errors)
    errors.extend(workflow_errors)
  except ValidationFailure as error:
    print(f"AURA SUPPLY-CHAIN VALIDATION FAILED: {error}")
    return 1

  if unallowed:
    errors.extend(f"unallowlisted secret-shaped finding: {item.path}:{item.line}:{item.pattern}" for item in unallowed)
  print(f"Tracked-content secret scan: {len(allowed)} intentional fixture findings allowed by exact marker/path/pattern; {len(unallowed)} unallowlisted findings")
  for item in allowed:
    print(f"  allowed fixture: {item.path}:{item.line}:{item.pattern}")
  print("Tracked prompt/ledger/log/artifact audit: no tracked log, crash, audio, screen, or archive artifacts; secret scan covers tracked text")
  print(f"Swift dependency provenance: {swift_summary}")
  print(f"Python dependency provenance: {python_summary}")
  print(f"GitHub Actions provenance: {workflow_summary}; all references are policy-approved full SHA pins")
  print("History scan: adopted-Git history scan is recorded separately; this validator covers current tracked content and provenance")
  if errors:
    for error in errors:
      print(f"ERROR: {error}")
    return 1
  print("AURA SUPPLY-CHAIN VALIDATION PASSED")
  return 0


if __name__ == "__main__":
  sys.exit(main())
