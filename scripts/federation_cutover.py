"""Test/implementation-only fixed Zao cutover supervisor. Not approved for live use.

One root lifetime owns prepare, producer acceptance, boot persistence and release.
Failure holds authority closed and keeps the process-local network receipt for an
explicit software-only recovery request. No accept override or trust restoration.
"""

import argparse
import grp
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import resource
import shlex
import signal
import socket
import stat
import struct
import subprocess
import sys
import time

# The wrapper uses Python isolated mode. Import only these adjacent, rooted files.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from federation_isolation import (  # noqa: E402
    ACTIVATION_WORKER,
    GATE_NAME,
    SYSTEM_UNITS,
    Isolation,
    Manager,
    Refusal,
)
from federation_network_isolation import NetworkIsolation  # noqa: E402

USER = "simonwjackson"
HOME = Path("/home/simonwjackson")
PRIVATE = Path("/var/lib/korrid")
IDENTITY = PRIVATE / "identity"
SUNSHINE = HOME / ".config/sunshine"
SUNSHINE_UNIT = "sunshine.service"
# The one actual listening nvhttp TLS endpoint of the fixed base port 47989.
# Both the acceptance certificate checks and the readiness gate use exactly it.
SUNSHINE_HTTPS = ("127.0.0.1", 47984)
SELECTORS = Path("/nix/var/nix/gcroots/korri-bundle")
ROOTS = Path("/nix/var/nix/gcroots/federation-cutover")
SUPERVISOR = "korri-cutover-supervisor.service"
RECOVERY_REQUEST = Path("/run/korri-cutover-recovery.sock")
PROFILE = Path("/nix/var/nix/profiles/system")
TEST_OWNER = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
MAINTENANCE = (
    "korri-bundle-selector.service",
    "korri-compositor.service",
    "korri-input-seat-receiver.service",
    "korri-certificate-control.socket",
    "sunshine.service",
)
ADAPTER_ENV = {
    "KORRID_PRIVATE_STATE_ROOT": str(PRIVATE),
    "KORRID_SUNSHINE_CERTIFICATE_CONTROL_SOCKET": "/run/korri-certificate-control/control.sock",
    "KORRID_SUNSHINE_CERTIFICATE_CONTROL_GID": "976",
    "KORRID_SUNSHINE_CERTIFICATE_CONTROL_PEER_UID": "0",
    "KORRID_SUNSHINE_CERTIFICATE_CONTROL_PEER_GID": "0",
}
# hosts/zao/commitments.nix retirement names not covered by USER_UNITS. An
# inactive loaded/transient authority is not absence and must not be adopted.
LEGACY_UNGATED = (
    "korri-session.target",
    "korri-compositor.service",
    "korri-sunshine.service",
    "pipewire.socket",
    "pipewire-pulse.socket",
    "gamemoded.service",
    "pipewire.service",
    "pipewire-pulse.service",
    "wireplumber.service",
)
HISTORICAL_CLIENT_PROOF = {
    "status": "deferred",
    "observation": "historically paired Moonlight TLS client was not tested",
    "decision": "00ca5161-b453-4991-8474-0273285c28ca:proceed-defer-old-client-probe",
}
PENDING = [
    "matching selected candidate startup with exact actual control idle",
    "producer-encrypted new-owner success and fresh old-owner/pass denial",
    "actual Sunshine empty membership, restart, authenticated automatic certificate provision/TLS/revoke and host attestation",
    "configured relay discovery and authenticated remembered recovery",
    "six actual Zao commitments and running executable/credential verification",
    "explicit new-owner system profile and verified boot action",
    "exact owned guard release followed by selected runtime verification",
]


def require(condition, message):
    if not condition:
        raise Refusal(message)


def decode(text):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "duplicate JSON key")
            result[key] = value
        return result

    try:
        return json.loads(text, object_pairs_hook=unique)
    except (ValueError, RecursionError) as error:
        raise Refusal("invalid bounded JSON evidence") from error


def decode_idle(response):
    require(len(response) <= 65536, "oversized status response")
    expected = {
        "_tag": "app.session.status",
        "outcome": {
            "_tag": "Err",
            "payload": {
                "code": "NoActiveSession",
                "message": "no host launch is active",
            },
        },
    }
    require(
        decode(response) == expected,
        "not the exact successful NoActiveSession response",
    )
    return expected


def directory(path, owner=None, mode=None):
    """Pin each ancestor with openat/nofollow; no pathname traversal through links."""
    path = Path(path)
    require(
        path.is_absolute() and str(path) == os.path.normpath(path), "noncanonical path"
    )
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        root_info = os.fstat(fd)
        require(
            root_info.st_uid == 0 and not root_info.st_mode & 0o022,
            "unsafe filesystem root",
        )
        for name in path.parts[1:]:
            child = os.open(
                name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd
            )
            os.close(fd)
            fd = child
            info = os.fstat(fd)
            require(
                info.st_uid in (0, 976, 1000)
                and (
                    not info.st_mode & 0o022
                    or info.st_uid == 0
                    and info.st_mode & stat.S_ISVTX
                ),
                "unsafe directory ancestor",
            )
        info = os.fstat(fd)
        if owner is not None:
            require((info.st_uid, info.st_gid) == owner, "directory identity drift")
        if mode is not None:
            require(stat.S_IMODE(info.st_mode) == mode, "directory mode drift")
        return fd
    except BaseException:
        os.close(fd)
        raise


