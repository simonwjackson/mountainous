#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise the actual file handoff, collision guards and root-preserving cleanup."""
import importlib.util
import os
from pathlib import Path
import tempfile
import time
import unittest

spec = importlib.util.spec_from_file_location('mover', Path(__file__).parents[1] / 'modules/media-library-mover.py')
mover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mover)


class LibraryHandoffTests(unittest.TestCase):
    def setUp(self):
        self.area = tempfile.TemporaryDirectory()
        self.base = Path(self.area.name)
        self.source = self.base / 'local'
        self.destination = self.base / 'stored'
        for root in [self.source, self.destination]:
            for part in ['movies', 'tv']:
                (root / part).mkdir(parents=True)
        self.item = self.source / 'tv/title/season/episode.mkv'
        self.item.parent.mkdir(parents=True)
        self.item.write_bytes(b'preserved media bytes' * 1000)
        self.item.chmod(0o640)
        self.when = time.time_ns() - 3600_000_000_000
        os.utime(self.item, ns=(self.when, self.when))

    def tearDown(self):
        self.area.cleanup()

    def run_handoff(self, **options):
        return mover.handoff(self.source, self.destination, min_age_seconds=60, **options)

    def test_verified_copy_preserves_contents_mode_time_and_physical_roots(self):
        payload = self.item.read_bytes()
        result = self.run_handoff()
        target = self.destination / 'tv/title/season/episode.mkv'
        self.assertEqual(target.read_bytes(), payload)
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)
        self.assertEqual(target.stat().st_mtime_ns, self.when)
        self.assertFalse(self.item.exists())
        self.assertEqual(result['moved_files'], 1)
        for root in [self.source, self.destination]:
            for part in ['tv', 'movies']:
                self.assertTrue((root / part).is_dir())

    def test_identical_destination_retains_existing_ownership_and_metadata(self):
        target = self.destination / 'tv/title/season/episode.mkv'
        target.parent.mkdir(parents=True)
        target.write_bytes(self.item.read_bytes())
        target.chmod(0o644)
        before = target.stat()
        self.run_handoff()
        after = target.stat()
        self.assertEqual((after.st_ino, after.st_uid, after.st_gid, after.st_mode, after.st_mtime_ns),
                         (before.st_ino, before.st_uid, before.st_gid, before.st_mode, before.st_mtime_ns))
        self.assertFalse(self.item.exists())

    def test_different_destination_never_replaces_or_deletes_either_file(self):
        target = self.destination / 'tv/title/season/episode.mkv'
        target.parent.mkdir(parents=True)
        target.write_bytes(b'existing library bytes')
        with self.assertRaises(ValueError):
            self.run_handoff()
        self.assertEqual(target.read_bytes(), b'existing library bytes')
        self.assertTrue(self.item.is_file())

    def test_recent_file_stays_local(self):
        os.utime(self.item, None)
        result = self.run_handoff()
        self.assertEqual(result['moved_files'], 0)
        self.assertTrue(self.item.is_file())

    def test_busy_file_stays_local(self):
        with self.item.open('rb'):
            result = self.run_handoff()
        self.assertEqual(result['moved_files'], 0)
        self.assertTrue(self.item.is_file())

    def test_source_symlink_is_not_followed(self):
        original = self.item.read_bytes()
        self.item.unlink()
        outside = self.base / 'outside.mkv'
        outside.write_bytes(original)
        self.item.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.run_handoff()
        self.assertEqual(outside.read_bytes(), original)
        self.assertTrue(self.item.is_symlink())

    def test_destination_parent_symlink_is_rejected(self):
        outside = self.base / 'outside'
        outside.mkdir()
        (self.destination / 'tv/title').symlink_to(outside, target_is_directory=True)
        with self.assertRaises((ValueError, OSError)):
            self.run_handoff()
        self.assertEqual(list(outside.iterdir()), [])
        self.assertTrue(self.item.is_file())

    def test_missing_library_root_refuses_before_moving_anything(self):
        (self.destination / 'movies').rmdir()
        with self.assertRaises((ValueError, OSError)):
            self.run_handoff()
        self.assertTrue(self.item.is_file())

    def test_same_source_and_destination_is_rejected(self):
        with self.assertRaises(ValueError):
            mover.handoff(self.source, self.source, min_age_seconds=0)
        self.assertTrue(self.item.is_file())

    def test_download_hardlink_survives_library_handoff(self):
        completed = self.base / 'completed.mkv'
        os.link(self.item, completed)
        payload = completed.read_bytes()
        self.run_handoff()
        self.assertEqual(completed.read_bytes(), payload)
        self.assertFalse(self.item.exists())

    def test_low_space_mode_skips_when_reserve_is_available(self):
        result = self.run_handoff(mode='low-space', min_free_percent=0)
        self.assertEqual(result['moved_files'], 0)
        self.assertTrue(self.item.is_file())

    def test_zero_length_file_is_counted_as_a_completed_publication(self):
        self.item.write_bytes(b'')
        os.utime(self.item, ns=(self.when, self.when))
        result = self.run_handoff()
        self.assertEqual(result, {'moved_files': 1, 'moved_bytes': 0})
        self.assertFalse(self.item.exists())

    def test_non_regular_destination_refuses_without_blocking_or_source_release(self):
        target = self.destination / 'tv/title/season/episode.mkv'
        target.parent.mkdir(parents=True)
        os.mkfifo(target)
        with self.assertRaises(ValueError):
            self.run_handoff()
        self.assertTrue(self.item.is_file())

    def test_pending_refresh_survives_file_release_for_next_attempt(self):
        pending = self.base / 'refresh-pending'
        result = self.run_handoff(pending_refresh=pending)
        self.assertEqual(result['moved_files'], 1)
        self.assertEqual(pending.read_bytes(), b'pending\n')
        self.assertEqual(pending.stat().st_mode & 0o777, 0o600)
        self.assertFalse(self.item.exists())
        self.run_handoff(pending_refresh=pending)
        self.assertTrue(pending.exists())

    def test_unprotected_pending_refresh_refuses_source_release(self):
        pending = self.base / 'refresh-pending'
        pending.write_bytes(b'keep existing unprotected record')
        pending.chmod(0o644)
        with self.assertRaises(ValueError):
            self.run_handoff(pending_refresh=pending)
        self.assertTrue(self.item.is_file())
        self.assertEqual(pending.read_bytes(), b'keep existing unprotected record')

    def test_private_working_files_are_not_published(self):
        hidden = self.item.with_name('.import-working.tmp')
        hidden.write_bytes(b'not imported')
        os.utime(hidden, ns=(self.when, self.when))
        self.run_handoff()
        self.assertTrue(hidden.exists())
        self.assertFalse((self.destination / 'tv/title/season/.import-working.tmp').exists())


if __name__ == '__main__':
    unittest.main()
