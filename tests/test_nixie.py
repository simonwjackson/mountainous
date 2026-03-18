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


class ParseInvocationTest(unittest.TestCase):
    def test_parse_invocation_enables_online_check_by_default(self):
        invocation = nixie.parse_invocation(["switch", "yari"])
        self.assertTrue(invocation.check_online)

    def test_parse_invocation_allows_disabling_online_check(self):
        invocation = nixie.parse_invocation(["switch", "yari", "--no-check-online"])
        self.assertFalse(invocation.check_online)


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
        self.assertEqual(
            plan.commands[0].argv,
            ("ssh", "usu", "mkdir -p ~/mountainous"),
        )
        self.assertEqual(
            plan.commands[1].argv,
            (
                "rsync",
                "-av",
                "--delete",
                "--exclude",
                ".git",
                "-e",
                "ssh",
                "--rsync-path=/etc/profiles/per-user/nix-on-droid/bin/rsync",
                "./",
                "usu:~/mountainous/",
            ),
        )
        self.assertEqual(plan.commands[2].argv[0:2], ("ssh", "usu"))

    def test_droid_test_aliases_to_switch_with_warning(self):
        plan = nixie.build_droid_plan(
            "test", nixie.ResolvedHost(name="usu", platform="droid")
        )
        self.assertEqual(plan.effective_action, "switch")
        self.assertIn("treating 'test' as 'switch'", plan.warning)

    def test_droid_boot_is_unsupported(self):
        with self.assertRaisesRegex(nixie.NixieError, "does not support action 'boot'"):
            nixie.build_droid_plan("boot", nixie.ResolvedHost(name="usu", platform="droid"))


class OnlineCheckTest(unittest.TestCase):
    def test_switch_and_test_require_online_check(self):
        self.assertTrue(nixie.should_check_online("switch"))
        self.assertTrue(nixie.should_check_online("test"))
        self.assertFalse(nixie.should_check_online("build"))
        self.assertFalse(nixie.should_check_online("boot"))

    def test_preflight_online_hosts_aborts_when_any_host_is_offline(self):
        hosts = (
            nixie.ResolvedHost(name="yari", platform="nixos"),
            nixie.ResolvedHost(name="usu", platform="droid"),
        )
        stdout = io.StringIO()
        with patch.object(
            nixie,
            "check_hosts_online",
            return_value=(
                nixie.HostReachability(host=hosts[0], online=True),
                nixie.HostReachability(host=hosts[1], online=False),
            ),
        ), redirect_stdout(stdout):
            with self.assertRaisesRegex(
                nixie.NixieError,
                "refusing to run switch because some hosts are offline: usu",
            ):
                nixie.preflight_online_hosts("switch", hosts)
        self.assertIn("Checking host reachability...", stdout.getvalue())
        self.assertIn("online: yari", stdout.getvalue())
        self.assertIn("offline: usu", stdout.getvalue())

    def test_preflight_online_hosts_skips_build(self):
        hosts = (nixie.ResolvedHost(name="yari", platform="nixos"),)
        with patch.object(nixie, "check_hosts_online") as check_hosts_online:
            nixie.preflight_online_hosts("build", hosts)
        check_hosts_online.assert_not_called()


class ExecutionTest(unittest.TestCase):
    def test_execute_invocation_runs_hosts_in_order(self):
        hosts = (
            nixie.ResolvedHost(name="yari", platform="nixos"),
            nixie.ResolvedHost(name="usu", platform="droid"),
        )
        plans = (
            nixie.HostPlan(
                host=hosts[0],
                requested_action="build",
                effective_action="build",
                commands=(),
            ),
            nixie.HostPlan(
                host=hosts[1],
                requested_action="build",
                effective_action="build",
                commands=(),
            ),
        )
        seen = []
        with patch.object(nixie, "resolve_hosts", return_value=hosts), patch.object(
            nixie, "preflight_online_hosts"
        ) as preflight_online_hosts, patch.object(
            nixie, "build_plans", return_value=plans
        ), patch.object(
            nixie, "execute_plan", side_effect=lambda plan: seen.append(plan.host.name)
        ):
            nixie.execute_invocation(nixie.Invocation(action="build", hosts=("yari", "usu")))
        preflight_online_hosts.assert_called_once_with("build", hosts)
        self.assertEqual(seen, ["yari", "usu"])

    def test_execute_invocation_skips_preflight_when_disabled(self):
        hosts = (nixie.ResolvedHost(name="yari", platform="nixos"),)
        plans = (
            nixie.HostPlan(
                host=hosts[0],
                requested_action="switch",
                effective_action="switch",
                commands=(),
            ),
        )
        with patch.object(nixie, "resolve_hosts", return_value=hosts), patch.object(
            nixie, "preflight_online_hosts"
        ) as preflight_online_hosts, patch.object(
            nixie, "build_plans", return_value=plans
        ), patch.object(nixie, "execute_plan"):
            nixie.execute_invocation(
                nixie.Invocation(action="switch", hosts=("yari",), check_online=False)
            )
        preflight_online_hosts.assert_not_called()

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
        self.assertIn(
            "warning: droid host 'usu' does not support a separate test mode",
            stderr.getvalue(),
        )
        self.assertIn("+ python3 -c", stdout.getvalue())


if __name__ == "__main__":
    unittest.main()
