"""modules/storage-alert.py through its CLI, with a recording notify CLI and a scripted probe.

Run: python3 tests/test_storage_alert.py path/to/storage-alert.py
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = None


def executable(path: Path, body: str) -> None:
    path.write_text(f"#!{shutil.which('bash')}\n" + body)
    path.chmod(0o755)


class Harness:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.state = self.root / "state"
        self.calls = self.root / "calls.jsonl"
        self.probe = self.root / "probe.sh"
        self.notify = self.root / "notify"
        # Records every call; sends fail while FAIL_SEND exists, clears while FAIL_CLEAR exists.
        executable(self.notify, f"""
python3 - "$@" <<'PY'
import json, os, sys, secrets
calls = {str(self.calls)!r}
args = sys.argv[1:]
token = os.environ.get("NOTIFY_TOKEN_FILE", "")
with open(calls, "a") as f:
    f.write(json.dumps({{"args": args, "tokenFromEnv": bool(token)}}) + "\\n")
if args[0] == "send":
    if os.path.exists({str(self.root / 'FAIL_SEND')!r}):
        sys.exit(1)
    print("agent-storage-test-" + secrets.token_hex(12))
elif args[0] == "clear":
    sys.exit(1 if os.path.exists({str(self.root / 'FAIL_CLEAR')!r}) else 0)
