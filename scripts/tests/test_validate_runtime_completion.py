import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts" / "validate_runtime_completion.py"
SPEC = importlib.util.spec_from_file_location("aura_validator", MODULE_PATH)
VALIDATOR = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(VALIDATOR)


class RuntimeCompletionValidatorTests(unittest.TestCase):
    def test_current_repository_state_is_valid(self):
        VALIDATOR.validate_repository(ROOT)

    def test_second_pass_active_prompt_id_is_accepted(self):
        # The second-pass program advances first-pass state so current-state.json
        # carries an active_prompt.id like SP-026. The first-pass schema must
        # accept SP-<NNN> ids (regression: previously only BOOTSTRAP|R[0-9]+|FINAL).
        schema = json.loads(
            (ROOT / "AURA_RUNTIME_COMPLETION/schemas/program-state.schema.json").read_text()
        )
        active_prompt_schema = schema["properties"]["active_prompt"]["properties"]
        pattern = active_prompt_schema["id"]["pattern"]
        for valid in ("SP-026", "BOOTSTRAP", "R0", "FINAL"):
            self.assertIsNotNone(
                __import__("re").search(pattern, valid), f"{valid} must match {pattern}"
            )
        for invalid in ("SP-26", "SP-0260", "sp-026", "X1", ""):
            self.assertIsNone(
                __import__("re").search(pattern, invalid), f"{invalid} must NOT match {pattern}"
            )

    def test_malformed_json_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "broken.json"
            path.write_text("{broken")
            with self.assertRaises(VALIDATOR.ValidationFailure):
                VALIDATOR.load_json(path)

    def test_schema_violation_is_rejected(self):
        schema = {"type": "object", "required": ["name"]}
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.SchemaSubsetValidator(schema, "test-schema").validate({})

    def test_missing_prompt_file_is_rejected(self):
        manifest = {
            "prompts": [
                {
                    "id": "BOOTSTRAP",
                    "order": 0,
                    "file": "AURA_RUNTIME_COMPLETION/prompts/missing.prompt.md",
                    "dependencies": [],
                }
            ]
        }
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(VALIDATOR.ValidationFailure):
                VALIDATOR.validate_manifest_prompt_files(Path(temporary), manifest)

    def test_dependency_cycle_is_rejected(self):
        manifest = {
            "prompts": [
                {"id": "BOOTSTRAP", "order": 0, "dependencies": ["R0"]},
                {"id": "R0", "order": 1, "dependencies": ["BOOTSTRAP"]},
            ]
        }
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_dependency_graph(manifest)

    def test_stale_active_prompt_is_rejected(self):
        manifest = {
            "prompts": [
                {
                    "id": "BOOTSTRAP",
                    "order": 0,
                    "file": "AURA_RUNTIME_COMPLETION/prompts/bootstrap.prompt.md",
                    "dependencies": [],
                }
            ],
            "shared_contract": "contract.md",
            "state_file": "state.json",
            "handoff_file": "handoff.json",
        }
        state = {"active_prompt": {"id": "BOOTSTRAP", "file": "wrong.prompt.md"}}
        handoff = {"active_prompt": {"id": "BOOTSTRAP", "file": "other.prompt.md"}, "required_first_reads": []}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            prompt_path = root / manifest["prompts"][0]["file"]
            prompt_path.parent.mkdir(parents=True)
            prompt_path.write_text("prompt")
            (root / "AURA_RUNTIME_COMPLETION/prompts/15_SESSION_CLOSEOUT.prompt.md").write_text("closeout")
            with self.assertRaises(VALIDATOR.ValidationFailure):
                VALIDATOR.validate_prompt_contract(root, manifest, state, handoff)

    def test_completed_track_without_evidence_is_rejected(self):
        state = {"tracks": [{"id": "R0", "state": "completed", "evidence_ids": []}]}
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_completed_tracks(state)

    def test_released_state_with_open_gate_is_rejected(self):
        state = {
            "program_status": "released",
            "release_gates": [
                {"id": "GATE-RELEASE", "required_for": "release", "state": "open"}
            ],
            "tracks": [],
        }
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_release_state(state)

    def test_live_capability_without_evidence_is_rejected(self):
        capability = {
            "capabilities": [
                {"id": "voice.example", "verification_state": "live_verified", "evidence_ids": []}
            ]
        }
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_capability_entries(capability, set())

    def test_dirty_user_owned_state_is_preserved(self):
        VALIDATOR.validate_worktree_claim(" M expected.md", "dirty_expected", ["expected metadata edit"])
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_worktree_claim(" M expected.md", "clean", ["expected metadata edit"])
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_worktree_claim(" M expected.md", "dirty_expected", [])

    def test_legacy_pointer_drift_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "ledger").mkdir()
            (root / "ledger/CURRENT_STATE.md").write_text("historical")
            (root / "SESSION_STARTER.md").write_text("historical compatibility")
            with self.assertRaises(VALIDATOR.ValidationFailure):
                VALIDATOR.validate_legacy_pointers(root)

    def test_unsupported_toolchain_is_rejected(self):
        toolchain = {
            "observed": {
                "swift_version": "Apple Swift 5.9",
                "architecture": "arm64",
                "xcodebuild_available": True,
            },
            "validation": {"script": "scripts/validate_runtime_completion.py"},
        }
        with self.assertRaises(VALIDATOR.ValidationFailure):
            VALIDATOR.validate_toolchain_environment(ROOT, toolchain, release=False)

    def test_projection_only_paths_are_distinguished(self):
        self.assertTrue(VALIDATOR.projection_only_paths(["AURA_RUNTIME_COMPLETION/state/current-state.json"]))
        self.assertTrue(VALIDATOR.projection_only_paths(["ledger/CURRENT_STATE.md", "TOOLCHAIN.md"]))
        self.assertFalse(VALIDATOR.projection_only_paths(["Sources/AuraCore/EventEnvelope.swift"]))


if __name__ == "__main__":
    unittest.main()
