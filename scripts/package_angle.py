#!/usr/bin/env python3
"""Create small, reproducible ANGLE runtime bundles from Electron releases."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path


ELECTRON_RELEASE_BASE = "https://github.com/electron/electron/releases/download"
FORMAT_VERSION = 1


@dataclass(frozen=True)
class Target:
    electron_platform: str
    electron_arch: str
    egl_name: str
    gles_name: str
    backends: tuple[str, ...]
    backend_markers: tuple[bytes, ...]
    required_runtime_names: tuple[str, ...] = ()
    optional_runtime_names: tuple[str, ...] = ()


TARGETS = {
    "windows-x64": Target(
        "win32", "x64", "libEGL.dll", "libGLESv2.dll",
        ("directx", "vulkan", "opengl"),
        (b"renderer\\d3d\\", b"renderer\\vulkan\\", b"renderer\\gl\\"),
        optional_runtime_names=("d3dcompiler_47.dll",),
    ),
    # Electron's Windows ARM64 build does not compile ANGLE's WGL renderer.
    "windows-arm64": Target(
        "win32", "arm64", "libEGL.dll", "libGLESv2.dll",
        ("directx", "vulkan"),
        (b"renderer\\d3d\\", b"renderer\\vulkan\\"),
        optional_runtime_names=("d3dcompiler_47.dll",),
    ),
    "linux-x64": Target(
        "linux", "x64", "libEGL.so", "libGLESv2.so",
        ("vulkan", "opengl"), (b"renderer/vulkan/", b"renderer/gl/"),
        required_runtime_names=("libvulkan.so.1",),
    ),
    "linux-arm64": Target(
        "linux", "arm64", "libEGL.so", "libGLESv2.so",
        ("vulkan", "opengl"), (b"renderer/vulkan/", b"renderer/gl/"),
        required_runtime_names=("libvulkan.so.1",),
    ),
    "macos-x64": Target(
        "darwin", "x64", "libEGL.dylib", "libGLESv2.dylib",
        ("metal", "opengl"), (b"renderer/metal/", b"renderer/gl/"),
    ),
    "macos-arm64": Target(
        "darwin", "arm64", "libEGL.dylib", "libGLESv2.dylib",
        ("metal", "opengl"), (b"renderer/metal/", b"renderer/gl/"),
    ),
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": "rayplate-angle-packager/1"})
    try:
        with urllib.request.urlopen(request) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def expected_archive_hash(shasums_path: Path, archive_name: str) -> str:
    for raw_line in shasums_path.read_text(encoding="utf-8").splitlines():
        parts = raw_line.strip().split(maxsplit=1)
        if len(parts) == 2 and parts[1].lstrip("*") == archive_name:
            if re.fullmatch(r"[0-9a-fA-F]{64}", parts[0]):
                return parts[0].lower()
    raise ValueError(f"No SHA-256 entry for {archive_name} in {shasums_path}")


def find_unique_member(archive: zipfile.ZipFile, basename: str, required: bool) -> zipfile.ZipInfo | None:
    matches = [entry for entry in archive.infolist() if not entry.is_dir() and Path(entry.filename).name == basename]
    if not matches:
        if required:
            raise ValueError(f"Electron archive does not contain {basename}")
        return None

    # Electron's macOS archive nests the libraries inside Electron.app. Refuse
    # ambiguous layouts rather than silently packaging an unexpected binary.
    if len(matches) != 1:
        names = ", ".join(entry.filename for entry in matches)
        raise ValueError(f"Electron archive contains multiple files named {basename}: {names}")
    return matches[0]


def extract_member(archive: zipfile.ZipFile, member: zipfile.ZipInfo, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with archive.open(member) as source, destination.open("wb") as output:
        shutil.copyfileobj(source, output)


def normalized_tar_info(info: tarfile.TarInfo, is_directory: bool) -> tarfile.TarInfo:
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    info.mode = 0o755 if is_directory or info.name.endswith((".dll", ".so", ".dylib")) else 0o644
    info.pax_headers = {}
    return info


def create_reproducible_tar(source_root: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as raw_output:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw_output, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                paths = [source_root, *sorted(source_root.rglob("*"), key=lambda item: item.as_posix())]
                for path in paths:
                    arcname = path.relative_to(source_root.parent).as_posix()
                    info = normalized_tar_info(archive.gettarinfo(str(path), arcname), path.is_dir())
                    if path.is_file():
                        with path.open("rb") as stream:
                            archive.addfile(info, stream)
                    else:
                        archive.addfile(info)


def package_angle(
    electron_version: str,
    target_name: str,
    output_dir: Path,
    cache_dir: Path,
    archive_path: Path | None = None,
    shasums_path: Path | None = None,
    archive_sha256: str | None = None,
) -> Path:
    version = electron_version.removeprefix("v")
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?", version):
        raise ValueError(f"Invalid Electron version: {electron_version}")
    if target_name not in TARGETS:
        raise ValueError(f"Unknown target: {target_name}")

    target = TARGETS[target_name]
    archive_name = f"electron-v{version}-{target.electron_platform}-{target.electron_arch}.zip"
    release_url = f"{ELECTRON_RELEASE_BASE}/v{version}"

    if archive_path is None:
        archive_path = cache_dir / archive_name
        if not archive_path.exists():
            download(f"{release_url}/{archive_name}", archive_path)
    elif not archive_path.is_file():
        raise ValueError(f"Electron archive does not exist: {archive_path}")

    if shasums_path is None and archive_sha256 is None:
        shasums_path = cache_dir / f"electron-v{version}-SHASUMS256.txt"
        if not shasums_path.exists():
            download(f"{release_url}/SHASUMS256.txt", shasums_path)

    if archive_sha256 is None:
        if shasums_path is None or not shasums_path.is_file():
            raise ValueError("A local SHASUMS256.txt or --archive-sha256 is required")
        archive_sha256 = expected_archive_hash(shasums_path, archive_name)
    elif not re.fullmatch(r"[0-9a-fA-F]{64}", archive_sha256):
        raise ValueError("--archive-sha256 must contain exactly 64 hexadecimal characters")
    archive_sha256 = archive_sha256.lower()

    actual_archive_sha256 = sha256_file(archive_path)
    if actual_archive_sha256 != archive_sha256:
        raise ValueError(
            f"Electron archive checksum mismatch for {archive_name}: "
            f"expected {archive_sha256}, got {actual_archive_sha256}"
        )

    bundle_name = f"rayplate-angle-electron-{version}-{target_name}"
    output_path = output_dir / f"{bundle_name}.tar.gz"
    output_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="rayplate-angle-") as temporary_directory:
        bundle_root = Path(temporary_directory) / bundle_name
        bin_dir = bundle_root / "bin"
        licenses_dir = bundle_root / "licenses"
        extracted = []

        with zipfile.ZipFile(archive_path) as electron_archive:
            required_files = (
                (target.egl_name, bin_dir / target.egl_name),
                (target.gles_name, bin_dir / target.gles_name),
                ("LICENSE", licenses_dir / "ELECTRON-LICENSE"),
                ("LICENSES.chromium.html", licenses_dir / "LICENSES.chromium.html"),
            )
            for basename, destination in required_files:
                member = find_unique_member(electron_archive, basename, required=True)
                assert member is not None
                extract_member(electron_archive, member, destination)
                extracted.append((member.filename, destination))

            for basename in target.required_runtime_names:
                member = find_unique_member(electron_archive, basename, required=True)
                assert member is not None
                destination = bin_dir / basename
                extract_member(electron_archive, member, destination)
                extracted.append((member.filename, destination))

            for basename in target.optional_runtime_names:
                member = find_unique_member(electron_archive, basename, required=False)
                if member is not None:
                    destination = bin_dir / basename
                    extract_member(electron_archive, member, destination)
                    extracted.append((member.filename, destination))

        gles_bytes = (bin_dir / target.gles_name).read_bytes()
        missing_markers = [marker.decode("ascii") for marker in target.backend_markers if marker not in gles_bytes]
        if missing_markers:
            raise ValueError(
                f"Electron's {target_name} ANGLE library is missing expected backend markers: "
                f"{', '.join(missing_markers)}"
            )

        files = []
        for source_member, path in sorted(extracted, key=lambda item: item[1].as_posix()):
            files.append(
                {
                    "bundle_path": path.relative_to(bundle_root).as_posix(),
                    "electron_archive_member": source_member,
                    "sha256": sha256_file(path),
                    "size": path.stat().st_size,
                }
            )

        manifest = {
            "format_version": FORMAT_VERSION,
            "target": target_name,
            "backends": list(target.backends),
            "electron": {
                "version": version,
                "archive": archive_name,
                "archive_sha256": actual_archive_sha256,
                "source_url": f"{release_url}/{archive_name}",
                "shasums_url": f"{release_url}/SHASUMS256.txt",
            },
            "files": files,
        }
        manifest_path = bundle_root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

        create_reproducible_tar(bundle_root, output_path)

    print(f"{sha256_file(output_path)}  {output_path.name}")
    return output_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--electron-version", required=True)
    parser.add_argument("--target", required=True, choices=sorted(TARGETS))
    parser.add_argument("--output-dir", type=Path, default=Path("dist/angle"))
    parser.add_argument("--cache-dir", type=Path, default=Path.home() / ".cache/rayplate/electron")
    parser.add_argument("--archive", type=Path, help="Use an existing Electron ZIP instead of downloading it")
    parser.add_argument("--shasums", type=Path, help="Use an existing Electron SHASUMS256.txt")
    parser.add_argument("--archive-sha256", help="Expected archive hash for a fully offline build")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        package_angle(
            electron_version=args.electron_version,
            target_name=args.target,
            output_dir=args.output_dir,
            cache_dir=args.cache_dir,
            archive_path=args.archive,
            shasums_path=args.shasums,
            archive_sha256=args.archive_sha256,
        )
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
