#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Preservation contracts use real files and captured catalog shapes."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HERE = Path(__file__).parent
snapshot = load('snapshot', HERE / 'media-library-snapshot.py')
parity = load('parity', HERE / 'media-scryer-parity.py')
audit = load('audit', HERE / 'media-scryer-indexer-audit.py')
state = load('state', HERE.parent / 'modules/media-state-ready.py')


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / '.hidden').mkdir()
        (self.root / '.hidden/video.mkv').write_bytes(b'original')
        (self.root / 'empty').mkdir()
        self.before = snapshot.snapshot({'tv': self.root})

    def tearDown(self):
        self.temporary.cleanup()

    def result(self):
        return snapshot.compare(self.before, snapshot.snapshot({'tv': self.root}))

    def test_unchanged_including_dotdirs(self):
        self.assertIn('tv/.hidden/video.mkv', self.before['entries'])
        self.assertEqual(self.result(), {'failures': [], 'warnings': [], 'new': []})

    def test_file_change_fails(self):
        (self.root / '.hidden/video.mkv').write_bytes(b'changed')
        self.assertTrue(self.result()['failures'])

    def test_missing_file_fails(self):
        (self.root / '.hidden/video.mkv').unlink()
        self.assertTrue(self.result()['failures'])

    def test_renamed_file_fails(self):
        (self.root / '.hidden/video.mkv').rename(self.root / '.hidden/renamed.mkv')
        self.assertTrue(self.result()['failures'])

    def test_new_file_is_listed_not_failure(self):
        (self.root / 'new.mkv').write_bytes(b'new')
        result = self.result()
        self.assertEqual(result['failures'], [])
        self.assertEqual(result['new'], ['tv/new.mkv'])

    def test_removed_empty_directory_warns(self):
        (self.root / 'empty').rmdir()
        result = self.result()
        self.assertEqual(result['failures'], [])
        self.assertEqual(len(result['warnings']), 1)

    def test_nonempty_removed_directory_fails(self):
        (self.root / '.hidden/video.mkv').unlink()
        (self.root / '.hidden').rmdir()
        self.assertTrue(self.result()['failures'])

    def test_recycle_content_always_fails_even_when_new(self):
        (self.root / '.scryer-recycle').mkdir()
        self.assertFalse(self.result()['failures'])
        (self.root / '.scryer-recycle/entry').mkdir()
        self.assertTrue(self.result()['failures'])

    def test_directory_ownership_and_mode_change_fails(self):
        (self.root / 'empty').chmod(0o700)
        self.assertTrue(self.result()['failures'])


class ParityTests(unittest.TestCase):
    def setUp(self):
        self.fixture = json.loads((HERE / 'fixtures/media-scryer-parity.json').read_text())

    def check(self, target):
        return parity.compare(self.fixture['source'], target)

    def test_complete_catalog_counts(self):
        counts, differences = self.check(self.fixture['target'])
        self.assertEqual(counts, {'series': 1, 'movies': 1, 'seasons': 2, 'episodes': 3, 'files': 2})
        self.assertEqual(differences, [])

    def test_missing_title_fails(self):
        self.assertTrue(self.check(self.fixture['target'][1:])[1])

    def test_each_monitoring_level_and_profile_and_path_is_a_gate(self):
        for field, value in [('monitored', False), ('seasons', {'0': False, '1': False}),
                             ('episodes', {'0:1': False, '1:1': False, '1:2': False}),
                             ('quality_profile', 'Any'), ('paths', [])]:
            target = copy.deepcopy(self.fixture['target'])
            target[0][field] = value
            self.assertTrue(self.check(target)[1], field)

    def test_unmonitored_missing_episode_is_not_treated_as_false(self):
        target = copy.deepcopy(self.fixture['target'])
        del target[0]['episodes']['1:2']
        self.assertTrue(self.check(target)[1])

    def test_duplicate_identity_fails(self):
        target = copy.deepcopy(self.fixture['target'])
        target.append(target[0])
        self.assertTrue(self.check(target)[1])


class AdmissionTests(unittest.TestCase):
    def test_cli_argument_errors_never_echo_input(self):
        value = 'never-print-this-fixture-value'
        for command in ('media-scryer-provision', 'media-scryer-import', 'media-scryer-parity',
                        'media-arr-archive', 'media-library-snapshot'):
            result = subprocess.run([sys.executable, str(HERE / (command + '.py')),
                                     '--invalid-credential-token=' + value],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, command)
            self.assertNotIn(value, result.stdout + result.stderr, command)
            self.assertTrue(result.stderr.startswith('Refused:'), command)

    def test_empty_and_readable_database_admitted_other_state_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state.validate_scryer(root)
            (root / 'encryption.key').write_text('not a database')
            with self.assertRaises(OSError):
                state.validate_scryer(root)
            (root / 'scryer.db').write_bytes(b'SQLite format 3\x00')
            state.validate_scryer(root)
            (root / 'scryer.db').unlink()
            (root / 'scryer.db').symlink_to(root / 'encryption.key')
            with self.assertRaises(OSError):
                state.validate_scryer(root)

    def test_indexers_only_use_prowlarr(self):
        for value in ('http://10.200.200.2:9696', 'https://indexers.hummingbird-lake.ts.net/1',
                      'http://indexers:9696'):
            self.assertTrue(audit.allowed_url(value), value)
        for value in ('http://10.200.200.2:7878', 'https://indexers.evil.test',
                      'https://indexers.hummingbird-lake.ts.net.evil.test',
                      'http://evil.test/indexers', 'http://secret@indexers', 'not a URL'):
            self.assertFalse(audit.allowed_url(value), value)

    def test_indexer_audit_absent_identity_is_explicit_skip(self):
        with tempfile.TemporaryDirectory() as temporary:
            audit.common.IDENTITY = Path(temporary) / 'absent.json'
            status, message = audit.audit()
            self.assertEqual(status, 'SKIP')
            self.assertIn('absent', message)


if __name__ == '__main__':
    unittest.main()
