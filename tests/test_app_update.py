import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "app_update", Path(__file__).parents[1] / "scripts/app-update.py"
)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class AppUpdateTests(unittest.TestCase):
    def test_original_ref_tracks_branch_not_old_revision(self):
        self.assertEqual(
            updater.input_ref(
                {
                    "type": "github",
                    "owner": "a",
                    "repo": "b",
                    "ref": "main",
                    "rev": "old",
                }
            ),
            "github:a/b/main",
        )

    def test_unknown_transport_is_rejected(self):
        with self.assertRaises(ValueError):
            updater.input_ref({"type": "path"})

    def test_no_version_downgrade(self):
        with self.assertRaises(ValueError):
            updater.require_not_downgrade(
                {"version": "2", "lastModified": 1},
                {"version": "1", "lastModified": 2},
                lambda a, b: int(a) - int(b),
            )

    def test_no_revision_downgrade(self):
        with self.assertRaises(ValueError):
            updater.require_not_downgrade(
                {"version": "1", "lastModified": 2},
                {"version": "2", "lastModified": 1},
                lambda a, b: int(a) - int(b),
            )

    def test_same_revision_can_retry_failed_hosts(self):
        release = {"version": "1", "lastModified": 2}
        updater.require_not_downgrade(release, release, lambda a, b: 0)

    def test_failure_does_not_skip_later_hosts(self):
        def command(host):
            subprocess.run(
                ["sh", "-c", "exit 1" if host == "offline" else "exit 0"], check=True
            )

        results = updater.deploy_hosts(["before", "offline", "after"], command)
        self.assertEqual(
            [results[h]["status"] for h in results], ["deployed", "failed", "deployed"]
        )

    def test_builds_are_bounded_and_do_not_delegate(self):
        command = updater.build_command(
            "x86_64-linux", ".#checks.x86_64-linux.app-pi", []
        )
        self.assertIn("2", command[command.index("--max-jobs") + 1 :])
        self.assertEqual(
            command[command.index("--option") + 1 : command.index("--option") + 3],
            ["builders", ""],
        )
        self.assertNotIn("--store", command)

    def test_arm_refuses_unprovisioned_native_build_transport(self):
        with self.assertRaisesRegex(ValueError, "Native target build transport"):
            updater.build_command("aarch64-linux", ".#checks.aarch64-linux.app-pi", [])

    def test_native_transport_realizes_on_yari_then_fetches_for_signing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "commands.jsonl"
            executable = root / "transport"
            executable.write_text(
                "#!/usr/bin/env python3\n"
                + "import json, os, sys\n"
                + "with open(os.environ['COMMAND_LOG'], 'a') as log: log.write(json.dumps([sys.argv, os.environ.get('NIX_SSHOPTS')]) + '\\n')\n"
                + "if sys.argv[1] == 'eval': print('/nix/store/' + 'a' * 32 + '-candidate.drv')\n"
                + "elif os.path.basename(sys.argv[0]) == 'ssh': print('/nix/store/' + 'b' * 32 + '-candidate')\n"
            )
            executable.chmod(0o755)
            (root / "nix").symlink_to(executable)
            (root / "ssh").symlink_to(executable)
            env = os.environ | {
                "PATH": str(root) + os.pathsep + os.environ["PATH"],
                "COMMAND_LOG": str(log),
            }

            def run(command, timeout=3600, env=None):
                return subprocess.run(
                    command,
                    env=env or environment,
                    timeout=timeout,
                    text=True,
                    capture_output=True,
                    check=True,
                ).stdout.strip()

            environment = env
            transport = {
                "privateKey": "/private/builder",
                "alias": "yari",
                "knownHosts": "/known-hosts",
                "hostName": "yari.example",
            }
            # native_build inherits the caller's environment for copy transports.
            previous = {k: os.environ.get(k) for k in ("PATH", "COMMAND_LOG")}
            os.environ.update({k: env[k] for k in previous})
            try:
                output = updater.native_build(
                    ".#checks.aarch64-linux.app-openclaw",
                    ["--no-write-lock-file"],
                    transport,
                    run,
                )
            finally:
                for key, value in previous.items():
                    if value is None:
                        os.environ.pop(key, None)
                    else:
                        os.environ[key] = value
            commands = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(len(commands), 4)
            self.assertIn("--derivation", commands[1][0])
            self.assertIn("ssh-ng://simon@yari.example", commands[1][0])
            self.assertIn("-F /dev/null", commands[1][1])
            self.assertIn("StrictHostKeyChecking=yes", commands[1][1])
            self.assertEqual(
                commands[2][0][-1],
                "app-native-build /nix/store/" + "a" * 32 + "-candidate.drv",
            )
            self.assertIn("--no-check-sigs", commands[3][0])
            self.assertEqual(output, "/nix/store/" + "b" * 32 + "-candidate")

    def test_native_transport_rejects_invalid_derivation_before_ssh(self):
        calls = []

        def run(command, **kwargs):
            calls.append(command)
            return "/nix/store/invalid;systemctl reboot"

        with self.assertRaisesRegex(ValueError, "Invalid native build derivation"):
            updater.native_build(".#candidate", [], {}, run)
        self.assertEqual(len(calls), 1)

    def test_native_ssh_gate_restricts_commands_and_disables_builder_hops(self):
        spec = importlib.util.spec_from_file_location(
            "native", Path(__file__).parents[1] / "scripts/app-native-build.py"
        )
        native = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(native)
        drv = "/nix/store/" + "a" * 32 + "-candidate.drv"
        command = native.command("app-native-build " + drv, "/nix/bin")
        self.assertEqual(
            command,
            [
                "/nix/bin/nix-store",
                "--realise",
                drv,
                "--max-jobs",
                "2",
                "--cores",
                "4",
                "--option",
                "builders",
                "",
            ],
        )
        self.assertEqual(
            native.command("nix-daemon --stdio", "/nix/bin"),
            ["/nix/bin/nix-daemon", "--stdio"],
        )
        for denied in (
            "",
            "bash",
            "nix-store --realise " + drv,
            "app-native-build " + drv + "; reboot",
            "app-native-build " + drv + " --option builders ssh://fuji",
            "nixos-rebuild switch",
        ):
            with self.subTest(denied=denied), self.assertRaises(ValueError):
                native.command(denied, "/nix/bin")

    def test_arm_cli_dry_run_deployment_and_build_failure_receipts(self):
        for mode in ("check-only", "deploy", "native-failure"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                repo = root / "repository"
                repo.mkdir()
                locked = {
                    "root": "root",
                    "nodes": {
                        "root": {"inputs": {"nix-openclaw": "upstream"}},
                        "upstream": {
                            "original": {"type": "github", "owner": "a", "repo": "b"},
                            "locked": {"lastModified": 1},
                        },
                    },
                }
                (repo / "flake.lock").write_text(json.dumps(locked))
                for args in (
                    ["init", "-q"],
                    ["add", "."],
                    [
                        "-c",
                        "user.name=Test",
                        "-c",
                        "user.email=test@example.invalid",
                        "commit",
                        "-qm",
                        "fixture",
                    ],
                ):
                    subprocess.run(
                        ["git", *args], cwd=repo, check=True, capture_output=True
                    )
                config = {
                    "stateDirectory": str(root),
                    "apps": {
                        "openclaw": {
                            "input": "nix-openclaw",
                            "hosts": ["yari"],
                            "checks": ["openclaw", "openclaw-config"],
                        }
                    },
                    "hosts": {"yari": "aarch64-linux"},
                    "nativeBuilders": {
                        "aarch64-linux": {
                            "privateKey": "/private/builder",
                            "alias": "yari",
                            "hostName": "yari.example",
                            "knownHosts": "/known-hosts",
                        }
                    },
                }
                config_path = root / "config.json"
                config_path.write_text(json.dumps(config))
                executable = root / "transport"
                executable.write_text("""#!/usr/bin/env python3
import json, os, sys
name = os.path.basename(sys.argv[0])
args = sys.argv[1:]
with open(os.environ['COMMAND_LOG'], 'a') as log:
    log.write(json.dumps([name, *args]) + '\\n')
if name == 'ssh':
    if os.environ['BEHAVIOR'] == 'native-failure': sys.exit(1)
    print('/nix/store/' + 'b' * 32 + '-candidate')
elif name == 'nix':
    if args[:2] == ['flake', 'metadata']:
        print(json.dumps({'locked': {'rev':'new', 'lastModified':2}, 'url':'github:a/b/new'}))
    elif args[0] == 'eval':
        if '--expr' in args: print('0')
        elif args[1].endswith('.version'): print('1.0')
        elif args[1].endswith('.drvPath'): print('/nix/store/' + 'a' * 32 + '-candidate.drv')
""")
                executable.chmod(0o755)
                for name in ("nix", "ssh", "deploy"):
                    (root / name).symlink_to(executable)
                log = root / "commands.jsonl"
                env = os.environ | {
                    "PATH": str(root) + os.pathsep + os.environ["PATH"],
                    "COMMAND_LOG": str(log),
                    "BEHAVIOR": mode,
                }
                command = [
                    "python3",
                    str(Path(updater.__file__)),
                    "--config",
                    str(config_path),
                    "--app",
                    "openclaw",
                ]
                if mode == "check-only":
                    command.append("--check-only")
                result = subprocess.run(
                    command, env=env, text=True, capture_output=True
                )
                self.assertEqual(
                    result.returncode,
                    1 if mode == "native-failure" else 0,
                    result.stdout + result.stderr,
                )
                receipt = json.loads(
                    next((root / "receipts").glob("*.json")).read_text()
                )
                self.assertFalse(receipt["system_deployment"])
                self.assertEqual(
                    receipt["status"],
                    {
                        "check-only": "checks-passed",
                        "deploy": "deployed",
                        "native-failure": "partial-failure",
                    }[mode],
                )
                commands = [json.loads(line) for line in log.read_text().splitlines()]
                signed = [c for c in commands if c[:3] == ["nix", "store", "sign"]]
                deployed = [c for c in commands if c[0] == "deploy"]
                self.assertEqual(bool(signed), mode == "deploy")
                self.assertEqual(bool(deployed), mode == "deploy")
                self.assertEqual(
                    (root / "accepted-openclaw.json").exists(), mode == "deploy"
                )
                if mode != "native-failure":
                    checked = [
                        c[2]
                        for c in commands
                        if c[:2] == ["nix", "eval"] and c[2].endswith(".drvPath")
                    ]
                    self.assertEqual(
                        checked[:4],
                        [
                            ".#checks.aarch64-linux." + name + ".drvPath"
                            for name in (
                                "app-openclaw",
                                "openclaw",
                                "openclaw-config",
                                "deploy-schema",
                            )
                        ],
                    )
                if deployed:
                    self.assertIn("--checksigs", deployed[0])
                    self.assertIn("--skip-checks", deployed[0])
                    self.assertIn("--auto-rollback", deployed[0])
                    self.assertIn("--magic-rollback", deployed[0])

    def test_receipt_is_private_and_atomic(self):
        import os

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.json"
            previous = os.umask(0o077)
            try:
                updater.write_json(path, {"rev": "accepted"})
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                self.assertEqual(updater.read_json(path)["rev"], "accepted")
                self.assertFalse(path.with_suffix(".tmp").exists())
            finally:
                os.umask(previous)


if __name__ == "__main__":
    unittest.main()
