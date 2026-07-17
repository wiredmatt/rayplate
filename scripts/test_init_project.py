import argparse
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from init_project import (  # noqa: E402
    PROJECT_FILES,
    ProjectIdentity,
    apply_changes,
    current_identity,
    default_bundle_identifier,
    parse_github_repository,
    plan_initialization,
    validate_title,
)


class InitProjectTests(unittest.TestCase):
    source_root = Path(__file__).resolve().parents[1]

    def copy_project_files(self, destination: Path) -> None:
        for relative_path in PROJECT_FILES:
            source = self.source_root / relative_path
            target = destination / relative_path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    def test_updates_identity_angle_source_and_workflows(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_project_files(root)
            requested = ProjectIdentity(
                name="tiny_frog",
                title="Tiny Frog",
                version="1.2.0",
                bundle_identifier="games.example.tiny-frog",
                github_repository="frog-studio/tiny-frog",
                copyright_holder="Frog Studio",
            )

            changes = plan_initialization(root, requested)
            self.assertEqual(set(changes), {root / path for path in PROJECT_FILES})
            apply_changes(changes)

            cmake = (root / "CMakeLists.txt").read_text(encoding="utf-8")
            workflow = (root / ".github/workflows/build.yml").read_text(
                encoding="utf-8"
            )
            readme = (root / "README.md").read_text(encoding="utf-8")
            self.assertIn('set(GAME_BIN_NAME "tiny_frog"', cmake)
            self.assertIn(
                'set(GAME_GITHUB_REPOSITORY "frog-studio/tiny-frog"', cmake
            )
            self.assertIn("build/tiny_frog", workflow)
            self.assertNotIn("build/my_game", workflow)
            self.assertIn("--repo frog-studio/tiny-frog", readme)
            self.assertIn("https://frog-studio.github.io/tiny-frog/", readme)
            self.assertEqual(current_identity(root), requested)

    def test_can_be_run_again_after_initialization(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_project_files(root)
            first = ProjectIdentity(
                "first_game", "First Game", "0.2.0", "games.test.first",
                "first-owner/first-repo", "First Owner"
            )
            second = ProjectIdentity(
                "second_game", "Second Game", "0.3.0", "games.test.second",
                "second-owner/second-repo", "Second Owner"
            )
            apply_changes(plan_initialization(root, first))
            apply_changes(plan_initialization(root, second))
            self.assertEqual(current_identity(root), second)
            self.assertEqual(plan_initialization(root, second), {})

    def test_generic_name_does_not_rewrite_readme_prose(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.copy_project_files(root)
            first = ProjectIdentity(
                "game", "A Game", "1", "games.test.game",
                "owner/game", "Owner"
            )
            second = ProjectIdentity(
                "next", "Next", "2", "games.test.next",
                "owner/next", "Owner"
            )
            apply_changes(plan_initialization(root, first))
            apply_changes(plan_initialization(root, second))
            readme = (root / "README.md").read_text(encoding="utf-8")
            self.assertIn("game that does not need ImGui", readme)
            self.assertIn("`src/game.c`", readme)
            self.assertIn("--name next", readme)
            self.assertIn('set(GAME_VERSION "2"', readme)

    def test_repository_and_bundle_defaults(self) -> None:
        self.assertEqual(
            parse_github_repository("some-org/cool_game"),
            ("some-org", "cool_game"),
        )
        self.assertEqual(
            default_bundle_identifier("Some-Org", "cool_game"),
            "io.github.some-org.cool-game",
        )
        with self.assertRaises(argparse.ArgumentTypeError):
            parse_github_repository("not-a-repository")
        with self.assertRaises(argparse.ArgumentTypeError):
            validate_title('${BAD_TITLE}')


if __name__ == "__main__":
    unittest.main()
