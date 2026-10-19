"""Filesystem tests; mount identity and real SnapRAID run in disk-array-vm.nix."""

import importlib.util
import os
import errno
from pathlib import Path
import tempfile
import subprocess
import sys
import time
import json
import select
import struct
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

    def directory_process(self, name, behavior):
        # Python audit events provide a deterministic subprocess stop/error at
        # the real metadata syscall boundary, without replacing filesystem I/O.
        code = """
import errno, os, signal, stat, sys
sys.path.insert(0, sys.argv[1])
import mover
source, target = mover.Root(sys.argv[2]), mover.Root(sys.argv[3])
def audit(event, args):
    if sys.argv[5] == "interrupt" and event == "os.chown":
        print("before-directory-owner", flush=True)
        os.kill(os.getpid(), signal.SIGSTOP)
    if sys.argv[5] == "unsupported" and event == "os.setxattr" and isinstance(args[0], int) and stat.S_ISDIR(os.fstat(args[0]).st_mode):
        raise OSError(errno.ENOTSUP, "directory xattrs unavailable")
sys.addaudithook(audit)
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
                behavior,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(lambda: process.poll() is None and process.kill())
        return process

    def test_interrupted_directory_initialization_is_not_published(self):
        name = self.seed()
        os.chmod(self.source / "media", 0o2750)
        os.setxattr(self.source / "media", "user.directory", b"keep")
        process = self.directory_process(name, "interrupt")
        self.assertTrue(select.select([process.stdout], [], [], 10)[0])
        self.assertEqual(process.stdout.readline().strip(), b"before-directory-owner")
        _, status = os.waitpid(process.pid, os.WUNTRACED)
        self.assertTrue(os.WIFSTOPPED(status))
        process.kill()
        process.communicate(timeout=10)
        self.assertFalse((self.target / "media").exists())
        staging = list(self.target.glob(".cache-mover-dir-*"))
        self.assertTrue(staging)
        self.assertTrue(all(path.stat().st_mode & 0o7777 == 0o700 for path in staging))
        mover.copy_file(self.src, self.dst, name)
        self.assertEqual((self.target / "media").stat().st_mode & 0o7777, 0o2750)
        self.assertEqual(os.getxattr(self.target / "media", "user.directory"), b"keep")
        self.assertEqual((self.target / name).read_bytes(), b"original")
        self.assertTrue((self.source / name).exists())

    def test_new_directory_does_not_inherit_destination_acl(self):
        name = self.seed()
        # Linux POSIX ACL wire format: owner, named user 12345, group, mask, other.
        acl = struct.pack("<I", 2) + b"".join(
            struct.pack("<HHI", tag, perm, ident)
            for tag, perm, ident in [
                (1, 7, 0xFFFFFFFF),
                (2, 5, 12345),
                (4, 5, 0xFFFFFFFF),
                (16, 5, 0xFFFFFFFF),
                (32, 0, 0xFFFFFFFF),
            ]
        )
        os.setxattr(self.target, "system.posix_acl_default", acl)
        self.assertEqual(os.listxattr(self.source / "media"), [])
        mover.copy_file(self.src, self.dst, name)
        self.assertEqual(os.listxattr(self.target / "media"), [])
        self.assertEqual(os.getxattr(self.target, "system.posix_acl_default"), acl)
        self.assertEqual(
            (self.target / "media").stat().st_mode & 0o7777,
            (self.source / "media").stat().st_mode & 0o7777,
        )

    def test_new_directory_preserves_source_acl_instead_of_parent_acl(self):
        name = self.seed()

        def acl_for(user):
            return struct.pack("<I", 2) + b"".join(
                struct.pack("<HHI", tag, perm, ident)
                for tag, perm, ident in [
                    (1, 7, 0xFFFFFFFF),
                    (2, 5, user),
                    (4, 5, 0xFFFFFFFF),
                    (16, 5, 0xFFFFFFFF),
                    (32, 0, 0xFFFFFFFF),
                ]
            )

        for key in ["system.posix_acl_access", "system.posix_acl_default"]:
            os.setxattr(self.source / "media", key, acl_for(12345))
        os.setxattr(self.target, "system.posix_acl_default", acl_for(54321))
        expected = {
            key: os.getxattr(self.source / "media", key)
            for key in os.listxattr(self.source / "media")
        }
        mover.copy_file(self.src, self.dst, name)
        self.assertEqual(
            {
                key: os.getxattr(self.target / "media", key)
                for key in os.listxattr(self.target / "media")
            },
            expected,
        )
        self.assertEqual(
            (self.target / "media").stat().st_mode,
            (self.source / "media").stat().st_mode,
        )
        self.assertEqual(os.listxattr(self.target / name), ["user.test"])

    def test_unsupported_directory_metadata_fails_before_publication(self):
        name = self.seed()
        os.setxattr(self.source / "media", "user.directory", b"keep")
        process = self.directory_process(name, "unsupported")
        _, error = process.communicate(timeout=10)
        self.assertNotEqual(process.returncode, 0)
        self.assertIn(b"directory xattrs unavailable", error)
        self.assertFalse((self.target / "media").exists())
        self.assertTrue((self.source / name).exists())
        mover.copy_file(self.src, self.dst, name)
        self.assertEqual(os.getxattr(self.target / "media", "user.directory"), b"keep")

    def test_existing_directory_permissions_and_xattrs_are_not_rewritten(self):
        name = self.seed()
        # Reproduce the setgid cache-root inheritance seen in the real XFS VM.
        os.chmod(self.target, 0o2775)
        (self.target / "media").mkdir(mode=0o700)
        os.setxattr(self.target / "media", "user.existing", b"keep")
        before = (self.target / "media").stat()
        attrs = {
            key: os.getxattr(self.target / "media", key)
            for key in os.listxattr(self.target / "media")
        }
        mover.copy_file(self.src, self.dst, name)
        after = (self.target / "media").stat()
        self.assertEqual(
            (after.st_ino, after.st_uid, after.st_gid, after.st_mode),
            (before.st_ino, before.st_uid, before.st_gid, before.st_mode),
        )
        self.assertEqual(
            {
                key: os.getxattr(self.target / "media", key)
                for key in os.listxattr(self.target / "media")
            },
            attrs,
        )

    def test_removing_already_absent_xattr_preserves_other_metadata(self):
        name = self.seed("attrs")
        with self.src.file(name) as fd:
            os.setxattr(fd, "user.remove", b"gone")
            mover.remove_xattr_if_present(fd, "user.remove")
            before = mover.metadata(fd)
            mover.remove_xattr_if_present(fd, "user.remove")
            self.assertEqual(mover.metadata(fd), before)
            self.assertEqual(os.getxattr(fd, "user.test"), b"metadata")

    def test_xattr_removal_propagates_errors_other_than_absence(self):
        name = self.seed("attrs")
        code = """
