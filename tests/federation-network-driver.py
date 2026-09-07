#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3
"""Guest-only contract tests. All peers are real sockets in this VM's namespaces."""

from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import queue
import re
import selectors
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time

TCP = [39217, 47984, 47989, 47990, 48010]
UDP = [47998, 47999, 48000, 48002, 48010, 60000, 60500, 61000]
HOSTS = [(4, "192.0.2.1"), (6, "fd42:1::1"), (4, "198.51.100.1"), (6, "fd42:2::1")]
PEERS = [(4, "192.0.2.2"), (6, "fd42:1::2")]
TABLE = "korri_maintenance_isolation"
PEER_SCRIPT = os.environ["NETWORK_PEER"]
NFT = os.environ["NETWORK_NFT"]
PROCESSES = []
SEQUENCE = 0


def run(*args, check=True, **kwargs):
    return subprocess.run(
        args, check=check, text=True, capture_output=True, timeout=30, **kwargs
    )


def read_line(process):
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        if not selector.select(15):
            raise AssertionError(f"control channel stalled: {process.args}")
    value = process.stdout.readline()
    assert value, (process.args, process.poll())
    return value.strip()


class SocketPeer:
    def __init__(
        self,
        mode="probe",
        namespace=None,
        uid=None,
        ports=None,
        log=None,
        targets=None,
        send_buffer=None,
    ):
        command = []
        if namespace:
            command += ["ip", "netns", "exec", namespace]
        if uid is not None:
            command += ["setpriv", f"--reuid={uid}", f"--regid={uid}", "--clear-groups"]
        command += [sys.executable, PEER_SCRIPT, mode]
        if ports is not None:
            command += ["--ports", json.dumps(ports), "--log", str(log)]
        if targets is not None:
            command += ["--targets", json.dumps(targets)]
        if send_buffer is not None:
            command += ["--send-buffer", str(send_buffer)]
        self.process = subprocess.Popen(
            command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1
        )
        PROCESSES.append(self.process)
        if mode in ("serve", "spray"):
            assert self.request(operation="ready")["kind"] == "ok"

    def request(self, **value):
        self.process.stdin.write(json.dumps(value) + "\n")
        self.process.stdin.flush()
        return json.loads(read_line(self.process))


def token():
    global SEQUENCE
    SEQUENCE += 1
    return f"probe-{SEQUENCE:06d}"


def connection(peer, family, host, protocol, port, blocked=False, source=None):
    key = token()
    request = dict(
        operation="open",
        key=key,
        family=family,
        host=host,
        protocol=protocol,
        port=port,
        value=key,
    )
    if source:
        request["source"] = source
    result = peer.request(**request)
    expect(result, key, blocked)
    return (peer, key)


def expect(result, value, blocked):
    if blocked:
        assert result["kind"] in ("blocked", "closed"), (value, result)
        if result["kind"] == "blocked":
            assert result["error"] in (
                "TimeoutError",
                "ConnectionRefusedError",
                "ConnectionResetError",
                "BrokenPipeError",
                "PermissionError",
            ), result
    else:
        assert result == {"kind": "ok", "value": value}, (value, result)


def exchange(conn, blocked=False, receive=False):
    peer, key = conn
    value = token()
    result = peer.request(
        operation="receive" if receive else "exchange", key=key, value=value
    )
    expect(result, value, blocked)
    return value


def nft(*args, check=True):
    return run(NFT, *args, check=check)


def table():
    return json.loads(nft("-j", "-a", "list", "table", "inet", TABLE).stdout)[
        "nftables"
    ][1:]


def fixture_delete():
    # Only this guest test may discard its deliberately damaged fixture table.
    handle = next(item["table"]["handle"] for item in table() if "table" in item)
    nft("delete", "table", "inet", "handle", str(handle))


def management_rules():
    result = {}
    for command in ("iptables-save", "ip6tables-save"):
        output = run(command).stdout
        result[command] = [
            re.sub(r"\[\d+:\d+\]", "[counts]", line)
            for line in output.splitlines()
            if "ts-" in line or line.startswith((":INPUT", ":OUTPUT", ":FORWARD"))
        ]
    return result


