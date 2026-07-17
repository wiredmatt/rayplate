#!/usr/bin/env python3
"""Initialize a project created from the Rayplate repository template."""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path


PROJECT_FILES = (
    Path("CMakeLists.txt"),
    Path("src/game.h"),
    Path(".github/workflows/build.yml"),
    Path(".github/workflows/deploy-pages.yml"),
    Path("README.md"),
    Path("LICENSE"),
)


@dataclass(frozen=True)
class ProjectIdentity:
    name: str
    title: str
    version: str
    bundle_identifier: str
    github_repository: str
    copyright_holder: str


def cmake_string(text: str, variable: str, source: Path) -> str:
    pattern = re.compile(
        rf'set\({re.escape(variable)}\s+"(?P<value>[^"]*)"\s+CACHE\s+STRING'
    )
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise ValueError(
            f"Expected exactly one CACHE STRING setting for {variable} in "
            f"{source}, found {len(matches)}"
        )
    return matches[0].group("value")


def replace_cmake_string(text: str, variable: str, value: str, source: Path) -> str:
    pattern = re.compile(
        rf'(?P<prefix>set\({re.escape(variable)}\s+")(?P<value>[^"]*)'
        rf'(?P<suffix>"\s+CACHE\s+STRING)'
    )
    updated, count = pattern.subn(
        lambda match: f'{match.group("prefix")}{value}{match.group("suffix")}',
        text,
    )
    if count != 1:
        raise ValueError(
            f"Expected exactly one CACHE STRING setting for {variable} in "
            f"{source}, found {count}"
        )
    return updated


