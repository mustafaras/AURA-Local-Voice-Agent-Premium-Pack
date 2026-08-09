#!/usr/bin/env python3
"""Generate a provenance-bound AURA bundle inventory and release manifest.

This tool deliberately does not sign, notarize, upload, install, or publish an
artifact. It makes a local development artifact auditable and marks it
``development_unverified`` unless a separately authorized release process
provides the required signature/notarization evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


EXPECTED_BUNDLE_ID = "ai.aura.local.agent"
ALLOWED_STATUSES = {"development_unverified", "release_candidate", "released"}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_optional(command: list[str]) -> str | None:
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return value or None


def source_provenance(source_root: Path) -> dict[str, Any]:
    commit = run_optional(["git", "-C", str(source_root), "rev-parse", "HEAD"])
    status = run_optional(["git", "-C", str(source_root), "status", "--porcelain"])
    return {
        "commit": commit or "unknown",
        "working_tree": "clean" if status == "" else "dirty_or_unavailable",
    }


def collect_bundle_files(bundle: Path) -> list[dict[str, Any]]:
    files: list[dict[str, Any]] = []
    for path in sorted(bundle.rglob("*")):
        if not path.is_file():
            continue
        if path.is_symlink():
            raise ValueError(f"symlink is not allowed in release bundle inventory: {path}")
        relative = path.relative_to(bundle).as_posix()
        files.append(
            {
                "path": relative,
                "size_bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    if not files:
        raise ValueError(f"bundle contains no regular files: {bundle}")
    return files


def reproducible_archive(bundle: Path, archive: Path) -> None:
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as output:
        for entry in collect_bundle_files(bundle):
            source = bundle / entry["path"]
            info = zipfile.ZipInfo(f"{bundle.name}/{entry['path']}")
            info.date_time = (1980, 1, 1, 0, 0, 0)
            info.compress_type = zipfile.ZIP_STORED
            info.external_attr = 0o100644 << 16
            output.writestr(info, source.read_bytes())


def read_bundle_identity(bundle: Path) -> dict[str, str]:
    info_path = bundle / "Contents" / "Info.plist"
    try:
        values = plistlib.loads(info_path.read_bytes())
    except (OSError, plistlib.InvalidFileException) as exc:
        raise ValueError(f"cannot read bundle Info.plist: {info_path}") from exc
    bundle_id = str(values.get("CFBundleIdentifier", ""))
    if bundle_id != EXPECTED_BUNDLE_ID:
        raise ValueError(f"unexpected bundle identifier: {bundle_id!r}")
    version = str(values.get("CFBundleShortVersionString", ""))
    build = str(values.get("CFBundleVersion", ""))
    if not version or not build:
        raise ValueError("bundle version/build metadata is incomplete")
    return {"bundle_id": bundle_id, "version": version, "build": build}


def build_manifest(args: argparse.Namespace) -> dict[str, Any]:
    bundle = args.bundle.resolve()
    if not bundle.is_dir() or bundle.suffix != ".app":
        raise ValueError(f"bundle must be an existing .app directory: {bundle}")
    if args.status not in ALLOWED_STATUSES:
        raise ValueError(f"unsupported release status: {args.status}")

    identity = read_bundle_identity(bundle)
    bundle_files = collect_bundle_files(bundle)
    archive_path: Path | None = args.archive.resolve() if args.archive else None
    if archive_path:
        reproducible_archive(bundle, archive_path)

    artifact: dict[str, Any] | None = None
    if archive_path:
        artifact = {
            "path": archive_path.name,
            "size_bytes": archive_path.stat().st_size,
            "sha256": sha256_file(archive_path),
        }

    components = [
        {
            "type": "file",
            "bom-ref": item["path"],
            "name": item["path"],
            "hashes": [{"alg": "SHA-256", "content": item["sha256"]}],
        }
        for item in bundle_files
    ]
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "manifest_type": "aura.release",
        "release_status": args.status,
        "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "bundle": {
            **identity,
            "minimum_os": args.minimum_os,
            "relative_path": bundle.name,
        },
        "source": source_provenance(args.source_root.resolve()),
        "toolchain": {
            "swift": run_optional(["swift", "--version"]) or "unavailable",
            "xcode_select": run_optional(["xcode-select", "-p"]) or "unavailable",
        },
        "helper_ipc_protocol": args.helper_ipc_protocol,
        "artifact": artifact,
        "bundle_files": bundle_files,
        "sbom": {
            "format": "aura-bundle-inventory-v1",
            "scope": "bundle-files-only",
            "components": components,
        },
        "signature": {
            "developer_id": False,
            "hardened_runtime": False,
            "notarization": "not_submitted",
            "stapled": False,
            "verification": "not_performed",
        },
    }
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--status", default="development_unverified")
    parser.add_argument("--minimum-os", default="27.0")
    parser.add_argument("--helper-ipc-protocol", required=True)
    args = parser.parse_args()
    try:
        manifest = build_manifest(args)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    except (OSError, ValueError) as exc:
        print(f"release manifest generation failed: {exc}", file=sys.stderr)
        return 2
    print(f"release manifest: {args.output}")
    if args.archive:
        print(f"reproducible archive: {args.archive}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
