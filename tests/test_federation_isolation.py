"""Filesystem contracts; systemd behavior is covered by federation-isolation.nix."""

import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(__file__).parents[1] / "scripts/federation_isolation.py"
spec = importlib.util.spec_from_file_location("isolation", SOURCE)
isolation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(isolation)


class OwnedArtifactsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / "state"
        self.artifacts = isolation.OwnedArtifacts(self.state)
        self.artifacts.__enter__()
        self.addCleanup(self.artifacts.__exit__, None, None, None)

    def test_restores_only_created_artifacts_and_preserves_existing_mask(self):
        previous = self.root / "sunshine.service"
        previous.symlink_to("/dev/null")
        metadata = previous.lstat()
        created = self.root / "korrid.service"
        self.artifacts.symlink(created, "/dev/null")
        self.artifacts.restore()
        self.assertFalse(created.is_symlink())
        self.assertEqual(previous.lstat(), metadata)

    def test_collision_does_not_replace_foreign_file_or_link(self):
        for kind in ("file", "link", "dangling"):
            with self.subTest(kind=kind):
                path = self.root / kind
                if kind == "file":
                    path.write_text("foreign")
                else:
                    path.symlink_to("/dev/null" if kind == "link" else "/absent")
                before = path.lstat()
                with self.assertRaises(isolation.Refusal):
                    self.artifacts.symlink(path, "/dev/null")
                self.assertEqual(path.lstat(), before)

    def test_changed_inode_or_contents_refuses_entire_restoration(self):
        first, second = self.root / "first", self.root / "second"
        self.artifacts.file(first, b"closed")
        self.artifacts.file(second, b"closed")
        second.write_bytes(b"foreign")
        with self.assertRaises(isolation.Refusal):
            self.artifacts.restore()
        self.assertEqual(first.read_bytes(), b"closed")
        self.assertEqual(second.read_bytes(), b"foreign")

    def test_identical_replacement_link_is_not_owned(self):
        path = self.root / "mask"
        self.artifacts.symlink(path, "/dev/null")
        other = self.root / "other"
        other.symlink_to("/dev/null")
        other.replace(path)
        with self.assertRaises(isolation.Refusal):
            self.artifacts.restore()
        self.assertTrue(path.is_symlink())

    def test_symlink_parent_refused_without_writing_through_it(self):
        real = self.root / "real"
        real.mkdir()
        alias = self.root / "alias"
        alias.symlink_to(real)
        with self.assertRaises(isolation.Refusal):
            self.artifacts.file(alias / "gate", b"closed")
        self.assertEqual(list(real.iterdir()), [])

    def test_unknown_directory_child_refuses_before_removing_any_gate(self):
        directory = self.root / "owned"
        self.artifacts.directory(directory)
        gate = directory / "gate"
        self.artifacts.file(gate, b"closed")
        (directory / "foreign").write_bytes(b"keep")
        with self.assertRaises(isolation.Refusal):
            self.artifacts.restore()
        self.assertEqual(gate.read_bytes(), b"closed")

    def test_malformed_manifest_reports_refusal_and_releases_lock(self):
        self.artifacts.__exit__()
        manifest = self.state / "manifest.json"
        manifest.write_text("{not-json")
        manifest.chmod(0o600)
        broken = isolation.OwnedArtifacts(self.state)
        self.addCleanup(broken.__exit__)
        try:
            broken.__enter__()
        except Exception as error:
            caught = error
        else:
            self.fail("accepted malformed evidence")
        # Repair only the deliberately corrupt fixture; never silently discard it.
        self.assertEqual(manifest.read_text(), "{not-json")
        manifest.write_text("{}")
        with isolation.OwnedArtifacts(self.state) as reopened:
            reopened.verify()
        self.assertIsInstance(caught, isolation.Refusal)

    def test_invalid_manifest_shape_refuses_without_replacing_evidence(self):
        self.artifacts.__exit__()
        manifest = self.state / "manifest.json"
        for content in ("[]", '{"/tmp/artifact": {}}'):
            with self.subTest(content=content):
                manifest.write_text(content)
                manifest.chmod(0o600)
                with self.assertRaises(isolation.Refusal):
                    with isolation.OwnedArtifacts(self.state):
                        pass
                self.assertEqual(manifest.read_text(), content)
        manifest.write_text("{}")
        with isolation.OwnedArtifacts(self.state) as reopened:
            reopened.verify()

    def test_manifest_drift_refuses_save_and_removal_without_adoption(self):
        for drift in ("bytes", "inode", "missing", "mode", "hardlink"):
            for operation in ("record", "restore"):
                with self.subTest(drift=drift, operation=operation):
                    root = self.root / f"{drift}-{operation}"
                    root.mkdir()
                    with isolation.OwnedArtifacts(root / "state") as artifacts:
                        gate = root / "gate"
                        artifacts.file(gate, b"closed")
                        manifest = artifacts.state / "manifest.json"
                        if drift == "bytes":
                            manifest.write_bytes(b"{}")
                        elif drift == "inode":
                            replacement = root / "replacement"
                            replacement.write_bytes(manifest.read_bytes())
                            replacement.chmod(0o600)
                            replacement.replace(manifest)
                        elif drift == "missing":
                            manifest.unlink()
                        elif drift == "mode":
                            manifest.chmod(0o644)
                        else:
                            os.link(manifest, root / "hardlink")
                        before = manifest.read_bytes() if manifest.exists() else None
                        metadata = manifest.lstat() if manifest.exists() else None
                        with self.assertRaises(isolation.Refusal):
                            if operation == "record":
                                artifacts.record(gate)
                            else:
                                artifacts.restore([gate])
                        self.assertEqual(gate.read_bytes(), b"closed")
                        self.assertEqual(
                            manifest.read_bytes() if manifest.exists() else None, before
                        )
                        self.assertEqual(
                            manifest.lstat() if manifest.exists() else None, metadata
                        )

    def test_exclusive_lock_blocks_second_writer(self):
        with self.assertRaises(isolation.Refusal):
            with isolation.OwnedArtifacts(self.state):
                self.fail("second writer entered")

    def test_partial_failure_retains_prior_gate_and_reopens_manifest(self):
        path = self.root / "gate"
        self.artifacts.file(path, b"closed")
        collision = self.root / "collision"
        collision.write_bytes(b"foreign")
        with self.assertRaises(isolation.Refusal):
            self.artifacts.file(collision, b"replacement")
        self.assertEqual(path.read_bytes(), b"closed")
        self.artifacts.__exit__(None, None, None)
        with isolation.OwnedArtifacts(self.state) as reopened:
            reopened.verify()
            reopened.restore()
        self.assertFalse(path.exists())
        self.assertEqual(collision.read_bytes(), b"foreign")


