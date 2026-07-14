import hashlib
import json
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from package_angle import package_angle  # noqa: E402


class PackageAngleTests(unittest.TestCase):
    def create_electron_archive(
        self, root: Path, gles_bytes: bytes = b"renderer/vulkan/ renderer/gl/"
    ) -> tuple[Path, str]:
        archive = root / "electron-v1.2.3-linux-x64.zip"
        with zipfile.ZipFile(archive, "w") as output:
            output.writestr("libEGL.so", b"egl")
            output.writestr("libGLESv2.so", gles_bytes)
            output.writestr("libvulkan.so.1", b"vulkan loader")
            output.writestr("LICENSE", b"electron license")
            output.writestr("LICENSES.chromium.html", b"chromium licenses")
            output.writestr("electron", b"must not be packaged")
        return archive, hashlib.sha256(archive.read_bytes()).hexdigest()

    def test_offline_bundle_is_minimal_and_reproducible(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, archive_hash = self.create_electron_archive(root)
            first = package_angle("1.2.3", "linux-x64", root / "one", root / "cache", archive, None, archive_hash)
            second = package_angle("1.2.3", "linux-x64", root / "two", root / "cache", archive, None, archive_hash)

            self.assertEqual(first.read_bytes(), second.read_bytes())
            with tarfile.open(first) as bundle:
                names = bundle.getnames()
                prefix = "rayplate-angle-electron-1.2.3-linux-x64"
                self.assertIn(f"{prefix}/bin/libEGL.so", names)
                self.assertIn(f"{prefix}/bin/libGLESv2.so", names)
                self.assertIn(f"{prefix}/bin/libvulkan.so.1", names)
                self.assertNotIn(f"{prefix}/electron", names)
                manifest_file = bundle.extractfile(f"{prefix}/manifest.json")
                self.assertIsNotNone(manifest_file)
                manifest = json.load(manifest_file)
                self.assertEqual(manifest["electron"]["archive_sha256"], archive_hash)
                self.assertEqual(manifest["target"], "linux-x64")
                self.assertEqual(manifest["backends"], ["vulkan", "opengl"])
                bundled_paths = {entry["bundle_path"] for entry in manifest["files"]}
                self.assertIn("bin/libvulkan.so.1", bundled_paths)

    def test_bad_archive_hash_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, _ = self.create_electron_archive(root)
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                package_angle("1.2.3", "linux-x64", root / "out", root / "cache", archive, None, "0" * 64)

    def test_missing_backend_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, archive_hash = self.create_electron_archive(root, b"renderer/gl/")
            with self.assertRaisesRegex(ValueError, "missing expected backend markers"):
                package_angle(
                    "1.2.3", "linux-x64", root / "out", root / "cache", archive, None, archive_hash
                )


if __name__ == "__main__":
    unittest.main()
