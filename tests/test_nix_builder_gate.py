"""Tests for modules/nix-builder-gate.py. Usage: python3 test_nix_builder_gate.py GATE

Fake `ip` and `ping` commands on PATH stand in for the network. Temporary
folders stand in for /sys/class/power_supply, /proc, /var/lib and /run.
"""

import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

GATE = Path(sys.argv.pop(1)).resolve()
HOME = "aa:bb:cc:dd:ee:01"
CAFE = "aa:bb:cc:dd:ee:99"


class Gate(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("ip", "ping"):
            script = self.bin / name
            script.write_text(
                "#!/bin/sh\n"
                f'[ "$(basename "$0")" = ping ] && {{ cp "{self.root}/arp-after-ping" "{self.root}/arp" 2>/dev/null; exit 0; }}\n'
                f'case "$*" in *route*) cat "{self.root}/route";; *neigh*) cat "{self.root}/arp" 2>/dev/null;; esac\n'
            )
            script.chmod(script.stat().st_mode | stat.S_IEXEC)
        (self.root / "power" / "AC").mkdir(parents=True)
        (self.root / "power" / "AC" / "type").write_text("Mains\n")
        (self.root / "power" / "BAT1").mkdir()
        (self.root / "power" / "BAT1" / "type").write_text("Battery\n")
        (self.root / "proc").mkdir()
        (self.root / "config.json").write_text(json.dumps({"mode": "home", "homeMacs": [HOME.upper()]}))
        self.network(HOME)
        self.power(True)

    def tearDown(self):
        shutil.rmtree(self.root)

    def network(self, mac, metric_routes=None):
        if mac is None:
            (self.root / "route").write_text("")
            (self.root / "arp").write_text("")
            return
        (self.root / "route").write_text(
            metric_routes or "default via 192.168.1.1 dev eth0 proto dhcp src 192.168.1.5 metric 100\n"
        )
        (self.root / "arp").write_text(f"192.168.1.1 lladdr {mac} REACHABLE\n")

    def power(self, mains):
        (self.root / "power" / "AC" / "online").write_text("1\n" if mains else "0\n")

    def gate(self, *args, expect=0):
        env = dict(os.environ)
        env.update(
            PATH=f"{self.bin}:{env['PATH']}",
            NIX_BUILDER_GATE_CONFIG=str(self.root / "config.json"),
            NIX_BUILDER_GATE_STATE=str(self.root / "state"),
            NIX_BUILDER_GATE_RUN=str(self.root / "run"),
            NIX_BUILDER_GATE_POWER=str(self.root / "power"),
            NIX_BUILDER_GATE_PROC=str(self.root / "proc"),
            NIX_BUILDER_GATE_DAEMON="true",
        )
        result = subprocess.run([sys.executable, str(GATE), *args], capture_output=True, text=True, env=env)
        self.assertEqual(result.returncode, expect, result.stderr)
        return result

    def status(self):
        state = json.loads(self.gate("status", "--json").stdout)
        on_disk = json.loads((self.root / "run" / "state.json").read_text())
        self.assertEqual(state, on_disk)
        return state

    def test_home_on_mains_accepts(self):
        state = self.status()
        self.assertEqual((state["accepting"], state["reason"], state["location"]), (True, "home", "home"))

    def test_home_on_battery_refuses(self):
        self.power(False)
        state = self.status()
        self.assertEqual((state["accepting"], state["reason"], state["power"]), (False, "battery", "battery"))

    def test_away_refuses_even_on_mains(self):
        self.network(CAFE)
        self.assertEqual(self.status()["reason"], "away")

    def test_no_route_refuses(self):
        self.network(None)
        state = self.status()
        self.assertEqual((state["accepting"], state["reason"], state["location"]), (False, "no-network", "unknown"))

    def test_lowest_metric_route_decides(self):
        self.network(HOME, "default via 10.0.0.1 dev wlo1 metric 600\ndefault via 192.168.1.1 dev eth0 metric 100\n")
        self.assertEqual(self.status()["location"], "home")

    def test_missing_arp_entry_is_resolved_by_one_ping(self):
        (self.root / "arp").write_text("")
        (self.root / "arp-after-ping").write_text(f"192.168.1.1 lladdr {HOME} REACHABLE\n")
        self.assertEqual(self.status()["location"], "home")

    def test_choice_off_at_home_lasts_until_another_network(self):
        self.gate("set", "off")
        self.assertEqual(self.status()["reason"], "choice-off")
        # Losing the network does not clear it.
        self.network(None)
        self.assertEqual(self.status()["reason"], "choice-off")
        self.network(HOME)
        self.assertEqual(self.status()["reason"], "choice-off")
        # A different router clears it; back home the default applies again.
        self.network(CAFE)
        self.assertEqual(self.status()["reason"], "away")
        self.network(HOME)
        self.assertEqual(self.status()["reason"], "home")

    def test_choice_on_away_lasts_until_another_network(self):
        self.network(CAFE)
        self.gate("set", "on")
        state = self.status()
        self.assertEqual((state["accepting"], state["reason"], state["location"]), (True, "choice-on", "away"))
        self.network("aa:bb:cc:dd:ee:77")
        self.assertEqual(self.status()["reason"], "away")

    def test_choice_on_beats_battery_and_power_changes_keep_it(self):
        self.power(False)
        self.gate("set", "on")
        self.assertTrue(self.status()["accepting"])
        self.power(True)
        self.assertEqual(self.status()["reason"], "choice-on")

    def test_set_default_clears_the_choice(self):
        self.gate("set", "off")
        self.gate("set", "default")
        state = self.status()
        self.assertEqual((state["reason"], state["choice"]), ("home", None))

    def test_serve_refuses_and_records_no_session(self):
        self.network(CAFE)
        result = self.gate("serve", expect=1)
        self.assertIn("away", result.stderr)
        self.assertFalse((self.root / "run" / "sessions").exists())

    def test_serve_accepts_and_execs_the_daemon(self):
        self.gate("serve")  # NIX_BUILDER_GATE_DAEMON=true exits 0
        self.assertEqual(len(list((self.root / "run" / "sessions").glob("*"))), 1)

    def test_running_counts_only_live_daemon_sessions(self):
        sessions = self.root / "run" / "sessions"
        sessions.mkdir(parents=True)
        for pid, cmdline in (("101", b"/nix/store/x-nix/bin/nix\0daemon\0--stdio\0"), ("102", b"bash\0")):
            (self.root / "proc" / pid).mkdir()
            (self.root / "proc" / pid / "cmdline").write_bytes(cmdline)
            (sessions / pid).touch()
        (sessions / "103").touch()  # gone
        self.assertEqual(self.status()["running"], 1)
        self.assertEqual(sorted(p.name for p in sessions.glob("*")), ["101"])

    def test_always_mode_ignores_network_and_power(self):
        (self.root / "config.json").write_text(json.dumps({"mode": "always"}))
        self.network(None)
        self.power(False)
        state = self.status()
        self.assertEqual((state["accepting"], state["reason"]), (True, "always"))

    def test_unknown_command_fails(self):
        self.gate("set", "maybe", expect=2)


if __name__ == "__main__":
    unittest.main(verbosity=1)
