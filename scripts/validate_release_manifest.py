#!/usr/bin/env python3
"""Validate AURA release manifest structure and bound file digests.

This is not a replacement for Apple's signature, notarization, or Gatekeeper
checks. This local validator accepts only ``development_unverified`` manifests;
release statuses require a separately authorized verifier that consumes actual
Apple/tool output rather than trusting booleans in JSON.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path
from typing import Any


STATUSES = {"development_unverified", "release_candidate", "released"}
REQUIRED_TOP_LEVEL = {
    "schema_version",
    "manifest_type",
    "release_status",
    "bundle",
    "source",
    "toolchain",
    "helper_ipc_protocol",
    "artifact",
    "bundle_files",
    "sbom",
    "signature",
}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_relative(value: str) -> str:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or value.startswith("/"):
        raise ValueError(f"unsafe manifest path: {value!r}")
    return path.as_posix()


def verify_artifact(artifact: dict[str, Any], artifact_path: Path) -> None:
    if artifact.get("path") != artifact_path.name:
        raise ValueError("artifact path does not match the supplied artifact")
    actual_size = artifact_path.stat().st_size
    actual_hash = digest(artifact_path.read_bytes())
    if artifact.get("size_bytes") != actual_size or artifact.get("sha256") != actual_hash:
        raise ValueError("artifact size or SHA-256 mismatch")


def verify_bundle_files(entries: list[dict[str, Any]], bundle_root: Path) -> None:
    seen: set[str] = set()
    for entry in entries:
        relative = safe_relative(str(entry.get("path", "")))
        if relative in seen:
            raise ValueError(f"duplicate bundle file: {relative}")
        seen.add(relative)
        path = bundle_root / relative
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"manifest file is missing or symlinked: {relative}")
        if entry.get("size_bytes") != path.stat().st_size:
            raise ValueError(f"bundle file size mismatch: {relative}")
        if entry.get("sha256") != digest(path.read_bytes()):
            raise ValueError(f"bundle file SHA-256 mismatch: {relative}")


def verify_manifest(manifest: dict[str, Any], bundle_root: Path | None, artifact_path: Path | None) -> None:
    missing = REQUIRED_TOP_LEVEL - manifest.keys()
    if missing:
        raise ValueError(f"manifest is missing keys: {sorted(missing)}")
    if manifest["schema_version"] != 1 or manifest["manifest_type"] != "aura.release":
        raise ValueError("unsupported release manifest schema/type")
    status = manifest["release_status"]
    if status not in STATUSES:
        raise ValueError(f"unsupported release status: {status!r}")
    bundle = manifest["bundle"]
    if bundle.get("bundle_id") != "ai.aura.local.agent":
        raise ValueError("unexpected bundle identifier")
    if not bundle.get("version") or not bundle.get("build") or not bundle.get("minimum_os"):
        raise ValueError("bundle identity/version/minimum OS is incomplete")
    if not str(manifest["helper_ipc_protocol"]).strip():
        raise ValueError("helper IPC protocol binding is missing")

    entries = manifest["bundle_files"]
    if not isinstance(entries, list) or not entries:
        raise ValueError("bundle_files must be a non-empty list")
    manifest_paths = {safe_relative(str(item.get("path", ""))) for item in entries}
    if len(manifest_paths) != len(entries):
        raise ValueError("duplicate bundle file path")
    sbom = manifest["sbom"]
    if sbom.get("format") != "aura-bundle-inventory-v1":
        raise ValueError("unsupported SBOM format")
    component_refs = {item.get("bom-ref") for item in sbom.get("components", [])}
    if component_refs != manifest_paths:
        raise ValueError("SBOM does not cover exactly the manifest bundle files")

    signature = manifest["signature"]
    if status != "development_unverified":
        raise ValueError(
            "release status is blocked; use a separately authorized external release verifier"
        )
    if signature.get("developer_id") or signature.get("notarization") != "not_submitted":
        raise ValueError("development artifact has an inconsistent signature status")

    if bundle_root:
        verify_bundle_files(entries, bundle_root)
    if artifact_path:
        artifact = manifest.get("artifact")
        if not isinstance(artifact, dict):
            raise ValueError("artifact metadata is required when an artifact is supplied")
        verify_artifact(artifact, artifact_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--bundle-root", type=Path)
    parser.add_argument("--artifact", type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        verify_manifest(
            manifest,
            args.bundle_root.resolve() if args.bundle_root else None,
            args.artifact.resolve() if args.artifact else None,
        )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"release manifest validation failed: {exc}", file=sys.stderr)
        return 2
    print(f"release manifest valid: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