def setup_network():
    run("ip", "netns", "add", "peer")
    run("ip", "-n", "peer", "link", "set", "lo", "up")
    run(
        "ip",
        "netns",
        "exec",
        "peer",
        "sysctl",
        "-w",
        "net.ipv4.ip_local_port_range=32768 39000",
    )
    for host_if, peer_if, prefix4, prefix6 in (
        ("isowire", "wire-peer", "192.0.2", "fd42:1"),
        ("tailscale0", "ts-peer", "198.51.100", "fd42:2"),
    ):
        run("ip", "link", "add", host_if, "type", "veth", "peer", "name", peer_if)
        run("ip", "link", "set", peer_if, "netns", "peer")
        run("ip", "address", "add", f"{prefix4}.1/24", "dev", host_if)
        run("ip", "-6", "address", "add", f"{prefix6}::1/64", "dev", host_if, "nodad")
        run("ip", "link", "set", host_if, "up")
        run("ip", "-n", "peer", "address", "add", f"{prefix4}.2/24", "dev", peer_if)
        run(
            "ip",
            "-n",
            "peer",
            "-6",
            "address",
            "add",
            f"{prefix6}::2/64",
            "dev",
            peer_if,
            "nodad",
        )
        run("ip", "-n", "peer", "link", "set", peer_if, "up")
    # Actual kernel iptables chains, not text-only fixtures. No tailscaled/control
    # plane is started; the veth gives the trusted-interface accept path real traffic.
    for command in ("iptables", "ip6tables"):
        run(command, "-N", "ts-input")
        run(command, "-A", "ts-input", "-i", "tailscale0", "-j", "ACCEPT")
        run(command, "-A", "ts-input", "-p", "udp", "--dport", "41641", "-j", "ACCEPT")
        run(command, "-I", "INPUT", "1", "-j", "ts-input")
        run(command, "-N", "ts-forward")
        run(
            command,
            "-A",
            "ts-forward",
            "-i",
            "tailscale0",
            "-j",
            "MARK",
            "--set-xmark",
            "0x40000/0xff0000",
        )
        run(
            command,
            "-A",
            "ts-forward",
            "-m",
            "mark",
            "--mark",
            "0x40000/0xff0000",
            "-j",
            "ACCEPT",
        )
        run(command, "-I", "FORWARD", "1", "-j", "ts-forward")
        run(command, "-t", "nat", "-N", "ts-postrouting")
        run(
            command,
            "-t",
            "nat",
            "-A",
            "ts-postrouting",
            "-m",
            "mark",
            "--mark",
            "0x40000/0xff0000",
            "-j",
            "MASQUERADE",
        )
        run(command, "-t", "nat", "-A", "POSTROUTING", "-j", "ts-postrouting")


