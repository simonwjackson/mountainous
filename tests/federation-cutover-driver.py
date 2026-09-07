#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3
"""Disposable VM consumer. Refuses without the NixOS fixture marker."""

import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import struct
import subprocess
import sys
import time


def fixture_certificates(output):
    # Build-cache time and guest time must not change TLS validity. These are
    # synthetic test certificates only; production SSL checks remain enabled.
    from datetime import datetime, timezone
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.x509.oid import NameOID

    output = Path(output)
    output.mkdir()
    for serial, name in enumerate(
        ("client-one", "client-two", "server", "expired-server"), start=1
    ):
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)])
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(subject)
            .public_key(key.public_key())
            .serial_number(serial)
            .not_valid_before(datetime(2020, 1, 1, tzinfo=timezone.utc))
            .not_valid_after(
                datetime(
                    2021 if name == "expired-server" else 2100,
                    1,
                    1,
                    tzinfo=timezone.utc,
                )
            )
            .add_extension(
                x509.BasicConstraints(ca=True, path_length=None), critical=True
            )
            .sign(key, hashes.SHA256())
        )
        (output / (name + ".crt")).write_bytes(
            cert.public_bytes(serialization.Encoding.PEM)
        )
        (output / (name + ".key")).write_bytes(
            key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption(),
            )
        )


if sys.argv[1:2] == ["certificates"]:
    fixture_certificates(sys.argv[2])
    sys.exit(0)

metadata = json.loads(Path(sys.argv[1]).read_text())
sys.path.insert(0, metadata["library"])
import federation_cutover as cutover  # noqa: E402
from federation_isolation import Isolation, Manager, SYSTEM_UNITS, USER_UNITS  # noqa: E402

MARKER = Path("/etc/federation-cutover-fixture")
assert MARKER.read_text() == "disposable synthetic VM only\n"
mode = sys.argv[2]
fixtures = Path(metadata["identities"])
tools = json.loads((Path(metadata["library"]) / "tools.json").read_text())


def call(argv, **kwargs):
    result = subprocess.run(argv, text=True, capture_output=True, **kwargs)
    if result.returncode:
        # This executable is VM-marker-only and contains synthetic identities.
        print(result.stdout, result.stderr, file=sys.stderr)
        result.check_returncode()
    return result.stdout


def params(action):
    values = json.loads(Path("/run/cutover-fixture-arguments.json").read_text())
    result = [action]
    for key, value in values.items():
        result += ["--" + key.replace("_", "-"), str(value)]
    return result


def assert_preflight_refusal():
    before = cutover.fingerprints()
    call([metadata["runner"], *params("launch")])
    manager = Manager()
    deadline = time.monotonic() + 30
    while manager.show(cutover.SUPERVISOR, "ActiveState") not in ("failed", "inactive"):
        assert time.monotonic() < deadline
        time.sleep(0.1)
    assert manager.show(cutover.SUPERVISOR, "Result") == "exit-code"
    assert not Path(
        "/var/lib/korri-maintenance-isolation/trust-mutation-started.json"
    ).exists()
    assert not Path("/var/lib/korri-maintenance-isolation/manifest.json").exists()
    assert cutover.fingerprints() == before
    manager.call("reset-failed", cutover.SUPERVISOR)


def private(path, data, owner, mode=0o600):
    path.write_bytes(data)
    os.chown(path, *owner)
    path.chmod(mode)


def manifest_fault(phase):
    """Real kernel file-open permission failure, not a replacement store/manager.

    fanotify holds the writer at manifest.next open until this VM-only process
    allows or denies it. The created inode is retained after a denied open.
    """
    import ctypes
    import select

    state = Path("/var/lib/korri-maintenance-isolation")
    state.mkdir(mode=0o700, exist_ok=True)
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.fanotify_init(1 | 2 | 4, os.O_RDONLY | os.O_CLOEXEC)
    assert fd >= 0, ctypes.get_errno()
    assert (
        libc.fanotify_mark(
            fd, 1, ctypes.c_uint64(0x10000 | 0x08000000), -100, os.fsencode(state)
        )
        == 0
    ), ctypes.get_errno()
    Path("/run/cutover-fault-ready").touch()
    while True:
        assert select.select([fd], [], [], 500)[0], "manifest fault event timed out"
        buffer = os.read(fd, 65536)
        offset = 0
        while offset < len(buffer):
            size, version, _, length, mask, event_fd, pid = struct.unpack_from(
                "=IBBHQii", buffer, offset
            )
            offset += size
            assert version == 3 and length == 24 and event_fd >= 0, (
                "fanotify event lost"
            )
            path = os.readlink(f"/proc/self/fd/{event_fd}")
            deny = False
            injected = False
            if path == str(state / "manifest.next"):
                injected = (
                    phase in ("journal", "grant", "commitment", "state", "legacy")
                    and (state / "local-accepted.json").exists()
                )
                if injected:
                    if phase == "journal":
                        private(
                            cutover.PRIVATE / "host-session/incompatible.json",
                            b"candidate-only incompatible journal facts\n",
                            (976, 976),
                        )
                    elif phase == "grant":
                        source = next(
                            (fixtures / "identity/peer-certificates").iterdir()
                        )
                        private(
                            cutover.IDENTITY / "peer-certificates" / source.name,
                            source.read_bytes(),
                            (976, 976),
                        )
                    elif phase == "commitment":
                        call(["umount", "/srv/range/media/tv"])
                    else:
                        document_path = cutover.SUNSHINE / "sunshine_state.json"
                        document = json.loads(document_path.read_text())
                        if phase == "state":
                            document["password"] = "unexpected-admin-change"
                        else:
                            document["root"]["devices"] = [
                                {
                                    "certs": [
                                        (fixtures / "certs/client-one.crt").read_text()
                                    ]
                                }
                            ]
                        private(
                            document_path, json.dumps(document).encode(), (1000, 100)
                        )
                if (
                    phase == "probe-revoke"
                    and (state / "automatic-provisioned.json").exists()
                ):
                    # Break the real producer adapter AFTER actual TLS acceptance.
                    # The authenticated revoke RPC must return failure, not success.
                    Path("/run/korri-certificate-control/control.sock").unlink()
                    injected = True
                deny = (
                    phase == "probe-receipt"
                    and (state / "automatic-revoked.json").exists()
                    or phase == "handshake"
                    and bool(list(Path("/run").glob("activation-*")))
                    or phase == "permits"
                    and bool(
                        list(Path("/run/korri-maintenance-isolation").glob("system-*"))
                    )
                    or phase == "before-table"
                    and (state / "local-accepted.json").exists()
                    or phase == "after-table"
                    and (state / "acceptance.json").exists()
                    or phase == "final-release"
                    and (state / "released.json").exists()
                )
            if deny or injected:
                assert pid == int(Manager().show(cutover.SUPERVISOR, "MainPID"))
                if phase in ("before-table", "after-table", "final-release"):
                    assert Manager().show("sunshine.service", "ActiveState") == "active"
                    assert Manager().show("korrid.service", "ActiveState") == "active"
                if phase == "before-table":
                    call(
                        [
                            tools["nft"],
                            "list",
                            "table",
                            "inet",
                            "korri_maintenance_isolation",
                        ]
                    )
                if phase in ("after-table", "final-release"):
                    call(
                        [
                            metadata["ip"],
                            "netns",
                            "exec",
                            "cutover-relay",
                            sys.executable,
                            __file__,
                            sys.argv[1],
                            "peer-open",
                        ]
                    )
                Path("/run/cutover-fault-supervisor").write_text(str(pid))
                Path("/run/cutover-fault-fired").write_text(phase)
            os.write(fd, struct.pack("=iI", event_fd, 2 if deny else 1))
            os.close(event_fd)
            if deny or injected:
                os.close(fd)
                return