def parse_copyright_holder(text: str, source: Path) -> str:
    match = re.search(r"^Copyright \(c\) \d{4} (?P<holder>.+)$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"Could not find a copyright holder in {source}")
    return match.group("holder")


def current_identity(root: Path) -> ProjectIdentity:
    cmake_path = root / "CMakeLists.txt"
    cmake = cmake_path.read_text(encoding="utf-8")
    license_path = root / "LICENSE"
    license_text = license_path.read_text(encoding="utf-8")
    return ProjectIdentity(
        name=cmake_string(cmake, "GAME_BIN_NAME", cmake_path),
        title=cmake_string(cmake, "GAME_WINDOW_TITLE", cmake_path),
        version=cmake_string(cmake, "GAME_VERSION", cmake_path),
        bundle_identifier=cmake_string(
            cmake, "GAME_BUNDLE_IDENTIFIER", cmake_path
        ),
        github_repository=cmake_string(
            cmake, "GAME_GITHUB_REPOSITORY", cmake_path
        ),
        copyright_holder=parse_copyright_holder(license_text, license_path),
    )


def parse_github_repository(value: str) -> tuple[str, str]:
    match = re.fullmatch(
        r"(?P<owner>[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?)"
        r"/(?P<repository>[A-Za-z0-9_.-]+)",
        value,
    )
    if not match:
        raise argparse.ArgumentTypeError(
            "expected OWNER/REPOSITORY using GitHub-compatible characters"
        )
    repository = match.group("repository")
    if repository in {".", ".."} or repository.endswith(".git"):
        raise argparse.ArgumentTypeError(
            "repository must be a GitHub repository name without a .git suffix"
        )
    return match.group("owner"), repository


def validate_name(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", value):
        raise argparse.ArgumentTypeError(
            "name must start with an alphanumeric character and contain only "
            "letters, digits, dots, underscores, or hyphens"
        )
    return value


def validate_version(value: str) -> str:
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,3}", value):
        raise argparse.ArgumentTypeError(
            "version must contain one to four numeric components, such as 0.1.0"
        )
    return value


def validate_bundle_identifier(value: str) -> str:
    if not re.fullmatch(
        r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", value
    ):
        raise argparse.ArgumentTypeError(
            "bundle identifier must be a reverse-DNS name such as com.example.game"
        )
    return value


def validate_single_line(value: str, label: str) -> str:
    if not value.strip() or "\n" in value or "\r" in value:
        raise argparse.ArgumentTypeError(f"{label} must be non-empty and single-line")
    return value


def validate_title(value: str) -> str:
    value = validate_single_line(value, "title")
    if any(character in value for character in ('"', "\\", "$")):
        raise argparse.ArgumentTypeError(
            'title must not contain double quotes, backslashes, or "$"'
        )
    return value


def default_title(name: str) -> str:
    return " ".join(part.capitalize() for part in re.split(r"[-_]+", name))


def bundle_component(value: str) -> str:
    component = re.sub(r"[^a-z0-9-]+", "-", value.lower()).strip("-")
    return component or "game"


def default_bundle_identifier(owner: str, repository: str) -> str:
    return f"io.github.{bundle_component(owner)}.{bundle_component(repository)}"


def replace_required(text: str, old: str, new: str, source: Path) -> str:
    if old == new:
        return text
    count = text.count(old)
    if count == 0:
        raise ValueError(f"Could not find {old!r} in {source}")
    return text.replace(old, new)


def replace_artifact_references(
    text: str, old: str, new: str, source: Path
) -> str:
    if old == new:
        return text

    escaped = re.escape(old)
    patterns = (
        # Executable and artifact paths in shell commands and documentation.
        re.compile(
            rf"(?P<prefix>\b(?:build|artifacts|release|MacOS|package-check)/"
            rf"(?:[A-Za-z0-9_.${{}}-]+/)*){escaped}"
            rf"(?P<suffix>(?=[^A-Za-z0-9_]|$))"
        ),
        # Artifact names declared in workflow YAML.
        re.compile(rf"(?P<prefix>name: ){escaped}(?P<suffix>(?=[^A-Za-z0-9_]|$))"),
        # Bundle and web filenames shown at the beginning of a line or span.
        re.compile(
            rf"(?P<prefix>^|[`(]){escaped}"
            rf"(?P<suffix>(?=\.(?:app|exe|html|js|wasm|data)\b))",
            re.MULTILINE,
        ),
    )
    replacement_count = 0
    updated = text
    for pattern in patterns:
        while True:
            updated, count = pattern.subn(
                lambda match: (
                    f'{match.group("prefix")}{new}{match.group("suffix")}'
                ),
                updated,
            )
            replacement_count += count
            if count == 0:
                break

    if replacement_count == 0:
        raise ValueError(f"Could not find artifact references for {old!r} in {source}")
    return updated


def update_game_header(
    text: str, current: ProjectIdentity, requested: ProjectIdentity, source: Path
) -> str:
    pattern = re.compile(
        r'(?P<prefix>#define GAME_WINDOW_TITLE ")(?P<title>[^"]*)'
        r'(?P<suffix>")'
    )
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise ValueError(
            f"Expected one GAME_WINDOW_TITLE fallback in {source}, "
            f"found {len(matches)}"
        )
    if matches[0].group("title") != current.title:
        raise ValueError(
            f"GAME_WINDOW_TITLE in {source} does not match CMakeLists.txt"
        )
    return pattern.sub(
        lambda match: f'{match.group("prefix")}{requested.title}{match.group("suffix")}',
        text,
    )


def update_readme(
    text: str, current: ProjectIdentity, requested: ProjectIdentity, source: Path
) -> str:
    current_owner, current_repository = current.github_repository.split("/", 1)
    requested_owner, requested_repository = requested.github_repository.split("/", 1)
    updated = text
    values = {
        "GAME_BIN_NAME": requested.name,
        "GAME_WINDOW_TITLE": requested.title,
        "GAME_VERSION": requested.version,
        "GAME_BUNDLE_IDENTIFIER": requested.bundle_identifier,
        "GAME_GITHUB_REPOSITORY": requested.github_repository,
    }
    for variable, value in values.items():
        updated = replace_cmake_string(updated, variable, value, source)
    updated = replace_required(
        updated,
        f"--repo {current.github_repository}",
        f"--repo {requested.github_repository}",
        source,
    )
    updated = replace_required(
        updated,
        f"https://{current_owner}.github.io/{current_repository}/",
        f"https://{requested_owner}.github.io/{requested_repository}/",
        source,
    )

    repository_argument = re.compile(r"(?P<prefix>--github-repository )\S+")
    updated, repository_argument_count = repository_argument.subn(
        rf"\g<prefix>{requested.github_repository}", updated, count=1
    )
    if repository_argument_count != 1:
        raise ValueError(
            f"Expected one --github-repository example argument in {source}"
        )
    example_arguments = {
        r"(?P<prefix>--name )\S+": requested.name,
        r'(?P<prefix>--title )"[^"]*"': f'"{requested.title}"',
    }
    for argument_pattern, value in example_arguments.items():
        updated, argument_count = re.subn(
            argument_pattern,
            rf"\g<prefix>{value}",
            updated,
            count=1,
        )
        if argument_count != 1:
            raise ValueError(
                f"Expected one initializer example matching {argument_pattern} "
                f"in {source}"
            )
    updated = replace_artifact_references(
        updated, current.name, requested.name, source
    )

    lines = updated.splitlines(keepends=True)
    if not lines or not lines[0].startswith("# "):
        raise ValueError(f"Expected a Markdown title in {source}")
    newline = "\n" if lines[0].endswith("\n") else ""
    lines[0] = f"# {requested.title}{newline}"
    updated = "".join(lines)

    template_intro = "Rayplate is a raylib 6.0 CMake template"
    initialized_intro = (
        f"{requested.title} is based on Rayplate, a raylib 6.0 CMake template"
    )
    if template_intro in updated:
        updated = updated.replace(template_intro, initialized_intro, 1)
    else:
        intro_pattern = re.compile(
            r"^[^\n]+ is based on Rayplate, a raylib 6\.0 CMake template",
            re.MULTILINE,
        )
        updated, intro_count = intro_pattern.subn(initialized_intro, updated, count=1)
        if intro_count != 1:
            raise ValueError(f"Could not update the Rayplate introduction in {source}")
    return updated


def update_license(
    text: str, requested: ProjectIdentity, source: Path
) -> str:
    pattern = re.compile(
        r"^(?P<prefix>Copyright \(c\) \d{4} )(?P<holder>.+)$",
        re.MULTILINE,
    )
    updated, count = pattern.subn(
        lambda match: f'{match.group("prefix")}{requested.copyright_holder}',
        text,
        count=1,
    )
    if count != 1:
        raise ValueError(f"Could not update the copyright holder in {source}")
    return updated


def plan_initialization(
    root: Path, requested: ProjectIdentity
) -> dict[Path, tuple[str, str]]:
    root = root.resolve()
    missing = [str(path) for path in PROJECT_FILES if not (root / path).is_file()]
    if missing:
        raise ValueError(f"Repository is missing required files: {', '.join(missing)}")

    current = current_identity(root)
    changes: dict[Path, tuple[str, str]] = {}
    for relative_path in PROJECT_FILES:
        path = root / relative_path
        original = path.read_text(encoding="utf-8")
        updated = original

        if relative_path == Path("CMakeLists.txt"):
            values = {
                "GAME_BIN_NAME": requested.name,
                "GAME_WINDOW_TITLE": requested.title,
                "GAME_VERSION": requested.version,
                "GAME_BUNDLE_IDENTIFIER": requested.bundle_identifier,
                "GAME_GITHUB_REPOSITORY": requested.github_repository,
            }
            for variable, value in values.items():
                updated = replace_cmake_string(updated, variable, value, path)
        elif relative_path == Path("src/game.h"):
            updated = update_game_header(updated, current, requested, path)
        elif relative_path in {
            Path(".github/workflows/build.yml"),
            Path(".github/workflows/deploy-pages.yml"),
        }:
            updated = replace_artifact_references(
                updated, current.name, requested.name, path
            )
        elif relative_path == Path("README.md"):
            updated = update_readme(updated, current, requested, path)
        elif relative_path == Path("LICENSE"):
            updated = update_license(updated, requested, path)

        if updated != original:
            changes[path] = (original, updated)

    return changes


def show_changes(root: Path, changes: dict[Path, tuple[str, str]]) -> None:
    for path, (original, updated) in changes.items():
        relative = path.relative_to(root)
        diff = difflib.unified_diff(
            original.splitlines(keepends=True),
            updated.splitlines(keepends=True),
            fromfile=str(relative),
            tofile=str(relative),
        )
        sys.stdout.writelines(diff)


def apply_changes(changes: dict[Path, tuple[str, str]]) -> None:
    for path, (_, updated) in changes.items():
        path.write_text(updated, encoding="utf-8")


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Update project identity, artifact names, workflows, Pages URLs, "
            "and the repository used to fetch ANGLE bundles."
        )
    )
    parser.add_argument("--name", required=True, type=validate_name,
                        help="executable and artifact basename")
    parser.add_argument("--title", help="human-readable game title")
    parser.add_argument(
        "--github-repository",
        required=True,
        metavar="OWNER/REPOSITORY",
        help="GitHub repository that will host the project and ANGLE releases",
    )
    parser.add_argument("--version", type=validate_version,
                        help="CMake-compatible project version (default: keep current)")
    parser.add_argument("--bundle-identifier", type=validate_bundle_identifier,
                        help="reverse-DNS bundle identifier")
    parser.add_argument("--copyright-holder",
                        help="copyright holder (default: GitHub owner)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the planned patch without changing files")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = create_parser()
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]

    try:
        owner, repository = parse_github_repository(args.github_repository)
        current = current_identity(root)
        title = args.title or default_title(args.name)
        copyright_holder = args.copyright_holder or owner
        requested = ProjectIdentity(
            name=args.name,
            title=validate_title(title),
            version=args.version or current.version,
            bundle_identifier=(
                args.bundle_identifier
                or default_bundle_identifier(owner, repository)
            ),
            github_repository=f"{owner}/{repository}",
            copyright_holder=validate_single_line(
                copyright_holder, "copyright holder"
            ),
        )
        changes = plan_initialization(root, requested)
    except (OSError, ValueError, argparse.ArgumentTypeError) as error:
        parser.error(str(error))

    if not changes:
        print("Project identity is already up to date.")
        return 0

    if args.dry_run:
        show_changes(root, changes)
        print(f"\nDry run: {len(changes)} files would change.")
    else:
        apply_changes(changes)
        print(f"Updated {len(changes)} files for {requested.github_repository}.")
        print(
            "Before the first desktop CI build, run the package-angle workflow "
            "with Electron 43.1.1 and package revision 2."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