def file_evidence(path, owner, mode, limit=65536):
    path = Path(path)
    parent = directory(path.parent)
    try:
        fd = os.open(
            path.name, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW, dir_fd=parent
        )
        try:
            before = os.fstat(fd)
            require(
                stat.S_ISREG(before.st_mode)
                and before.st_nlink == 1
                and (before.st_uid, before.st_gid) == owner
                and stat.S_IMODE(before.st_mode) == mode
                and 0 <= before.st_size <= limit,
                "unsafe bounded file",
            )
            data = bytearray()
            while len(data) <= limit:
                part = os.read(fd, min(65536, limit + 1 - len(data)))
                if not part:
                    break
                data.extend(part)
            after = os.fstat(fd)

            def stable(info):
                return (
                    info.st_dev,
                    info.st_ino,
                    info.st_uid,
                    info.st_gid,
                    info.st_mode,
                    info.st_nlink,
                    info.st_size,
                    info.st_mtime_ns,
                    info.st_ctime_ns,
                )

            require(
                stable(before) == stable(after) and len(data) == before.st_size,
                "file changed during read",
            )
            current = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
            require(stable(current) == stable(after), "file path changed during read")
            return bytes(data), {
                "dev": before.st_dev,
                "ino": before.st_ino,
                "uid": before.st_uid,
                "gid": before.st_gid,
                "mode": before.st_mode,
                "size": before.st_size,
                "nlink": before.st_nlink,
                "mtime_ns": before.st_mtime_ns,
                "ctime_ns": before.st_ctime_ns,
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        finally:
            os.close(fd)
    finally:
        os.close(parent)


def entries(path, owner, limit=4096):
    fd = directory(path, owner, 0o700)
    try:
        names = []
        with os.scandir(fd) as stream:
            for entry in stream:
                require(len(names) < limit, "directory inventory exceeds bound")
                names.append(entry.name)
        return sorted(names)
    finally:
        os.close(fd)


def empty_journal():
    require(
        entries(PRIVATE / "host-session", (976, 976), 16) == [],
        "journal is not exactly empty; never delete recovery facts",
    )


def absent_state():
    for path in (
        PRIVATE / "federation",
        IDENTITY / "nip46-client.key",
        IDENTITY / "nip46.connection.json",
    ):
        fd = directory(path.parent, (976, 976), 0o700)
        try:
            try:
                os.stat(path.name, dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                continue
            raise Refusal("federation/NIP46 state appeared; separate review required")
        finally:
            os.close(fd)


def sunshine_state_digest(raw, *, retired=False):
    """Lossless retirement projection: exclude only root.devices/named_devices.

    Matches offline-retirement.cpp checked_document's integer/depth/duplicate
    restrictions. Keep only a digest; never serialize old memberships to evidence.
    """
    document = decode(raw)

    def lossless(value, depth=0):
        require(depth <= 64, "state nesting bound exceeded")
        require(not isinstance(value, float), "non-lossless Sunshine number")
        if isinstance(value, int) and not isinstance(value, bool):
            require(-(2**63) <= value < 2**64, "Sunshine integer overflow")
        if isinstance(value, dict):
            for child in value.values():
                lossless(child, depth + 1)
        elif isinstance(value, list):
            for child in value:
                lossless(child, depth + 1)

    lossless(document)
    require(
        isinstance(document, dict)
        and isinstance(document.get("root"), dict)
        and isinstance(document["root"].get("uniqueid"), str),
        "invalid Sunshine host document",
    )
    root = document["root"]
    for name in ("devices", "named_devices"):
        if name not in root:
            continue
        clients = root.pop(name)
        require(isinstance(clients, list) or clients == "", "invalid client collection")
        if retired:
            require(clients in ([], ""), "Sunshine membership reappeared")
        for client in clients:
            require(isinstance(client, dict), "invalid Sunshine client")
            if name == "named_devices":
                require(
                    all(
                        isinstance(client.get(key), str)
                        for key in ("name", "uuid", "cert")
                    ),
                    "invalid named client",
                )
            elif "certs" in client:
                certs = client["certs"]
                require(
                    (
                        isinstance(certs, list)
                        and all(isinstance(cert, str) for cert in certs)
                    )
                    or certs == "",
                    "invalid legacy certificates",
                )
    try:
        canonical = json.dumps(
            document,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    except (UnicodeError, ValueError) as error:
        raise Refusal("non-lossless Sunshine document") from error
    return hashlib.sha256(canonical).hexdigest()


def sunshine_state_evidence(path):
    """Only Sunshine's state writer may replace users:100 with its fixed GID 980.

    certificate-control's atomic 0600 temporary file inherits Sunshine's actual
    primary group. No chown/repair occurs; all other private files stay exact.
    Preflight and offline retirement separately require the original GID 100.
    """
    group = Path(path).lstat().st_gid
    require(group in (100, 980), "unexpected Sunshine state writer group")
    return file_evidence(path, (1000, group), 0o600, 16 * 1024 * 1024)


def fingerprints():
    """Fixed baseline paths plus bounded producer grant/revocation directories.

    Fingerprints only, never private snapshots. Unrelated game/storage trees are
    not traversed, initialized, restored or passed to any mutation operation.
    """
    result = {}
    for path, owner, mode, limit in (
        (IDENTITY / "device.key", (976, 976), 0o600, 128),
        (IDENTITY / "owner.event.json", (976, 976), 0o600, 65536),
        (SUNSHINE / "sunshine_state.json", (1000, 100), 0o600, 16 * 1024 * 1024),
        (SUNSHINE / "sunshine.conf", (1000, 100), 0o644, 65536),
        (SUNSHINE / "credentials/cacert.pem", (1000, 100), 0o644, 65536),
        (SUNSHINE / "credentials/cakey.pem", (1000, 100), 0o600, 65536),
        (SUNSHINE / "apps.json", (1000, 100), 0o644, 4 * 1024 * 1024),
        (Path("/var/lib/korri/config.yaml"), (976, 976), 0o600, 4 * 1024 * 1024),
        (Path("/var/lib/korri/library.yaml"), (976, 976), 0o600, 4 * 1024 * 1024),
    ):
        raw, evidence = (
            sunshine_state_evidence(path)
            if path == SUNSHINE / "sunshine_state.json"
            else file_evidence(path, owner, mode, limit)
        )
        if path == SUNSHINE / "sunshine_state.json":
            evidence["nonmembership_sha256"] = sunshine_state_digest(raw)
            state_root = decode(raw)["root"]
            evidence["memberships_empty"] = all(
                state_root.get(name, []) in ([], "")
                for name in ("devices", "named_devices")
            )
        result[str(path)] = evidence
    total = 0
    for name, bound in (
        ("peer-certificates", 131072),
        ("authorization-revocations", 65536),
    ):
        root = IDENTITY / name
        for name in entries(root, (976, 976), 4096):
            path = root / name
            evidence = file_evidence(path, (976, 976), 0o600, bound)[1]
            total += evidence["size"]
            require(total <= 32 * 1024 * 1024, "trust inventory exceeds total bound")
            result[str(path)] = evidence
    for path, owner, mode in (
        (PRIVATE, (976, 976), 0o700),
        (IDENTITY, (976, 976), 0o700),
        (SUNSHINE, (1000, 100), 0o700),
        (HOME / ".config", (1000, 100), 0o755),
        (SUNSHINE / "credentials", (1000, 100), 0o755),
    ):
        fd = directory(path, owner, mode)
        info = os.fstat(fd)
        os.close(fd)
        result[str(path)] = {
            "dev": info.st_dev,
            "ino": info.st_ino,
            "uid": info.st_uid,
            "gid": info.st_gid,
            "mode": info.st_mode,
        }
    return result


def immutable(path, executable=False, root=False):
    original = os.fspath(path)
    path = Path(path)
    require(original == str(path), "noncanonical immutable path spelling")
    require(
        re.fullmatch(r"/nix/store/[0-9a-df-np-sv-z]{32}-[^/]+(?:/[^/]+)*", str(path)),
        "explicit immutable store path required",
    )
    require(str(path) == os.path.normpath(path), "noncanonical store path")
    if root:
        require(
            path.parent == Path("/nix/store")
            and path.is_dir()
            and not path.is_symlink(),
            "direct store-root directory required",
        )
    resolved = path.resolve(strict=True)
    require(str(resolved).startswith("/nix/store/"), "immutable path escapes store")
    info = resolved.stat()
    require(info.st_uid == 0 and not info.st_mode & 0o222, "mutable store artifact")
    if executable:
        require(stat.S_ISREG(info.st_mode) and info.st_mode & 0o111, "not executable")
    return str(path)


class PrimitiveFailure(Refusal):
    """Bounded child diagnostics stay private; str() contains only a public label."""

    def __init__(self, executable, code, stdout):
        super().__init__(f"child refused: {Path(executable).name} exit={code}")
        self.code = code
        self.stdout = stdout


def command(argv, *, data=None, identity=None, environment=None, timeout=30):
    """Capture primitive diagnostics; never publish certificate/key/error bodies."""
    options = {}
    if identity:
        options = dict(user=identity[0], group=identity[1], extra_groups=[])
    env = {
        "PATH": os.environ["PATH"],
        "LC_ALL": "C",
        "HOME": "/root",
        "SYSTEMD_COLORS": "0",
        "SYSTEMD_PAGER": "",
        **(environment or {}),
    }
    process = subprocess.Popen(
        argv,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
        env=env,
        **options,
    )
    try:
        stdout, stderr = process.communicate(data, timeout=timeout)
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.communicate()
        raise Refusal("bounded child interrupted; keep authority closed") from None
    require(len(stdout) <= 262144 and len(stderr) <= 262144, "oversized child output")
    if process.returncode != 0:
        raise PrimitiveFailure(argv[0], process.returncode, stdout)
    return stdout


def raw_selector(name):
    fd = directory(SELECTORS, (0, 0), 0o711)
    try:
        info = os.stat(name, dir_fd=fd, follow_symlinks=False)
        require(
            stat.S_ISLNK(info.st_mode)
            and (info.st_uid, info.st_gid) == (0, 0)
            and info.st_nlink == 1,
            "unsafe selector",
        )
        target = os.readlink(name, dir_fd=fd)
        immutable(target, root=True)
        return target
    finally:
        os.close(fd)


def public_verify(tools, args, new=False):
    path = Path(args.event) if new else IDENTITY / "owner.event.json"
    if new:
        immutable(path)
        require(
            path.stat().st_size <= 65536
            and Path(args.template).stat().st_size <= 65536,
            "oversized public binding/template",
        )
        raw = path.read_bytes()
        decode(raw)
        decode(Path(args.template).read_bytes())
        require(
            len(raw) <= 65536 and hashlib.sha256(raw).hexdigest() == args.event_sha256,
            "approved event digest changed",
        )
    else:
        raw = file_evidence(path, (976, 976), 0o600)[0]
    command(
        [
            tools["ownerVerify"],
            args.device,
            args.new_owner if new else TEST_OWNER,
            args.new_event if new else args.old_event,
            args.template if new else "-",
        ],
        data=raw,
    )
    return raw


def key_matches(tools, expected, path=IDENTITY / "device.key", owner=(976, 976)):
    raw = file_evidence(path, owner, 0o600, 128)[0]
    require(
        re.fullmatch(b"[0-9a-f]{64}\n?", raw), "invalid existing device key encoding"
    )
    der = (
        bytes.fromhex("302e0201010420")
        + bytes.fromhex(raw.decode().strip())
        + bytes.fromhex("a00706052b8104000a")
    )
    public = command(
        [tools["openssl"], "ec", "-inform", "DER", "-pubout", "-outform", "DER"],
        data=der,
    )
    require(
        len(public) == 88 and public[-65] == 4 and public[-64:-32].hex() == expected,
        "existing device key does not match exact expected public key",
    )


def games(managers):
    for manager, _ in managers:
        require(
            not manager.call(
                "list-units",
                "korri-game-*.service",
                "--all",
                "--no-legend",
                "--no-pager",
                "--plain",
            ),
            "game-unit evidence in manager",
        )


def idle(tools, isolation):
    require(
        isolation.managers[0][0].show("korrid.service", "ActiveState") == "active",
        "korrid not already active; never infer idle or socket-activate it",
    )
    fd = directory("/run/korrid-control", (0, 977), 0o750)
    try:
        info = os.stat("control.sock", dir_fd=fd, follow_symlinks=False)
        require(
            stat.S_ISSOCK(info.st_mode)
            and (info.st_uid, info.st_gid) == (0, 977)
            and stat.S_IMODE(info.st_mode) == 0o660,
            "control socket metadata drift",
        )
    finally:
        os.close(fd)
    response = command(
        [
            tools["curl"],
            "--fail",
            "--silent",
            "--connect-timeout",
            "1",
            "--max-time",
            "3",
            "--max-filesize",
            "65536",
            "--unix-socket",
            "/run/korrid-control/control.sock",
            "http://localhost/rpc",
            "-H",
            "content-type: application/json",
            "-d",
            '{"_tag":"app.session.status","payload":{}}',
        ],
        identity=(977, 977),
        timeout=6,
    )
    result = decode_idle(response)
    games(isolation.managers)
    empty_journal()
    return result


def await_idle(tools, isolation):
    deadline = time.monotonic() + 30
    while True:
        try:
            return idle(tools, isolation)
        except Refusal:
            require(
                time.monotonic() < deadline,
                "matching daemon failed exact idle readiness",
            )
            time.sleep(0.2)


def unit_text(generation, unit):
    path = Path(generation) / "etc/systemd/system" / unit
    immutable(path)
    text = path.read_text()
    dropins = path.with_name(path.name + ".d")
    if dropins.exists():
        immutable(dropins)
        paths = sorted(dropins.iterdir())
        require(len(paths) <= 32, "too many generation drop-ins")
        for path in paths:
            immutable(path)
            require(path.suffix == ".conf", "unknown generation drop-in")
            text += "\n" + path.read_text()
    require(len(text) <= 262144 and GATE_NAME not in text, "generation owns gate path")
    return text


def environment(text):
    result = {}
    for line in text.splitlines():
        require(
            not line.startswith(
                ("EnvironmentFile=", "UnsetEnvironment=", "PassEnvironment=")
            ),
            "unsupported indirect runtime environment",
        )
        if line.startswith("Environment="):
            for assignment in shlex.split(line.removeprefix("Environment=")):
                key, value = assignment.split("=", 1)
                require(key not in result, "duplicate runtime environment")
                result[key] = value
    return result


def unit_setting(text, name, default=""):
    values = [
        line.split("=", 1)[1]
        for line in text.splitlines()
        if line.startswith(name + "=")
    ]
    require(len(values) <= 1, "ambiguous unit setting: " + name)
    return values[0] if values else default


def reject_condition_reset(text):
    require(
        all(line.strip() != "ConditionPathExists=" for line in text.splitlines()),
        "unit configuration resets startup conditions",
    )


def reject_ungated_legacy(isolation):
    manager = isolation.managers[1][0]
    for unit in LEGACY_UNGATED:
        require(
            manager.show(unit, "LoadState") == "not-found"
            and manager.show(unit, "ActiveState") == "inactive"
            and manager.show(unit, "FragmentPath") == ""
            and manager.show(unit, "Transient") == "no",
            "ungated legacy authority is not proven absent: " + unit,
        )


def preflight_gate_namespace(isolation):
    reject_ungated_legacy(isolation)
    # A differently named override can reset conditions after our drop-in. Do
    # not mistake a new filename for exclusive ownership of the loaded policy.
    for manager, units in isolation.managers:
        for unit in units:
            root = isolation.gate_path(manager.user, unit).parent
            require(
                not root.exists() and not root.is_symlink(),
                "pre-existing authority control drop-ins require review",
            )
            for name in shlex.split(manager.show(unit, "DropInPaths")):
                path = Path(name).resolve(strict=True)
                immutable(path)
                require(path.stat().st_size <= 262144, "oversized loaded drop-in")
                reject_condition_reset(path.read_text())


def sunshine_command(argv):
    # config.cpp::parse selects the LAST positional file and applies overrides.
    # log_path only redirects logs; encoder only selects video.encoder. These are
    # the producer's actual Zao tail, not a general command-line option parser.
    require(
        len(argv) >= 2
        and argv[1] == str(SUNSHINE / "sunshine.conf")
        and tuple(argv[2:])
        in ((), ("log_path=/dev/null",), ("log_path=/dev/null", "encoder=nvenc")),
        "unsupported Sunshine command: exactly one inspected configuration required",
    )
    immutable(argv[0], executable=True)


def sunshine_configuration(text):
    # Bounded subset of parse_option: reject list continuation, duplicates and
    # control whitespace rather than inspect a line swallowed by another value.
    # parse_option retains inline '#' text in path values (begin_val..endl),
    # despite using endc for name parsing. Only whole-line comments are supported.
    require(
        not any(char in text for char in "\x00\r\v\f[]"),
        "unsupported Sunshine configuration grammar",
    )
    values = {}
    for line in text.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.fullmatch(
            r"[ \t]*([a-zA-Z_][a-zA-Z_0-9]*)[ \t]*=[ \t]*([^#]*)", line
        )
        require(match is not None, "unsupported Sunshine configuration line")
        name, value = match[1], match[2] or ""
        require(name not in values, "duplicate Sunshine setting")
        values[name] = value
    require(
        values.get("file_state", "")
        in ("", "sunshine_state.json", str(SUNSHINE / "sunshine_state.json")),
        "Sunshine targets another trust document",
    )
    for setting, filename in (("cert", "cacert.pem"), ("pkey", "cakey.pem")):
        relative = "credentials/" + filename
        require(
            values.get(setting, "") in ("", relative, str(SUNSHINE / relative)),
            "Sunshine TLS inputs differ from validated credentials",
        )
    require(
        values.get("port", "47989") in ("", "47989"),
        "fixed network policy requires Sunshine base port 47989",
    )
    return values


def network_namespace_contract(text):
    require(
        unit_setting(text, "PrivateNetwork", "false") in ("false", "no", "0")
        and all(
            unit_setting(text, name) == ""
            for name in (
                "NetworkNamespacePath",
                "JoinsNamespaceOf",
                "RootDirectory",
                "RootImage",
            )
        ),
        "unsupported authority network/filesystem namespace",
    )


def loaded_sunshine_contract(generation, manager):
    expected = shlex.split(
        unit_setting(unit_text(generation, "sunshine.service"), "ExecStart")
    )
    sunshine_command(expected)
    text = manager.show("sunshine.service", "ExecStart")
    match = re.fullmatch(
        r"\{ path=([^;]+?) ; argv\[\]=([^;]+?) ; ignore_errors=no ; .* \}", text
    )
    require(
        match is not None
        and match[1] == expected[0]
        and match[2] == " ".join(expected),
        "loaded Sunshine command differs",
    )
    require(
        manager.show("sunshine.service", "PrivateNetwork") == "no"
        and all(
            manager.show("sunshine.service", name) == ""
            for name in (
                "NetworkNamespacePath",
                "JoinsNamespaceOf",
                "RootDirectory",
                "RootImage",
            )
        ),
        "loaded Sunshine namespace differs",
    )


def inspect_generation(args, generation, bundle, *, new_contract, binding):
    immutable(generation, root=True)
    immutable(bundle, root=True)
    immutable(Path(generation) / "bin/switch-to-configuration", executable=True)
    control = Path(generation) / "etc/systemd/system.control"
    require(
        not control.exists() and not control.is_symlink(),
        "generation owns persistent gate namespace",
    )
    for unit in SYSTEM_UNITS:
        text = unit_text(generation, unit)
        reject_condition_reset(text)
    selector = unit_text(generation, "korri-bundle-selector.service")
    require(bundle in selector, "generation declares another bundle")
    found = set(
        re.findall(r"/nix/store/[0-9a-df-np-sv-z]{32}-korri-bundle-[^\s\";]+", selector)
    )
    require(found == {bundle}, "ambiguous generation bundle")
    env = environment(unit_text(generation, "korrid.service"))
    prefix = "KORRID_RUNTIME_" if new_contract else "KORRID_GAMEPLAY_"
    other = "KORRID_GAMEPLAY_" if new_contract else "KORRID_RUNTIME_"
    require(
        env.get(prefix + "UID") == "1000"
        and env.get(prefix + "GID") == "100"
        and not any(key.startswith(other) for key in env),
        "mixed or wrong runtime IDs",
    )
    require(
        env.get("KORRID_PRIVATE_STATE_ROOT") == str(PRIVATE)
        and env.get("KORRID_SUNSHINE_PRIVATE_STATE_ROOT") == str(SUNSHINE)
        and env.get("KORRI_BUNDLE_ACTIVE") == str(SELECTORS / "active"),
        "runtime path drift",
    )
    importer = unit_text(generation, "korrid-identity.service")
    if binding:
        require(
            args.event in importer,
            "generation does not pin exact approved public event",
        )
    else:
        require(args.old_binding in importer, "old generation owner artifact drift")
    pinned = args.event if binding else args.old_binding
    importer_argv = shlex.split(unit_setting(importer, "ExecStart"))
    require(
        (
            importer_argv[1:] == ["identity", "import", "--file", pinned]
            or (
                Path(importer_argv[0]).name == "korri-bundle-launch"
                and importer_argv[1:]
                == ["korrid", "identity", "import", "--file", pinned]
            )
        ),
        "immutable importer command differs",
    )
    for unit, user, group in (
        ("korrid.service", "korrid", "korrid"),
        ("korrid-identity.service", "korrid", "korrid"),
        ("korri-inputd.service", "korri-inputd", "korri-control"),
        ("inputplumber.service", "root", "root"),
        ("korri-input-seat-receiver.service", "root", "root"),
        ("korri-bundle-selector.service", "root", "root"),
        ("korri-compositor.service", USER, "users"),
        ("sunshine.service", USER, "korri-sunshine-input-seat"),
    ):
        text = unit_text(generation, unit)
        require(
            unit_setting(text, "User", "root") == user
            and unit_setting(text, "Group", "root") == group,
            "declared runtime credentials differ: " + unit,
        )
    sunshine_text = unit_text(generation, "sunshine.service")
    sunshine_argv = shlex.split(unit_setting(sunshine_text, "ExecStart"))
    sunshine_command(sunshine_argv)
    for unit in ("sunshine.service", "korrid.service"):
        network_namespace_contract(unit_text(generation, unit))
    sunshine_env = environment(sunshine_text)
    # config.cpp::path_f resolves relative file_state under Linux appdata(),
    # whose exact HOME/XDG/ConfigurationDirectory precedence is in misc.cpp.
    require(
        unit_setting(sunshine_text, "ConfigurationDirectory") == ""
        and sunshine_env.get("HOME") in (None, "", str(HOME))
        and all(
            sunshine_env.get(name) in (None, "", str(HOME / ".config"))
            for name in ("XDG_CONFIG_HOME", "CONFIGURATION_DIRECTORY")
        )
        and sunshine_env.get("SUNSHINE_MIGRATE_CONFIG") != "1",
        "Sunshine appdata can move away from inspected private state",
    )
    sunshine_conf = file_evidence(SUNSHINE / "sunshine.conf", (1000, 100), 0o644)[
        0
    ].decode()
    sunshine_configuration(sunshine_conf)
    for name, value in {
        "KORRI_CERTIFICATE_CONTROL_UID": "976",
        "KORRI_CERTIFICATE_CONTROL_GID": "976",
        "KORRI_CERTIFICATE_CONTROL_OWNER_GID": "976",
        "KORRI_CERTIFICATE_CONTROL_MODE": "0660",
        "KORRI_CERTIFICATE_CONTROL_PATH": ADAPTER_ENV[
            "KORRID_SUNSHINE_CERTIFICATE_CONTROL_SOCKET"
        ],
    }.items():
        require(
            sunshine_env.get(name) == value, "Sunshine adapter credentials/path differ"
        )
    inspect_executable_images(generation, bundle)
    return env


def management(manager):
    result = {}
    for unit in ("sshd.service", "tailscaled.service", "user@1000.service"):
        require(
            manager.show(unit, "ActiveState") == "active", "management is not active"
        )
        pid = manager.show(unit, "MainPID")
        require(pid.isdigit() and int(pid) > 0, "management has no process")
        result[unit] = {"pid": pid, "restarts": manager.show(unit, "NRestarts")}
    # A real local SSH transport probe, not a process-state proxy. This is NOT
    # proof of the parent's remote SSH/Tailscale path; that remains acceptance.
    with socket.create_connection(("127.0.0.1", 22), timeout=3) as connection:
        connection.settimeout(3)
        require(
            connection.recv(256).startswith(b"SSH-2.0-"), "SSH transport probe failed"
        )
    return result


def unit_baseline(isolation):
    result = {}
    fields = (
        "Id",
        "LoadState",
        "ActiveState",
        "SubState",
        "MainPID",
        "NRestarts",
        "Result",
        "User",
        "Group",
        "ExecStart",
        "StateDirectory",
        "StateDirectoryMode",
        "FragmentPath",
    )
    for manager, units in isolation.managers:
        result["user_units" if manager.user else "system_units"] = {
            unit: {field: manager.show(unit, field) for field in fields}
            for unit in units
        }
    result["failed"] = {
        "user" if manager.user else "system": manager.call(
            "list-units", "--failed", "--no-legend", "--plain", "--no-pager"
        )
        for manager, _ in isolation.managers
    }
    return result


def save_private_bytes(artifacts, name, data):
    path = artifacts.state / name
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    artifacts.record(path)
    require(
        file_evidence(path, (0, 0), 0o600, 262144)[0] == data,
        "staged public/evidence bytes differ",
    )
    return str(path)


def save_private(artifacts, name, value):
    save_private_bytes(artifacts, name, json.dumps(value, sort_keys=True).encode())


def assert_materialized(args, generation, bundle, isolation, *, new_contract):
    require(
        str(Path("/run/current-system").resolve(strict=True)) == generation,
        "activation did not install exact generation",
    )
    require(raw_selector("active") == bundle, "active bundle drift")
    expected = inspect_generation(
        args, generation, bundle, new_contract=new_contract, binding=True
    )
    for unit in SYSTEM_UNITS:
        actual = Path("/etc/systemd/system") / unit
        source = Path(generation) / "etc/systemd/system" / unit
        require(
            actual.resolve(strict=True) == source.resolve(strict=True),
            "materialized unit differs",
        )
        actual_dropins = actual.with_name(actual.name + ".d")
        source_dropins = source.with_name(source.name + ".d")
        require(
            actual_dropins.exists() == source_dropins.exists(),
            "materialized drop-ins differ",
        )
        if source_dropins.exists():
            require(
                actual_dropins.resolve(strict=True)
                == source_dropins.resolve(strict=True),
                "materialized drop-in path drift",
            )
    isolation.verify_activation_lists()
    isolation.verify_closed()
    return expected


def activate(tools, generation, isolation, action="test"):
    """Independent worker waits for recorded invocation before executing activation."""
    isolation.verify_closed()
    manager = isolation.managers[0][0]
    require(
        manager.show(ACTIVATION_WORKER, "ActiveState") in ("inactive", "failed"),
        "activation worker already running",
    )
    go = None
    try:
        try:
            command(
                [
                    tools["systemdRun"],
                    "--unit=" + ACTIVATION_WORKER,
                    "--collect",
                    "--service-type=exec",
                    "--property=User=root",
                    "--property=Group=root",
                    "--property=KillMode=control-group",
                    "--property=RemainAfterExit=yes",
                    "--property=TimeoutStopSec=30",
                    "--property=UMask=0077",
                    str(Path(__file__).resolve().parents[1] / "bin/federation-cutover"),
                    "activation-worker",
                    generation,
                    action,
                ]
            )
        finally:
            # A response loss may still have created the bounded waiting worker.
            # Capture its exact invocation before any evidence or handshake write.
            if manager.show(ACTIVATION_WORKER, "ActiveState") not in (
                "inactive",
                "failed",
            ):
                isolation.own_activation_worker(
                    manager.show(ACTIVATION_WORKER, "InvocationID")
                )
        invocation = manager.show(ACTIVATION_WORKER, "InvocationID")
        require(
            isolation.worker_receipt is not None, "activation worker was not recorded"
        )
        go = Path("/run") / ("activation-" + invocation)
        isolation.artifacts.file(go, b"recorded\n")
        deadline = time.monotonic() + 180
        while manager.show(ACTIVATION_WORKER, "SubState") not in (
            "exited",
            "dead",
            "failed",
        ):
            require(time.monotonic() < deadline, "activation timed out")
            time.sleep(0.1)
        require(
            manager.show(ACTIVATION_WORKER, "Result") == "success"
            and manager.show(ACTIVATION_WORKER, "ExecMainStatus") == "0",
            "test activation failed; no downgrade attempted",
        )
    finally:
        # Stop/reap the exact recorded worker, cancel explicit affected jobs and
        # stop user activation outside its cgroup. Never delete /run/nixos lists.
        isolation.close()
    require(go is not None, "activation handshake missing")
    isolation.artifacts.restore([go])


def maintenance(tools, args, generation, bundle, isolation, network):
    env = assert_materialized(args, generation, bundle, isolation, new_contract=True)
    require(
        all(env.get(key) == value for key, value in ADAPTER_ENV.items()),
        "adapter environment drift",
    )
    network.verify()
    # Compose ONLY the inspected Sunshine dependency closure. Keep all other masks.
    isolation.artifacts.verify()
    isolation.artifacts.restore(
        [isolation.mask_root(False) / unit for unit in MAINTENANCE]
    )
    manager = isolation.managers[0][0]
    manager.call("daemon-reload")
    loaded_sunshine_contract(generation, manager)
    for unit in MAINTENANCE:
        isolation.artifacts.file(isolation.permit_path(False, unit), b"maintenance\n")
    try:
        for unit in MAINTENANCE:
            require(
                str(isolation.gate_path(False, unit))
                in manager.show(unit, "DropInPaths"),
                "maintenance startup gate not loaded",
            )
        manager.call("start", "sunshine.service")
        require(
            manager.show("sunshine.service", "ActiveState") == "active",
            "Sunshine did not start",
        )
        # This block ends in close(), which stops Sunshine. Never signal it
        # before its main loop can act on the signal.
        await_sunshine_ready(manager)
        network.verify()
        fd = directory("/run/korri-certificate-control", (0, 976), 0o751)
        try:
            info = os.stat("control.sock", dir_fd=fd, follow_symlinks=False)
            require(
                stat.S_ISSOCK(info.st_mode)
                and (info.st_uid, info.st_gid) == (0, 976)
                and stat.S_IMODE(info.st_mode) == 0o660,
                "certificate socket drift",
            )
        finally:
            os.close(fd)
        count = len(entries(IDENTITY / "peer-certificates", (976, 976)))
        output = command(
            [
                tools["korrid"],
                "identity",
                "reconcile-stale-grants-offline",
                "--expected-device",
                args.device,
                "--expected-owner",
                args.new_owner,
                "--expected-event",
                args.new_event,
            ],
            identity=(976, 976),
            environment=ADAPTER_ENV,
        )
        require(
            output
            == f"Reconciled {count} stale client grants; remaining grants: 0.\n".encode(),
            "grant reconciliation output did not match complete inventory",
        )
        require(
            entries(IDENTITY / "peer-certificates", (976, 976)) == [], "grants remain"
        )
        network.verify()
    finally:
        isolation.close()


def check_preserved(before, after, removed_grants=False):
    state = str(SUNSHINE / "sunshine_state.json")
    if state in before or state in after:
        require(
            before.get(state, {}).get("nonmembership_sha256") is not None
            and before[state]["nonmembership_sha256"]
            == after.get(state, {}).get("nonmembership_sha256")
            and after.get(state, {}).get("memberships_empty") is True,
            "nonmembership Sunshine state changed",
        )
    allowed = {
        str(IDENTITY / "owner.event.json"),
        str(SUNSHINE / "sunshine_state.json"),
    }
    if removed_grants:
        allowed |= {
            path
            for path in before
            if Path(path).parent == IDENTITY / "peer-certificates"
        }
    require(
        {key: value for key, value in before.items() if key not in allowed}
        == {key: value for key, value in after.items() if key not in allowed},
        "preserved key/credential/config/revocation evidence changed",
    )


def validate_tls_inputs(tools):
    import ssl

    for certificate, key, owner, cert_mode in (
        (
            SUNSHINE / "credentials/cacert.pem",
            SUNSHINE / "credentials/cakey.pem",
            (1000, 100),
            0o644,
        ),
    ):
        before = (
            file_evidence(certificate, owner, cert_mode)[1],
            file_evidence(key, owner, 0o600)[1],
        )
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        try:
            context.load_cert_chain(certificate, key, password=b"")
            dates = (
                command(
                    [
                        tools["openssl"],
                        "x509",
                        "-in",
                        str(certificate),
                        "-noout",
                        "-startdate",
                        "-enddate",
                    ]
                )
                .decode()
                .splitlines()
            )
            require(
                len(dates) == 2
                and dates[0].startswith("notBefore=")
                and dates[1].startswith("notAfter="),
                "certificate validity unavailable",
            )
            now = time.time()
            require(
                ssl.cert_time_to_seconds(dates[0].split("=", 1)[1])
                <= now
                < ssl.cert_time_to_seconds(dates[1].split("=", 1)[1]),
                "TLS certificate is not currently valid",
            )
        except (ssl.SSLError, ValueError) as error:
            raise Refusal("TLS certificate/key pair is unusable") from error
        require(
            before
            == (
                file_evidence(certificate, owner, cert_mode)[1],
                file_evidence(key, owner, 0o600)[1],
            ),
            "TLS inputs changed during validation",
        )
    # Preserve the real server-validation contract, including CA parsing.
    ssl.create_default_context(cafile=str(SUNSHINE / "credentials/cacert.pem"))


def prepare(args, tools, isolation, network):
    artifacts = isolation.artifacts
    client_evidence(args, tools, pristine=True)
    validate_tls_inputs(tools)
    preflight_gate_namespace(isolation)
    for generation, bundle, new_contract, binding in (
        (args.old, args.old_bundle, False, False),
        (args.candidate, args.candidate_bundle, True, True),
        (args.recovery, args.recovery_bundle, False, True),
    ):
        inspect_generation(
            args, generation, bundle, new_contract=new_contract, binding=binding
        )
    require(
        not artifacts.records,
        "existing cutover evidence: no automatic retry or table adoption",
    )
    for name, target in (
        ("old", args.old),
        ("candidate", args.candidate),
        ("recovery", args.recovery),
        ("old-bundle", args.old_bundle),
        ("candidate-bundle", args.candidate_bundle),
        ("recovery-bundle", args.recovery_bundle),
        ("tooling", str(Path(__file__).resolve().parents[1])),
    ):
        artifacts.directory(ROOTS)
        artifacts.symlink(ROOTS / name, target)
    signed = public_verify(tools, args, new=True)
    template = Path(args.template).read_bytes()
    require(
        hashlib.sha256(template).hexdigest() == args.template_sha256,
        "approved template digest changed",
    )
    # The producer requires 0700/0600 sources. Stage ONLY these already-verified
    # public bytes, never a private key, pairing document or identity backup.
    staged_event = save_private_bytes(artifacts, "approved-owner.event.json", signed)
    staged_template = save_private_bytes(
        artifacts, "approved-owner.template.json", template
    )
    require(
        str(Path("/run/current-system").resolve(strict=True)) == args.old
        and str(Path("/nix/var/nix/profiles/system").resolve(strict=True)) == args.old
        and str(Path("/run/booted-system").resolve(strict=True)) == args.booted,
        "current/profile/booted generation drift",
    )
    require(
        raw_selector("active") == args.old_bundle
        and raw_selector("previous") == args.previous_bundle,
        "selector baseline drift",
    )
    current = public_verify(tools, args)
    require(
        Path(args.old_binding).stat().st_size <= 65536
        and decode(current) == decode(Path(args.old_binding).read_bytes()),
        "old immutable importer binding differs from current exact event",
    )
    key_matches(tools, args.device)
    absent_state()
    state = decode(
        file_evidence(
            SUNSHINE / "sunshine_state.json", (1000, 100), 0o600, 16 * 1024 * 1024
        )[0]
    )
    require(
        isinstance(state, dict)
        and isinstance(state.get("root"), dict)
        and state["root"].get("uniqueid") == args.host_uuid,
        "Sunshine host UUID differs from exact approved expectation",
    )
    del state  # No state body is recorded or passed to another serializer.
    baseline = {
        "profiles": {"current": args.old, "profile": args.old, "booted": args.booted},
        "selectors": {"active": args.old_bundle, "previous": args.previous_bundle},
        "fingerprints": fingerprints(),
        "idle": idle(tools, isolation),
        "management": management(isolation.managers[0][0]),
        "parameters": vars(args),
        "historical_client_proof": HISTORICAL_CLIENT_PROOF,
        "journal": {"entries": {}},
        "games": {"system": [], "user": []},
        **unit_baseline(isolation),
    }
    require(
        len(entries(IDENTITY / "peer-certificates", (976, 976))) == args.grants,
        "grant count differs from approved inventory",
    )
    save_private(artifacts, "baseline.json", baseline)
    preflight_gate_namespace(isolation)
    isolation.install()
    network.install()
    require(
        management(isolation.managers[0][0]) == baseline["management"],
        "management changed under filter",
    )
    # Reprove exact idle AFTER all startup gates and network policy, BEFORE stop.
    idle(tools, isolation)
    isolation.close()
    empty_journal()
    absent_state()
    require(
        fingerprints() == baseline["fingerprints"],
        "private inventory changed during quiescence",
    )
    public_verify(tools, args)
    network.verify()
    validate_tls_inputs(tools)
    # Monotonic from FIRST potential trust mutation, not owner-write success.
    save_private(artifacts, "trust-mutation-started.json", {"boot": artifacts.boot})
    digest = baseline["fingerprints"][str(SUNSHINE / "sunshine_state.json")]["sha256"]
    output = command(
        [
            tools["retire"],
            "--exclusive-quiescence-confirmed",
            "--state",
            str(SUNSHINE / "sunshine_state.json"),
            "--expect-host-uuid",
            args.host_uuid,
            "--expect-state-sha256",
            digest,
        ],
        identity=(1000, 100),
    )
    match = re.fullmatch(
        rb"retired_clients=([0-9]+) state_sha256=([0-9a-f]{64})\n", output
    )
    require(match is not None, "retirement result is unknown; never restore trust")
    require(
        file_evidence(
            SUNSHINE / "sunshine_state.json", (1000, 100), 0o600, 16 * 1024 * 1024
        )[1]["sha256"]
        == match[2].decode(),
        "retirement digest does not match persisted state",
    )
    require(
        sunshine_state_digest(
            file_evidence(
                SUNSHINE / "sunshine_state.json", (1000, 100), 0o600, 16 * 1024 * 1024
            )[0],
            retired=True,
        )
        == baseline["fingerprints"][str(SUNSHINE / "sunshine_state.json")][
            "nonmembership_sha256"
        ],
        "retirement changed nonmembership state",
    )
    isolation.verify_closed()
    network.verify()
    output = command(
        [
            tools["korrid"],
            "identity",
            "replace-test-owner-offline",
            "--expected-device",
            args.device,
            "--expected-owner",
            TEST_OWNER,
            "--expected-event",
            args.old_event,
            "--new-owner",
            args.new_owner,
            "--template",
            staged_template,
            "--file",
            staged_event,
        ],
        environment={"KORRID_PRIVATE_STATE_ROOT": str(PRIVATE)},
    )
    owned = decode(output)
    require(
        owned.get("_tag") == "Owned"
        and owned.get("devicePublicKey") == args.device
        and owned.get("ownerPublicKey") == args.new_owner
        and owned.get("eventId") == args.new_event,
        "owner replacement output mismatch",
    )
    installed = file_evidence(IDENTITY / "owner.event.json", (976, 976), 0o600)[0]
    require(
        hashlib.sha256(installed).hexdigest() == args.event_sha256,
        "installed new event differs",
    )
    key_matches(tools, args.device)
    check_preserved(baseline["fingerprints"], fingerprints())
    output = command(
        [
            tools["selector"],
            "offline-select",
            args.old_bundle,
            args.candidate_bundle,
            "--acknowledge-exclusive-quiescence",
        ]
    )
    require(
        output == f"active={args.candidate_bundle}\n".encode(),
        "offline selection result unknown",
    )
    require(
        raw_selector("previous") == args.previous_bundle, "previous selector changed"
    )
    activate(tools, args.candidate, isolation)
    verify_new_state(args, tools, baseline, require_empty_grants=False)
    maintenance(tools, args, args.candidate, args.candidate_bundle, isolation, network)
    verify_new_state(args, tools, baseline)
    check_preserved(baseline["fingerprints"], fingerprints(), removed_grants=True)
    empty_journal()
    absent_state()
    require(
        management(isolation.managers[0][0]) == baseline["management"],
        "management continuity lost",
    )
    require(
        str(Path("/nix/var/nix/profiles/system").resolve(strict=True)) == args.old,
        "unaccepted boot profile changed",
    )
    network.verify()
    isolation.verify_closed()
    save_private(
        artifacts,
        "prepared-not-accepted.json",
        {
            "generation": args.candidate,
            "bundle": args.candidate_bundle,
            "event": args.new_event,
            "retired_clients": int(match[1]),
            "remaining_grants": 0,
            "historical_client_proof": HISTORICAL_CLIENT_PROOF,
            "required": PENDING,
            "network_receipt_recovery": "held by surviving supervisor; reboot only on receipt loss",
        },
    )
    # The live object and root service continue; normal preparation does NOT lose
    # the network receipt. The phase record is not a release authorization.
    return baseline


def client_evidence(args, tools, *, pristine=False):
    root = Path(args.verification_client_root)
    require(
        root != PRIVATE and PRIVATE not in root.parents,
        "client must hold a separate device key",
    )
    fd = directory(root, (0, 0), 0o700)
    try:
        if pristine:
            try:
                os.stat("federation", dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                raise Refusal(
                    "verification client has cached federation memory; never clear it"
                )
    finally:
        os.close(fd)
    fd = directory(root / "identity", (0, 0), 0o700)
    os.close(fd)
    event = file_evidence(root / "identity/owner.event.json", (0, 0), 0o600)[0]
    require(
        hashlib.sha256(event).hexdigest() == args.verification_event_sha256,
        "client signed artifact digest differs",
    )
    require(
        args.verification_device != args.device,
        "host key cannot stand in for client key",
    )
    command(
        [
            tools["ownerVerify"],
            args.verification_device,
            args.new_owner,
            args.verification_event,
            "-",
        ],
        data=event,
    )
    key_matches(tools, args.verification_device, root / "identity/device.key", (0, 0))
    return {
        name: file_evidence(root / "identity" / name, (0, 0), 0o600)[1]
        for name in ("device.key", "owner.event.json")
    }


def verify_new_state(args, tools, baseline, *, require_empty_grants=True):
    require(
        file_evidence(IDENTITY / "owner.event.json", (976, 976), 0o600)[0]
        == Path(args.event).read_bytes(),
        "new binding changed",
    )
    key_matches(tools, args.device)
    check_preserved(baseline["fingerprints"], fingerprints(), removed_grants=True)
    if require_empty_grants:
        require(
            entries(IDENTITY / "peer-certificates", (976, 976)) == [],
            "grants must stay empty",
        )
    state = decode(sunshine_state_evidence(SUNSHINE / "sunshine_state.json")[0])
    require(
        sunshine_state_digest(json.dumps(state), retired=True)
        == baseline["fingerprints"][str(SUNSHINE / "sunshine_state.json")][
            "nonmembership_sha256"
        ],
        "nonmembership Sunshine state changed",
    )
    require(
        state["root"]["uniqueid"] == args.host_uuid
        and state["root"].get("named_devices", []) in ([], "")
        and state["root"].get("devices", []) in ([], ""),
        "persisted Sunshine trust is not empty",
    )
    require(raw_selector("previous") == args.previous_bundle, "previous selector drift")


def executable_image(path, runtime_environment=None, depth=0):
    """Interpret only complete reviewed wrapper grammars; never execute shell."""
    require(depth < 4, "executable wrapper nesting exceeds bound")
    path = Path(path).resolve(strict=True)
    immutable(path, executable=True)
    env = dict(runtime_environment or {})
    require(
        not any(env.get(key) for key in ("LD_PRELOAD", "LD_AUDIT", "BASH_ENV", "ENV")),
        "unsupported executable environment",
    )
    with path.open("rb") as stream:
        header = stream.read(65537)
    if header.startswith(b"\x7fELF"):
        return str(path)
    require(len(header) <= 65536, "oversized executable wrapper")
    store = r"/nix/store/[0-9a-df-np-sv-z]{32}-[^/\s\"']+"
    make_wrapper = re.fullmatch(
        r"#! " + store + r"/bin/bash -e\n"
        r"(?P<exports>(?:export [A-Z_][A-Z_0-9]*='[^'\n]*'\n)*)"
        r'exec -a "\$0" "(?P<target>' + store + r'/bin/\.[^/\s\"]+-wrapped)"  "\$@" \n',
        header.decode(),
    )
    if make_wrapper:
        for key, value in re.findall(
            r"export ([A-Z_][A-Z_0-9]*)='([^'\n]*)'", make_wrapper["exports"]
        ):
            env[key] = value
        return executable_image(make_wrapper["target"], env, depth + 1)
    sway = re.fullmatch(
        r"#!"
        + store
        + r"/bin/bash\n"
        + re.escape(
            'set -o errexit\nif [ ! "$_SWAY_WRAPPER_ALREADY_EXECUTED" ]; then\n'
            "  export XDG_CURRENT_DESKTOP=sway\n  \n"
            "  export _SWAY_WRAPPER_ALREADY_EXECUTED=1\nfi\n"
            'if [ "$DBUS_SESSION_BUS_ADDRESS" ]; then\n'
            "  export DBUS_SESSION_BUS_ADDRESS\n  exec "
        )
        + r"(?P<target>"
        + store
        + r"/bin/sway)"
        + re.escape(' "$@"\nelse\n  exec ')
        + r"(?P<dbus>"
        + store
        + r"/bin/dbus-run-session) (?P=target)"
        + re.escape(' "$@"\nfi\n\n'),
        header.decode(),
    )
    require(sway is not None, "unsupported executable wrapper")
    require(
        env.get("DBUS_SESSION_BUS_ADDRESS") == "unix:path=/run/user/1000/bus",
        "unsupported Sway DBus branch/environment",
    )
    immutable(sway["dbus"], executable=True)
    return executable_image(sway["target"], env, depth + 1)


def inspect_executable_images(generation, bundle):
    images = {}
    for unit, name in (
        ("korrid.service", "korrid"),
        ("korri-inputd.service", "korri-inputd"),
        ("inputplumber.service", "inputplumber"),
        ("korri-input-seat-receiver.service", "korri-input-seat-receiver"),
        ("sunshine.service", None),
        ("korri-compositor.service", None),
    ):
        text = unit_text(generation, unit)
        expected = (
            Path(bundle) / "bin" / name
            if name
            else Path(shlex.split(unit_setting(text, "ExecStart"))[0])
        )
        images[unit] = executable_image(expected, environment(text))
    return images


def running_evidence(generation, bundle, isolation, *, guard_state="permitted"):
    reject_ungated_legacy(isolation)
    manager = isolation.managers[0][0]
    result = {}
    for unit, name, uid, gid in (
        ("korrid.service", "korrid", 976, 976),
        ("korri-inputd.service", "korri-inputd", 977, 977),
        ("inputplumber.service", "inputplumber", 0, 0),
        ("korri-input-seat-receiver.service", "korri-input-seat-receiver", 0, 0),
        ("sunshine.service", None, 1000, 980),
        ("korri-compositor.service", None, 1000, 100),
    ):
        require(
            manager.show(unit, "ActiveState") == "active",
            "runtime authority inactive: " + unit,
        )
        pid = manager.show(unit, "MainPID")
        require(pid.isdigit() and int(pid) > 0, "runtime authority lacks PID")
        expected = (
            Path(bundle) / "bin" / name
            if name
            else Path(
                shlex.split(unit_setting(unit_text(generation, unit), "ExecStart"))[0]
            )
        )
        image = executable_image(expected, environment(unit_text(generation, unit)))
        require(
            str(Path("/proc", pid, "exe").resolve(strict=True)) == image,
            "running executable not selected: " + unit,
        )
        if unit in ("sunshine.service", "korrid.service"):
            require(
                os.stat(f"/proc/{pid}/ns/net").st_ino
                == os.stat("/proc/self/ns/net").st_ino,
                "running authority escaped reviewed network namespace",
            )
        status = Path("/proc", pid, "status").read_text()
        for field, value in (("Uid", uid), ("Gid", gid)):
            found = re.findall(r"^" + field + r":\s+([0-9 ]+[0-9\t ]*)$", status, re.M)
            require(
                len(found) == 1 and found[0].split() == [str(value)] * 4,
                "running credentials differ: " + unit,
            )
        result[unit] = {"pid": pid, "executable": image, "uid": uid, "gid": gid}
    require(
        manager.show("korri-input-source-guard.service", "ActiveState") == "active",
        "input source guard unavailable",
    )
    for manager, units in isolation.managers:
        for unit in units:
            if guard_state == "released":
                require(
                    not isolation.gate_path(manager.user, unit).exists(),
                    "owned gate not released",
                )
                if manager.user:
                    require(
                        manager.show(unit, "ActiveState") in ("inactive", "failed"),
                        "legacy authority reopened",
                    )
            elif guard_state == "permitted":
                if manager.user:
                    require(
                        manager.show(unit, "LoadState") == "masked"
                        and manager.show(unit, "ActiveState") in ("inactive", "failed"),
                        "legacy authority reopened",
                    )
                else:
                    require(
                        str(isolation.gate_path(False, unit))
                        in manager.show(unit, "DropInPaths"),
                        "persistent gate not loaded",
                    )
            else:
                raise Refusal("unknown runtime guard state")
    games(isolation.managers)
    return result


def start_matching(
    args, tools, isolation, network, generation, bundle, *, new_contract
):
    """Only a pre-inspected, matching selection can get explicit runtime permits."""
    empty_journal()  # Facts require a separate controlled journal-recovery design.
    assert_materialized(args, generation, bundle, isolation, new_contract=new_contract)
    network.verify()
    isolation.artifacts.restore(
        [isolation.mask_root(False) / unit for unit in SYSTEM_UNITS]
    )
    manager = isolation.managers[0][0]
    manager.call("daemon-reload")
    loaded_sunshine_contract(generation, manager)
    for unit in SYSTEM_UNITS:
        isolation.artifacts.file(
            isolation.permit_path(False, unit), b"matching-generation\n"
        )
    for unit in SYSTEM_UNITS:
        require(
            str(isolation.gate_path(False, unit)) in manager.show(unit, "DropInPaths"),
            "normal startup gate missing",
        )
    manager.call("start", "korrid-identity.service")
    for unit in (
        "sunshine.service",
        "inputplumber.service",
        "korri-inputd.service",
        "korrid.service",
    ):
        manager.call("start", unit)
    await_sunshine_ready(manager)
    await_idle(tools, isolation)
    network.verify()
    return running_evidence(generation, bundle, isolation)


def sunshine_process(manager):
    """Actual systemd evidence for the exact process a stop signal would reach."""
    state = manager.show(SUNSHINE_UNIT, "ActiveState")
    substate = manager.show(SUNSHINE_UNIT, "SubState")
    pid = manager.show(SUNSHINE_UNIT, "MainPID")
    require(
        (state, substate) == ("active", "running") and pid.isdigit() and int(pid) > 0,
        "Sunshine is not an active running process",
    )
    return int(pid)


def sunshine_serving():
    """Pinned-leaf evidence from the same listener certificate_tls uses.

    No client credential is presented, so nvhttp treats the peer as an
    unauthorized client: it cannot pair, launch or change any trust state. The
    server's exact leaf DER is still pinned, so a foreign listener on the fixed
    endpoint cannot satisfy this.
    """
    import ssl

    server = file_evidence(SUNSHINE / "credentials/cacert.pem", (1000, 100), 0o644)[0]
    context = ssl.create_default_context(
        cafile=str(SUNSHINE / "credentials/cacert.pem")
    )
    context.check_hostname = False  # Exact leaf DER is pinned below, not a hostname.
    with socket.create_connection(SUNSHINE_HTTPS, timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname="localhost") as connection:
            require(
                connection.getpeercert(binary_form=True)
                == ssl.PEM_cert_to_DER_cert(server.decode()),
                "Sunshine TLS server identity differs",
            )


def sunshine_main_loop(pid):
    """Kernel evidence that the signalled main thread reached its event loop.

    main() installs the terminate handler long before the handler can finish:
    it only takes effect once mainThreadLoop runs. A stop signal delivered while
    the leader thread is still doing start-up work is ignored for the whole 90 s
    stop timeout. The listening endpoint is not that boundary; it answers about
    60-80 ms BEFORE the loop starts, inside the exact failure window. That loop
    is the only place the leader thread parks in a timed wait, so the kernel's
    record of a clock_nanosleep/nanosleep wait is the observable boundary. Both
    kernel views of the same wait are accepted; a kernel that exposes neither
    yields a bounded refusal, never a proceed.
    """
    for name, waits in (
        ("syscall", (b"230", b"35")),
        ("wchan", (b"hrtimer_nanosleep",)),
    ):
        try:
            with open(f"/proc/{pid}/{name}", "rb") as stream:
                fields = stream.read(4096).split()
        except OSError:
            continue
        if fields and fields[0] in waits:
            return True
    return False


def sunshine_ready(manager):
    """One observation of actual readiness of the exact running Sunshine."""
    pid = sunshine_process(manager)
    sunshine_serving()
    require(sunshine_main_loop(pid), "Sunshine main loop has not started")
    require(
        sunshine_process(manager) == pid,
        "Sunshine main process changed during readiness observation",
    )
    return pid


def await_sunshine_ready(manager):
    """Bounded wait for actual readiness before signalling or trusting Sunshine.

    A restart issued during start-up delivers SIGTERM before Sunshine can act on
    it; systemd then waits out its whole stop timeout and the supervisor can only
    report unknown containment. A timeout refuses here. It never proceeds,
    retries the restart, relaxes the stop timeout or downgrades any other gate.
    """
    deadline = time.monotonic() + 60
    while True:
        try:
            return sunshine_ready(manager)
        except (Refusal, OSError):
            require(
                time.monotonic() < deadline,
                "Sunshine did not reach actual observable readiness",
            )
            time.sleep(0.2)


def certificate_tls(certificate, key, host_uuid, *, accepted):
    # nvhttp.cpp performs cert_chain.verify AFTER the TLS handshake. Require
    # actual XML acceptance/denial, never count a socket error as a result.
    import ssl
    import xml.etree.ElementTree as xml

    for path in (certificate, key):
        file_evidence(path, (0, 0), 0o600)
    context = ssl.create_default_context(
        cafile=str(SUNSHINE / "credentials/cacert.pem")
    )
    context.check_hostname = False  # Exact leaf DER is pinned below, not a hostname.
    context.load_cert_chain(certificate, key, password=b"")
    server = file_evidence(SUNSHINE / "credentials/cacert.pem", (1000, 100), 0o644)[0]
    with socket.create_connection(SUNSHINE_HTTPS, timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname="localhost") as connection:
            connection.settimeout(5)
            require(
                connection.getpeercert(binary_form=True)
                == ssl.PEM_cert_to_DER_cert(server.decode()),
                "Sunshine TLS server identity differs",
            )
            connection.sendall(
                b"GET /serverinfo?uniqueid=federation-cutover HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
            )
            body = bytearray()
            while len(body) < 65536:
                part = connection.recv(4096)
                if not part:
                    break
                body.extend(part)
    require(
        len(body) < 65536 and b"\r\n\r\n" in body,
        "bounded TLS verifier response missing",
    )
    headers, payload = bytes(body).split(b"\r\n\r\n", 1)
    require(
        headers.split(b"\r\n", 1)[0] == b"HTTP/1.1 200 OK", "unexpected TLS HTTP status"
    )
    root = xml.fromstring(payload)
    if accepted:
        require(
            root.tag == "root"
            and root.get("status_code") == "200"
            and [item.text for item in root.findall("uniqueid")] == [host_uuid]
            and [item.text for item in root.findall("PairStatus")] == ["1"],
            "temporary certificate not accepted by exact Sunshine host",
        )
    else:
        require(
            root.tag == "root"
            and root.get("status_code") == "401"
            and root.get("status_message")
            == "The client is not authorized. Certificate verification failed.",
            "new temporary certificate not denied after revoke",
        )


def await_certificate_tls(certificate, key, host_uuid, *, accepted):
    deadline = time.monotonic() + 15
    while True:
        try:
            return certificate_tls(certificate, key, host_uuid, accepted=accepted)
        except OSError:
            require(
                time.monotonic() < deadline,
                "no actual Sunshine certificate verifier response",
            )
            time.sleep(0.2)


def temporary_membership(raw, certificate, host_uuid):
    """The only permitted temporary Sunshine membership, not a cleanup plan."""
    sunshine_state_digest(raw)
    root = decode(raw)["root"]
    clients = root.get("named_devices")
    require(
        root["uniqueid"] == host_uuid
        and root.get("devices", []) in ([], "")
        and isinstance(clients, list)
        and len(clients) == 1
        and set(clients[0]) == {"name", "uuid", "cert"}
        and clients[0]["cert"] == certificate,
        "unexplained Sunshine membership during automatic probe; retain all facts",
    )


def verify_probe_state(args, tools, baseline, certificate, client_before):
    """Check only our exact new grant; do not reconcile/delete unexpected facts."""
    require(
        client_evidence(args, tools) == client_before,
        "verification client identity changed",
    )
    require(
        file_evidence(IDENTITY / "owner.event.json", (976, 976), 0o600)[0]
        == Path(args.event).read_bytes(),
        "new binding changed",
    )
    empty_journal()
    require(
        entries(IDENTITY / "peer-certificates", (976, 976))
        == [args.verification_device],
        "unexpected automatic probe grant inventory",
    )
    grant_path = IDENTITY / "peer-certificates" / args.verification_device
    grant = decode(file_evidence(grant_path, (976, 976), 0o600, 131072)[0])
    client_event = file_evidence(
        Path(args.verification_client_root) / "identity/owner.event.json", (0, 0), 0o600
    )[0]
    require(
        set(grant) == {"hostUuid", "clientCertificate", "authorization"}
        and grant["hostUuid"] == args.host_uuid
        and grant["clientCertificate"] == certificate
        and set(grant["authorization"]) == {"kind", "owner_statement"}
        and grant["authorization"]["kind"] == "ownerDevice"
        and decode(grant["authorization"]["owner_statement"]) == decode(client_event),
        "automatic probe grant differs from exact authenticated client",
    )
    state_path = SUNSHINE / "sunshine_state.json"
    raw, state_evidence = sunshine_state_evidence(state_path)
    require(state_evidence["gid"] == 980, "automatic write lacks exact Sunshine group")
    temporary_membership(raw, certificate, args.host_uuid)
    before, after = baseline["fingerprints"], fingerprints()
    require(
        sunshine_state_digest(raw)
        == before[str(state_path)]["nonmembership_sha256"]
        == after[str(state_path)]["nonmembership_sha256"],
        "nonmembership Sunshine state changed during automatic probe",
    )
    # Membership is separately checked above, never marked empty to bypass F5.
    check_preserved(
        {key: value for key, value in before.items() if key != str(state_path)},
        {
            key: value
            for key, value in after.items()
            if key not in (str(state_path), str(grant_path))
        },
        removed_grants=True,
    )
    require(raw_selector("previous") == args.previous_bundle, "previous selector drift")


def automatic_certificate_probe(
    args, tools, isolation, network, baseline, client_before
):
    artifacts = isolation.artifacts
    verify_new_state(args, tools, baseline)
    root = artifacts.state / "automatic-probe"
    # Unlike parent/gate directories this credential root must never be adopted.
    root.mkdir(mode=0o700)
    artifacts.record(root)
    key = save_private_bytes(
        artifacts,
        "automatic-probe/client.key",
        command(
            [
                tools["openssl"],
                "genpkey",
                "-algorithm",
                "RSA",
                "-pkeyopt",
                "rsa_keygen_bits:2048",
            ]
        ),
    )
    certificate = save_private_bytes(
        artifacts,
        "automatic-probe/client.crt",
        command(
            [
                tools["openssl"],
                "req",
                "-new",
                "-x509",
                "-key",
                key,
                "-sha256",
                "-days",
                "1",
                "-subj",
                "/CN=federation-cutover-temporary",
            ]
        ),
    )
    cert = file_evidence(certificate, (0, 0), 0o600)[0].decode()
    common = [
        args.verification_client_root,
        args.verification_device,
        args.new_owner,
        args.verification_event,
        args.device,
        args.host_uuid,
        certificate,
        str(SUNSHINE / "credentials/cacert.pem"),
    ]
    artifacts.verify()
    network.verify()
    idle(tools, isolation)
    verify_new_state(args, tools, baseline)
    save_private(
        artifacts,
        "automatic-provision-started.json",
        {
            "client": args.verification_device,
            "certificate_sha256": hashlib.sha256(cert.encode()).hexdigest(),
            "recovery": "incomplete probe prohibits recovery; no automatic cleanup or retry",
        },
    )
    require(
        command([tools["ownerVerify"], "certificate-provision", *common])
        == b"verified authenticated certificate provision and exact server certificate\n",
        "authenticated automatic provision result unknown",
    )
    verify_probe_state(args, tools, baseline, cert, client_before)
    await_certificate_tls(certificate, key, args.host_uuid, accepted=True)
    save_private(
        artifacts,
        "automatic-provisioned.json",
        {
            "provision": "authenticated encrypted producer RPC",
            "tls": "temporary certificate accepted by pinned server and exact host UUID",
        },
    )
    # No finally-revoke: even a timeout may have written trust. Preserve it for
    # refusal, rather than giving another RPC authority to erase unexplained facts.
    artifacts.verify()
    network.verify()
    verify_probe_state(args, tools, baseline, cert, client_before)
    require(
        command([tools["ownerVerify"], "certificate-revoke", *common])
        == b"verified authenticated temporary certificate removal\n",
        "authenticated temporary revoke result unknown",
    )
    require(
        sunshine_state_evidence(SUNSHINE / "sunshine_state.json")[1]["gid"] == 980,
        "revoke write lacks exact Sunshine group",
    )
    verify_new_state(args, tools, baseline)
    await_certificate_tls(certificate, key, args.host_uuid, accepted=False)
    manager = isolation.managers[0][0]
    await_sunshine_ready(manager)
    manager.call("restart", "sunshine.service")
    await_certificate_tls(certificate, key, args.host_uuid, accepted=False)
    # Socket activation may already have restarted the selected daemon. Repeated
    # start jobs also rerun its oneshot importer and can exhaust its rate limit.
    if manager.show("korrid.service", "ActiveState") not in ("active", "activating"):
        manager.call("start", "korrid.service")
    await_idle(tools, isolation)
    verify_new_state(args, tools, baseline)
    require(
        client_evidence(args, tools) == client_before,
        "verification client identity changed",
    )
    network.verify()
    save_private(
        artifacts,
        "automatic-revoked.json",
        {
            "revoke": "authenticated encrypted producer RPC removed only temporary certificate",
            "remaining_grants": 0,
            "remaining_clients": 0,
            "tls": "NEW temporary certificate denied before and after Sunshine restart",
            "historical_client_proof": HISTORICAL_CLIENT_PROOF,
        },
    )


def local_acceptance(args, tools, isolation, network, baseline):
    client_before = client_evidence(args, tools)
    runtime = start_matching(
        args,
        tools,
        isolation,
        network,
        args.candidate,
        args.candidate_bundle,
        new_contract=True,
    )
    verify_new_state(args, tools, baseline)
    manager = isolation.managers[0][0]
    await_sunshine_ready(manager)
    manager.call("restart", "sunshine.service")
    # Requires/BindsTo may stop korrid when Sunshine restarts. Start only if socket
    # activation has not already done so; never reset or disable start limits.
    if manager.show("korrid.service", "ActiveState") not in ("active", "activating"):
        manager.call("start", "korrid.service")
    await_idle(tools, isolation)
    verify_new_state(args, tools, baseline)
    negative = isolation.artifacts.state / "negative-probes"
    isolation.artifacts.directory(negative, 0o700)
    output = command(
        [
            tools["ownerVerify"],
            "local-check",
            args.verification_client_root,
            args.verification_device,
            args.new_owner,
            args.verification_event,
            args.device,
            str(negative),
            args.old_binding,
            args.host_uuid,
        ],
        timeout=45,
    )
    require(
        output
        == b"verified encrypted owner success and fresh old-owner/pass rejection\n",
        "local producer evidence missing",
    )
    require(
        client_evidence(args, tools) == client_before,
        "verification client identity changed",
    )
    automatic_certificate_probe(
        args, tools, isolation, network, baseline, client_before
    )
    idle(tools, isolation)
    verify_new_state(args, tools, baseline)
    network.verify()
    runtime = running_evidence(args.candidate, args.candidate_bundle, isolation)
    save_private(
        isolation.artifacts,
        "local-accepted.json",
        {
            "runtime": runtime,
            "client": args.verification_device,
            "owner": args.new_owner,
            "event": args.verification_event,
            "tls": "automatic authenticated provision, pinned server TLS acceptance, authenticated revoke, new temporary certificate denied before/after restart",
            "historical_client_proof": HISTORICAL_CLIENT_PROOF,
        },
    )


def verify_boot_default(generation):
    require(
        str(PROFILE.resolve(strict=True)) == generation, "explicit system profile drift"
    )
    # Exact systemd-boot producer files. Other bootloaders are unsupported rather
    # than treating a profile symlink alone as proof of the boot default.
    loader = Path("/boot/loader/loader.conf").read_text()
    defaults = re.findall(r"^default (nixos-generation-[0-9]+\.conf)$", loader, re.M)
    require(len(defaults) == 1, "unsupported or ambiguous boot default")
    entry = Path("/boot/loader/entries") / defaults[0]
    text = entry.read_text()
    options = re.findall(r"^options (.+)$", text, re.M)
    require(
        len(options) == 1
        and [option for option in shlex.split(options[0]) if option.startswith("init=")]
        == ["init=" + generation + "/init"],
        "boot entry does not select exact generation",
    )
    # EFI one-shot/default overrides can supersede loader.conf. Refuse any such
    # variable; do not clear user-owned firmware state to make acceptance pass.
    variables = Path("/sys/firmware/efi/efivars")
    require(
        variables.is_dir()
        and not list(variables.glob("LoaderEntryOneShot-*"))
        and not list(variables.glob("LoaderEntryDefault-*"))
        and not list(variables.glob("BootNext-*")),
        "EFI entry override requires review",
    )
    return {
        "profile": str(PROFILE),
        "generation": generation,
        "action": "boot",
        "entry": str(entry),
        "sha256": hashlib.sha256(text.encode()).hexdigest(),
    }


def persist_boot(args, tools, isolation, generation, bundle, baseline, name):
    isolation.close()
    empty_journal()
    verify_new_state(args, tools, baseline)
    inspect_generation(
        args,
        generation,
        bundle,
        new_contract=generation == args.candidate,
        binding=True,
    )
    require(raw_selector("active") == bundle, "boot selection mismatch")
    command(
        [tools["nixEnv"], "--profile", str(PROFILE), "--set", generation], timeout=60
    )
    activate(tools, generation, isolation, "boot")
    evidence = verify_boot_default(generation)
    verify_new_state(args, tools, baseline)
    save_private(isolation.artifacts, name, evidence)


def verify_commitments(generation):
    verifier = Path(generation) / "sw/bin/zao-verify-commitments"
    immutable(verifier, executable=True)
    output = command([str(verifier)], timeout=90)
    names = (
        "towada-storage",
        "media-tiering-sink",
        "jellyfin-media-server",
        "shared-office-printer",
        "tailnet-access",
        "eval-memory-safety",
    )
    require(
        output.decode()
        == "".join("PASS " + name + "\n" for name in names) + "\n6 passed, 0 failed\n",
        "six actual commitments did not pass",
    )
    return output


def complete_candidate(args, tools, isolation, network, baseline):
    local_acceptance(args, tools, isolation, network, baseline)
    # peer_rpc.rs reconciles stale grants before native requests. Detect any
    # acceptance-time facts before giving the next producer probe that authority.
    # This does not replace the required exclusion of concurrent client writers.
    empty_journal()
    verify_new_state(args, tools, baseline)
    # Network release is allowed ONLY after owner/trust and automatic TLS proof.
    # All persistent gates and runtime permits remain owned throughout.
    isolation.artifacts.verify()
    network.remove()
    env = environment(unit_text(args.candidate, "korrid.service"))
    relays = env.get("KORRID_RELAYS", "")
    require(relays, "no configured relay producer input")
    output = command(
        [
            tools["ownerVerify"],
            "relay-check",
            args.verification_client_root,
            args.verification_device,
            args.new_owner,
            args.verification_event,
            args.device,
            relays,
        ],
        timeout=180,
    )
    require(
        output
        == b"verified configured relay discovery and remembered native recovery\n",
        "relay acceptance incomplete",
    )
    # The candidate supplies the ACTUAL six-commitment producer, not a callback,
    # executable argument, an accept flag or a supplied success document.
    try:
        commitments = verify_commitments(args.candidate)
    except PrimitiveFailure as failure:
        save_private(
            isolation.artifacts,
            "commitments-refused.json",
            {"exit": failure.code, "output": failure.stdout.decode()},
        )
        raise
    idle(tools, isolation)
    runtime = running_evidence(args.candidate, args.candidate_bundle, isolation)
    verify_new_state(args, tools, baseline)
    require(
        management(isolation.managers[0][0]) == baseline["management"],
        "management continuity lost",
    )
    save_private(
        isolation.artifacts,
        "acceptance.json",
        {
            "runtime": runtime,
            "commitments": commitments.decode(),
            "generation": args.candidate,
            "owner": args.new_owner,
            "historical_client_proof": HISTORICAL_CLIENT_PROOF,
        },
    )
    persist_boot(
        args,
        tools,
        isolation,
        args.candidate,
        args.candidate_bundle,
        baseline,
        "accepted-boot.json",
    )
    release_owned_guards(args, tools, isolation, baseline)
    return "ACCEPTED generation persisted; exact owned guards released. Historical-client TLS proof deferred; physical client checks remain external."


def release_owned_guards(args, tools, isolation, baseline):
    isolation.verify_closed()
    isolation.verify_activation_lists()
    verify_boot_default(args.candidate)
    verify_new_state(args, tools, baseline)
    require(raw_selector("active") == args.candidate_bundle, "release selector drift")
    # Keep evidence and explicit roots. Never restore() the whole manifest, which
    # includes evidence and negative-probe state. Remove only exact guard paths.
    guards = []
    for manager, units in isolation.managers:
        for unit in units:
            guards += [
                isolation.gate_path(manager.user, unit),
                isolation.mask_root(manager.user) / unit,
            ]
    # Prove the final runtime under the same persistent gates. Reboot is still
    # closed if ANY evidence write up to the durable release decision fails.
    masks = [isolation.mask_root(False) / unit for unit in SYSTEM_UNITS]
    isolation.artifacts.restore(masks)
    manager = isolation.managers[0][0]
    manager.call("daemon-reload")
    loaded_sunshine_contract(args.candidate, manager)
    for unit in SYSTEM_UNITS:
        isolation.artifacts.file(isolation.permit_path(False, unit), b"final-runtime\n")
    manager.call(
        "start",
        "korrid.service",
        "sunshine.service",
        "inputplumber.service",
        "korri-inputd.service",
    )
    await_sunshine_ready(manager)
    await_idle(tools, isolation)
    verify_new_state(args, tools, baseline)
    runtime = running_evidence(args.candidate, args.candidate_bundle, isolation)
    save_private(
        isolation.artifacts,
        "released.json",
        {"generation": args.candidate, "owner": args.new_owner, "runtime": runtime},
    )
    # Durable success boundary: all acceptance, boot and final runtime evidence
    # is committed. Only now remove conditions; no service restart follows.
    # A post-commit cleanup refusal is NOT a claim of reboot-closed failure.
    isolation.artifacts.restore(
        [path for path in guards if path not in masks]
        + [isolation.permit_path(False, unit) for unit in SYSTEM_UNITS]
    )
    for manager, _ in isolation.managers:
        manager.call("daemon-reload")
    running_evidence(
        args.candidate, args.candidate_bundle, isolation, guard_state="released"
    )
    verify_new_state(args, tools, baseline)
    idle(tools, isolation)


def secure_recovery(args, tools, isolation, network, baseline):
    """Fresh active matching candidate proof before any software downgrade."""
    isolation.close()
    require(
        str(isolation.artifacts.state / "automatic-provision-started.json")
        not in isolation.artifacts.records
        or str(isolation.artifacts.state / "automatic-revoked.json")
        in isolation.artifacts.records,
        "incomplete automatic certificate probe; retain facts and refuse recovery",
    )
    verify_new_state(args, tools, baseline, require_empty_grants=False)
    empty_journal()
    actual_grants = {
        path: value
        for path, value in fingerprints().items()
        if Path(path).parent == IDENTITY / "peer-certificates"
    }
    require(
        all(
            baseline["fingerprints"].get(path) == value
            for path, value in actual_grants.items()
        )
        and (
            not actual_grants
            or str(isolation.artifacts.state / "prepared-not-accepted.json")
            not in isolation.artifacts.records
        ),
        "new grant facts prohibit recovery; never reconcile acceptance-time facts",
    )
    require(
        raw_selector("active") == args.candidate_bundle,
        "recovery requires selected candidate",
    )
    # A failed /etc activation can leave current-system stale. Retry only the
    # same inspected selected candidate under all gates, never the old software.
    activate(tools, args.candidate, isolation)
    verify_new_state(args, tools, baseline, require_empty_grants=False)
    maintenance(tools, args, args.candidate, args.candidate_bundle, isolation, network)
    verify_new_state(args, tools, baseline)
    start_matching(
        args,
        tools,
        isolation,
        network,
        args.candidate,
        args.candidate_bundle,
        new_contract=True,
    )
    idle(tools, isolation)
    verify_commitments(args.candidate)
    require(
        management(isolation.managers[0][0]) == baseline["management"],
        "management continuity lost before recovery selection",
    )
    isolation.close()
    empty_journal()
    verify_new_state(args, tools, baseline)
    network.verify()
    inspect_generation(
        args, args.recovery, args.recovery_bundle, new_contract=False, binding=True
    )
    output = command(
        [
            tools["selector"],
            "offline-select",
            args.candidate_bundle,
            args.recovery_bundle,
            "--acknowledge-exclusive-quiescence",
        ]
    )
    require(
        output == f"active={args.recovery_bundle}\n".encode(),
        "recovery selection result unknown",
    )
    activate(tools, args.recovery, isolation)
    start_matching(
        args,
        tools,
        isolation,
        network,
        args.recovery,
        args.recovery_bundle,
        new_contract=False,
    )
    idle(tools, isolation)
    verify_commitments(args.recovery)
    require(
        management(isolation.managers[0][0]) == baseline["management"],
        "management continuity lost in recovery",
    )
    persist_boot(
        args,
        tools,
        isolation,
        args.recovery,
        args.recovery_bundle,
        baseline,
        "secure-recovery-boot.json",
    )
    verify_commitments(args.recovery)
    require(
        management(isolation.managers[0][0]) == baseline["management"],
        "management continuity lost after recovery boot action",
    )
    network.verify()
    return "SECURE RECOVERY boot persisted with new owner and empty trust; authority remains gated."


def contain_failure(isolation, failure, name):
    """Receipt owner survives evidence refusal; stopping is not guard release."""
    status = "unknown"
    try:
        isolation.emergency_stop()
        status = "stopped; reboot closure not established"
    except BaseException:
        pass  # The explicit unknown status is retained, never reported as closed.
    try:
        isolation.close()
        status = "closed with verified persistent gates"
    except BaseException:
        pass  # The independently proved stopped/unknown status remains exact.
    evidence = {
        "reason": str(failure)
        if isinstance(failure, Refusal)
        else type(failure).__name__,
        "pid": os.getpid(),
        "containment": status,
    }
    print(json.dumps(evidence, sort_keys=True), flush=True)
    try:
        isolation.artifacts.verify_manifest()
        save_private(isolation.artifacts, name, evidence)
    except BaseException:
        print(
            "Evidence persistence refused; live receipt retained. No release or evidence adoption.",
            flush=True,
        )
    return status


def recovery_requested(connection):
    try:
        _, uid, gid = struct.unpack(
            "3i", connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
        )
        connection.settimeout(5)
        requested = connection.recv(64)
        if not requested:
            return False
        if (uid, gid) != (0, 0) or requested != b"secure-recovery":
            connection.sendall(b"refused")
            return False
        connection.sendall(b"requested; no acceptance implied")
        return True
    except (OSError, struct.error):
        # No mutating action has begun. An acknowledgment error never retries it.
        return False


def await_recovery(args, tools, isolation, network, baseline):
    # Not an acceptance override. Only root on this boot may request the single
    # software recovery plan already pinned in the protected baseline.
    require(not RECOVERY_REQUEST.exists(), "recovery request socket collision")
    with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as listener:
        listener.bind(str(RECOVERY_REQUEST))
        RECOVERY_REQUEST.chmod(0o600)
        listener.listen(1)
        while True:
            try:
                connection = listener.accept()[0]
            except OSError:
                time.sleep(0.2)
                continue
            with connection:
                if not recovery_requested(connection):
                    continue
            try:
                isolation.artifacts.verify()
                # A completed remove leaves this SAME object without a receipt;
                # a new exclusive install succeeds only if the table is absent.
                try:
                    network.install()
                except BaseException:
                    network.verify()  # Owned receipt only; never adoption.
                result = secure_recovery(args, tools, isolation, network, baseline)
            except BaseException as failure:
                contain_failure(
                    isolation, failure, f"recovery-refused-{time.time_ns()}.json"
                )
                continue
            print(result, flush=True)
            return result


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("launch", "run", "recover"))
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
        "event-sha256",
        "template-sha256",
        "device",
        "old-event",
        "new-owner",
        "new-event",
        "host-uuid",
        "verification-client-root",
        "verification-device",
        "verification-event",
        "verification-event-sha256",
    ):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--grants", required=True, type=int)
    args = parser.parse_args(argv)
    for name in (
        "event_sha256",
        "template_sha256",
        "device",
        "old_event",
        "new_owner",
        "new_event",
        "verification_device",
        "verification_event",
        "verification_event_sha256",
    ):
        require(
            re.fullmatch("[0-9a-f]{64}", getattr(args, name)),
            "invalid exact public expectation",
        )
    require(
        args.new_owner != TEST_OWNER
        and args.old != args.candidate
        and args.recovery != args.old,
        "new-owner candidate and secure recovery must not be old generation",
    )
    require(
        re.fullmatch(
            r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", args.host_uuid
        )
        and 0 <= args.grants <= 4096,
        "invalid approved host/count expectation",
    )
    return args


def root_environment():
    require(
        os.geteuid() == 0 and socket.gethostname() == "zao",
        "local root Zao supervisor only",
    )
    for name, uid, gid in (
        (USER, 1000, 100),
        ("korrid", 976, 976),
        ("korri-inputd", 977, 977),
    ):
        account = pwd.getpwnam(name)
        require(
            (account.pw_uid, account.pw_gid) == (uid, gid), "baseline account drift"
        )
    require(pwd.getpwnam(USER).pw_dir == str(HOME), "baseline home drift")
    require(grp.getgrnam("korri-control").gr_gid == 977, "inputd control group drift")
    require(
        grp.getgrnam("korri-sunshine-input-seat").gr_gid == 980,
        "Sunshine runtime group drift",
    )
    immutable(__file__)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    def interrupted(_signal, _frame):
        raise Refusal("supervisor interrupted; stop and retain guards")

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    # Gate directories/drop-ins must be readable by the actual user manager.
    # Evidence directories/files still request explicit 0700/0600 modes.
    os.umask(0o022)
    tools = decode(Path(__file__).with_name("tools.json").read_bytes())
    for path in tools.values():
        immutable(path, executable=True)
    os.environ.clear()
    os.environ.update(
        PATH=str(Path(tools["systemctl"]).parent),
        LC_ALL="C",
        SYSTEMD_COLORS="0",
        SYSTEMD_PAGER="",
    )
    return tools


def worker(tools, generation, action):
    immutable(generation, root=True)
    manager = Manager()
    require(
        manager.show(ACTIVATION_WORKER, "MainPID") == str(os.getpid()),
        "worker is not independently supervised",
    )
    invocation = manager.show(ACTIVATION_WORKER, "InvocationID")
    require(re.fullmatch("[0-9a-f]{32}", invocation), "worker invocation missing")
    path = Path("/run") / ("activation-" + invocation)
    deadline = time.monotonic() + 30
    while not path.exists():
        require(time.monotonic() < deadline, "worker was never recorded")
        time.sleep(0.05)
    require(
        file_evidence(path, (0, 0), 0o644)[0] == b"recorded\n",
        "unsafe activation handshake",
    )
    executable = str(Path(generation) / "bin/switch-to-configuration")
    require(action in ("test", "boot"), "unsupported activation action")
    os.execv(executable, [executable, action])


def main():
    tools = root_environment()
    if sys.argv[1:2] == ["activation-worker"]:
        require(len(sys.argv) == 4, "worker requires exact generation/action")
        worker(tools, sys.argv[2], sys.argv[3])
        return
    args = arguments(sys.argv[1:])
    for name in (
        "old",
        "candidate",
        "recovery",
        "old_bundle",
        "candidate_bundle",
        "recovery_bundle",
        "previous_bundle",
        "booted",
    ):
        immutable(getattr(args, name), root=True)
    for name in ("old_binding", "event", "template"):
        immutable(getattr(args, name))
    executable = str(Path(__file__).resolve().parents[1] / "bin/federation-cutover")
    if args.action == "recover":
        baseline = decode(
            file_evidence(
                Path("/var/lib/korri-maintenance-isolation/baseline.json"),
                (0, 0),
                0o600,
                262144,
            )[0]
        )
        expected = dict(baseline["parameters"])
        expected["action"] = "recover"
        require(vars(args) == expected, "recovery request differs from pinned plan")
        info = RECOVERY_REQUEST.lstat()
        require(
            stat.S_ISSOCK(info.st_mode)
            and info.st_uid == 0
            and stat.S_IMODE(info.st_mode) == 0o600,
            "missing safe surviving supervisor",
        )
        with socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET) as connection:
            connection.settimeout(5)
            connection.connect(str(RECOVERY_REQUEST))
            pid, uid, gid = struct.unpack(
                "3i", connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12)
            )
            require(
                (uid, gid) == (0, 0)
                and Manager().show(SUPERVISOR, "MainPID") == str(pid),
                "recovery peer is not surviving root supervisor",
            )
            connection.sendall(b"secure-recovery")
            require(
                connection.recv(128) == b"requested; no acceptance implied",
                "recovery request unknown",
            )
        return
    if args.action == "launch":
        command(
            [
                tools["systemdRun"],
                "--unit=" + SUPERVISOR,
                "--service-type=exec",
                "--property=User=root",
                "--property=Group=root",
                "--property=KillMode=control-group",
                "--property=UMask=0077",
                "--property=LimitCORE=0",
                "--property=TimeoutStopSec=45",
                executable,
                "run",
                *sys.argv[2:],
            ]
        )
        print("Independent root supervisor requested; no acceptance implied.")
        return
    manager = Manager()
    require(
        manager.show(SUPERVISOR, "MainPID") == str(os.getpid())
        and manager.show(SUPERVISOR, "FragmentPath")
        == f"/run/systemd/transient/{SUPERVISOR}"
        and manager.show(SUPERVISOR, "User") == "root"
        and manager.show(SUPERVISOR, "KillMode") == "control-group",
        "independent root supervision required",
    )
    with Isolation(USER, HOME) as isolation:
        network = NetworkIsolation(tools["nft"])
        try:
            baseline = prepare(args, tools, isolation, network)
            result = complete_candidate(args, tools, isolation, network, baseline)
        except BaseException as failure:
            # Close again ONLY once the full gate set exists. Never remove evidence,
            # retry a trust primitive, select old software or restore private bytes.
            gates = [
                isolation.gate_path(manager.user, unit)
                for manager, units in isolation.managers
                for unit in units
            ]
            if (
                all(str(path) in isolation.artifacts.records for path in gates)
                or str(isolation.artifacts.state / "trust-mutation-started.json")
                in isolation.artifacts.records
            ):
                contain_failure(isolation, failure, "failure-held.json")
            if (
                str(isolation.artifacts.state / "trust-mutation-started.json")
                not in isolation.artifacts.records
            ):
                raise
            baseline = decode(
                file_evidence(
                    isolation.artifacts.state / "baseline.json", (0, 0), 0o600, 262144
                )[0]
            )
            result = await_recovery(args, tools, isolation, network, baseline)
        print(result, flush=True)


if __name__ == "__main__":
    try:
        main()
    except BaseException as error:
        # Only our controlled refusals contain public diagnostics. Never print a
        # raw parser/OS/producer exception or captured child stderr.
        if isinstance(error, Refusal):
            print(str(error), file=sys.stderr)
        print(
            "REFUSED/UNKNOWN: retain gates and evidence; no old-state restoration or acceptance.",
            file=sys.stderr,
        )
        sys.exit(1)