class Management:
    def __init__(self, remote, operator):
        self.remote = remote
        self.operator = operator
        self.rules = management_rules()
        self.sshd = run("systemctl", "show", "sshd", "-p", "MainPID", "--value").stdout
        self.sessions = []
        for _, host in HOSTS:
            process = subprocess.Popen(
                [
                    "ip",
                    "netns",
                    "exec",
                    "peer",
                    "ssh",
                    "-F",
                    "/dev/null",
                    "-T",
                    "-i",
                    "/etc/network-fixture-key",
                    "-o",
                    "StrictHostKeyChecking=no",
                    "-o",
                    "UserKnownHostsFile=/dev/null",
                    "-o",
                    "ConnectTimeout=5",
                    f"root@{host}",
                    sys.executable,
                    PEER_SCRIPT,
                    "ssh-echo",
                ],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
            PROCESSES.append(process)
            self.sessions.append(process)
        self.connections = [
            connection(remote, family, host, "tcp", 18080) for family, host in HOSTS
        ]
        self.check()

    def check(self):
        assert self.rules == management_rules(), (
            "Tailscale chains/rules or global policies changed"
        )
        assert (
            self.sshd
            == run("systemctl", "show", "sshd", "-p", "MainPID", "--value").stdout
        )
        for process in self.sessions:
            value = token()
            assert process.poll() is None, "established SSH session exited"
            process.stdin.write(value + "\n")
            process.stdin.flush()
            assert read_line(process) == value, (
                "same established SSH stream must remain usable"
            )
        for conn in self.connections:
            exchange(conn)
        for process in self.sessions:
            value = token() + "\n"
            # Separate new SSH connection; the four original sessions above stay
            # open and are never replaced to manufacture continuity.
            assert run(*process.args, input=value).stdout == value
        for family, host in HOSTS:
            for protocol, port in (
                ("tcp", 18080),
                ("tcp", 443),
                ("udp", 18081),
                ("udp", 41641),
                ("udp", 53),
                ("udp", 67),
                ("udp", 68),
                ("udp", 546),
                ("udp", 547),
                ("udp", 59999),
                ("udp", 61001),
            ):
                connection(self.remote, family, host, protocol, port)
        for family, host in PEERS:
            for protocol, port in (
                ("tcp", 18080),
                ("tcp", 443),
                ("udp", 18081),
                ("udp", 53),
                ("udp", 41641),
            ):
                connection(self.operator, family, host, protocol, port)
        print(
            "PASS: same established IPv4/IPv6 SSH and unrelated TCP streams; new management/DNS/DHCP/transport/UID1000 traffic; exact ts-* rules and policies",
            flush=True,
        )


@contextmanager
def scenario(name):
    started = time.monotonic()
    yield
    print(f"PASS: {name} ({time.monotonic() - started:.2f}s)", flush=True)


def load_module():
    spec = importlib.util.spec_from_file_location(
        "federation_network_isolation", os.environ["NETWORK_MODULE"]
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def refusal(module, operation):
    try:
        operation()
    except module.Refusal as error:
        return error
    raise AssertionError("expected fail-closed refusal")


def sender_state(sender, state, previous=None):
    assert sender["kind"] == "ok", sender
    assert sender["state"] == state, sender
    assert sender["progress"], sender
    for item in sender["progress"]:
        assert item["attempts"] == item["sends"] + item["blocked"], item
        assert (
            item["sends"]
            <= item["sent_bytes"]
            <= item["sends"] * len(b"firewall-leak-check\n")
        ), item
    if previous is not None:
        assert len(sender["progress"]) == len(previous["progress"])
        for current, earlier in zip(sender["progress"], previous["progress"]):
            assert current["sent_bytes"] > earlier["sent_bytes"], (earlier, current)
            assert current["attempts"] > earlier["attempts"], (earlier, current)
    return sender


def sender_reset_checks():
    """Reset actual established TCP after successful TCP/UDP fixture baselines."""
    for reset_state in ("paused", "active", "backpressure"):
        address = "127.0.0.254"
        with socket.socket() as tcp, socket.socket(type=socket.SOCK_DGRAM) as udp:
            tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            tcp.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024)
            tcp.bind((address, 39217))
            tcp.listen(1)
            tcp.settimeout(5)
            udp.bind((address, 60500))
            udp.settimeout(5)
            connections = queue.Queue()

            def accept():
                connection, _ = tcp.accept()
                connection.settimeout(5)
                value = connection.recv(4096)
                assert value == b"spray-baseline\n"
                connection.sendall(value)
                connections.put(connection)

            def datagram():
                value, peer = udp.recvfrom(4096)
                assert value == b"spray-baseline\n"
                udp.sendto(value, peer)

            workers = [
                threading.Thread(target=accept),
                threading.Thread(target=datagram),
            ]
            for worker in workers:
                worker.start()
            sender = SocketPeer(
                "spray",
                targets=[(4, address)],
                send_buffer=4096 if reset_state == "backpressure" else None,
            )
            for worker in workers:
                worker.join(timeout=5)
                assert not worker.is_alive()
            connection = connections.get(timeout=5)
            try:
                if reset_state == "backpressure":
                    sender_state(sender.request(operation="start"), "active")
                    # The real receiver stops draining a small TCP window. UDP
                    # remains writable; it must not conceal stalled TCP progress.
                    time.sleep(2)
                    result = sender.request(operation="status")
                    assert result == {
                        "kind": "failed",
                        "error": "WorkerHandshakeTimeout",
                    }, result
                    paused = sender_state(sender.request(operation="stop"), "paused")
                    counts = paused["progress"][0]
                    assert counts["blocked"] > 0, paused
                    received = 0
                    connection.settimeout(2)
                    while True:
                        try:
                            value = connection.recv(65536)
                            assert value, "backpressure sender unexpectedly closed"
                            received += len(value)
                        except TimeoutError:
                            break
                    assert received == counts["sent_bytes"], (received, counts)
                    assert sender.request(operation="status") == paused
                    sender.process.terminate()
                    sender.process.wait(timeout=5)
                    print(
                        f"PASS: real TCP backpressure refuses stalled progress; only actual bytes counted: {counts}",
                        flush=True,
                    )
                    continue
                # First reproduce the reset itself, so the old silent-worker
                # failure cannot be hidden by a missing new response field.
                if reset_state == "active":
                    sender_state(sender.request(operation="start"), "active")
                connection.setsockopt(
                    socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0)
                )
                connection.close()
                result = sender.request(
                    operation="start" if reset_state == "paused" else "status"
                )
                deadline = time.monotonic() + 5
                while result["kind"] == "ok" and time.monotonic() < deadline:
                    time.sleep(0.01)
                    result = sender.request(operation="status")
                assert result == {"kind": "failed", "error": "ConnectionResetError"}, (
                    result
                )
                for operation in ("start", "status", "stop"):
                    assert sender.request(operation=operation) == result
                sender.process.stdin.close()
                assert sender.process.wait(timeout=5) != 0
            finally:
                connection.close()
            print(
                f"PASS: real TCP reset while {reset_state} fails sender controls and exit",
                flush=True,
            )

    # With a healthy server, start waits for every socket to send, status proves
    # further successful sends, and stop acknowledges a quiescent worker.
    with tempfile.TemporaryDirectory(prefix="sender-handshake-") as directory:
        server = SocketPeer(
            "serve",
            ports={"tcp": [39217], "udp": [60500]},
            log=Path(directory) / "received",
        )
        sender = SocketPeer("spray", targets=[(4, "127.0.0.1")])
        paused = sender_state(sender.request(operation="status"), "paused")
        assert all(item["attempts"] == 0 for item in paused["progress"])
        for _ in range(3):
            active = sender_state(sender.request(operation="start"), "active", paused)
            sender_state(sender.request(operation="status"), "active", active)
            paused = sender_state(sender.request(operation="stop"), "paused")
            time.sleep(0.03)
            assert sender.request(operation="status") == paused
        sender.process.terminate()
        sender.process.wait(timeout=5)
        server.process.terminate()
        server.process.wait(timeout=5)
    print(
        "PASS: sender activation/progress/quiescence handshake on real TCP/UDP",
        flush=True,
    )


