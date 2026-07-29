#!/usr/bin/env python3
"""Install the exact Chatterbox V3 model snapshot outside the repository."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

from huggingface_hub import snapshot_download


MODEL_REPOSITORY = "ResembleAI/chatterbox"
MODEL_REVISION = "5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18"
MODEL_FILES = (
    "ve.pt",
    "t3_mtl23ls_v3.safetensors",
    "s3gen.pt",
    "grapheme_mtl_merged_expanded_v1.json",
    "conds.pt",
    "Cangjie5_TC.json",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True)
    args = parser.parse_args()

    model_dir = Path(args.model_dir).expanduser().resolve()
    model_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(model_dir, 0o700)

    snapshot_download(
        repo_id=MODEL_REPOSITORY,
        repo_type="model",
        revision=MODEL_REVISION,
        allow_patterns=list(MODEL_FILES),
        local_dir=model_dir,
    )

    missing = [name for name in MODEL_FILES if not (model_dir / name).is_file()]
    if missing:
        raise RuntimeError(f"model snapshot incomplete: {', '.join(missing)}")
    for name in MODEL_FILES:
        os.chmod(model_dir / name, 0o600)

    manifest = {
        "schema_version": 1,
        "repository": MODEL_REPOSITORY,
        "revision": MODEL_REVISION,
        "variant": "multilingual-v3",
        "files": {
            name: {
                "bytes": (model_dir / name).stat().st_size,
                "sha256": sha256(model_dir / name),
            }
            for name in MODEL_FILES
        },
    }
    manifest_path = model_dir / "AURA_MODEL_MANIFEST.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.chmod(manifest_path, 0o600)
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