def setup():
    assert os.geteuid() == 0
    setup_commitments()
    client = Path("/var/lib/cutover-verification-client")
    client.mkdir(mode=0o700)
    (client / "identity").mkdir(mode=0o700)
    for name in ("device.key", "owner.event.json"):
        private(
            client / "identity" / name,
            (fixtures / "verification-client/identity" / name).read_bytes(),
            (0, 0),
        )
    Path("/var/lib/korri").mkdir(mode=0o700)
    os.chown("/var/lib/korri", 976, 976)
    for name in ("config.yaml", "library.yaml"):
        private(Path("/var/lib/korri") / name, b"{}\n", (976, 976))
    assert not cutover.PRIVATE.exists()
    for path in (cutover.PRIVATE, cutover.IDENTITY, cutover.PRIVATE / "host-session"):
        path.mkdir(mode=0o700)
        os.chown(path, 976, 976)
    for name in ("device.key", "owner.event.json"):
        private(
            cutover.IDENTITY / name,
            (fixtures / "identity" / name).read_bytes(),
            (976, 976),
        )
    for name in ("peer-certificates", "authorization-revocations"):
        dest = cutover.IDENTITY / name
        dest.mkdir(mode=0o700)
        os.chown(dest, 976, 976)
        for source in (fixtures / "identity" / name).iterdir():
            private(dest / source.name, source.read_bytes(), (976, 976))
    cutover.SUNSHINE.mkdir(mode=0o700)
    os.chown(cutover.SUNSHINE, 1000, 100)
    credentials = cutover.SUNSHINE / "credentials"
    credentials.mkdir(mode=0o755)
    os.chown(credentials, 1000, 100)
    private(
        credentials / "cacert.pem",
        (fixtures / "certs/server.crt").read_bytes(),
        (1000, 100),
        0o644,
    )
    private(
        credentials / "cakey.pem",
        (fixtures / "certs/server.key").read_bytes(),
        (1000, 100),
    )
    state = {
        "root": {
            "uniqueid": "6832F97F-A2D5-C30B-2B1C-1D4E31150449",
            "named_devices": [
                {
                    "name": "tracked",
                    "uuid": "22222222-2222-2222-2222-222222222222",
                    "cert": (fixtures / "certs/client-one.crt").read_text(),
                },
                {
                    "name": "manual",
                    "uuid": "33333333-3333-3333-3333-333333333333",
                    "cert": (fixtures / "certs/client-two.crt").read_text(),
                },
            ],
            "history": ["preserved-game", 42],
        },
        "username": "unchanged-test-admin",
        "salt": "unchanged-salt",
        "password": "unchanged-hash",
    }
    private(
        cutover.SUNSHINE / "sunshine_state.json",
        json.dumps(state).encode(),
        (1000, 100),
    )
    private(cutover.SUNSHINE / "apps.json", b'{"apps":[],"env":{}}', (1000, 100), 0o644)
    conf = (
        f"file_state = {cutover.SUNSHINE}/sunshine_state.json\n"
        f"cert = {credentials}/cacert.pem\npkey = {credentials}/cakey.pem\n"
        f"file_apps = {cutover.SUNSHINE}/apps.json\ncapture = x11\nencoder = software\n"
        "min_log_level = 2\n"
    )
    private(cutover.SUNSHINE / "sunshine.conf", conf.encode(), (1000, 100), 0o644)
    cutover.SELECTORS.mkdir(mode=0o711)
    (cutover.SELECTORS / "active").symlink_to(metadata["oldBundle"])
    (cutover.SELECTORS / "previous").symlink_to(metadata["oldBundle"])
    old = str(Path("/run/current-system").resolve())
    expected = json.loads((fixtures / "expected.json").read_text())
    values = {
        **expected,
        **json.loads((fixtures / "verification-expected.json").read_text()),
        "verification_client_root": str(client),
        "verification_event_sha256": hashlib.sha256(
            (client / "identity/owner.event.json").read_bytes()
        ).hexdigest(),
        "old": old,
        "old_bundle": metadata["oldBundle"],
        "candidate": str((Path(old) / "specialisation/candidate").resolve()),
        "candidate_bundle": metadata["candidateBundle"],
        "recovery": str((Path(old) / "specialisation/recovery").resolve()),
        "recovery_bundle": metadata["recoveryBundle"],
        "previous_bundle": metadata["oldBundle"],
        "booted": str(Path("/run/booted-system").resolve()),
        "old_binding": str(fixtures / "old.json"),
        "event": str(fixtures / "new.json"),
        "template": str(fixtures / "template.json"),
        "event_sha256": hashlib.sha256(
            (fixtures / "new.json").read_bytes()
        ).hexdigest(),
        "template_sha256": hashlib.sha256(
            (fixtures / "template.json").read_bytes()
        ).hexdigest(),
        "host_uuid": state["root"]["uniqueid"],
        "grants": 1,
    }
    private(
        Path("/run/cutover-fixture-arguments.json"), json.dumps(values).encode(), (0, 0)
    )
    private(
        Path("/var/lib/cutover-fixture-arguments.json"),
        json.dumps(values).encode(),
        (0, 0),
    )
    call([tools["systemctl"], "start", "korrid.service"])


def setup_commitments():
    root = Path("/var/lib/cutover-storage")
    root.mkdir()
    for disk in range(5):
        image = root / f"{disk:02}.xfs"
        with image.open("wb") as stream:
            stream.truncate(384 * 1024 * 1024)
        call(["mkfs.xfs", "-f", str(image)])
    call(
        [
            tools["systemctl"],
            "start",
            "towada-mergerfs-mount.service",
            "towada-array.target",
            "towada-merged.target",
        ]
    )
    call(
        [
            tools["systemctl"],
            "start",
            "media-tiering-tv-mount.service",
            "media-tiering-movies-mount.service",
            "jellyfin-seed-bootstrap.service",
            "tsnet-proxy-jellyfin.service",
            "ensure-office-printer.service",
        ]
    )
    call(["headscale", "users", "create", "fixture"])
    users = json.loads(call(["headscale", "--output", "json", "users", "list"]))
    user = next(user for user in users if user["name"] == "fixture")
    key = json.loads(
        call(
            [
                "headscale",
                "--output",
                "json",
                "preauthkeys",
                "create",
                "--user",
                str(user["id"]),
            ]
        )
    )["key"]
    call(
        [
            "tailscale",
            "up",
            "--login-server=http://127.0.0.1:8080",
            "--auth-key=" + key,
            "--accept-dns=false",
            "--timeout=45s",
        ]
    )
    deadline = time.monotonic() + 90
    while True:
        result = subprocess.run(
            ["zao-verify-commitments"], capture_output=True, text=True
        )
        if result.returncode == 0:
            break
        if time.monotonic() > deadline:
            print(result.stdout, result.stderr, file=sys.stderr)
            result.check_returncode()
        time.sleep(1)