def nft_adapter():
    """Immutable guest adapter: run real nft, changing only result timing/failure."""
    arguments = sys.argv[2:]
    mode = os.environ["NETWORK_FAULT_MODE"]
    log = Path(os.environ["NETWORK_FAULT_LOG"])
    contents = sys.stdin.read() if arguments == ["-f", "-"] else None
    installing = "-e" in arguments
    deleting = contents is not None and contents.startswith("delete table inet handle ")

    def record(stage, **extra):
        with log.open("a") as output:
            output.write(
                json.dumps(
                    dict(stage=stage, arguments=arguments, contents=contents, **extra)
                )
                + "\n"
            )

    record("called")
    if mode == "before-install" and installing:
        time.sleep(30)
    if mode == "post-delete-list" and arguments == ["-j", "list", "tables", "inet"]:
        record("listing-failure", returncode=71)
        sys.stderr.write("configured post-delete listing failure\n")
        return 71
    result = run(NFT, *arguments, input=contents, check=False)
    record("completed", returncode=result.returncode)
    if result.returncode == 0 and (
        (mode == "after-install" and installing)
        or (mode == "after-delete" and deleting)
    ):
        time.sleep(30)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


def transaction_checks(module):
    def absent():
        objects = json.loads(nft("-j", "list", "tables", "inet").stdout)["nftables"]
        return not any(item.get("table", {}).get("name") == TABLE for item in objects)

    def journal():
        return [json.loads(line) for line in log.read_text().splitlines()]

    def calls():
        return [entry for entry in journal() if entry["stage"] == "called"]

    def timed_out(operation):
        started = time.monotonic()
        error = refusal(module, operation)
        cause = error
        while cause.__cause__ is not None:
            cause = cause.__cause__
        assert isinstance(cause, subprocess.TimeoutExpired), error
        print(
            f"ACTUAL NFT TIMEOUT: {time.monotonic() - started:.2f}s; {error}",
            flush=True,
        )
        return error

    failures = []
    with tempfile.TemporaryDirectory(prefix="nft-outcomes-") as directory:
        log = Path(directory) / "calls.jsonl"
        os.environ["NETWORK_FAULT_LOG"] = str(log)
        for mode in (
            "before-install",
            "after-install",
            "after-delete",
            "post-delete-list",
        ):
            assert absent(), "each outcome starts without a fixture table"
            os.environ["NETWORK_FAULT_MODE"] = mode
            log.write_text("")
            isolation = module.NetworkIsolation(os.environ["NETWORK_NFT_ADAPTER"])
            try:
                if mode.endswith("install"):
                    timed_out(isolation.install)
                    assert absent() == (mode == "before-install")
                    entries = journal()
                    assert len(calls()) == 1 and "-e" in calls()[0]["arguments"]
                    assert [entry["stage"] for entry in entries] == (
                        ["called"]
                        if mode == "before-install"
                        else ["called", "completed"]
                    )
                    if mode == "after-install":
                        assert entries[-1]["returncode"] == 0
                    for operation in (isolation.verify, isolation.remove):
                        assert "no owned table receipt" in str(
                            refusal(module, operation)
                        )
                    assert journal() == entries, "no compensation or receipt adoption"
                    if mode == "after-install":
                        original = table()
                        other = module.NetworkIsolation(NFT)
                        refusal(module, other.install)
                        refusal(module, other.remove)
                        assert table() == original, (
                            "unknown-result table must remain unchanged"
                        )
                    print(
                        f"PASS: {mode}: actual kernel absent={absent()}, no receipt/compensation/adoption",
                        flush=True,
                    )
                else:
                    isolation.install()
                    log.write_text("")
                    error = (
                        timed_out(isolation.remove)
                        if mode == "after-delete"
                        else refusal(module, isolation.remove)
                    )
                    assert absent(), (
                        "actual deletion committed; no automatic restoration"
                    )
                    recorded = calls()
                    assert len(recorded) == (2 if mode == "after-delete" else 3)
                    assert recorded[0]["arguments"] == [
                        "-j",
                        "-a",
                        "-n",
                        "list",
                        "table",
                        "inet",
                        TABLE,
                    ]
                    assert recorded[1]["arguments"] == ["-f", "-"]
                    assert recorded[1]["contents"].startswith(
                        "delete table inet handle "
                    )
                    completed = [
                        entry for entry in journal() if entry["stage"] == "completed"
                    ]
                    assert len(completed) == 2 and all(
                        entry["returncode"] == 0 for entry in completed
                    )
                    if mode == "post-delete-list":
                        assert journal()[-1]["stage"] == "listing-failure"
                        assert journal()[-1]["returncode"] == 71
                    # Receipt loss is not claimed: retry must refuse rather than
                    # silently clear the stale receipt or delete anything by name.
                    refusal(module, isolation.remove)
                    assert len(calls()) == len(recorded) + 1
                    assert calls()[-1]["arguments"] == recorded[0]["arguments"]
                    assert "already holds a table receipt" in str(
                        refusal(module, isolation.install)
                    )
                    assert absent()
                    print(
                        f"VERIFIED {mode}: kernel absent; stale-receipt retry refuses; no compensation",
                        flush=True,
                    )
                    assert "table may already be absent" in str(error), str(error)
                    assert "keep separate persistent gates in place" in str(error), str(
                        error
                    )
                    assert "supervisor inspection" in str(error), str(error)
                    assert isinstance(error, module.RemovalUncertain), type(error)
                    print(
                        f"PASS: {mode}: phase-specific uncertainty: {error}", flush=True
                    )
            except AssertionError as error:
                failures.append((mode, str(error)))
            finally:
                # Guest-only teardown AFTER inspecting real state. This is not
                # an operation by the module or a proposed production recovery.
                if not absent():
                    fixture_delete()
        assert not failures, failures


