#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Regression for the mover's accidental deletion of required library roots."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('cleanup', Path(__file__).parent.parent / 'modules/media-library-cleanup.py')
cleanup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleanup)


class RootPreservation(unittest.TestCase):
    def test_empty_library_roots_and_media_root_remain(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            for part in ('movies', 'tv'):
                (root / part / 'title' / 'season').mkdir(parents=True)
            self.assertEqual(cleanup.prune_empty_titles(root), 4)
            self.assertTrue(root.is_dir())
            self.assertEqual(sorted(path.name for path in root.iterdir()), ['movies', 'tv'])
            self.assertEqual(cleanup.prune_empty_titles(root), 0)

    def test_media_files_and_symlink_targets_survive(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / 'movies' / 'kept').mkdir(parents=True)
            (root / 'tv').mkdir()
            media = root / 'movies' / 'kept' / 'video'
            media.write_bytes(b'unchanged media')
            outside = root / 'outside' / 'empty'
            outside.mkdir(parents=True)
            (root / 'tv' / 'linked').symlink_to(outside, target_is_directory=True)
            self.assertEqual(cleanup.prune_empty_titles(root), 0)
            self.assertEqual(media.read_bytes(), b'unchanged media')
            self.assertTrue(outside.is_dir())
            self.assertTrue((root / 'tv' / 'linked').is_symlink())

    def test_missing_library_fails_before_deleting_titles(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            empty = root / 'movies' / 'empty'
            empty.mkdir(parents=True)
            with self.assertRaises(FileNotFoundError):
                cleanup.prune_empty_titles(root)
            self.assertTrue(empty.is_dir())

    def test_symlink_library_root_fails_before_deleting_titles(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            empty = root / 'movies' / 'empty'
            empty.mkdir(parents=True)
            (root / 'outside').mkdir()
            (root / 'tv').symlink_to(root / 'outside', target_is_directory=True)
            with self.assertRaises(OSError):
                cleanup.prune_empty_titles(root)
            self.assertTrue(empty.is_dir())


if __name__ == '__main__':
    unittest.main()
