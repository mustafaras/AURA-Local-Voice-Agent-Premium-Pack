from __future__ import annotations

import json
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import generate_release_manifest as generator  # noqa: E402
import validate_release_manifest as validator  # noqa: E402


class ReleaseManifestTests(unittest.TestCase):
    def make_bundle(self, root: Path) -> Path:
        bundle = root / "AURA.app"
        contents = bundle / "Contents"
        (contents / "MacOS").mkdir(parents=True)
        (contents / "Resources").mkdir()
        (contents / "MacOS" / "AURA").write_bytes(b"release-test-binary")
        (contents / "Resources" / "marker.txt").write_text("marker\n", encoding="utf-8")
        (contents / "Info.plist").write_bytes(
            plistlib.dumps(
                {
                    "CFBundleIdentifier": "ai.aura.local.agent",
                    "CFBundleShortVersionString": "0.1.0",
                    "CFBundleVersion": "1",
                }
            )
        )
        return bundle

    def args(self, root: Path, bundle: Path, manifest: Path, archive: Path):
        return type(
            "Args",
            (),
            {
                "bundle": bundle,
                "archive": archive,
                "output": manifest,
                "source_root": root,
                "status": "development_unverified",
                "minimum_os": "27.0",
                "helper_ipc_protocol": "2",
            },
        )()

    def test_development_manifest_round_trips_and_archive_is_stable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = self.make_bundle(root)
            first_archive = root / "first.zip"
            first_manifest = generator.build_manifest(
                self.args(root, bundle, root / "first.json", first_archive)
            )
            second_archive = root / "second.zip"
            second_manifest = generator.build_manifest(
                self.args(root, bundle, root / "second.json", second_archive)
            )

            self.assertEqual(first_archive.read_bytes(), second_archive.read_bytes())
            validator.verify_manifest(first_manifest, bundle, first_archive)
            validator.verify_manifest(second_manifest, bundle, second_archive)

    def test_tampered_bundle_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = self.make_bundle(root)
            archive = root / "artifact.zip"
            manifest = generator.build_manifest(self.args(root, bundle, root / "m.json", archive))
            (bundle / "Contents" / "Resources" / "marker.txt").write_text(
                "tampered\n", encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "bundle file (size|SHA-256) mismatch"):
                validator.verify_manifest(manifest, bundle, archive)

    def test_release_status_requires_external_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = self.make_bundle(root)
            manifest = generator.build_manifest(
                self.args(root, bundle, root / "m.json", root / "artifact.zip")
            )
            manifest["release_status"] = "release_candidate"
            with self.assertRaisesRegex(ValueError, "release status is blocked"):
                validator.verify_manifest(manifest, bundle, root / "artifact.zip")

    def test_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = self.make_bundle(root)
            manifest = generator.build_manifest(
                self.args(root, bundle, root / "m.json", root / "artifact.zip")
            )
            manifest["bundle_files"][0]["path"] = "../outside"
            with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
                validator.verify_manifest(manifest, bundle, root / "artifact.zip")

    def test_source_provenance_distinguishes_clean_from_unavailable(self):
        # A git repo with a clean working tree must report "clean", not
        # "dirty_or_unavailable" (regression: empty status output was
        # collapsed to None by run_optional).
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess = __import__("subprocess")
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(
                ["git", "-C", str(root), "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "base"],
                check=True,
            )
            clean = generator.source_provenance(root)
            self.assertEqual(clean["working_tree"], "clean")
            self.assertNotEqual(clean["commit"], "unknown")
            # A non-existent path must report dirty_or_unavailable, not crash.
            missing = generator.source_provenance(root / "does-not-exist")
            self.assertEqual(missing["working_tree"], "dirty_or_unavailable")


if __name__ == "__main__":
    unittest.main()