PY
""")
        self.findings([])

    def findings(self, rows, complete=True, exit_code=0, at=None):
        now = at if at is not None else int(time.time())
        text = "".join(f"{level}\t{message}\n" for level, message in rows)
        if complete:
            text += f"complete\t{now}\n"
        output = self.root / "probe-output"
        output.write_text(text)
        self.probe.write_text(f"cat {str(output)!r}\nexit {exit_code}\n")

    def run(self, *extra):
        env = dict(os.environ, NOTIFY_TOKEN_FILE=str(self.root / "token"))
        return subprocess.run(
            [sys.executable, SCRIPT, "--probe", str(self.probe), "--profile", "test",
             "--state-dir", str(self.state), "--notify", str(self.notify), *extra],
            env=env, capture_output=True, text=True,
        )

    def take(self):
        if not self.calls.exists():
            return []
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.calls.unlink()
        return calls

    def saved(self):
        return json.loads((self.state / "state.json").read_text())


class StorageAlert(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.addCleanup(self.h.tmp.cleanup)

    def sends(self, calls):
        return [c["args"] for c in calls if c["args"][0] == "send"]

    def test_first_bad_alerts_once_and_unchanged_never_repeats(self):
        self.h.findings([("warn", "cache 82% used"), ("bad", "towada: last SnapRAID sync 40 h ago")])
        self.assertEqual(self.h.run().returncode, 0)
        sends = self.sends(self.h.take())
        self.assertEqual(len(sends), 1)
        self.assertIn("towada: last SnapRAID sync 40 h ago", sends[0])
        self.assertIn("storage problem", " ".join(sends[0]))
        # The hour count changes every run; the problem is the same.
        self.h.findings([("bad", "towada: last SnapRAID sync 41 h ago")])
        self.assertEqual(self.h.run().returncode, 0)
        self.assertEqual(self.h.take(), [])

    def test_second_disk_failure_alerts_separately(self):
        self.h.findings([("bad", "/srv/shores/towada/03 is missing or not mounted")])
        self.h.run()
        self.h.take()
        self.h.findings([
            ("bad", "/srv/shores/towada/03 is missing or not mounted"),
            ("bad", "/srv/shores/towada/04 is missing or not mounted"),
        ])
        self.h.run()
        sends = self.sends(self.h.take())
        self.assertEqual(len(sends), 1)
        self.assertIn("/srv/shores/towada/04 is missing or not mounted", sends[0])

    def test_warn_and_ok_never_alert(self):
        self.h.findings([("warn", "nscd.service failed"), ("ok", "all checks passed")])
        self.assertEqual(self.h.run().returncode, 0)
        self.assertEqual(self.h.take(), [])

    def test_recovery_sends_once_and_clears_original(self):
        self.h.findings([("bad", "towada disk 03 is missing or not mounted")])
        self.h.run()
        seq = self.h.saved()["alerts"]["towada disk 03 is missing or not mounted"]["seq"]
        self.h.take()
        self.h.findings([])
        self.assertEqual(self.h.run().returncode, 0)
        calls = [c["args"] for c in self.h.take()]
        self.assertEqual(calls[0][:1], ["send"])
        self.assertIn("storage recovered", " ".join(calls[0]))
        self.assertEqual(calls[1], ["clear", seq])
        self.assertEqual(self.h.saved()["alerts"], {})
        self.h.run()
        self.assertEqual(self.h.take(), [])

    def test_unknown_is_rate_limited_and_not_recovery(self):
        self.h.findings([("bad", "towada disk 03 is missing or not mounted")])
        self.h.run()
        self.h.take()
        self.h.findings([], complete=False)
        self.h.run("--unknown-interval", "3600")
        sends = self.sends(self.h.take())
        self.assertEqual(len(sends), 1)
        self.assertIn("unavailable", " ".join(sends[0]))
        # The open storage alert must survive an unknown result.
        self.assertIn("towada disk 03 is missing or not mounted", self.h.saved()["alerts"])
        self.h.run("--unknown-interval", "3600")
        self.assertEqual(self.h.take(), [])
        # After the interval it may repeat, clearing the older notice.
        state = self.h.saved()
        state["unknown"]["sentAt"] -= 3601
        (self.h.state / "state.json").write_text(json.dumps(state))
        self.h.run("--unknown-interval", "3600")
        calls = [c["args"] for c in self.h.take()]
        self.assertEqual([c[0] for c in calls], ["send", "clear"])

    def test_malformed_failed_or_stale_probe_is_unknown(self):
        for case in (
            dict(rows=[("bad", "x")], complete=False),
            dict(rows=[("fine", "x")]),
            dict(rows=[], exit_code=2),
            dict(rows=[("bad", "x")], at=int(time.time()) - 600),
        ):
            with self.subTest(case=case):
                self.h.findings(**case)
                self.h.run()
                sends = self.sends(self.h.take())
                state = self.h.saved()
                self.assertEqual(state["alerts"], {})
                self.assertIsNotNone(state["unknown"])
                (self.h.state / "state.json").unlink()
                self.assertTrue(sends)

    def test_unknown_recovery_clears_notice(self):
        self.h.findings([], complete=False)
        self.h.run()
        seq = self.h.saved()["unknown"]["seq"]
        self.h.take()
        self.h.findings([])
        self.h.run()
        calls = [c["args"] for c in self.h.take()]
        self.assertIn("check recovered", " ".join(calls[0]))
        self.assertEqual(calls[1], ["clear", seq])
        self.assertIsNone(self.h.saved()["unknown"])

    def test_publish_failure_retries_next_run(self):
        (self.h.root / "FAIL_SEND").touch()
        self.h.findings([("bad", "srv-lakes-towada.mount failed")])
        result = self.h.run()
        self.assertEqual(result.returncode, 1)
        self.assertIn("publish failed", result.stderr)
        self.assertEqual(self.h.saved()["alerts"], {})
        self.h.take()
        (self.h.root / "FAIL_SEND").unlink()
        self.assertEqual(self.h.run().returncode, 0)
        self.assertEqual(len(self.sends(self.h.take())), 1)

    def test_clear_failure_keeps_record_without_resending_recovery(self):
        self.h.findings([("bad", "srv-lakes-towada.mount failed")])
        self.h.run()
        self.h.take()
        (self.h.root / "FAIL_CLEAR").touch()
        self.h.findings([])
        self.assertEqual(self.h.run().returncode, 1)
        self.assertEqual([c["args"][0] for c in self.h.take()], ["send", "clear"])
        (self.h.root / "FAIL_CLEAR").unlink()
        self.assertEqual(self.h.run().returncode, 0)
        self.assertEqual([c["args"][0] for c in self.h.take()], ["clear"])
        self.assertEqual(self.h.saved()["alerts"], {})

    def test_finding_that_returns_while_clear_is_pending_alerts_again(self):
        self.h.findings([("bad", "srv-lakes-towada.mount failed")])
        self.h.run()
        (self.h.root / "FAIL_CLEAR").touch()
        self.h.findings([])
        self.h.run()
        self.h.take()
        (self.h.root / "FAIL_CLEAR").unlink()
        self.h.findings([("bad", "srv-lakes-towada.mount failed")])
        self.assertEqual(self.h.run().returncode, 0)
        sends = self.sends(self.h.take())
        self.assertEqual(len(sends), 1)
        self.assertIn("storage problem", " ".join(sends[0]))
        self.assertFalse(self.h.saved()["alerts"]["srv-lakes-towada.mount failed"].get("recovered"))

    def test_token_comes_from_environment_never_argv(self):
        self.h.findings([("bad", "srv-lakes-towada.mount failed")])
        self.h.run()
        for call in self.h.take():
            self.assertTrue(call["tokenFromEnv"])
            self.assertFalse(any("token" in a for a in call["args"]))

    def test_corrupt_state_starts_empty_and_still_alerts(self):
        self.h.state.mkdir()
        (self.h.state / "state.json").write_text("{not json")
        self.h.findings([("bad", "srv-lakes-towada.mount failed")])
        self.assertEqual(self.h.run().returncode, 0)
        self.assertEqual(len(self.sends(self.h.take())), 1)


if __name__ == "__main__":
    SCRIPT = sys.argv.pop(1)
    unittest.main(verbosity=2)
