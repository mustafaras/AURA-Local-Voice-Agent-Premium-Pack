#!/usr/bin/env python3
"""Persistent, stdin/stdout-only Chatterbox Multilingual V3 helper."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import resource
import sys
import time
import uuid
import wave


MAX_TEXT_CHARACTERS = 2_000
SUPPORTED_LANGUAGES = {"tr", "en"}
MODEL_FILES = (
    "ve.pt",
    "t3_mtl23ls_v3.safetensors",
    "s3gen.pt",
    "grapheme_mtl_merged_expanded_v1.json",
    "conds.pt",
    "Cangjie5_TC.json",
)
MODEL_REPOSITORY = "ResembleAI/chatterbox"
MODEL_REVISION = "5bb1f6ee58e50c3b8d408bc82a6d3740c2db6e18"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_model_manifest(model_dir: Path) -> None:
    manifest_path = model_dir / "AURA_MODEL_MANIFEST.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError("model integrity manifest unavailable") from error

    if (
        manifest.get("schema_version") != 1
        or manifest.get("repository") != MODEL_REPOSITORY
        or manifest.get("revision") != MODEL_REVISION
        or manifest.get("variant") != "multilingual-v3"
    ):
        raise RuntimeError("model integrity manifest identity mismatch")

    files = manifest.get("files")
    if not isinstance(files, dict) or set(files) != set(MODEL_FILES):
        raise RuntimeError("model integrity manifest file set mismatch")

    for name in MODEL_FILES:
        path = model_dir / name
        entry = files.get(name)
        if (
            path.is_symlink()
            or not path.is_file()
            or not isinstance(entry, dict)
            or entry.get("bytes") != path.stat().st_size
            or entry.get("sha256") != sha256(path)
        ):
            raise RuntimeError(f"model integrity verification failed: {name}")


def validate_reference_audio(path: Path) -> None:
    if (
        path.is_symlink()
        or not path.is_file()
        or path.suffix.lower() != ".wav"
        or not 44 < path.stat().st_size <= 100 * 1024 * 1024
    ):
        raise RuntimeError("reference audio must be a bounded regular WAV file")
    try:
        with wave.open(str(path), "rb") as recording:
            channels = recording.getnchannels()
            sample_width = recording.getsampwidth()
            sample_rate = recording.getframerate()
            frame_count = recording.getnframes()
    except (OSError, EOFError, wave.Error) as error:
        raise RuntimeError("reference audio must contain valid PCM WAV data") from error

    duration = frame_count / sample_rate if sample_rate else 0
    if (
        channels not in {1, 2}
        or sample_width not in {2, 4}
        or not 16_000 <= sample_rate <= 48_000
        or not 3.0 <= duration <= 30.0
    ):
        raise RuntimeError(
            "reference audio must be 3...30 s PCM, mono/stereo, 16...48 kHz"
        )


def emit(payload: dict[str, object]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def safe_error(detail: object) -> str:
    text = str(detail).replace("\n", " ").replace("\r", " ").strip()
    return text[:500] if text else "unknown helper error"


def validate_runtime_paths(
    model_dir: Path, output_dir: Path, reference_audio: Path | None
) -> None:
    if not model_dir.is_dir():
        raise RuntimeError("model directory is unavailable")
    missing = [name for name in MODEL_FILES if not (model_dir / name).is_file()]
    if missing:
        raise RuntimeError(f"model snapshot incomplete: {', '.join(missing)}")
    verify_model_manifest(model_dir)

    output_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(output_dir, 0o700)

    if reference_audio is not None:
        validate_reference_audio(reference_audio)


def select_device(requested: str) -> str:
    import torch

    if requested == "mps" and torch.backends.mps.is_available():
        return "mps"
    if requested in {"mps", "cpu"}:
        return "cpu"
    raise RuntimeError("unsupported inference device")


def load_model(model_dir: Path, device: str):
    with contextlib.redirect_stdout(sys.stderr):
        from chatterbox.mtl_tts import ChatterboxMultilingualTTS

        return ChatterboxMultilingualTTS.from_local(
            model_dir, device=device, t3_model="v3"
        )


def synthesize(
    model,
    request: dict[str, object],
    output_dir: Path,
    reference_audio: Path | None,
) -> dict[str, object]:
    import torch
    import torchaudio

    request_id = str(request.get("id", ""))
    try:
        uuid.UUID(request_id)
    except (ValueError, TypeError) as error:
        raise ValueError("request id must be a UUID") from error

    text = request.get("text")
    if not isinstance(text, str):
        raise ValueError("text must be a string")
    text = text.strip()
    if not text or len(text) > MAX_TEXT_CHARACTERS:
        raise ValueError(f"text length must be 1...{MAX_TEXT_CHARACTERS}")

    language = request.get("language", "tr")
    if language not in SUPPORTED_LANGUAGES:
        raise ValueError("language must be tr or en")

    emphasis = request.get("emphasis", 0.0)
    if not isinstance(emphasis, (int, float)) or not 0.0 <= float(emphasis) <= 1.0:
        raise ValueError("emphasis must be within 0...1")

    exaggeration = 0.48 + (0.18 * float(emphasis))
    cfg_weight = 0.35
    output_path = (output_dir / f"{request_id}.wav").resolve()
    if output_path.parent != output_dir:
        raise RuntimeError("invalid output path")

    started = time.monotonic()
    kwargs: dict[str, object] = {
        "text": text,
        "language_id": language,
        "exaggeration": exaggeration,
        "cfg_weight": cfg_weight,
        "temperature": 0.8,
    }
    if reference_audio is not None:
        kwargs["audio_prompt_path"] = str(reference_audio)

    with contextlib.redirect_stdout(sys.stderr), torch.inference_mode():
        waveform = model.generate(**kwargs)
        if waveform.ndim == 1:
            waveform = waveform.unsqueeze(0)
        waveform = waveform.detach().to("cpu")
        torchaudio.save(str(output_path), waveform, model.sr)

    os.chmod(output_path, 0o600)
    return {
        "type": "result",
        "id": request_id,
        "path": str(output_path),
        "sample_rate": int(model.sr),
        "frames": int(waveform.shape[-1]),
        "synthesis_ms": int((time.monotonic() - started) * 1_000),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--reference-audio")
    parser.add_argument("--device", choices=("mps", "cpu"), default="mps")
    args = parser.parse_args()

    model_dir = Path(args.model_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    reference_audio = (
        Path(args.reference_audio).expanduser().resolve()
        if args.reference_audio
        else None
    )

    try:
        validate_runtime_paths(model_dir, output_dir, reference_audio)
        device = select_device(args.device)
        model = load_model(model_dir, device)
        emit(
            {
                "type": "ready",
                "device": device,
                "model": "chatterbox-multilingual-v3",
                "reference_configured": reference_audio is not None,
                "max_rss_bytes": int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss),
            }
        )
    except Exception as error:
        emit({"type": "fatal", "detail": safe_error(error)})
        return 1

    for line in sys.stdin:
        try:
            if len(line) > 16_384:
                raise ValueError("request exceeds protocol byte limit")
            request = json.loads(line)
            if not isinstance(request, dict):
                raise ValueError("request must be a JSON object")
            command = request.get("command")
            if command == "shutdown":
                emit({"type": "stopped"})
                return 0
            if command == "health":
                emit(
                    {
                        "type": "health",
                        "device": device,
                        "model": "chatterbox-multilingual-v3",
                        "reference_configured": reference_audio is not None,
                    }
                )
                continue
            if command != "synthesize":
                raise ValueError("unsupported command")
            emit(synthesize(model, request, output_dir, reference_audio))
        except Exception as error:
            emit(
                {
                    "type": "error",
                    "id": request.get("id") if isinstance(request, dict) else None,
                    "detail": safe_error(error),
                }
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