class ManagerProcessTests(unittest.TestCase):
    def test_user_operations_require_root_even_without_bus_io(self):
        self.assertNotEqual(os.geteuid(), 0)
        import pwd

        with self.assertRaises(isolation.Refusal):
            isolation.Manager(pwd.getpwuid(1000).pw_name).call("--version")

    def test_unknown_user_never_executes_a_successful_nonquery(self):
        for user in ("no-such-federation-user", "root", ""):
            with self.subTest(user=user), self.assertRaises(isolation.Refusal):
                isolation.Manager(user).call("--version")

    def test_failed_real_manager_query_is_fatal(self):
        with self.assertRaisesRegex(
            isolation.Refusal, "systemd operation failed: show"
        ):
            isolation.Manager().call("show", "--not-a-systemctl-option")


class JobContractTests(unittest.TestCase):
    def test_exact_authority_jobs_only(self):
        jobs = isolation.parse_jobs(
            "12 korrid.service start waiting\n13 sshd.service restart running\n"
        )
        self.assertEqual(
            isolation.authority_job_ids(jobs, isolation.SYSTEM_UNITS), ["12"]
        )

    def test_ambiguous_job_output_refuses(self):
        for text in (
            "oops",
            "12 korrid.service start\n",
            "x korrid.service start waiting\n",
            "12 a.service start waiting\n12 b.service start waiting\n",
        ):
            with self.subTest(text=text), self.assertRaises(isolation.Refusal):
                isolation.parse_jobs(text)


if __name__ == "__main__":
    unittest.main()