import errno, os, sys
sys.path.insert(0, sys.argv[1])
import mover
fd = os.open(sys.argv[2], os.O_RDONLY)
def audit(event, args):
    if event == "os.removexattr":
        raise OSError(int(sys.argv[3]), "removal denied")
sys.addaudithook(audit)
try:
    mover.remove_xattr_if_present(fd, "user.test")
finally:
    os.close(fd)
"""
        for error in (errno.ENOTSUP, errno.EPERM, errno.EIO):
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    code,
                    str(Path(SPEC.origin).parent),
                    str(self.source / name),
                    str(error),
                ],
                capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(f"[Errno {error}] removal denied".encode(), result.stderr)
            self.assertEqual(os.getxattr(self.source / name, "user.test"), b"metadata")

    def test_siblings_preserve_directory_permissions_not_directory_timestamps(self):
        first = self.seed("media/first")
        second = self.seed("media/second")
        os.chmod(self.source / "media", 0o2750)
        os.setxattr(self.source / "media", "user.directory", b"keep")
        os.utime(self.source / "media", ns=(1_000_000_000, 2_000_000_000))
        mover.copy_file(self.src, self.dst, first)
        mover.copy_file(self.src, self.dst, second)
        self.assertEqual((self.target / "media").stat().st_mode & 0o7777, 0o2750)
        self.assertEqual(os.getxattr(self.target / "media", "user.directory"), b"keep")
        self.assertNotEqual((self.target / "media").stat().st_mtime_ns, 2_000_000_000)
        for name in [first, second]:
            self.assertEqual((self.target / name).stat().st_mtime_ns, 2_000_000_001)

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
