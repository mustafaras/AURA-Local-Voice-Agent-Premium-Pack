import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def git(*args: str, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )


class RepoHygieneIgnoreRuleTests(unittest.TestCase):
    def test_current_rules_cover_generated_paths_and_leave_authored_paths_visible(self):
        generated = (
            ".build/generated/module.o",
            ".venv/bin/python",
            "Runtime/chatterbox/.venv/bin/python",
            "__pycache__/module.pyc",
            "nested/cache/module.pyc",
            ".DS_Store",
            "xcuserdata/user.xcuserdatad/state.xcuserstate",
            "DerivedData/AURA/Build/Products/debug/AURA",
        )
        authored = (
            "Sources/AURA/AuraKernel.swift",
            "Tests/AuraAgentTests/Fixtures/ollama_generate_structured_real.json",
            "Tests/AuraIntentTests/BilingualGoldenCorpusTests.swift",
            "AURA_RUNTIME_COMPLETION/repo-hygiene/REPO_HYGIENE_STATE.json",
            "docs/operations/REPO_HYGIENE_PROGRAM.md",
        )

        for path in generated:
            result = git("check-ignore", "-q", "--no-index", "--", path)
            self.assertEqual(result.returncode, 0, f"generated path is visible: {path}")

        for path in authored:
            result = git("check-ignore", "-q", "--no-index", "--", path)
            self.assertNotEqual(result.returncode, 0, f"authored path is ignored: {path}")

        root_venv_rule = git("check-ignore", "-v", "--no-index", "--", ".venv/bin/python")
        self.assertEqual(root_venv_rule.returncode, 0)
        self.assertIn(".gitignore", root_venv_rule.stdout)
        self.assertIn("/.venv/", root_venv_rule.stdout)

        tracked_ignored = git("ls-files", "-ci", "--exclude-standard")
        self.assertEqual(tracked_ignored.returncode, 0)
        self.assertEqual(tracked_ignored.stdout, "")

    def test_clean_fixture_keeps_generated_files_ignored_and_fixtures_visible(self):
        with tempfile.TemporaryDirectory(prefix="aura-h003-ignore-fixture-") as directory:
            fixture = Path(directory)
            init = git("init", "-q", cwd=fixture)
            self.assertEqual(init.returncode, 0, init.stderr)

            (fixture / ".gitignore").write_text(
                (ROOT / ".gitignore").read_text(encoding="utf-8"), encoding="utf-8"
            )
            nested_ignore = fixture / "Runtime/chatterbox/.gitignore"
            nested_ignore.parent.mkdir(parents=True)
            nested_ignore.write_text(
                (ROOT / "Runtime/chatterbox/.gitignore").read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            for relative in (
                ".build/debug/module.o",
                ".venv/bin/python",
                "Runtime/chatterbox/.venv/bin/python",
                ".DS_Store",
                "__pycache__/module.pyc",
            ):
                path = fixture / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("generated", encoding="utf-8")
            for relative in (
                "Sources/Example.swift",
                "Tests/Fixtures/intent.json",
            ):
                path = fixture / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("authored", encoding="utf-8")

            add = git("add", ".gitignore", "Runtime/chatterbox/.gitignore", cwd=fixture)
            self.assertEqual(add.returncode, 0, add.stderr)

            for relative in (
                ".build/debug/module.o",
                ".venv/bin/python",
                "Runtime/chatterbox/.venv/bin/python",
                ".DS_Store",
                "__pycache__/module.pyc",
            ):
                result = git("check-ignore", "-q", "--", relative, cwd=fixture)
                self.assertEqual(result.returncode, 0, f"fixture path is visible: {relative}")

            status = git("status", "--porcelain=v1", "--untracked-files=all", cwd=fixture)
            self.assertEqual(status.returncode, 0, status.stderr)
            self.assertIn("?? Sources/Example.swift", status.stdout)
            self.assertIn("?? Tests/Fixtures/intent.json", status.stdout)
            for relative in (
                ".build/debug/module.o",
                ".venv/bin/python",
                "Runtime/chatterbox/.venv/bin/python",
                ".DS_Store",
                "__pycache__/module.pyc",
            ):
                self.assertNotIn(relative, status.stdout)


if __name__ == "__main__":
    unittest.main()
