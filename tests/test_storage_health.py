"""Run the shipped shell probes against real temp files and controlled commands."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

PROBE = STATUS = None
NOW = 1_760_860_000
UUID = "e5f61013-d6f5-260d-9883-4dda26b2c293"


def command(directory, name, body):
    path = Path(directory) / name
    path.write_text(f"#!{shutil.which('bash')}\n" + textwrap.dedent(body))
    path.chmod(0o755)


class Fixture:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.etc = self.root / "etc"
        self.etc.mkdir()
        self.srv = self.root / "srv"
        self.fs = self.root / "bcachefs"
        self.env = dict(
            os.environ,
            PATH=str(self.bin) + ":" + os.environ["PATH"],
            STORAGE_HEALTH_ETC=str(self.etc),
            STORAGE_HEALTH_SRV=str(self.srv),
            STORAGE_HEALTH_BCACHEFS=str(self.fs),
            STORAGE_HEALTH_NOW=str(NOW),
            STORAGE_HEALTH_STATE=str(self.root / "state"),
            STORAGE_HEALTH_RUN=str(self.root / "run"),
            FAILED="",
            FAILED_EXIT="0",
            UNMOUNTED="",
            HISTORY=str(NOW - 3600),
            HISTORY_EXIT="0",
            PCENT="40",
            DF_EXIT="0",
            MOUNT_UUID="",
            MOUNT_IDENTITY="b11bc61f-1632-4809-8c94-efbf39614f22",
            EXPECTED_IDENTITY="b11bc61f-1632-4809-8c94-efbf39614f22",
        )
        command(self.bin, "systemctl", 'printf "%s" "$FAILED"; exit "$FAILED_EXIT"')
        command(self.bin, "mountpoint", '[ "${!#}" != "$UNMOUNTED" ]')
        command(
            self.bin,
            "journalctl",
            """
            [[ "$*" == *MESSAGE_ID=39f53479d3a045ac8e11786248231fbf* ]] || exit 2
            for t in $HISTORY; do echo "$t.123456 host systemd[1]: Finished fixture."; done
            exit "$HISTORY_EXIT"
        """,
        )
        command(self.bin, "df", 'printf "Use%%\\n %s%%\\n" "$PCENT"; exit "$DF_EXIT"')
        command(
            self.bin,
            "findmnt",
            """
            case "$*" in
              *bcachefs*) printf '%s\\n' "$MOUNT_UUID" ;;
              *--fstab*) printf '%s\\n' "$EXPECTED_IDENTITY" ;;
              *) printf '%s\\n' "$MOUNT_IDENTITY" ;;
            esac
        """,
        )
        command(self.bin, "media-storage-health", 'exit "${MEDIA_EXIT:-0}"')

    def towada(self):
        roots = []
        for disk in ("00", "01", "02", "03", "04"):
            root = self.srv / "shores" / "towada" / disk
            root.mkdir(parents=True)
            roots.append(root)
        (self.srv / "cache" / "towada").mkdir(parents=True)
        (self.etc / "snapraid-towada.conf").write_text(
            "".join(f"data d{i} {p}\n" for i, p in enumerate(roots[:4]))
            + f"parity {roots[4]}/snapraid.parity\n"
        )

    def member(self, number, label, state="rw", errors=(0, 0, 0)):
        dev = self.fs / UUID / f"dev-{number}"
        dev.mkdir(parents=True)
        (dev / "label").write_text(label + "\n")
        (dev / "state").write_text(f"[{state}] ro spare\n")
        read, write, checksum = errors
        (dev / "io_errors").write_text(
            f"IO errors since filesystem creation\n read: {read}\n write: {write}\n checksum:{checksum}\n"
            "IO errors since 8 y ago\n read: 99\n write: 99\n checksum:99\n"
        )
        return dev

    def unzen(self):
        self.env["MOUNT_UUID"] = UUID
        for number, label in enumerate(
            ("onboard.sn770", "card.samsung", "card.sabrent"), 1
        ):
            self.member(number, label)

    def probe(self, profile="unknown", **env):
        result = subprocess.run(
            ["bash", PROBE, profile],
            env=dict(self.env, **env),
            capture_output=True,
            text=True,
            check=True,
        )
        lines = [tuple(line.split("\t")) for line in result.stdout.splitlines()]
        assert lines.pop() == ("complete", str(NOW)), lines
        return lines


class Probe(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.addCleanup(self.fx.tmp.cleanup)

    def test_missing_topology_never_green(self):
        self.assertNotIn("ok", [level for level, _ in self.fx.probe()])
        self.assertIn(
            ("bad", "expected towada SnapRAID configuration missing or unreadable"),
            self.fx.probe("zao"),
        )
        self.assertIn(
            ("bad", "expected Unzen bcachefs filesystem is not mounted"),
            self.fx.probe("unzen"),
        )

    def test_systemctl_failure_not_healthy(self):
        self.fx.unzen()
        self.assertIn(
            ("warn", "failed-unit query unavailable"),
            self.fx.probe("unzen", FAILED_EXIT="1"),
        )

    def test_healthy_unzen_and_failed_units(self):
        self.fx.unzen()
        self.assertEqual(self.fx.probe("unzen"), [("ok", "all checks passed")])
        lines = self.fx.probe(
            "unzen",
            FAILED="media-library-mover@low-space.service loaded failed failed\nnscd.service loaded failed failed\n",
        )
        self.assertEqual(
            lines,
            [
                ("bad", "media-library-mover@low-space.service failed"),
                ("warn", "nscd.service failed"),
            ],
        )

    def test_unreadable_media_view_is_bad(self):
        self.fx.unzen()
        self.assertIn(
            ("bad", "media views unreadable or not mounted"),
            self.fx.probe("unzen", MEDIA_EXIT="1"),
        )

    def test_storage_failure_latch_stays_visible_after_view_repair(self):
        self.fx.unzen()
        path = self.fx.root / "run" / "media-storage-blocked"
        path.parent.mkdir()
        path.touch()
        self.assertIn(
            (
                "warn",
                "media processing held after storage failure; operator recovery required",
            ),
            self.fx.probe("unzen"),
        )

    def test_missing_config_paths_and_missing_mount_directory(self):
        self.fx.towada()
        path = self.fx.srv / "shores" / "towada" / "03"
        path.rmdir()
        self.assertIn(
            ("bad", f"{path} is missing or not mounted"), self.fx.probe("zao")
        )
        (self.fx.etc / "snapraid-towada.conf").write_text("")
        self.assertIn(
            ("bad", "towada has no configured data/parity paths"), self.fx.probe("zao")
        )

    def test_unmounted_parity_and_wrong_identity(self):
        self.fx.towada()
        path = str(self.fx.srv / "shores" / "towada" / "04")
        self.assertIn(
            ("bad", f"{path} is missing or not mounted"),
            self.fx.probe("zao", UNMOUNTED=path),
        )
        self.assertTrue(
            any(
                "differs from fstab" in message
                for _, message in self.fx.probe("zao", MOUNT_IDENTITY="/dev/wrong")
            )
        )
        self.assertTrue(
            any(
                "identity unavailable" in message
                for _, message in self.fx.probe("zao", EXPECTED_IDENTITY="")
            )
        )

    def test_shared_pool_thresholds_not_cache_fullness(self):
        self.fx.towada()
        for percent, level in (
            ("70", None),
            ("79", None),
            ("80", "warn"),
            ("89", "warn"),
            ("90", "bad"),
        ):
            with self.subTest(percent=percent):
                lines = self.fx.probe("zao", PCENT=percent)
                usage = [
                    row for row in lines if "filesystem" in row[1] and "used" in row[1]
                ]
                self.assertEqual(
                    usage,
                    []
                    if level is None
                    else [(level, f"towada shared cache filesystem {percent}% used")],
                )
                self.assertTrue(
                    any("backlog/protection unknown" in message for _, message in lines)
                )
        self.assertTrue(
            any(
                "usage unavailable" in message
                for _, message in self.fx.probe("zao", DF_EXIT="1")
            )
        )
        self.assertTrue(
            any(
                "usage unavailable" in message
                for _, message in self.fx.probe("zao", PCENT="garbage")
            )
        )

    def test_cache_summary_is_last_batch_not_live_backlog(self):
        import json

        self.fx.towada()
        path = self.fx.root / "state" / "towada" / "status.json"
        path.parent.mkdir(parents=True)
        summary = dict(
            schemaVersion=1,
            observedAt=NOW,
            phase="copied",
            pendingFiles=None,
            pendingBytes=None,
            protectedFiles=12,
            releasedFiles=0,
            lastError=None,
        )
        path.write_text(json.dumps(summary))
        lines = self.fx.probe("zao")
        self.assertIn(
            (
                "warn",
                "towada last batch: copied; protected 12, released 0 files; backlog unknown files / unknown bytes",
            ),
            lines,
        )
        self.assertIn(
            ("warn", "towada automatic source release held; cache can fill"), lines
        )
        summary.update(observedAt=NOW - 129601, lastError="copy_failed")
        path.write_text(json.dumps(summary))
        lines = self.fx.probe("zao")
        self.assertIn(("warn", "towada cache summary stale or clock differs"), lines)
        self.assertIn(("bad", "towada cache mover: copy_failed"), lines)
        summary["pendingBytes"] = "0"
        path.write_text(json.dumps(summary))
        self.assertIn(("warn", "towada cache summary invalid"), self.fx.probe("zao"))
        path.write_text("partial{")
        self.assertIn(("warn", "towada cache summary invalid"), self.fx.probe("zao"))

    def test_sync_scrub_history_missing_unreadable_stale_future(self):
        self.fx.towada()
        for history, expected in (
            ("", "no recorded success"),
            (str(NOW - 337 * 3600), "last success 337 h ago"),
            (str(NOW + 3600), "in the future"),
        ):
            lines = self.fx.probe("zao", HISTORY=history)
            for label in ("sync", "scrub"):
                self.assertTrue(
                    any(
                        label in message and expected in message for _, message in lines
                    ),
                    lines,
                )
        self.assertTrue(
            any(
                "history unreadable" in message
                for _, message in self.fx.probe("zao", HISTORY_EXIT="1")
            )
        )
        self.assertFalse(
            any(
                "last success" in message
                for _, message in self.fx.probe("zao", HISTORY=str(NOW - 36 * 3600))
            )
        )
        self.assertTrue(
            any(
                "sync: last success" in message
                for _, message in self.fx.probe("zao", HISTORY=str(NOW - 36 * 3600 - 1))
            )
        )

    def test_bcachefs_missing_members_state_and_counters(self):
        self.fx.unzen()
        dev = self.fx.fs / UUID / "dev-2"
        (dev / "state").unlink()
        (dev / "io_errors").write_text("unreadable output\n")
        lines = self.fx.probe("unzen")
        self.assertIn(("warn", "bcachefs card.samsung state unreadable"), lines)
        self.assertIn(("warn", "bcachefs card.samsung I/O counters unreadable"), lines)
        shutil.rmtree(dev)
        self.assertIn(
            ("bad", "expected bcachefs member card.samsung missing"),
            self.fx.probe("unzen"),
        )

    def test_bcachefs_lifetime_counters_and_mounted_detection(self):
        self.fx.member(1, "onboard.sn770", "ro", (14, 118, 175))
        self.assertEqual(
            self.fx.probe(),
            [
                ("bad", "bcachefs onboard.sn770 is ro"),
                ("warn", "bcachefs onboard.sn770: 307 I/O errors since creation"),
            ],
        )
        shutil.rmtree(self.fx.fs)
        self.assertIn(
            ("bad", "mounted bcachefs has no readable sysfs probes"),
            self.fx.probe(MOUNT_UUID=UUID),
        )


class Status(unittest.TestCase):
    def run_status(self, output, code=0):
        with tempfile.TemporaryDirectory() as root:
            command(root, "ssh", 'printf "%s" "$OUTPUT"; exit "$EXIT"')
            probe = Path(root) / "probe.sh"
            probe.touch()
            return subprocess.run(
                ["bash", STATUS, str(probe), "simon@unzen"],
                env=dict(
                    os.environ,
                    PATH=root + ":" + os.environ["PATH"],
                    OUTPUT=output,
                    EXIT=str(code),
                    STORAGE_HEALTH_NOW=str(NOW),
                ),
                capture_output=True,
                text=True,
                check=True,
            ).stdout

    def test_valid_completed_sample_keeps_time(self):
        self.assertEqual(
            self.run_status(f"bad\tmover failed\nwarn\tnscd failed\ncomplete\t{NOW}\n"),
            f"unzen\tbad\tmover failed\t{NOW}\nunzen\twarn\tnscd failed\t{NOW}\n",
        )

    def test_partial_failed_junk_and_empty_output_never_green(self):
        for output, code in (
            ("ok\tall checks passed\n", 0),
            (f"ok\tall checks passed\ncomplete\t{NOW}\n", 255),
            (f"ok\tgood\nnoise\ncomplete\t{NOW}\n", 0),
            ("", 0),
            (f"complete\t{NOW}\n", 0),
            (f"complete\t{NOW}\nok\tlate\n", 0),
        ):
            with self.subTest(output=output, code=code):
                self.assertIn("\tunreachable\t", self.run_status(output, code))

    def test_stale_future_and_invalid_timestamps(self):
        for timestamp in (NOW - 121, NOW + 121, "NaN", "123", "1;exit"):
            self.assertIn(
                "\tunreachable\t", self.run_status(f"ok\tgood\ncomplete\t{timestamp}\n")
            )


if __name__ == "__main__":
    PROBE, STATUS = sys.argv[1:3]
    unittest.main(argv=sys.argv[:1], verbosity=2)
