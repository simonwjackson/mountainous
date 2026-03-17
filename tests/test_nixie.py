import io
import pathlib
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from packages.nixie import nixie


class ParseHostsTest(unittest.TestCase):
    def test_parse_hosts_accepts_comma_separated_list(self):
        self.assertEqual(nixie.parse_hosts("yari,fuji,usu"), ("yari", "fuji", "usu"))

    def test_parse_hosts_rejects_empty_entries(self):
        with self.assertRaises(Exception):
            nixie.parse_hosts("yari,,usu")


class ResolveHostsTest(unittest.TestCase):
    def test_resolve_host_prefers_flake_outputs(self):
        flake_hosts = nixie.FlakeHosts(nixos=frozenset({"yari"}), droid=frozenset({"usu"}))
        self.assertEqual(
            nixie.resolve_host("yari", flake_hosts),
            nixie.ResolvedHost(name="yari", platform="nixos"),
        )
        self.assertEqual(
            nixie.resolve_host("usu", flake_hosts),
            nixie.ResolvedHost(name="usu", platform="droid"),
        )

    def test_resolve_host_errors_for_unknown_host(self):
        flake_hosts = nixie.FlakeHosts(nixos=frozenset({"yari"}), droid=frozenset())
        with self.assertRaisesRegex(nixie.NixieError, "unknown host 'fuji'"):
            nixie.resolve_host("fuji", flake_hosts)


class PlanGenerationTest(unittest.TestCase):
    def test_nixos_plan_uses_canonical_command_shape(self):
        plan = nixie.build_nixos_plan(
            "switch", nixie.ResolvedHost(name="yari", platform="nixos")
        )
        self.assertEqual(
            plan.commands[0].argv,
            (
                "nixos-rebuild",
                "switch",
                "--flake",
                ".#yari",
                "--build-host",
                "yari",
                "--target-host",
                "yari",
                "--sudo",
            ),
        )

    def test_droid_switch_plan_hardens_transport(self):
        plan = nixie.build_droid_plan(
            "switch", nixie.ResolvedHost(name="usu", platform="droid")
        )
        self.assertEqual(plan.commands[0].argv, ("ssh", "-F", "/dev/null", "usu", "mkdir -p ~/mountainous"))
        self.assertEqual(
            plan.commands[1].argv,
            (
                "rsync",
                "-av",
                "--delete",
                "--exclude",
                ".git",
                "-e",
                "ssh -F /dev/null",
                "--rsync-path=/etc/profiles/per-user/nix-on-droid/bin/rsync",
                "./",
                "usu:~/mountainous/",
            ),
        )
        self.assertEqual(plan.commands[2].argv[0:4], ("ssh", "-F", "/dev/null", "usu"))

    def test_droid_test_aliases_to_switch_with_warning(self):
        plan = nixie.build_droid_plan(
            "test", nixie.ResolvedHost(name="usu", platform="droid")
        )
        self.assertEqual(plan.effective_action, "switch")
        self.assertIn("treating 'test' as 'switch'", plan.warning)

    def test_droid_boot_is_unsupported(self):
        with self.assertRaisesRegex(nixie.NixieError, "does not support action 'boot'"):
            nixie.build_droid_plan("boot", nixie.ResolvedHost(name="usu", platform="droid"))


class ExecutionTest(unittest.TestCase):
    def test_execute_invocation_runs_hosts_in_order(self):
        seen = []
        with patch.object(
            nixie,
            "plan_commands",
            return_value=(
                nixie.HostPlan(
                    host=nixie.ResolvedHost(name="yari", platform="nixos"),
                    requested_action="build",
                    effective_action="build",
                    commands=(),
                ),
                nixie.HostPlan(
                    host=nixie.ResolvedHost(name="usu", platform="droid"),
                    requested_action="build",
                    effective_action="build",
                    commands=(),
                ),
            ),
        ), patch.object(nixie, "execute_plan", side_effect=lambda plan: seen.append(plan.host.name)):
            nixie.execute_invocation(nixie.Invocation(action="build", hosts=("yari", "usu")))
        self.assertEqual(seen, ["yari", "usu"])

    def test_execute_plan_prints_warning_and_fails_fast(self):
        plan = nixie.HostPlan(
            host=nixie.ResolvedHost(name="usu", platform="droid"),
            requested_action="test",
            effective_action="switch",
            commands=(
                nixie.PlannedCommand(("python3", "-c", "pass")),
                nixie.PlannedCommand(("python3", "-c", "import sys; sys.exit(9)")),
            ),
            warning="droid host 'usu' does not support a separate test mode; treating 'test' as 'switch'",
        )
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            with self.assertRaisesRegex(nixie.NixieError, "host 'usu' action 'test' failed"):
                nixie.execute_plan(plan)
        self.assertIn("warning: droid host 'usu' does not support a separate test mode", stderr.getvalue())
        self.assertIn("+ python3 -c", stdout.getvalue())


if __name__ == "__main__":
    unittest.main()
