"""Filesystem tests; mount identity and real SnapRAID run in disk-array-vm.nix."""

import importlib.util
import os
from pathlib import Path
import tempfile
import subprocess
import sys
import time
import json
import unittest

SPEC = importlib.util.spec_from_file_location(
    "mover", Path(__file__).parents[1] / "features/disk-array/mover.py"
)
mover = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mover)


class CopyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / "source"
        self.target = self.base / "target"
        self.source.mkdir()
        self.target.mkdir()
        self.src = mover.Root(str(self.source))
        self.dst = mover.Root(str(self.target))
        self.addCleanup(self.src.close)
        self.addCleanup(self.dst.close)

    def seed(self, name="media/a b\n:c", data=b"original"):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        os.chmod(path, 0o640)
        os.setxattr(path, "user.test", b"metadata")
        os.utime(path, ns=(1_000_000_000, 2_000_000_001))
        return name

    def test_copy_preserves_source_and_metadata(self):
        name = self.seed()
        receipt = mover.copy_file(self.src, self.dst, name)
        self.assertEqual((self.source / name).read_bytes(), b"original")
        self.assertEqual((self.target / name).read_bytes(), b"original")
        self.assertEqual(os.getxattr(self.target / name, "user.test"), b"metadata")
        self.assertEqual((self.target / name).stat().st_mtime_ns, 2_000_000_001)
        self.assertEqual((self.target / name).stat().st_mode & 0o777, 0o640)
        self.assertEqual(receipt["sha256"], mover.digest_path(self.dst, name))

    def test_conflict_never_replaced(self):
        name = self.seed("same")
        (self.target / name).write_bytes(b"different")
        with self.assertRaises(mover.Unsafe):
            mover.copy_file(self.src, self.dst, name)
        self.assertEqual((self.target / name).read_bytes(), b"different")
        self.assertTrue((self.source / name).exists())

    def test_identical_destination_adopted_only_with_metadata(self):
        name = self.seed("same")
        first = mover.copy_file(self.src, self.dst, name)
        inode = (self.target / name).stat().st_ino
        self.assertEqual(mover.copy_file(self.src, self.dst, name), first)
        self.assertEqual((self.target / name).stat().st_ino, inode)
        os.chmod(self.target / name, 0o600)
        with self.assertRaises(mover.Unsafe):
            mover.copy_file(self.src, self.dst, name)

    def test_hardlinks_and_symlinks_refused(self):
        name = self.seed("original")
        os.link(self.source / name, self.source / "hardlink")
        with self.assertRaises(mover.Unsafe):
            mover.copy_file(self.src, self.dst, name)
        (self.source / "symlink").symlink_to(name)
        with self.assertRaises((mover.Unsafe, OSError)):
            mover.copy_file(self.src, self.dst, "symlink")

    def test_symlink_ancestor_refused(self):
        name = self.seed()
        (self.target / "media").symlink_to(self.source / "media")
        with self.assertRaises((mover.Unsafe, OSError)):
            mover.copy_file(self.src, self.dst, name)
        self.assertTrue((self.source / name).exists())

    def test_self_copy_refused(self):
        name = self.seed()
        with self.assertRaises(mover.Unsafe):
            mover.copy_file(self.src, self.src, name)
        self.assertTrue((self.source / name).exists())

    def test_open_writer_refused(self):
        name = self.seed("active")
        with open(self.source / name, "ab"):
            with self.assertRaises((mover.Unsafe, OSError)):
                mover.copy_file(self.src, self.dst, name)
        self.assertTrue((self.source / name).exists())

    def copy_process(self, name):
        code = """
import sys
sys.path.insert(0, sys.argv[1])
import mover
source, target = mover.Root(sys.argv[2]), mover.Root(sys.argv[3])
try:
    mover.copy_file(source, target, sys.argv[4])
finally:
    source.close()
    target.close()
"""
        process = subprocess.Popen(
            [
                sys.executable,
                "-c",
                code,
                str(Path(SPEC.origin).parent),
                str(self.source),
                str(self.target),
                name,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(lambda: process.poll() is None and process.kill())
        deadline = time.monotonic() + 10
        while not list(self.target.glob(".cache-mover-*")):
            if process.poll() is not None or time.monotonic() > deadline:
                self.fail("copy did not enter temporary publication stage")
            time.sleep(0.001)
        return process

    def test_writer_during_copy_retains_source(self):
        name = self.seed("large")
        with open(self.source / name, "r+b") as stream:
            stream.truncate(128 * 1024 * 1024)
        process = self.copy_process(name)
        with open(self.source / name, "ab") as writer:
            writer.write(b"changed")
        _, error = process.communicate(timeout=10)
        self.assertNotEqual(process.returncode, 0, error)
        self.assertTrue((self.source / name).exists())
        self.assertEqual((self.source / name).stat().st_size, 128 * 1024 * 1024 + 7)

    def test_killed_publication_can_resume_without_source_loss(self):
        name = self.seed("large")
        with open(self.source / name, "r+b") as stream:
            stream.truncate(128 * 1024 * 1024)
        process = self.copy_process(name)
        process.kill()
        process.communicate(timeout=10)
        self.assertTrue((self.source / name).exists())
        self.assertFalse((self.target / name).exists())
        self.assertTrue(list(self.target.glob(".cache-mover-*")))
        mover.copy_file(self.src, self.dst, name)
        self.assertEqual(
            mover.digest_path(self.src, name), mover.digest_path(self.dst, name)
        )

    def test_nonreplacing_publication(self):
        self.seed("source")
        (self.target / "existing").write_bytes(b"keep")
        with self.assertRaises(FileExistsError):
            mover.rename_new(self.src.fd, "source", self.dst.fd, "existing")
        self.assertEqual((self.target / "existing").read_bytes(), b"keep")
        self.assertTrue((self.source / "source").exists())

    def test_detached_root_never_falls_back(self):
        self.source.rename(self.base / "detached")
        self.source.mkdir()
        with self.assertRaises(mover.Unsafe):
            self.src.attached()

    def test_directory_metadata_preserved_for_new_directories(self):
        name = self.seed()
        directory = self.source / "media"
        os.chmod(directory, 0o2750)
        os.setxattr(directory, "user.directory", b"keep")
        mover.copy_file(self.src, self.dst, name)
        self.assertEqual((self.target / "media").stat().st_mode & 0o7777, 0o2750)
        self.assertEqual(os.getxattr(self.target / "media", "user.directory"), b"keep")
        self.assertEqual((self.target / name).stat().st_atime_ns, 1_000_000_000)

    def test_status_is_public_and_does_not_claim_backlog(self):
        path = self.base / "status.json"
        mover.publish_status({"statusPath": str(path)}, "copy-complete")
        result = json.loads(path.read_text())
        self.assertEqual(result["schemaVersion"], 1)
        self.assertIsNone(result["pendingFiles"])
        self.assertIsNone(result["pendingBytes"])
        self.assertEqual(path.stat().st_mode & 0o777, 0o644)
        self.assertNotIn(str(self.source), path.read_text())


class PolicyTests(unittest.TestCase):
    def test_diff_fail_closed(self):
        for status, output in [
            (1, "0 removed\n0 updated\n"),
            (0, "broken"),
            (2, "0 removed\n"),
        ]:
            with self.assertRaises(mover.Unsafe):
                mover.diff_counts(status, output)
        self.assertEqual(mover.diff_counts(2, " 1 removed\n 2 updated\n"), (1, 2))

    def test_nohidden_and_exclusions(self):
        for path in [
            ".secret",
            "media/.secret/a",
            "a.tmp",
            "tmp/a",
            "a/Thumbs.db",
            "snapraid.content",
        ]:
            self.assertFalse(mover.protectable(path, ["*.tmp", "/tmp/", "Thumbs.db"]))
        self.assertTrue(mover.protectable("media/a b\n:c", []))


if __name__ == "__main__":
    unittest.main()
