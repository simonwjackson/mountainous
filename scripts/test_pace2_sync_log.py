"""The public log projection accepts tracing's real quoted string format."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).with_name("pace2-sync-log.py")
spec = importlib.util.spec_from_file_location("sync_log", path)
sync_log = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync_log)


class SyncLogContract(unittest.TestCase):
    def test_real_tracing_format_drops_counts(self):
        self.assertEqual(
            sync_log.parse_sync_line('INFO pace: bank sync outcome="complete" warnings=[] problems=[] added=7'),
            {"outcome": "complete", "warnings": []},
        )

    def test_unquoted_value_and_warning_codes(self):
        self.assertEqual(
            sync_log.parse_sync_line('bank sync outcome=partial warnings=["gen.api"] problems=[] added=0'),
            {"outcome": "partial", "warnings": ["gen.api"]},
        )

    def test_ignores_admission_logs(self):
        self.assertIsNone(sync_log.parse_sync_line('DEBUG admitted person="laure" method=POST'))

    def test_invalid_outcome_is_not_a_success(self):
        with self.assertRaises(ValueError):
            sync_log.parse_sync_line('bank sync outcome="unknown" warnings=[]')


if __name__ == "__main__":
    unittest.main()
