"""modules/storage-health-probe.sh and storage-health-status.sh.

The fixtures copy Zao's and Unzen's real output of 2026-10-19: Zao's towada
pool with its NVMe cache, and Unzen's bcachefs members in sysfs.
Run: python3 tests/test_storage_health.py PROBE STATUS
"""

import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

PROBE = STATUS = None
NOW = 1_760_860_000


def stub(directory, name, body):
    path = os.path.join(directory, name)
    # The Nix build sandbox has no /usr/bin/env.
    with open(path, "w") as handle:
        handle.write(f"#!{shutil.which('bash')}\n" + textwrap.dedent(body))
    os.chmod(path, 0o755)


class Fixture:
    """A fake root and PATH for one probe run."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.bin = os.path.join(self.root, "bin")
        os.makedirs(self.bin)
        self.env = dict(
            os.environ,
            PATH=self.bin + ":" + os.environ["PATH"],
            STORAGE_HEALTH_ETC=os.path.join(self.root, "etc"),
            STORAGE_HEALTH_SRV=os.path.join(self.root, "srv"),
            STORAGE_HEALTH_BCACHEFS=os.path.join(self.root, "bcachefs"),
            STORAGE_HEALTH_NOW=str(NOW),
            FAKE_FAILED="",
            FAKE_UNMOUNTED="",
            FAKE_FINISHED="",
            FAKE_PCENT="40",
        )
        os.makedirs(self.env["STORAGE_HEALTH_ETC"])
        stub(self.bin, "systemctl", 'printf "%s" "$FAKE_FAILED"\n')
        stub(
            self.bin,
            "mountpoint",
            'for d in $FAKE_UNMOUNTED; do [ "${!#}" = "$d" ] && exit 1; done; exit 0\n',
        )
        stub(
            self.bin,
            "journalctl",
            """\
            for t in $FAKE_FINISHED; do
              echo "$t.123456 zao systemd[1]: Finished SnapRAID Sync for towada."
            done
            """,
        )
        stub(self.bin, "df", 'printf "Use%%\\n %s%%\\n" "$FAKE_PCENT"\n')

    def towada(self, disks=("00", "01", "02", "03", "04")):
        with open(os.path.join(self.env["STORAGE_HEALTH_ETC"], "snapraid-towada.conf"), "w"):
            pass
        for disk in disks:
            os.makedirs(os.path.join(self.env["STORAGE_HEALTH_SRV"], "shores", "towada", disk))
        os.makedirs(os.path.join(self.env["STORAGE_HEALTH_SRV"], "cache", "towada"))

    def bcachefs_member(self, number, label, state, errors=(0, 0, 0)):
        dev = os.path.join(self.env["STORAGE_HEALTH_BCACHEFS"], "e5f61013", f"dev-{number}")
        os.makedirs(dev)
        with open(os.path.join(dev, "label"), "w") as handle:
            handle.write(label + "\n")
        states = ["rw", "ro", "evacuating", "spare"]
        with open(os.path.join(dev, "state"), "w") as handle:
            handle.write(" ".join(f"[{s}]" if s == state else s for s in states) + " \n")
        read, write, checksum = errors
        block = f"  read:    {read}\n  write:   {write}\n  checksum:{checksum}\n"
        with open(os.path.join(dev, "io_errors"), "w") as handle:
            # The second block counts since the last reset; only the first counts.
            handle.write("IO errors since filesystem creation\n" + block)
            handle.write("IO errors since 8 y ago\n" + block.replace(str(read), "99", 1))

    def probe(self, **env):
        result = subprocess.run(
            ["bash", PROBE],
            env=dict(self.env, **env),
            capture_output=True,
            text=True,
            check=True,
        )
        return [tuple(line.split("\t")) for line in result.stdout.splitlines()]


class Probe(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.addCleanup(self.fx.tmp.cleanup)

    def test_healthy_pool_reports_ok(self):
        self.fx.towada()
        lines = self.fx.probe(FAKE_FINISHED=str(NOW - 3600))
        self.assertEqual(lines, [("ok", "all checks passed")])

    def test_no_pool_and_no_bcachefs_reports_ok(self):
        self.assertEqual(self.fx.probe(), [("ok", "all checks passed")])

    def test_failed_storage_unit_is_bad_and_other_unit_is_warn(self):
        failed = (
            "media-library-mover@low-space.service loaded failed failed Handoff\n"
            "nscd.service loaded failed failed Name Service Cache Daemon (nsncd)\n"
        )
        self.assertEqual(
            self.fx.probe(FAKE_FAILED=failed),
            [
                ("bad", "media-library-mover@low-space.service failed"),
                ("warn", "nscd.service failed"),
            ],
        )

    def test_unmounted_disk_stale_sync_and_full_cache(self):
        self.fx.towada()
        shore = os.path.join(self.fx.env["STORAGE_HEALTH_SRV"], "shores", "towada", "03")
        lines = self.fx.probe(
            FAKE_UNMOUNTED=shore,
            FAKE_FINISHED=f"{NOW - 90 * 3600} {NOW - 50 * 3600}",
            FAKE_PCENT="78",
        )
        self.assertEqual(
            lines,
            [
                ("bad", "towada disk 03 is not mounted"),
                ("bad", "towada: last SnapRAID sync 50 h ago"),
                ("bad", "towada NVMe cache 78% full, no parity"),
            ],
        )

    def test_sync_at_the_limit_passes_and_one_hour_over_fails(self):
        self.fx.towada()
        self.assertEqual(
            self.fx.probe(FAKE_FINISHED=str(NOW - 36 * 3600)),
            [("ok", "all checks passed")],
        )
        self.assertEqual(
            self.fx.probe(FAKE_FINISHED=str(NOW - 37 * 3600)),
            [("bad", "towada: last SnapRAID sync 37 h ago")],
        )

    def test_missing_sync_history_is_bad(self):
        self.fx.towada()
        self.assertEqual(
            self.fx.probe(),
            [("bad", "towada: no successful SnapRAID sync in 7 days")],
        )

    def test_cache_thresholds(self):
        self.fx.towada()
        recent = str(NOW - 3600)
        cases = {"59": [], "60": ["warn"], "74": ["warn"], "75": ["bad"]}
        for pcent, levels in cases.items():
            lines = self.fx.probe(FAKE_FINISHED=recent, FAKE_PCENT=pcent)
            got = [level for level, _ in lines if level != "ok"]
            self.assertEqual(got, levels, pcent)

    def test_bcachefs_member_state_and_lifetime_errors(self):
        self.fx.bcachefs_member(1, "onboard.sn770", "rw")
        self.fx.bcachefs_member(2, "card.samsung", "ro")
        self.fx.bcachefs_member(3, "card.sabrent", "rw", errors=(14, 118, 175))
        self.assertEqual(
            self.fx.probe(),
            [
                ("bad", "bcachefs card.samsung is ro"),
                ("warn", "bcachefs card.sabrent: 307 I/O errors since creation"),
            ],
        )


class Status(unittest.TestCase):
    def test_hosts_in_order_with_unreachable_and_junk_dropped(self):
        with tempfile.TemporaryDirectory() as root:
            stub(
                root,
                "ssh",
                """\
                target=${@: -3:1}
                case "$target" in
                  simon@unzen) printf 'bad\\tmover failed\\nnoise line\\nwarn\\tnscd failed\\n' ;;
                  simonwjackson@zao) printf 'ok\\tall checks passed\\n' ;;
                  *) exit 255 ;;
                esac
                """,
            )
            probe = os.path.join(root, "probe.sh")
            open(probe, "w").close()
            result = subprocess.run(
                ["bash", STATUS, probe, "simonwjackson@zao", "simon@unzen", "x@gone"],
                env=dict(os.environ, PATH=root + ":" + os.environ["PATH"]),
                capture_output=True,
                text=True,
                check=True,
            )
        self.assertEqual(
            result.stdout.splitlines(),
            [
                "zao\tok\tall checks passed",
                "unzen\tbad\tmover failed",
                "unzen\twarn\tnscd failed",
                "gone\tunreachable\tno answer over SSH (exit 255)",
            ],
        )


if __name__ == "__main__":
    PROBE, STATUS = sys.argv[1], sys.argv[2]
    unittest.main(argv=sys.argv[:1], verbosity=2)
