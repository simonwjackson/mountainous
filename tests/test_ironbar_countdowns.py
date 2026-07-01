import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "features" / "hyprland" / "ironbar-countdowns.py"


class IronbarCountdownsTest(unittest.TestCase):
    def run_countdowns(self, contents, today="2026-06-22"):
        with tempfile.TemporaryDirectory() as tmpdir:
            countdowns = pathlib.Path(tmpdir) / "countdowns"
            countdowns.write_text(contents)
            env = os.environ.copy()
            env["IRONBAR_COUNTDOWNS_TODAY"] = today
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--file", str(countdowns)],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )
            return result

    def test_outputs_label_and_calendar_days_remaining(self):
        result = self.run_countdowns(
            """
            # label | date
            Trip | 2026-07-02
            Taxes | 2026-07-22
            """
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "Trip 10d  Taxes 30d")

    def test_allows_date_first_lines_with_spaced_labels(self):
        result = self.run_countdowns("2026-07-02 Summer trip\n")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "Summer trip 10d")

    def test_outputs_business_days_when_mode_is_business(self):
        result = self.run_countdowns(
            """
            Sprint | 2026-06-29 | business
            Trip | 2026-07-02
            """
        )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "Sprint 5d  Trip 10d")

    def test_business_days_support_overdue_dates(self):
        result = self.run_countdowns("Missed | 2026-06-22 | business\n", today="2026-06-29")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "Missed -5d")

    def test_missing_file_outputs_no_segments(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            missing = pathlib.Path(tmpdir) / "missing"
            env = os.environ.copy()
            env["IRONBAR_COUNTDOWNS_TODAY"] = "2026-06-22"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--file", str(missing)],
                text=True,
                capture_output=True,
                env=env,
                check=False,
            )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "\n")

    def test_invalid_lines_are_skipped_with_stderr_hint(self):
        result = self.run_countdowns("bad-line\nTrip | 2026-07-02\n")

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "Trip 10d")
        self.assertIn("skipping invalid countdown line 1", result.stderr)


if __name__ == "__main__":
    unittest.main()