def storage_mounts():
    for disk in range(5):
        path = Path(f"/srv/shores/towada/{disk:02}")
        path.mkdir(parents=True, exist_ok=True)
        call(
            [
                "mount",
                "-t",
                "xfs",
                "-o",
                "loop",
                f"/var/lib/cutover-storage/{disk:02}.xfs",
                str(path),
            ]
        )
    Path("/srv/lakes/towada").mkdir(parents=True, exist_ok=True)
    call(
        [
            "mergerfs",
            "-o",
            "minfreespace=16M",
            "/srv/shores/towada/00:/srv/shores/towada/01:/srv/shores/towada/04",
            "/srv/lakes/towada",
        ]
    )
    for kind in ("tv", "movies"):
        Path("/srv/lakes/towada/media", kind).mkdir(parents=True, exist_ok=True)
        Path("/srv/range/media", kind).mkdir(parents=True, exist_ok=True)


def printer():
    call(
        [
            "lpadmin",
            "-p",
            "Office_Printer",
            "-E",
            "-v",
            "socket://127.0.0.1:9100",
            "-m",
            "raw",
        ]
    )
    call(["lpadmin", "-d", "Office_Printer"])


def status_server():
    listener = socket.socket(fileno=3)
    while True:
        conn, _ = listener.accept()
        with conn:
            conn.settimeout(3)
            _, uid, gid = struct.unpack(
                "3i", conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
            )
            assert (uid, gid) == (977, 977)
            data = conn.recv(65536)
            if b"app.session.status" not in data:
                data += conn.recv(65536)
            assert b"app.session.status" in data
            outcome = Path("/run/cutover-fixture-status-error")
            code = "TransportFailure" if outcome.exists() else "NoActiveSession"
            body = json.dumps(
                {
                    "_tag": "app.session.status",
                    "outcome": {
                        "_tag": "Err",
                        "payload": {
                            "code": code,
                            "message": "no host launch is active",
                        },
                    },
                }
            ).encode()
            conn.sendall(
                b"HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Length: "
                + str(len(body)).encode()
                + b"\r\n\r\n"
                + body
            )


def boundaries():
    before = cutover.fingerprints()
    values = json.loads(Path("/run/cutover-fixture-arguments.json").read_text())
    commands = [
        (
            [
                tools["retire"],
                "--exclusive-quiescence-confirmed",
                "--state",
                str(cutover.SUNSHINE / "sunshine_state.json"),
                "--expect-host-uuid",
                values["host_uuid"],
                "--expect-state-sha256",
                "0" * 64,
            ],
            (1000, 100),
        ),
        (
            [
                tools["korrid"],
                "identity",
                "replace-test-owner-offline",
                "--expected-device",
                "0" * 64,
                "--expected-owner",
                cutover.TEST_OWNER,
                "--expected-event",
                values["old_event"],
                "--new-owner",
                values["new_owner"],
                "--template",
                values["template"],
                "--file",
                values["event"],
            ],
            None,
        ),
        (
            [
                tools["selector"],
                "offline-select",
                metadata["candidateBundle"],
                metadata["recoveryBundle"],
                "--acknowledge-exclusive-quiescence",
            ],
            None,
        ),
        (
            [
                tools["korrid"],
                "identity",
                "reconcile-stale-grants-offline",
                "--expected-device",
                values["device"],
                "--expected-owner",
                values["new_owner"],
                "--expected-event",
                values["new_event"],
            ],
            (976, 976),
        ),
    ]
    for argv, identity in commands:
        try:
            cutover.command(argv, identity=identity, environment=cutover.ADAPTER_ENV)
        except cutover.Refusal:
            pass
        else:
            raise AssertionError(
                "actual primitive unexpectedly accepted wrong evidence"
            )
    assert cutover.fingerprints() == before
    assert cutover.raw_selector("active") == metadata["oldBundle"]


def assert_preserved_state(bundle=None):
    baseline = json.loads(
        Path("/var/lib/korri-maintenance-isolation/baseline.json").read_text()
    )
    cutover.check_preserved(
        baseline["fingerprints"], cutover.fingerprints(), removed_grants=True
    )
    assert (cutover.IDENTITY / "owner.event.json").read_bytes() == (
        fixtures / "new.json"
    ).read_bytes()
    state = json.loads((cutover.SUNSHINE / "sunshine_state.json").read_text())
    assert state["root"]["uniqueid"] == "6832F97F-A2D5-C30B-2B1C-1D4E31150449"
    assert state["root"]["named_devices"] in ([], "")
    assert state["root"]["history"] == ["preserved-game", 42]
    assert state["password"] == "unchanged-hash"
    assert cutover.raw_selector("active") == (bundle or metadata["candidateBundle"])
    assert cutover.raw_selector("previous") == metadata["oldBundle"]
    assert (cutover.SUNSHINE / "apps.json").read_bytes() == b'{"apps":[],"env":{}}'


def sunshine_marks(cursor):
    """Real monotonic journal marks of the actual Sunshine unit after `cursor`."""
    text = call(
        [
            "journalctl",
            "-u",
            "sunshine.service",
            "-o",
            "short-monotonic",
            "--no-pager",
            "--after-cursor",
            cursor,
        ]
    )
    marks = {}
    for line in text.splitlines():
        stamp = re.match(r"\[\s*([0-9.]+)\]", line)
        if not stamp:
            continue
        for label, needle in (
            ("main_loop", "Starting main loop"),
            ("stopping", "Stopping sunshine.service"),
            ("terminate", "Terminate handler called"),
        ):
            if needle in line:
                marks.setdefault(label, float(stamp[1]))
    return marks


def terminate_handler_installed(pid):
    """Kernel evidence that Sunshine's own SIGTERM handler is already installed.

    Waiting for this puts the unguarded signal in the exact reported window:
    after main() installs the handler and before mainThreadLoop can act on it.
    """
    for line in Path(f"/proc/{pid}/status").read_text().splitlines():
        if line.startswith("SigCgt:"):
            return bool(int(line.split()[1], 16) & (1 << (signal.SIGTERM - 1)))
    return False