def main():
    assert Path("/etc/federation-network-vm-fixture").is_file()
    assert socket.gethostname() == "machine"
    if len(sys.argv) > 1 and sys.argv[1] == "nft-adapter":
        sys.exit(nft_adapter())
    module = load_module()
    if len(sys.argv) == 2 and sys.argv[1] == "sender-reset-checks":
        sender_reset_checks()
        return
    if len(sys.argv) == 2 and sys.argv[1] == "transaction-checks":
        transaction_checks(module)
        return
    if len(sys.argv) == 2 and sys.argv[1] == "install-and-exit":
        module.NetworkIsolation(NFT).install()
        return
    version = run("systemctl", "--version").stdout
    assert version.startswith("systemd 259")
    print(version, flush=True)
    print(run(NFT, "--version").stdout, flush=True)
    print(run("iptables", "--version").stdout, flush=True)
    print(
        f"ARTIFACTS: module={module.__file__} rules={module.RULES_FILE} nft={NFT} driver={__file__} peer={PEER_SCRIPT}",
        flush=True,
    )
    setup_network()
    service_log = Path("/run/network-service.log")
    admin_log = Path("/tmp/network-admin.log")
    peer_log = Path("/run/network-peer.log")
    unrelated_udp = [53, 67, 68, 546, 547, 41641, 18081, 59999, 61001]
    host_server = SocketPeer(
        "serve",
        ports={
            "tcp": [port for port in TCP if port != 47990] + [18080, 443],
            "udp": UDP + unrelated_udp,
        },
        log=service_log,
    )
    admin_server = SocketPeer("serve", uid=976, ports={"tcp": [47990]}, log=admin_log)
    SocketPeer(
        "serve",
        namespace="peer",
        ports={"tcp": [18080, 443], "udp": unrelated_udp},
        log=peer_log,
    )
    remote = SocketPeer(namespace="peer")
    root = SocketPeer(uid=0)
    korrid = SocketPeer(uid=976)
    operator = SocketPeer(uid=1000)
    service_user = SocketPeer(uid=1001)
    management = Management(remote, operator)
    isolation = module.NetworkIsolation(NFT)

    with scenario(
        "foreign install collision and failed nft batch leave every foreign object intact"
    ):
        nft("-f", os.environ["NETWORK_COLLISION"])
        original = table()
        refusal(module, isolation.install)
        assert table() == original
        fixture_delete()
        failed = nft("-f", os.environ["NETWORK_INVALID"], check=False)
        assert failed.returncode != 0
        assert nft("list", "table", "inet", TABLE, check=False).returncode != 0
        management.check()

    established = []
    local = []
    relay = []
    source_flows = []
    with scenario(
        "baseline exchanges establish all IPv4/IPv6 TCP/UDP flows before installation"
    ):
        for family, host in HOSTS:
            for protocol, ports in (("tcp", TCP), ("udp", UDP)):
                for port in ports:
                    established.append(connection(remote, family, host, protocol, port))
        for client in (root, korrid, operator, service_user):
            for family, host in ((4, "127.0.0.1"), (6, "::1"), *HOSTS[:2]):
                for protocol, port in (("tcp", 47990), ("udp", 47998), ("udp", 60500)):
                    local.append(
                        (client, connection(client, family, host, protocol, port))
                    )
        for family, host in PEERS:
            for protocol, port in (("tcp", 443), ("udp", 18081)):
                relay.append(connection(korrid, family, host, protocol, port))
        for family, host in PEERS:
            source_flows.append(
                connection(root, family, host, "tcp", 18080, source=47989)
            )
            source_flows.append(
                connection(root, family, host, "udp", 18081, source=60320)
            )
        # Keep conntrack UDP entries fresh throughout the long negative matrix.
        run("sysctl", "-w", "net.netfilter.nf_conntrack_udp_timeout_stream=600")
        run("sysctl", "-w", "net.netfilter.nf_conntrack_udp_timeout=600")
        for conn in established + relay + source_flows + [conn for _, conn in local]:
            exchange(conn)
        print(run("conntrack", "-L", "-p", "udp").stdout, flush=True)
        spray = SocketPeer(
            "spray", namespace="peer", targets=HOSTS, send_buffer=4194304
        )

    with scenario(
        "one atomic install blocks existing and new service ingress on both interfaces and families"
    ):
        isolation.install()
        isolation.verify()
        denied = []
        for conn in established:
            denied.append(exchange(conn, blocked=True))
        for family, host in HOSTS:
            for protocol, ports in (("tcp", TCP), ("udp", UDP)):
                for port in ports:
                    conn = connection(
                        remote, family, host, protocol, port, blocked=True
                    )
                    denied.append(conn[1])
        logs = service_log.read_text() + admin_log.read_text()
        assert not any(value in logs for value in denied), (
            "blocked ingress reached real server"
        )
        management.check()

    with scenario(
        "server-initiated output cannot leak on existing TCP/UDP source-port flows"
    ):
        host_server.request(
            operation="broadcast", value="denied-server-push", ports=TCP + UDP
        )
        admin_server.request(
            operation="broadcast", value="denied-server-push", ports=TCP + UDP
        )
        for conn in established:
            exchange(conn, blocked=True, receive=True)
        denied = [exchange(conn, blocked=True) for conn in source_flows]
        for family, host in PEERS:
            denied.append(
                connection(root, family, host, "tcp", 443, blocked=True, source=47984)[
                    1
                ]
            )
            denied.append(
                connection(
                    root, family, host, "udp", 18081, blocked=True, source=60321
                )[1]
            )
        assert not any(value in peer_log.read_text() for value in denied)
        management.check()

    with scenario(
        "loopback permits root maintenance only, including existing sockets and local interface addresses"
    ):
        denied = []
        # The broadcast included local baseline sockets. Discard that one legitimate
        # reply before testing their client-to-service direction.
        for client, conn in local:
            value = client.request(operation="receive", key=conn[1])
            assert value["kind"] == "ok" and "denied-server-push" in value["value"], (
                value
            )
            value = exchange(conn, blocked=client is not root)
            if client is not root:
                denied.append(value)
        for client in (root, korrid, operator, service_user):
            for family, host in ((4, "127.0.0.1"), (6, "::1"), *HOSTS[:2]):
                for protocol, ports in (("tcp", TCP), ("udp", UDP)):
                    for port in ports:
                        conn = connection(
                            client,
                            family,
                            host,
                            protocol,
                            port,
                            blocked=client is not root,
                        )
                        if client is not root:
                            denied.append(conn[1])
        logs = service_log.read_text() + admin_log.read_text()
        assert not any(value in logs for value in denied), (
            "denied local traffic reached service"
        )
        isolation.verify()

    with scenario(
        "UID976 existing/new relay egress is closed without blocking root or UID1000"
    ):
        denied = [exchange(conn, blocked=True) for conn in relay]
        for family, host in PEERS:
            for protocol, port in (("tcp", 443), ("udp", 18081)):
                denied.append(
                    connection(korrid, family, host, protocol, port, blocked=True)[1]
                )
                connection(root, family, host, protocol, port)
                connection(operator, family, host, protocol, port)
        assert not any(value in peer_log.read_text() for value in denied)
        management.check()

    with scenario(
        "actual pinned NixOS firewall stop/start/reload/restart preserves effective isolation"
    ):
        print(run("systemctl", "cat", "firewall.service").stdout, flush=True)
        paused = sender_state(spray.request(operation="status"), "paused")
        for action in ("stop", "start", "reload", "restart"):
            # Keep the same established sockets, but send only across the actual
            # action. Filling TCP queues during lengthy intervening negative
            # probes would prevent fresh successful sends at the next action.
            active = sender_state(spray.request(operation="start"), "active", paused)
            before = sender_state(spray.request(operation="status"), "active", active)
            run("systemctl", action, "firewall.service")
            active = sender_state(spray.request(operation="status"), "active", before)
            paused = sender_state(spray.request(operation="stop"), "paused")
            time.sleep(0.03)
            assert spray.request(operation="status") == paused
            print(
                f"SENDER PROGRESS {action}: before={before} after={active}", flush=True
            )
            isolation.verify()
            for family, host in HOSTS:
                connection(remote, family, host, "tcp", 39217, blocked=True)
                connection(remote, family, host, "udp", 60500, blocked=True)
            for conn in (
                established[0],
                established[5],
                established[13],
                established[18],
                *relay,
                *source_flows,
            ):
                exchange(conn, blocked=True)
            for family, host in ((4, "127.0.0.1"), (6, "::1")):
                connection(root, family, host, "tcp", 47990)
                connection(operator, family, host, "tcp", 47990, blocked=True)
            management.check()
            print(f"PASS: real firewall {action}", flush=True)
        assert spray.request(operation="status") == paused
        assert "firewall-leak-check" not in service_log.read_text(), (
            "traffic leaked DURING real firewall operations"
        )
        spray.process.terminate()
        spray.process.wait(timeout=10)

    with scenario(
        "changed contents and same-name replacement refuse removal without deleting foreign rules"
    ):
        nft("add", "chain", "inet", TABLE, "foreign_change")
        changed = table()
        refusal(module, isolation.remove)
        assert table() == changed
        nft("delete", "chain", "inet", TABLE, "foreign_change")
        isolation.verify()
        old_handle = next(
            item["table"]["handle"] for item in table() if "table" in item
        )
        fixture_delete()
        nft("-f", str(module.RULES_FILE))
        replacement = table()
        refusal(module, isolation.remove)
        assert (
            nft(
                "delete", "table", "inet", "handle", str(old_handle), check=False
            ).returncode
            != 0
        )
        assert table() == replacement
        for family, host in HOSTS[:2]:
            connection(remote, family, host, "tcp", 47990, blocked=True)
        fixture_delete()
        isolation = module.NetworkIsolation(NFT)
        isolation.install()
        # Handles can collide across namespaces. Receipts must bind the namespace.
        with (
            open("/proc/self/ns/net", "rb") as original,
            open("/run/netns/peer", "rb") as target,
        ):
            try:
                os.setns(target.fileno())
                refusal(module, isolation.remove)
            finally:
                os.setns(original.fileno())
        isolation.verify()
        management.check()

    with scenario(
        "exact owned cleanup restores real service/relay traffic and preserves management"
    ):
        isolation.remove()
        assert nft("list", "table", "inet", TABLE, check=False).returncode != 0
        refusal(module, isolation.remove)
        reopened = []
        for family, host in HOSTS:
            for protocol, ports in (("tcp", TCP), ("udp", UDP)):
                for port in ports:
                    reopened.append(connection(remote, family, host, protocol, port))
        for peer, key in relay + source_flows:
            peer.request(operation="close", key=key)
        relay = []
        for family, host in PEERS:
            relay.append(connection(korrid, family, host, "tcp", 443))
            relay.append(connection(korrid, family, host, "udp", 18081))
        for client in (korrid, operator, service_user):
            for family, host in ((4, "127.0.0.1"), (6, "::1")):
                connection(client, family, host, "tcp", 47990)
                connection(client, family, host, "udp", 60500)
        management.check()

    with scenario(
        "installer exit does not remove kernel filtering; lost receipt cannot adopt or remove it"
    ):
        run(sys.executable, __file__, "install-and-exit")
        fresh = module.NetworkIsolation(NFT)
        refusal(module, fresh.install)
        refusal(module, fresh.remove)
        for family, host in HOSTS:
            connection(remote, family, host, "tcp", 47990, blocked=True)
            connection(remote, family, host, "udp", 60500, blocked=True)
        for conn in reopened + relay:
            exchange(conn, blocked=True)
        for client in (root, korrid, operator, service_user):
            for family, host in ((4, "127.0.0.1"), (6, "::1")):
                connection(
                    client, family, host, "tcp", 47990, blocked=client is not root
                )
                connection(
                    client, family, host, "udp", 60500, blocked=client is not root
                )
        management.check()
    print(
        "PASS: network fixture complete; table deliberately retained for reboot non-persistence test",
        flush=True,
    )


if __name__ == "__main__":
    try:
        main()
    finally:
        for process in reversed(PROCESSES):
            process.terminate()
        for process in reversed(PROCESSES):
            process.wait(timeout=10)
