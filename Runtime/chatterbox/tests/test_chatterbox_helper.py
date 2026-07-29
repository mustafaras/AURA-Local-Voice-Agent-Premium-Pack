from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
import wave

import chatterbox_helper as helper


class ChatterboxHelperIntegrityTests(unittest.TestCase):
    def test_exact_manifest_is_accepted_and_tampering_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            model_dir = Path(temporary)
            files: dict[str, dict[str, object]] = {}
            for index, name in enumerate(helper.MODEL_FILES):
                path = model_dir / name
                path.write_bytes(f"fixture-{index}".encode())
                files[name] = {
                    "bytes": path.stat().st_size,
                    "sha256": helper.sha256(path),
                }

            manifest = {
                "schema_version": 1,
                "repository": helper.MODEL_REPOSITORY,
                "revision": helper.MODEL_REVISION,
                "variant": "multilingual-v3",
                "files": files,
            }
            (model_dir / "AURA_MODEL_MANIFEST.json").write_text(
                json.dumps(manifest), encoding="utf-8"
            )

            helper.verify_model_manifest(model_dir)
            (model_dir / helper.MODEL_FILES[0]).write_bytes(b"tampered")

            with self.assertRaisesRegex(RuntimeError, "integrity verification failed"):
                helper.verify_model_manifest(model_dir)

    def test_missing_manifest_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(RuntimeError, "manifest unavailable"):
                helper.verify_model_manifest(Path(temporary))

    def test_manifest_cannot_substitute_model_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            model_dir = Path(temporary)
            (model_dir / "AURA_MODEL_MANIFEST.json").write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "repository": "attacker/model",
                        "revision": helper.MODEL_REVISION,
                        "variant": "multilingual-v3",
                        "files": {},
                    }
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(RuntimeError, "identity mismatch"):
                helper.verify_model_manifest(model_dir)

    def test_reference_audio_has_bounded_pcm_shape(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            reference = Path(temporary) / "reference.wav"
            with wave.open(str(reference), "wb") as recording:
                recording.setnchannels(1)
                recording.setsampwidth(2)
                recording.setframerate(16_000)
                recording.writeframes(b"\0\0" * 16_000 * 3)

            helper.validate_reference_audio(reference)

            truncated = Path(temporary) / "truncated.wav"
            truncated.write_bytes(b"not-a-wave" * 8)
            with self.assertRaisesRegex(RuntimeError, "valid PCM WAV"):
                helper.validate_reference_audio(truncated)


if __name__ == "__main__":
    unittest.main()