def restart_observation(manager, *, guarded):
    """One real stop-signal observation against the actual Sunshine unit."""
    manager.call("stop", "sunshine.service")
    cursor = (
        call(["journalctl", "-n", "0", "--show-cursor", "--no-pager"])
        .split("cursor: ")[-1]
        .strip()
    )
    manager.call("start", "sunshine.service")
    if guarded:
        cutover.await_sunshine_ready(manager)
    else:
        pid = int(manager.show("sunshine.service", "MainPID"))
        deadline = time.monotonic() + 60
        while not terminate_handler_installed(pid):
            assert time.monotonic() < deadline, "Sunshine never installed a handler"
            time.sleep(0.002)
    started = time.monotonic()
    refused = None
    try:
        manager.call("restart", "sunshine.service")
    except cutover.Refusal as error:
        refused = str(error)
    seconds = round(time.monotonic() - started, 3)
    deadline = time.monotonic() + 240
    while manager.show("sunshine.service", "ActiveState") not in ("active", "failed"):
        assert time.monotonic() < deadline, "Sunshine never settled after the restart"
        time.sleep(0.5)
    marks = sunshine_marks(cursor)
    assert "stopping" in marks, marks
    return {
        "guarded": guarded,
        "restart_seconds": seconds,
        "refused": refused,
        "marks": marks,
        "signal_before_main_loop": "main_loop" not in marks
        or marks["stopping"] < marks["main_loop"],
        "acted_on_signal": "terminate" in marks,
        "handler_installed_before_signal": not guarded,
    }


def start_limit_window(manager):
    """The unit's own real start-limit interval. This test waits it out.

    Repeated observations would otherwise exhaust the burst. Nothing here may
    reset, relax or disable a systemd start limit; the acceptance path performs
    far fewer Sunshine starts than the burst allows.
    """
    interval = manager.show("sunshine.service", "StartLimitIntervalUSec")
    burst = manager.show("sunshine.service", "StartLimitBurst")
    assert (interval, burst) == ("10s", "5"), (interval, burst)
    return 11.0


def sunshine_restart_race():
    """Actual early-signal race check against the real systemd unit and binary.

    Reported blocker: a stop signal that reaches Sunshine before its main loop
    runs is ignored for the whole 90 s stop timeout, so the supervisor can only
    report unknown containment. The unguarded observation waits for Sunshine's
    own installed handler and so lands in exactly that window; no guarded
    observation may ever reproduce the ordering.
    """
    manager = Manager()
    window = start_limit_window(manager)
    unguarded = restart_observation(manager, guarded=False)
    print(json.dumps(unguarded), flush=True)
    assert unguarded["signal_before_main_loop"], unguarded
    for _ in range(3):
        time.sleep(window)
        guarded = restart_observation(manager, guarded=True)
        print(json.dumps(guarded), flush=True)
        assert not guarded["signal_before_main_loop"], guarded
        assert guarded["acted_on_signal"], guarded
        assert guarded["refused"] is None, guarded
        assert guarded["restart_seconds"] < 30, guarded
    # A readiness timeout refuses and contains: it never proceeds or signals.
    time.sleep(window)
    manager.call("stop", "sunshine.service")
    restarts = manager.show("sunshine.service", "NRestarts")
    started = time.monotonic()
    try:
        cutover.await_sunshine_ready(manager)
    except cutover.Refusal as error:
        assert "actual observable readiness" in str(error), error
    else:
        raise AssertionError("stopped Sunshine accepted as ready")
    waited = time.monotonic() - started
    assert 55 < waited < 180, waited
    assert manager.show("sunshine.service", "ActiveState") == "inactive"
    assert manager.show("sunshine.service", "NRestarts") == restarts
    manager.call("start", "sunshine.service")
    assert cutover.await_sunshine_ready(manager) == int(
        manager.show("sunshine.service", "MainPID")
    )
    print(json.dumps({"readiness_timeout_seconds": round(waited, 3)}), flush=True)


def assert_authority_closed():
    # The surviving supervisor owns the exclusive lock. Observe actual managers
    # and gate files without opening a competing mutation/receipt context.
    observation = Isolation(cutover.USER, cutover.HOME)
    for manager, units in observation.managers:
        for unit in units:
            assert manager.show(unit, "LoadState") == "masked"
            assert manager.show(unit, "ActiveState") in ("inactive", "failed")
            assert (
                os.readlink(observation.mask_root(manager.user) / unit) == "/dev/null"
            )
            assert (
                cutover.file_evidence(
                    observation.gate_path(manager.user, unit), (0, 0), 0o644
                )[0]
                == f"[Unit]\nConditionPathExists={observation.permit_path(manager.user, unit)}\n".encode()
            )
    cutover.games(observation.managers)


def assert_cut():
    cutover.verify_commitments(str(Path("/run/current-system").resolve()))
    baseline = json.loads(
        Path("/var/lib/korri-maintenance-isolation/baseline.json").read_text()
    )
    assert cutover.management(Manager()) == baseline["management"]
    assert_preserved_state()
    assert_authority_closed()
    for executable in (
        tools["korrid"],
        str(Path(metadata["oldBundle"]) / "bin/korrid"),
    ):
        try:
            cutover.command(
                [
                    executable,
                    "identity",
                    "import",
                    "--file",
                    str(fixtures / "old.json"),
                ],
                identity=(976, 976),
                environment=cutover.ADAPTER_ENV,
            )
        except cutover.Refusal:
            pass
        else:
            raise AssertionError("ordinary old-owner import accepted")
    assert_preserved_state()


def incomplete_probe_observation():
    """Diagnose retained synthetic facts, never relax the supervisor contract."""
    evidence = Path("/var/lib/korri-maintenance-isolation")
    args = cutover.arguments(params("run"))
    cert = (evidence / "automatic-probe/client.crt").read_text()
    raw, state = cutover.file_evidence(
        cutover.SUNSHINE / "sunshine_state.json", (1000, 980), 0o600, 16 * 1024 * 1024
    )
    cutover.temporary_membership(raw, cert, args.host_uuid)
    baseline = json.loads((evidence / "baseline.json").read_text())
    assert (
        cutover.sunshine_state_digest(raw)
        == baseline["fingerprints"][str(cutover.SUNSHINE / "sunshine_state.json")][
            "nonmembership_sha256"
        ]
    )
    assert (cutover.IDENTITY / "device.key").read_bytes() == (
        fixtures / "identity/device.key"
    ).read_bytes()
    assert cutover.entries(cutover.IDENTITY / "peer-certificates", (976, 976)) == [
        args.verification_device
    ]
    grant_raw, grant = cutover.file_evidence(
        cutover.IDENTITY / "peer-certificates" / args.verification_device,
        (976, 976),
        0o600,
        131072,
    )
    assert json.loads(grant_raw)["clientCertificate"] == cert
    assert (cutover.IDENTITY / "owner.event.json").read_bytes() == (
        fixtures / "new.json"
    ).read_bytes()
    assert (evidence / "automatic-provision-started.json").exists()
    assert not (evidence / "automatic-provisioned.json").exists()
    assert not (evidence / "automatic-revoked.json").exists()
    assert not (evidence / "local-accepted.json").exists()
    assert not (evidence / "released.json").exists()
    return {"state": state, "grant": grant}


