"""Real files/subprocesses; no service-control replacements or private host reads."""

import ast
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import shutil
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "cutover", ROOT / "scripts/federation_cutover.py"
)
cutover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutover)


class CutoverEvidenceTests(unittest.TestCase):
    def test_approved_operation_needs_no_historical_client_credentials(self):
        values = {
            name: "1" * 64
            for name in (
                "event-sha256",
                "template-sha256",
                "device",
                "old-event",
                "new-owner",
                "new-event",
                "verification-device",
                "verification-event",
                "verification-event-sha256",
            )
        }
        for name in (
            "old",
            "old-bundle",
            "candidate",
            "candidate-bundle",
            "recovery",
            "recovery-bundle",
            "previous-bundle",
            "booted",
            "old-binding",
            "event",
            "template",
            "verification-client-root",
        ):
            values[name] = "/explicit/" + name
        values.update(
            {"host-uuid": "6832F97F-A2D5-C30B-2B1C-1D4E31150449", "grants": "1"}
        )
        argv = [
            "run",
            *[part for key, value in values.items() for part in ("--" + key, value)],
        ]
        result = cutover.arguments(argv)
        self.assertEqual(
            result.verification_client_root, values["verification-client-root"]
        )
        self.assertNotIn("retired_client_key", vars(result))
        self.assertEqual(result.host_uuid, values["host-uuid"])
        index = argv.index("--host-uuid") + 1
        for valid in (
            values["host-uuid"].lower(),
            "6832F97f-A2d5-C30B-2b1C-1D4e31150449",
        ):
            changed = argv.copy()
            changed[index] = valid
            self.assertEqual(cutover.arguments(changed).host_uuid, valid)
        for invalid in (
            "",
            "-" * 36,
            "a" * 36,
            "6832F97F-A2D5-C30B-2B1C-1D4E3115044Z",
            "6832F97FA2D5-C30B-2B1C-1D4E31150449-",
            "{6832F97F-A2D5-C30B-2B1C-1D4E31150449}",
            values["host-uuid"] + "\n",
            values["host-uuid"] + "\x00",
        ):
            changed = argv.copy()
            changed[index - 1 : index + 1] = ["--host-uuid=" + invalid]
            with self.subTest(invalid=invalid), self.assertRaises(cutover.Refusal):
                cutover.arguments(changed)
        for override in (
            "--accept",
            "--skip-provision",
            "--defer-old-client",
            "--retired-client-key",
        ):
            with self.subTest(override=override), self.assertRaises(SystemExit):
                cutover.arguments([*argv, override])

    def test_temporary_certificate_never_allows_unexplained_client_membership(self):
        client = {
            "name": "temporary",
            "uuid": "test-client",
            "cert": "temporary-certificate",
        }
        document = {"root": {"uniqueid": "host", "named_devices": [client]}}
        cutover.temporary_membership(
            json.dumps(document), "temporary-certificate", "host"
        )
        for changed in (
            {"root": {"uniqueid": "other", "named_devices": [client]}},
            {"root": {"uniqueid": "host", "named_devices": []}},
            {"root": {"uniqueid": "host", "named_devices": [client, client]}},
            {
                "root": {
                    "uniqueid": "host",
                    "named_devices": [{**client, "cert": "unrelated"}],
                }
            },
            {
                "root": {
                    "uniqueid": "host",
                    "named_devices": [client],
                    "devices": [{"certs": ["legacy"]}],
                }
            },
        ):
            with self.subTest(changed=changed), self.assertRaises(cutover.Refusal):
                cutover.temporary_membership(
                    json.dumps(changed), "temporary-certificate", "host"
                )

    def test_host_uuid_membership_comparison_preserves_exact_case(self):
        host = "6832F97F-A2D5-C30B-2B1C-1D4E31150449"
        raw = json.dumps(
            {
                "root": {
                    "uniqueid": host,
                    "named_devices": [
                        {"name": "temporary", "uuid": "client", "cert": "certificate"}
                    ],
                }
            }
        )
        cutover.temporary_membership(raw, "certificate", host)
        with self.assertRaises(cutover.Refusal):
            cutover.temporary_membership(raw, "certificate", host.lower())

    def test_sunshine_state_read_keeps_private_file_checks(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sunshine_state.json"
            path.write_bytes(b'{"root":{"uniqueid":"host"}}')
            path.chmod(0o600)
            raw, receipt = cutover.sunshine_state_evidence(path)
            self.assertEqual(raw, path.read_bytes())
            self.assertEqual((receipt["uid"], receipt["gid"]), (1000, 100))
            path.chmod(0o640)
            with self.assertRaises(cutover.Refusal):
                cutover.sunshine_state_evidence(path)
            path.chmod(0o600)
            link = path.with_name("link")
            link.symlink_to(path)
            with self.assertRaises(OSError):
                cutover.sunshine_state_evidence(link)
            link.unlink()
            os.link(path, link)
            with self.assertRaises(cutover.Refusal):
                cutover.sunshine_state_evidence(path)

    def test_only_exact_successful_idle_response_is_idle(self):
        value = {
            "_tag": "app.session.status",
            "outcome": {
                "_tag": "Err",
                "payload": {
                    "code": "NoActiveSession",
                    "message": "no host launch is active",
                },
            },
        }
        self.assertEqual(cutover.decode_idle(json.dumps(value)), value)
        for response in (
            "",
            "{}",
            "null",
            '{"_tag":"app.session.status","outcome":{"_tag":"Ok","payload":{}}}',
            json.dumps(value).replace("NoActiveSession", "TransportFailure"),
            json.dumps(value).replace("no host launch is active", "timeout"),
            '{"outcome":null,"outcome":null}',
            "x" * 65537,
        ):
            with (
                self.subTest(response=response[:60]),
                self.assertRaises(cutover.Refusal),
            ):
                cutover.decode_idle(response)

    def test_private_read_is_bounded_nofollow_and_single_link(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            root.chmod(0o700)
            path = root / "evidence"
            path.write_bytes(b"synthetic private bytes")
            path.chmod(0o600)
            owner = (os.geteuid(), os.getegid())
            data, evidence = cutover.file_evidence(path, owner, 0o600)
            self.assertEqual(data, b"synthetic private bytes")
            self.assertNotIn("synthetic", json.dumps(evidence))
            self.assertEqual(cutover.file_evidence(path, owner, 0o600)[1], evidence)
            with self.assertRaises(cutover.Refusal):
                cutover.file_evidence(path, owner, 0o600, 2)
            hard = root / "hard"
            os.link(path, hard)
            with self.assertRaises(cutover.Refusal):
                cutover.file_evidence(path, owner, 0o600)
            hard.unlink()
            link = root / "link"
            link.symlink_to(path)
            with self.assertRaises(OSError):
                cutover.file_evidence(link, owner, 0o600)
            fifo = root / "fifo"
            os.mkfifo(fifo, 0o600)
            with self.assertRaises(cutover.Refusal):
                cutover.file_evidence(fifo, owner, 0o600)
            path.chmod(0o644)
            with self.assertRaises(cutover.Refusal):
                cutover.file_evidence(path, owner, 0o600)

    def test_symlink_ancestor_and_writable_private_parent_refuse(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            parent = root / "parent"
            parent.mkdir(mode=0o700)
            alias = root / "alias"
            alias.symlink_to(parent)
            with self.assertRaises(OSError):
                cutover.directory(alias)
            parent.chmod(0o777)
            with self.assertRaises(cutover.Refusal):
                cutover.directory(parent)

    def test_inventory_does_not_treat_missing_or_populated_as_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            path.chmod(0o700)
            owner = (os.geteuid(), os.getegid())
            self.assertEqual(cutover.entries(path, owner), [])
            (path / "active.json").write_bytes(b"candidate recovery fact")
            self.assertEqual(cutover.entries(path, owner), ["active.json"])
            with self.assertRaises(cutover.Refusal):
                cutover.entries(path, owner, 0)
            with self.assertRaises(FileNotFoundError):
                cutover.entries(path / "missing", owner)
            self.assertEqual(
                (path / "active.json").read_bytes(), b"candidate recovery fact"
            )

    def test_failed_real_child_does_not_count_as_success_and_output_is_captured(self):
        with self.assertRaises(cutover.Refusal) as failure:
            cutover.command(["/bin/sh", "-c", "printf synthetic-secret >&2; exit 23"])
        self.assertNotIn("synthetic-secret", str(failure.exception))
        self.assertEqual(cutover.command(["/bin/sh", "-c", "printf exact"]), b"exact")

    def test_timeout_reaps_real_child_process_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            pidfile = Path(tmp) / "pid"
            with self.assertRaises(cutover.Refusal):
                cutover.command(
                    [
                        "/bin/sh",
                        "-c",
                        'echo $$ > "$1"; exec sleep 30',
                        "child",
                        str(pidfile),
                    ],
                    timeout=0.1,
                )
            pid = int(pidfile.read_text())
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)

    def test_preserved_evidence_cannot_allow_key_or_revocation_change(self):
        key = str(cutover.IDENTITY / "device.key")
        grant = str(cutover.IDENTITY / "peer-certificates/" / ("0" * 64))
        old = {key: {"sha256": "original"}, grant: {"sha256": "grant"}}
        cutover.check_preserved(old, old)
        cutover.check_preserved(old, {key: old[key]}, removed_grants=True)
        with self.assertRaises(cutover.Refusal):
            cutover.check_preserved(
                old, {key: {"sha256": "changed"}}, removed_grants=True
            )
        with self.assertRaises(cutover.Refusal):
            cutover.check_preserved(old, {key: old[key]})

    def test_separately_supplied_key_is_checked_by_real_openssl_without_replacement(
        self,
    ):
        openssl = shutil.which("openssl")
        self.assertIsNotNone(openssl)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "device.key"
            path.write_text("0" * 63 + "1\n")
            path.chmod(0o600)
            owner = (os.geteuid(), os.getegid())
            before = cutover.file_evidence(path, owner, 0o600)[1]
            cutover.key_matches(
                {"openssl": openssl},
                "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
                path,
                owner,
            )
            with self.assertRaises(cutover.Refusal):
                cutover.key_matches({"openssl": openssl}, "0" * 64, path, owner)
            self.assertEqual(cutover.file_evidence(path, owner, 0o600)[1], before)

    def test_nonempty_journal_inventory_survives_repeated_refusal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            root.chmod(0o700)
            path = root / "active.json"
            path.write_bytes(b"durable candidate-only recovery facts")
            path.chmod(0o600)
            owner = (os.geteuid(), os.getegid())
            before = cutover.file_evidence(path, owner, 0o600)[1]
            for _ in range(2):
                with self.assertRaises(cutover.Refusal):
                    cutover.require(
                        cutover.entries(root, owner) == [], "journal must be empty"
                    )
            self.assertEqual(cutover.file_evidence(path, owner, 0o600)[1], before)

    def test_fixed_sunshine_port_and_state_parser_rejects_hidden_targets(self):
        for text in ("", "port = 47989\n", "file_state = sunshine_state.json\n"):
            cutover.sunshine_configuration(text)
        for text in (
            "port = 55000\n",
            "port = 47989\nport = 55000\n",
            "file_state = other.json\n",
            "file_state = sunshine_state.json#other.json\n",
            "cert = credentials/cacert.pem#other.pem\n",
            "pkey = credentials/cakey.pem#other.pem\n",
            "file_state = sunshine_state.json \n",
            "resolutions = [\nport = 55000\n]\n",
            "\x00port = 55000\n",
        ):
            with self.subTest(text=text), self.assertRaises(cutover.Refusal):
                cutover.sunshine_configuration(text)
        for text in (
            "PrivateNetwork=true",
            "NetworkNamespacePath=/run/netns/other",
            "JoinsNamespaceOf=other.service",
            "RootImage=/tmp/other",
        ):
            with self.assertRaises(cutover.Refusal):
                cutover.network_namespace_contract(text)
        cutover.network_namespace_contract("PrivateNetwork=false")

    def test_actual_public_zao_wrappers_resolve_before_runtime(self):
        generation = ROOT / "result-federation-zao"
        if not generation.exists():
            self.skipTest("public generated Zao artifact not supplied")
        generation = str(generation.resolve())
        selector = cutover.unit_text(generation, "korri-bundle-selector.service")
        import re

        bundle = re.search(
            r"/nix/store/[0-9a-df-np-sv-z]{32}-korri-bundle-[^\s]+", selector
        )[0]
        images = cutover.inspect_executable_images(generation, bundle)
        self.assertEqual(len(images), 6)
        for image in images.values():
            with Path(image).open("rb") as stream:
                self.assertEqual(stream.read(4), b"\x7fELF")
        sway = cutover.unit_text(generation, "korri-compositor.service")
        import shlex

        sunshine = cutover.unit_text(generation, "sunshine.service")
        argv = shlex.split(cutover.unit_setting(sunshine, "ExecStart"))
        cutover.sunshine_command(argv)
        for tail in (
            ["other.conf"],
            ["file_state=other.json"],
            ["port=55000"],
            ["log_path=/dev/null", "other.conf"],
            ["--help"],
            ["log_path=/other/log"],
            ["encoder=nvenc"],
        ):
            with self.assertRaises(cutover.Refusal):
                cutover.sunshine_command(argv[:2] + tail)
        wrapper = shlex.split(cutover.unit_setting(sway, "ExecStart"))[0]
        with self.assertRaises(cutover.Refusal):
            cutover.executable_image(wrapper, {})
        inputd = cutover.unit_text(generation, "korri-inputd.service")
        self.assertEqual(cutover.unit_setting(inputd, "Group"), "korri-control")
        self.assertEqual(cutover.environment(inputd)["KORRI_INPUTD_CONTROL_GID"], "977")

    def test_projection_accepts_only_lossless_producer_state_and_both_empty_memberships(
        self,
    ):
        original = {
            "root": {"uniqueid": "host", "named_devices": [], "history": [42]},
            "password": "preserved",
        }
        digest = cutover.sunshine_state_digest(json.dumps(original), retired=True)
        original["root"]["devices"] = ""
        self.assertEqual(
            cutover.sunshine_state_digest(json.dumps(original), retired=True), digest
        )
        original["root"]["devices"] = [{"certs": ["legacy-client"]}]
        with self.assertRaises(cutover.Refusal):
            cutover.sunshine_state_digest(json.dumps(original), retired=True)
        for invalid in (1.2, 2**64, -(2**63) - 1, float("nan")):
            original["root"]["history"] = [invalid]
            with self.assertRaises(cutover.Refusal):
                cutover.sunshine_state_digest(json.dumps(original))

    def test_nonmembership_digest_is_preserved_even_when_membership_changes(self):
        path = str(cutover.SUNSHINE / "sunshine_state.json")
        before = {path: {"sha256": "old", "nonmembership_sha256": "preserved"}}
        after = {
            path: {
                "sha256": "new",
                "nonmembership_sha256": "preserved",
                "memberships_empty": True,
            }
        }
        cutover.check_preserved(before, after)
        after[path]["nonmembership_sha256"] = "changed-admin-password"
        with self.assertRaises(cutover.Refusal):
            cutover.check_preserved(before, after)

    def test_recovery_request_eof_cannot_exit_listener(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = str(Path(tmp) / "recovery.sock")
            child = subprocess.Popen(
                [sys.executable, "-B", __file__, "--recovery-listener", path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            try:
                deadline = time.monotonic() + 5
                while not Path(path).exists() and child.poll() is None:
                    self.assertLess(time.monotonic(), deadline)
                    time.sleep(0.01)
                for payload in (b"", b"invalid", b"secure-recovery"):
                    with socket.socket(
                        socket.AF_UNIX, socket.SOCK_SEQPACKET
                    ) as connection:
                        connection.connect(path)
                        if payload:
                            connection.sendall(payload)
                    time.sleep(0.1)
                    self.assertIsNone(
                        child.poll(), "EOF/reset terminated receipt owner"
                    )
            finally:
                child.kill()
                child.communicate(timeout=5)

    def test_startup_condition_resets_refuse_even_with_indentation(self):
        cutover.reject_condition_reset("[Unit]\nConditionPathExists=/run/required\n")
        for text in (
            "[Unit]\nConditionPathExists=\n",
            "[Unit]\n  ConditionPathExists=  \n",
        ):
            with self.assertRaises(cutover.Refusal):
                cutover.reject_condition_reset(text)

    def test_indirect_and_duplicate_environment_never_passes_contract_inspection(self):
        self.assertEqual(
            cutover.environment('Environment="KORRID_RUNTIME_UID=1000"\n'),
            {"KORRID_RUNTIME_UID": "1000"},
        )
        for text in (
            "EnvironmentFile=/etc/private",
            "UnsetEnvironment=KORRID_RUNTIME_UID",
            'Environment="X=1"\nEnvironment="X=2"',
        ):
            with self.assertRaises(cutover.Refusal):
                cutover.environment(text)


class SunshineReadinessTests(unittest.TestCase):
    """Real child processes; the kernel supplies every observation."""

    def parked(self, pid, *, expected, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if cutover.sunshine_main_loop(pid) == expected:
                return True
            time.sleep(0.02)
        return False

    def test_timed_wait_evidence_reflects_actual_process_state(self):
        parked = subprocess.Popen(
            [sys.executable, "-B", "-c", "import time; time.sleep(30)"]
        )
        busy = subprocess.Popen(
            [sys.executable, "-B", "-c", "import time\nwhile True:\n    pass"]
        )
        try:
            self.assertTrue(
                self.parked(parked.pid, expected=True, seconds=10),
                "a real timed wait was not observed",
            )
            for _ in range(25):
                self.assertFalse(
                    cutover.sunshine_main_loop(busy.pid),
                    "a real busy process was reported as parked",
                )
                time.sleep(0.02)
        finally:
            for child in (parked, busy):
                child.kill()
                child.wait(timeout=5)

    def test_exited_process_is_never_evidence_of_a_running_main_loop(self):
        child = subprocess.Popen([sys.executable, "-B", "-c", "pass"])
        child.wait(timeout=10)
        self.assertFalse(cutover.sunshine_main_loop(child.pid))
        self.assertFalse(cutover.sunshine_main_loop(2**31 - 1))

    def test_readiness_and_certificate_checks_share_one_recorded_endpoint(self):
        self.assertEqual(cutover.SUNSHINE_HTTPS, ("127.0.0.1", 47984))
        self.assertEqual(cutover.SUNSHINE_UNIT, "sunshine.service")
        source = (ROOT / "scripts/federation_cutover.py").read_text()
        self.assertEqual(source.count("47984"), 1)
        self.assertEqual(source.count("socket.create_connection(SUNSHINE_HTTPS"), 2)

    def test_no_supervisor_path_can_signal_sunshine_without_waiting_first(self):
        """Every Sunshine restart the supervisor issues waits for readiness.

        The whole module is the unit under test here: one unguarded restart
        anywhere reopens the reported early-signal race, and no single runtime
        call can observe that absence.
        """
        tree = ast.parse((ROOT / "scripts/federation_cutover.py").read_text())
        restarts = {}
        for owner in ast.walk(tree):
            if not isinstance(owner, ast.FunctionDef):
                continue
            for node in ast.walk(owner):
                if (
                    isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Attribute)
                    and node.func.attr == "call"
                    and node.args
                    and getattr(node.args[0], "value", None) == "restart"
                ):
                    restarts.setdefault(owner.name, []).append(node)
        self.assertEqual(sorted(restarts), ["restart_sunshine"])
        (restart,) = restarts["restart_sunshine"]
        self.assertEqual(
            [argument.id for argument in restart.args[1:]],
            ["SUNSHINE_UNIT"],
            "the restarted unit must be the one recorded Sunshine unit",
        )
        (helper,) = [
            node
            for node in tree.body
            if isinstance(node, ast.FunctionDef) and node.name == "restart_sunshine"
        ]
        waits = [
            node.lineno
            for node in ast.walk(helper)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "await_sunshine_ready"
        ]
        self.assertEqual(len(waits), 1)
        self.assertLess(waits[0], restart.lineno)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--recovery-listener"]:
        cutover.RECOVERY_REQUEST = Path(sys.argv[2])
        cutover.await_recovery(None, None, None, None, None)
    else:
        unittest.main()