def assert_boot_closed():
    assert_preserved_state()
    cutover.absent_state()
    state = Path("/var/lib/korri-maintenance-isolation")
    baseline = json.loads((state / "baseline.json").read_text())
    assert str(Path("/run/current-system").resolve()) == baseline["profiles"]["current"]
    expected_grants = 0 if (state / "prepared-not-accepted.json").exists() else 1
    assert (
        len(cutover.entries(cutover.IDENTITY / "peer-certificates", (976, 976)))
        == expected_grants
    )
    assert not Path("/run/korri-maintenance-isolation").exists()
    for manager, units in (
        (Manager(), SYSTEM_UNITS),
        (Manager(cutover.USER), USER_UNITS),
    ):
        for unit in units:
            if manager.show(unit, "LoadState") != "masked":
                manager.call("start", unit)
            assert manager.show(unit, "ActiveState") in ("inactive", "failed")
    tables = call([tools["nft"], "list", "tables"])
    assert "korri_maintenance_isolation" not in tables
    assert (cutover.IDENTITY / "owner.event.json").read_bytes() == (
        fixtures / "new.json"
    ).read_bytes()


if mode == "status-server":
    status_server()
else:
    assert os.geteuid() == 0
    if mode == "setup":
        setup()
    elif mode == "fault-manifest":
        manifest_fault(sys.argv[3])
    elif mode in ("peer-closed", "peer-open"):
        with socket.create_connection(("192.0.2.1", 22), timeout=3) as connection:
            assert connection.recv(256).startswith(b"SSH-2.0-")
        for port in (47989, 47984, 39217):
            try:
                connection = socket.create_connection(("192.0.2.1", port), timeout=2)
            except (ConnectionRefusedError, TimeoutError):
                if mode == "peer-open":
                    raise AssertionError(
                        "trusted peer could not reach active authority before fault"
                    )
                continue
            connection.close()
            if mode == "peer-closed":
                raise AssertionError(
                    "authority answered reachable peer after failed persistence"
                )
    elif mode == "assert-emergency-stopped":
        observation = Isolation(cutover.USER, cutover.HOME)
        for manager, units in observation.managers:
            assert not cutover.games(observation.managers)
            for unit in units:
                assert manager.show(unit, "ActiveState") in ("inactive", "failed"), unit
                observation.verify_empty_cgroup(manager.show(unit, "ControlGroup"))
        assert Manager().show(cutover.ACTIVATION_WORKER, "ActiveState") in (
            "inactive",
            "failed",
        )
        assert Manager().show(cutover.SUPERVISOR, "ActiveState") == "active"
        assert (
            Manager().show(cutover.SUPERVISOR, "MainPID")
            == Path("/run/cutover-fault-supervisor").read_text()
        )
        call(
            [
                metadata["ip"],
                "netns",
                "exec",
                "cutover-relay",
                sys.executable,
                __file__,
                sys.argv[1],
                "peer-closed",
            ]
        )
        baseline = json.loads(
            Path("/var/lib/korri-maintenance-isolation/baseline.json").read_text()
        )
        assert cutover.management(Manager()) == baseline["management"]
        assert (cutover.IDENTITY / "owner.event.json").read_bytes() == (
            fixtures / "new.json"
        ).read_bytes()
        assert (
            json.loads((cutover.SUNSHINE / "sunshine_state.json").read_text())["root"][
                "named_devices"
            ]
            == []
        )
        call(["zao-verify-commitments"])
        cutover.management(Manager())
    elif mode == "boundaries":
        boundaries()
    elif mode == "preflight-review":
        apps = cutover.SUNSHINE / "apps.json"
        before = cutover.file_evidence(apps, (1000, 100), 0o644)[1]
        assert cutover.fingerprints()[str(apps)] == before
        assert cutover.file_evidence(apps, (1000, 100), 0o644)[1] == before
        for drift in ("sha256", "mode", "gid", "ino", "size"):
            changed = {**before, drift: "changed"}
            try:
                cutover.check_preserved({str(apps): before}, {str(apps): changed})
            except cutover.Refusal:
                pass
            else:
                raise AssertionError("apps preservation bypass: " + drift)
        for owner, permissions in (
            ((1000, 100), 0o600),
            ((1000, 100), 0o664),
            ((0, 0), 0o644),
        ):
            os.chown(apps, *owner)
            apps.chmod(permissions)
            try:
                cutover.fingerprints()
            except cutover.Refusal:
                pass
            else:
                raise AssertionError("unsafe apps inventory accepted")
        os.chown(apps, 1000, 100)
        apps.chmod(0o644)
        saved_apps = apps.with_name("apps.saved")
        apps.rename(saved_apps)
        try:
            for kind in ("symlink", "hardlink", "fifo", "oversize"):
                if kind == "symlink":
                    apps.symlink_to(saved_apps)
                elif kind == "hardlink":
                    os.link(saved_apps, apps)
                elif kind == "fifo":
                    os.mkfifo(apps, 0o644)
                else:
                    with apps.open("wb") as stream:
                        stream.truncate(4 * 1024 * 1024 + 1)
                if kind != "symlink":
                    os.chown(apps, 1000, 100)
                try:
                    try:
                        cutover.fingerprints()
                    except (cutover.Refusal, OSError):
                        pass
                    else:
                        raise AssertionError("unsafe apps object accepted: " + kind)
                finally:
                    apps.unlink()
        finally:
            saved_apps.rename(apps)
        assert apps.read_bytes() == b'{"apps":[],"env":{}}'
        # Real VM filesystem ownership, never a metadata replacement. Only the
        # state writer's fixed private groups are allowed, not arbitrary groups.
        state_policy = Path("/run/cutover-state-policy.json")
        for group, permissions, allowed in (
            (100, 0o600, True),
            (980, 0o600, True),
            (976, 0o600, False),
            (0, 0o600, False),
            (980, 0o640, False),
        ):
            private(
                state_policy,
                b'{"root":{"uniqueid":"host"}}',
                (1000, group),
                permissions,
            )
            try:
                cutover.sunshine_state_evidence(state_policy)
            except cutover.Refusal:
                assert not allowed, (group, permissions)
            else:
                assert allowed, (group, permissions)
        state_policy.unlink()
        args = cutover.arguments(params("run"))
        config = cutover.SUNSHINE / "sunshine.conf"
        original = config.read_bytes()
        other_state = cutover.SUNSHINE / "other_state.json"
        private(
            other_state,
            (cutover.SUNSHINE / "sunshine_state.json").read_bytes(),
            (1000, 100),
        )
        private(
            cutover.SUNSHINE / "other.conf",
            b"file_state = " + str(other_state).encode() + b"\n",
            (1000, 100),
            0o644,
        )
        failures = []
        other_before = cutover.file_evidence(other_state, (1000, 100), 0o600)[1]
        parameters_path = Path("/run/cutover-fixture-arguments.json")
        original_parameters = parameters_path.read_bytes()
        for case, generation, content in (
            (
                "F1-second-config",
                str((Path(args.old) / "specialisation/secondconfig").resolve()),
                original,
            ),
            ("F2-shifted-port", args.old, original + b"port = 55000\n"),
            (
                "F1-inline-comment",
                args.old,
                original.replace(
                    b"sunshine_state.json\n", b"sunshine_state.json#other\n"
                ),
            ),
            (
                "F2-namespace",
                str((Path(args.old) / "specialisation/namespace").resolve()),
                original,
            ),
            (
                "F1-extra-state",
                args.old,
                original.replace(b"sunshine_state.json", b"other_state.json"),
            ),
        ):
            private(config, content, (1000, 100), 0o644)
            before = cutover.fingerprints()
            try:
                second = case in ("F1-second-config", "F2-namespace")
                cutover.inspect_generation(
                    args,
                    generation,
                    args.candidate_bundle if second else args.old_bundle,
                    new_contract=second,
                    binding=second,
                )
            except cutover.Refusal as error:
                print(case, "refused", str(error), flush=True)
            else:
                failures.append(case)
                print(case, "UNSAFE ACCEPT", flush=True)
            assert cutover.fingerprints() == before
            assert not Path(
                "/var/lib/korri-maintenance-isolation/trust-mutation-started.json"
            ).exists()
            if case not in failures:
                if case in ("F1-second-config", "F2-namespace"):
                    parameters = json.loads(original_parameters)
                    parameters["candidate"] = generation
                    private(parameters_path, json.dumps(parameters).encode(), (0, 0))
                assert_preflight_refusal()
                private(parameters_path, original_parameters, (0, 0))
                assert (
                    cutover.file_evidence(other_state, (1000, 100), 0o600)[1]
                    == other_before
                )
        private(config, original, (1000, 100), 0o644)
        key = cutover.SUNSHINE / "credentials/cakey.pem"
        original_key = key.read_bytes()
        for bad in (b"malformed key", (fixtures / "certs/client-two.key").read_bytes()):
            private(key, bad, (1000, 100))
            assert_preflight_refusal()
        private(key, original_key, (1000, 100))
        cert = cutover.SUNSHINE / "credentials/cacert.pem"
        server_key = cutover.SUNSHINE / "credentials/cakey.pem"
        good_cert, good_key = cert.read_bytes(), server_key.read_bytes()
        private(
            cert,
            (fixtures / "certs/expired-server.crt").read_bytes(),
            (1000, 100),
            0o644,
        )
        private(
            server_key,
            (fixtures / "certs/expired-server.key").read_bytes(),
            (1000, 100),
        )
        assert_preflight_refusal()
        private(cert, good_cert, (1000, 100), 0o644)
        private(server_key, good_key, (1000, 100))
        call(
            [
                "systemd-run",
                "--user",
                "--machine=" + cutover.USER + "@.host",
                "--unit=korri-compositor",
                "--collect",
                metadata["sleep"],
                "infinity",
            ]
        )
        assert (
            Manager(cutover.USER).show("korri-compositor.service", "ActiveState")
            == "active"
        )
        assert_preflight_refusal()
        Manager(cutover.USER).call("stop", "korri-compositor.service")
        assert not failures, failures
    elif mode == "storage-mounts":
        storage_mounts()
    elif mode == "relay-network":
        call(["ip", "netns", "add", "cutover-relay"])
        call(
            [
                "ip",
                "link",
                "add",
                "relay-host",
                "type",
                "veth",
                "peer",
                "name",
                "relay-peer",
            ]
        )
        call(["ip", "link", "set", "relay-peer", "netns", "cutover-relay"])
        call(["ip", "address", "add", "192.0.2.1/30", "dev", "relay-host"])
        call(["ip", "link", "set", "relay-host", "up"])
        call(
            [
                "ip",
                "-n",
                "cutover-relay",
                "address",
                "add",
                "192.0.2.2/30",
                "dev",
                "relay-peer",
            ]
        )
        call(["ip", "-n", "cutover-relay", "link", "set", "relay-peer", "up"])
        call(["ip", "-n", "cutover-relay", "link", "set", "lo", "up"])
    elif mode == "printer":
        printer()
    elif mode == "launch":
        print(call([metadata["runner"], *params("launch")]))
    elif mode == "sunshine-restart-race":
        sunshine_restart_race()
    elif mode == "assert-cut":
        assert_cut()
    elif mode == "check-commitments":
        print(call(["zao-verify-commitments"]))
        cutover.management(Manager())
    elif mode == "assert-facts-held":
        state = Path("/var/lib/korri-maintenance-isolation")
        phase = Path("/run/cutover-fault-fired").read_text()
        baseline = json.loads((state / "baseline.json").read_text())
        assert cutover.management(Manager()) == baseline["management"]
        assert_authority_closed()
        assert not (state / "acceptance.json").exists()
        assert not (state / "released.json").exists()
        assert cutover.raw_selector("active") == metadata["candidateBundle"]
        profile = str(cutover.PROFILE.resolve())
        assert profile == baseline["parameters"]["old"]
        watched = [cutover.SUNSHINE / "sunshine_state.json"]
        watched += list((cutover.IDENTITY / "peer-certificates").iterdir())
        watched += list((cutover.PRIVATE / "host-session").iterdir())
        before = {
            str(path): (path.read_bytes(), path.stat().st_ino) for path in watched
        }
        manager = Manager()
        pid = manager.show(cutover.SUPERVISOR, "MainPID")
        for _ in range(2):
            count = len(list(state.glob("recovery-refused-*.json")))
            call([metadata["runner"], *params("recover")])
            deadline = time.monotonic() + 120
            while len(list(state.glob("recovery-refused-*.json"))) == count:
                assert time.monotonic() < deadline
                assert manager.show(cutover.SUPERVISOR, "MainPID") == pid
                time.sleep(0.1)
            assert before == {
                str(path): (path.read_bytes(), path.stat().st_ino) for path in watched
            }
            assert cutover.raw_selector("active") == metadata["candidateBundle"]
            assert str(cutover.PROFILE.resolve()) == profile
            assert not (state / "secure-recovery-boot.json").exists()
            assert_authority_closed()
        if phase == "commitment":
            try:
                cutover.verify_commitments(str(Path("/run/current-system").resolve()))
            except cutover.PrimitiveFailure as failure:
                assert (
                    b"FAIL media-tiering-sink" in failure.stdout and failure.code != 0
                )
            else:
                raise AssertionError("unmounted commitment passed")
            manager.call("restart", "media-tiering-tv-mount.service")
        cutover.verify_commitments(str(Path("/run/current-system").resolve()))
        assert cutover.management(Manager()) == baseline["management"]
    elif mode == "recovery-death-client":
        with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as connection:
            connection.connect(str(cutover.RECOVERY_REQUEST))
            if sys.argv[3] == "sent":
                connection.sendall(b"secure-recovery")
                assert connection.recv(128) == b"requested; no acceptance implied"
            Path("/run/recovery-death-ready").touch()
            time.sleep(60)
    elif mode == "recovery-client-deaths":
        manager = Manager()
        pid = manager.show(cutover.SUPERVISOR, "MainPID")
        state = Path("/var/lib/korri-maintenance-isolation")
        for stage in ("connected", "sent"):
            ready = Path("/run/recovery-death-ready")
            ready.unlink(missing_ok=True)
            before = len(list(state.glob("recovery-refused-*.json")))
            child = subprocess.Popen(
                [sys.executable, __file__, sys.argv[1], "recovery-death-client", stage]
            )
            try:
                deadline = time.monotonic() + 10
                while not ready.exists():
                    assert child.poll() is None and time.monotonic() < deadline
                    time.sleep(0.01)
                child.kill()
                child.wait(timeout=5)
                time.sleep(2)
                assert manager.show(cutover.SUPERVISOR, "MainPID") == pid
                assert manager.show(cutover.SUPERVISOR, "ActiveState") == "active"
                if stage == "connected":
                    assert len(list(state.glob("recovery-refused-*.json"))) == before
                else:
                    deadline = time.monotonic() + 90
                    while len(list(state.glob("recovery-refused-*.json"))) == before:
                        assert time.monotonic() < deadline
                        assert manager.show(cutover.SUPERVISOR, "MainPID") == pid
                        time.sleep(0.1)
                    assert (
                        len(list(state.glob("recovery-refused-*.json"))) == before + 1
                    )
                call(
                    [
                        tools["nft"],
                        "list",
                        "table",
                        "inet",
                        "korri_maintenance_isolation",
                    ]
                )
                assert cutover.raw_selector("active") == metadata["candidateBundle"]
            finally:
                if child.poll() is None:
                    child.kill()
                    child.wait()
    elif mode == "assert-incomplete-probe-held":
        state = Path("/var/lib/korri-maintenance-isolation")
        before = incomplete_probe_observation()
        assert_authority_closed()
        args = cutover.arguments(params("run"))
        pid = Manager().show(cutover.SUPERVISOR, "MainPID")
        for _ in range(2):
            count = len(list(state.glob("recovery-refused-*.json")))
            call([metadata["runner"], *params("recover")])
            deadline = time.monotonic() + 60
            while len(list(state.glob("recovery-refused-*.json"))) == count:
                assert time.monotonic() < deadline
                time.sleep(0.1)
            assert "incomplete automatic certificate probe" in call(
                ["journalctl", "-u", cutover.SUPERVISOR, "--no-pager"]
            )
            assert incomplete_probe_observation() == before
            assert_authority_closed()
            assert Manager().show(cutover.SUPERVISOR, "MainPID") == pid
            assert cutover.raw_selector("active") == args.candidate_bundle
            assert str(cutover.PROFILE.resolve()) == args.old
            call([tools["nft"], "list", "table", "inet", "korri_maintenance_isolation"])
        call(
            [
                metadata["ip"],
                "netns",
                "exec",
                "cutover-relay",
                sys.executable,
                __file__,
                sys.argv[1],
                "peer-closed",
            ]
        )
        private(
            Path("/var/lib/cutover-incomplete-probe.json"),
            json.dumps(before).encode(),
            (0, 0),
        )
        print(
            "verified retained new certificate/grant, same supervisor, two refused recoveries, closed authority and peer sockets:",
            json.dumps(before, sort_keys=True),
        )
    elif mode == "assert-probe-held":
        state = Path("/var/lib/korri-maintenance-isolation")
        args = cutover.arguments(params("run"))
        phase = Path("/run/cutover-fault-fired").read_text()
        assert phase in ("probe-revoke", "probe-receipt")
        assert (state / "automatic-provisioned.json").exists()
        assert not (state / "local-accepted.json").exists()
        assert not (state / "acceptance.json").exists()
        assert not (state / "released.json").exists()
        observation = Isolation(cutover.USER, cutover.HOME)
        for manager, units in observation.managers:
            for unit in units:
                assert manager.show(unit, "ActiveState") in ("inactive", "failed")
                observation.verify_empty_cgroup(manager.show(unit, "ControlGroup"))
        assert (cutover.IDENTITY / "owner.event.json").read_bytes() == (
            fixtures / "new.json"
        ).read_bytes()
        assert cutover.raw_selector("active") == args.candidate_bundle
        assert str(cutover.PROFILE.resolve()) == args.old
        cert = (state / "automatic-probe/client.crt").read_text()
        raw = (cutover.SUNSHINE / "sunshine_state.json").read_bytes()
        if phase == "probe-revoke":
            cutover.temporary_membership(raw, cert, args.host_uuid)
            assert cutover.entries(
                cutover.IDENTITY / "peer-certificates", (976, 976)
            ) == [args.verification_device]
        else:
            baseline = json.loads((state / "baseline.json").read_text())
            cutover.verify_new_state(args, tools, baseline)
        before = cutover.fingerprints()
        pid = Manager().show(cutover.SUPERVISOR, "MainPID")
        observation_path = Path("/var/lib/cutover-probe-held.json")
        private(observation_path, json.dumps(before).encode(), (0, 0))
        # Persist only this fixture observation before a hard power loss. A
        # global sync would hide missing durability in the actual supervisor.
        with observation_path.open("rb") as stream:
            os.fsync(stream.fileno())
        parent = os.open(observation_path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(parent)
        finally:
            os.close(parent)
        previous = call(["journalctl", "-u", cutover.SUPERVISOR, "--no-pager"]).count(
            "Evidence persistence refused"
        )
        for attempt in range(2):
            refusals = len(list(state.glob("recovery-refused-*.json")))
            call([metadata["runner"], *params("recover")])
            deadline = time.monotonic() + 45
            while True:
                text = call(["journalctl", "-u", cutover.SUPERVISOR, "--no-pager"])
                if (
                    phase == "probe-revoke"
                    and len(list(state.glob("recovery-refused-*.json"))) > refusals
                ):
                    assert "incomplete automatic certificate probe" in text
                    break
                if (
                    phase == "probe-receipt"
                    and text.count("Evidence persistence refused") > previous + attempt
                ):
                    break
                assert time.monotonic() < deadline
                time.sleep(0.1)
            assert cutover.fingerprints() == before
            assert Manager().show(cutover.SUPERVISOR, "MainPID") == pid
            assert Manager().show(cutover.SUPERVISOR, "ActiveState") == "active"
            assert cutover.raw_selector("active") == args.candidate_bundle
            assert str(cutover.PROFILE.resolve()) == args.old
            call([tools["nft"], "list", "table", "inet", "korri_maintenance_isolation"])
        call(
            [
                metadata["ip"],
                "netns",
                "exec",
                "cutover-relay",
                sys.executable,
                __file__,
                sys.argv[1],
                "peer-closed",
            ]
        )
    elif mode in ("assert-fault-boot", "assert-incomplete-probe-boot"):
        if mode == "assert-incomplete-probe-boot":
            private(
                Path("/run/cutover-fixture-arguments.json"),
                Path("/var/lib/cutover-fixture-arguments.json").read_bytes(),
                (0, 0),
            )
            assert incomplete_probe_observation() == json.loads(
                Path("/var/lib/cutover-incomplete-probe.json").read_text()
            )
            print("verified retained exact new certificate/grant through reboot")
        probe_facts = Path("/var/lib/cutover-probe-held.json")
        if probe_facts.exists():
            assert cutover.fingerprints() == json.loads(probe_facts.read_text())
        assert (cutover.IDENTITY / "owner.event.json").read_bytes() == (
            fixtures / "new.json"
        ).read_bytes()
        assert not Path("/run/korri-maintenance-isolation").exists()
        for manager, units in (
            (Manager(), SYSTEM_UNITS),
            (Manager(cutover.USER), USER_UNITS),
        ):
            for unit in units:
                if manager.show(unit, "LoadState") != "masked":
                    manager.call("start", unit)
                assert manager.show(unit, "ActiveState") in ("inactive", "failed"), unit
                Isolation.verify_empty_cgroup(manager.show(unit, "ControlGroup"))
        cutover.verify_commitments(str(Path("/run/current-system").resolve()))
        cutover.management(Manager())
    elif mode == "phase":
        evidence_root = Path("/var/lib/korri-maintenance-isolation")
        print("phase files:", sorted(item.name for item in evidence_root.iterdir()))
        for item in [
            cutover.SUNSHINE / "sunshine_state.json",
            *sorted((cutover.IDENTITY / "peer-certificates").iterdir()),
        ]:
            info = item.lstat()
            print(
                "metadata:",
                str(item),
                info.st_uid,
                info.st_gid,
                oct(info.st_mode & 0o777),
                info.st_nlink,
                info.st_size,
            )
        path = evidence_root / "failure-held.json"
        print(path.read_text() if path.exists() else "no failure")
        path = path.with_name("commitments-refused.json")
        if path.exists():
            print(path.read_text())
        for recovery in sorted(path.parent.glob("recovery-refused-*.json")):
            print(recovery.read_text())
        print(call(["zao-verify-commitments"]))
    elif mode == "recover":
        print(call([metadata["runner"], *params("recover")]))
    elif mode == "relay-cache-refuses":
        args = cutover.arguments(params("run"))
        path = Path(args.verification_client_root) / "federation/peers.json"
        before = path.read_bytes()
        Manager().call("stop", "strfry.service", "cutover-relay-route.service")
        try:
            cutover.command(
                [
                    tools["ownerVerify"],
                    "relay-check",
                    args.verification_client_root,
                    args.verification_device,
                    args.new_owner,
                    args.verification_event,
                    args.device,
                    '["ws://127.0.0.1:7777"]',
                ],
                timeout=170,
            )
        except cutover.Refusal:
            pass
        else:
            raise AssertionError(
                "cached directory passed with configured relay unavailable"
            )
        assert path.read_bytes() == before
    elif mode in ("assert-accepted", "assert-accepted-boot"):
        state = Path("/var/lib/korri-maintenance-isolation")
        for name in (
            "baseline.json",
            "local-accepted.json",
            "acceptance.json",
            "automatic-revoked.json",
        ):
            assert (
                json.loads((state / name).read_text())["historical_client_proof"]
                == cutover.HISTORICAL_CLIENT_PROOF
            )
        assert (
            json.loads((state / "automatic-provisioned.json").read_text())["provision"]
            == "authenticated encrypted producer RPC"
        )
        assert not Path("/var/lib/retired-client.key").exists()
        assert not Path("/var/lib/retired-client.crt").exists()
        assert (
            cutover.sunshine_state_evidence(cutover.SUNSHINE / "sunshine_state.json")[
                1
            ]["gid"]
            == 980
        )
        for path in (
            state / "automatic-probe/client.crt",
            state / "automatic-probe/client.key",
        ):
            cutover.file_evidence(path, (0, 0), 0o600)
        assert_preserved_state()
        baseline = json.loads(
            Path("/var/lib/korri-maintenance-isolation/baseline.json").read_text()
        )
        generation = baseline["parameters"]["candidate"]
        cutover.verify_boot_default(generation)
        assert str(Path("/run/current-system").resolve()) == generation
        if mode == "assert-accepted-boot":
            assert str(Path("/run/booted-system").resolve()) == generation
        for manager, units in (
            (Manager(), SYSTEM_UNITS),
            (Manager(cutover.USER), USER_UNITS),
        ):
            for unit in units:
                assert (
                    not (
                        Path("/etc/systemd/system.control")
                        if not manager.user
                        else cutover.HOME / ".config/systemd/user.control"
                    )
                    .joinpath(unit + ".d", cutover.GATE_NAME)
                    .exists()
                )
        assert "korri_maintenance_isolation" not in call(
            [tools["nft"], "list", "tables"]
        )
        assert Manager().show("korrid.service", "ActiveState") == "active"
        args = (
            cutover.arguments(params("run"))
            if mode == "assert-accepted"
            else cutover.arguments(
                [
                    "run",
                    *[
                        part
                        for key, value in baseline["parameters"].items()
                        if key != "action"
                        for part in ("--" + key.replace("_", "-"), str(value))
                    ],
                ]
            )
        )
        cutover.verify_new_state(args, tools, baseline)
        observation = Isolation(cutover.USER, cutover.HOME)
        cutover.idle(tools, observation)
        cutover.running_evidence(
            generation, metadata["candidateBundle"], observation, guard_state="released"
        )
    elif mode in ("assert-release-failed", "assert-release-failed-boot"):
        assert_preserved_state()
        baseline = json.loads(
            Path("/var/lib/korri-maintenance-isolation/baseline.json").read_text()
        )
        generation = baseline["parameters"]["candidate"]
        cutover.verify_boot_default(generation)
        if mode == "assert-release-failed-boot":
            assert str(Path("/run/booted-system").resolve()) == generation
        for manager, units in (
            (Manager(), SYSTEM_UNITS),
            (Manager(cutover.USER), USER_UNITS),
        ):
            for unit in units:
                if manager.show(unit, "LoadState") != "masked":
                    manager.call("start", unit)
                assert manager.show(unit, "ActiveState") in ("inactive", "failed")
    elif mode in ("assert-recovery", "assert-recovery-boot"):
        assert_preserved_state(metadata["recoveryBundle"])
        baseline = json.loads(
            Path("/var/lib/korri-maintenance-isolation/baseline.json").read_text()
        )
        generation = baseline["parameters"]["recovery"]
        cutover.verify_boot_default(generation)
        assert str(Path("/run/current-system").resolve()) == generation
        if mode == "assert-recovery-boot":
            assert str(Path("/run/booted-system").resolve()) == generation
            for manager, units in (
                (Manager(), SYSTEM_UNITS),
                (Manager(cutover.USER), USER_UNITS),
            ):
                for unit in units:
                    if manager.show(unit, "LoadState") != "masked":
                        manager.call("start", unit)
                    assert manager.show(unit, "ActiveState") in ("inactive", "failed")
        else:
            assert_authority_closed()
    elif mode == "assert-boot-closed":
        assert_boot_closed()
    elif mode == "recover-refuses":
        result = subprocess.run(
            [metadata["runner"], *params("recover")], capture_output=True
        )
        if result.returncode == 0:
            deadline = time.monotonic() + 45
            manager = Manager()
            while manager.show(cutover.SUPERVISOR, "ActiveState") != "failed":
                assert time.monotonic() < deadline, (
                    "recovery did not refuse stopped candidate as non-idle"
                )
                time.sleep(0.1)
        assert_cut()  # Neither request collision nor failed idle proof may downgrade.
    else:
        raise AssertionError("unknown fixture mode")
