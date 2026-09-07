"""Narrow maintenance isolation primitives, not a cutover or deployment runner.

No identity, trust, selector, network, activation, boot-profile or recovery writes.
Callers must exclude concurrent administrators and record their root activation
worker before drain. No cleanup occurs on exception. Persistent gates close on boot.
"""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import shutil
import stat
import subprocess
import time

SYSTEM_UNITS = (
    "korrid-control.socket",
    "korri-certificate-control.socket",
    "korrid.service",
    "korrid-identity.service",
    "sunshine.service",
    "korri-bundle-selector.service",
    "inputplumber.service",
    "korri-inputd.service",
    "korri-input-seat-receiver.service",
    "korri-compositor.service",
)
USER_UNITS = (
    "korrid-control.socket",
    "korrid.service",
    "sunshine.service",
    "x11-headless.service",
)
GATE_NAME = "90-korri-maintenance-isolation.conf"
PERMITS = Path("/run/korri-maintenance-isolation")
ACTIVATION_WORKER = "korri-maintenance-activation.service"
SYSTEM_ACTIVATION_JOBS = (ACTIVATION_WORKER, "sysinit-reactivation.target")
USER_ACTIVATION_JOBS = ("nixos-activation.service",)


class Refusal(RuntimeError):
    """Evidence is insufficient. Retain isolation and require inspection."""


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def checked_parents(path):
    for parent in reversed(path.parents):
        if parent.is_symlink():
            raise Refusal(f"symlink parent: {parent}")
        if not parent.is_dir():
            raise Refusal(f"missing parent: {parent}")


def snapshot(path):
    st = path.lstat()
    result = {
        "dev": st.st_dev,
        "ino": st.st_ino,
        "uid": st.st_uid,
        "gid": st.st_gid,
        "mode": st.st_mode,
    }
    if not stat.S_ISDIR(st.st_mode):
        result["nlink"] = st.st_nlink
    if stat.S_ISLNK(st.st_mode):
        result["target"] = os.readlink(path)
    elif stat.S_ISREG(st.st_mode) and st.st_nlink == 1:
        if st.st_size > 262144:
            raise Refusal(f"oversized artifact: {path}")
        result["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    elif not stat.S_ISDIR(st.st_mode):
        raise Refusal(f"unsafe artifact: {path}")
    return result


class OwnedArtifacts:
    """Exclusive creations and a protected operational manifest, never overwrite.

    The manifest records public filesystem evidence only. An interrupted create
    before its manifest sync is an unowned collision, never an excuse to delete.
    """

    def __init__(self, state):
        self.state = Path(state)
        self.lock = None
        self.records = {}
        self.write_failed = False
        self.manifest_receipt = None
        self.boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()

    def __enter__(self):
        checked_parents(self.state)
        self.state.mkdir(mode=0o700, exist_ok=True)
        st = self.state.lstat()
        if (
            not stat.S_ISDIR(st.st_mode)
            or st.st_uid != os.geteuid()
            or stat.S_IMODE(st.st_mode) != 0o700
        ):
            raise Refusal("manifest directory must be private and owned")
        fd = os.open(self.state / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        self.lock = fd
        try:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise Refusal("another isolation writer holds the lock") from error
            self.records = {}
            self.write_failed = False
            self.manifest_receipt = None
            manifest = self.state / "manifest.json"
            if manifest.exists() or manifest.is_symlink():
                st = manifest.lstat()
                if (
                    not stat.S_ISREG(st.st_mode)
                    or st.st_uid != os.geteuid()
                    or stat.S_IMODE(st.st_mode) != 0o600
                    or st.st_nlink != 1
                    or st.st_size > 262144
                ):
                    raise Refusal("unsafe manifest")
                raw, self.manifest_receipt = self.read_manifest()
                self.records = json.loads(raw)
                if not isinstance(self.records, dict) or any(
                    not Path(name).is_absolute()
                    or not isinstance(record, dict)
                    or set(record) != {"stat", "boot"}
                    or not isinstance(record["stat"], dict)
                    or not isinstance(record["stat"].get("mode"), int)
                    or not isinstance(record["boot"], str)
                    for name, record in self.records.items()
                ):
                    raise Refusal("invalid manifest evidence")
            return self
        except BaseException as error:
            # __exit__ is not called by Python when __enter__ raises.
            self.__exit__()
            if isinstance(error, (OSError, ValueError)):
                raise Refusal("invalid or unreadable manifest") from error
            raise

    def __exit__(self, *_):
        if self.lock is not None:
            os.close(self.lock)
            self.lock = None

    def read_manifest(self):
        path = self.state / "manifest.json"
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        try:
            before = os.fstat(fd)
            if (
                not stat.S_ISREG(before.st_mode)
                or before.st_uid != os.geteuid()
                or stat.S_IMODE(before.st_mode) != 0o600
                or before.st_nlink != 1
                or before.st_size > 262144
            ):
                raise Refusal("unsafe durable manifest")
            raw = bytearray()
            while len(raw) <= 262144:
                part = os.read(fd, min(65536, 262145 - len(raw)))
                if not part:
                    break
                raw.extend(part)

            def metadata(info):
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

            if (
                len(raw) != before.st_size
                or metadata(before) != metadata(os.fstat(fd))
                or metadata(before) != metadata(path.lstat())
            ):
                raise Refusal("durable manifest changed during read")
            return bytes(raw), (metadata(before), bytes(raw))
        finally:
            os.close(fd)

    def verify_manifest(self):
        try:
            pending = self.state / "manifest.next"
            if self.write_failed or pending.exists() or pending.is_symlink():
                raise Refusal("artifact persistence failed or is unfinished")
            path = self.state / "manifest.json"
            if self.manifest_receipt is None:
                if path.exists() or path.is_symlink():
                    raise Refusal("unowned durable manifest appeared")
            elif self.read_manifest()[1] != self.manifest_receipt:
                raise Refusal("durable manifest changed")
        except BaseException as error:
            self.write_failed = True
            if isinstance(error, OSError):
                raise Refusal("durable manifest unavailable") from error
            raise

    def save(self):
        self.verify_manifest()
        try:
            temporary = self.state / "manifest.next"
            fd = os.open(
                temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600
            )
            payload = json.dumps(self.records, sort_keys=True).encode()
            with os.fdopen(fd, "wb") as output:
                output.write(payload)
                output.flush()
                os.fsync(output.fileno())
                owned = os.fstat(output.fileno())
            temporary.replace(self.state / "manifest.json")
            sync_directory(self.state)
            raw, receipt = self.read_manifest()
            if raw != payload or receipt[0][:7] != (
                owned.st_dev,
                owned.st_ino,
                owned.st_uid,
                owned.st_gid,
                owned.st_mode,
                owned.st_nlink,
                owned.st_size,
            ):
                raise Refusal("own manifest replacement changed before receipt")
            self.manifest_receipt = receipt
        except BaseException:
            # An in-memory record is not proof of successful persistence.
            self.write_failed = True
            raise

    def record(self, path):
        self.verify_manifest()
        sync_directory(path.parent)
        self.records[str(path)] = {"stat": snapshot(path), "boot": self.boot}
        self.save()

    def directory(self, path, mode=0o755):
        path = Path(path)
        checked_parents(path)
        if path.exists() or path.is_symlink():
            st = path.lstat()
            if (
                not stat.S_ISDIR(st.st_mode)
                or st.st_uid != os.geteuid()
                or st.st_mode & 0o022
            ):
                raise Refusal(f"unsafe directory: {path}")
            return
        path.mkdir(mode=mode)
        self.record(path)

    def file(self, path, content):
        path = Path(path)
        checked_parents(path)
        try:
            fd = os.open(
                path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644
            )
        except FileExistsError as error:
            raise Refusal(f"artifact collision: {path}") from error
        with os.fdopen(fd, "wb") as output:
            output.write(content)
            output.flush()
            os.fsync(output.fileno())
        self.record(path)

    def symlink(self, path, target):
        path = Path(path)
        checked_parents(path)
        try:
            path.symlink_to(target)
        except FileExistsError as error:
            raise Refusal(f"artifact collision: {path}") from error
        self.record(path)

    def expired(self, path, record):
        return (
            str(path).startswith("/run/")
            and record["boot"] != self.boot
            and not path.exists()
            and not path.is_symlink()
        )

    def verify(self, runtime_missing=False):
        self.verify_manifest()
        for name, record in self.records.items():
            path = Path(name)
            if runtime_missing and self.expired(path, record):
                continue
            checked_parents(path)
            try:
                actual = snapshot(path)
            except FileNotFoundError as error:
                raise Refusal(f"owned artifact missing: {path}") from error
            if actual != record["stat"]:
                raise Refusal(f"owned artifact changed: {path}")

    def restore(self, paths=None):
        # Validate ALL artifacts before removing the first one, not one at a time.
        self.verify(runtime_missing=True)
        selected = set(self.records) if paths is None else set(map(str, paths))
        for name in selected:
            path = Path(name)
            record = self.records[name]
            if stat.S_ISDIR(record["stat"]["mode"]) and not self.expired(path, record):
                if any(str(child) not in selected for child in path.iterdir()):
                    raise Refusal(f"unowned directory contents: {path}")
        for name in sorted(
            selected, key=lambda value: (value.count("/"), value), reverse=True
        ):
            self.verify_manifest()
            record = self.records[name]
            path = Path(name)
            if not self.expired(path, record):
                if stat.S_ISDIR(record["stat"]["mode"]):
                    path.rmdir()  # Never recursively remove unexpected contents.
                else:
                    path.unlink()
                sync_directory(path.parent)
            del self.records[name]
            self.save()


def parse_jobs(text):
    jobs = []
    seen = set()
    for line in text.splitlines():
        fields = line.split()
        if (
            len(fields) != 4
            or not fields[0].isdigit()
            or fields[0] in seen
            or fields[3] not in ("waiting", "running")
        ):
            raise Refusal("ambiguous systemd job listing")
        seen.add(fields[0])
        jobs.append(tuple(fields))
    return jobs


def authority_job_ids(jobs, units):
    return [job[0] for job in jobs if job[1] in units]


class Manager:
    """Bounded real systemctl operations; errors never stand in for inactivity."""

    def __init__(self, user=None):
        self.user = user
        self.prefix = ["systemctl"]
        if user is not None:
            self.prefix += ["--user"]

    def user_context(self):
        # Drop credentials in the child only. Gate/manifest writes remain root.
        # Zao refuses the root machine bridge and root direct user-bus queries.
        # There is exactly one transport, not an error-driven fallback.
        if os.geteuid() != 0:
            raise Refusal("user manager requires a root caller")
        try:
            account = pwd.getpwnam(self.user)
            if (account.pw_uid, account.pw_gid, account.pw_dir) != (
                1000,
                100,
                f"/home/{self.user}",
            ) or pwd.getpwuid(1000).pw_name != self.user:
                raise Refusal("user manager account drift")
            flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
            for parts in (
                (
                    ("/", 0, 0, 0o755),
                    ("home", 0, 0, 0o755),
                    (self.user, 1000, 100, None),
                ),
                (
                    ("/", 0, 0, 0o755),
                    ("run", 0, 0, 0o755),
                    ("user", 0, 0, 0o755),
                    ("1000", 1000, 100, 0o700),
                ),
            ):
                fd = None
                try:
                    for name, uid, gid, mode in parts:
                        child = os.open(name, flags, dir_fd=fd)
                        if fd is not None:
                            os.close(fd)
                        fd = child
                        info = os.fstat(fd)
                        if (
                            (info.st_uid, info.st_gid) != (uid, gid)
                            or info.st_mode & 0o022
                            or (mode is not None and stat.S_IMODE(info.st_mode) != mode)
                        ):
                            raise Refusal("unsafe user manager ancestry")
                    if parts[-1][0] == "1000":
                        info = os.stat("bus", dir_fd=fd, follow_symlinks=False)
                        if (
                            not stat.S_ISSOCK(info.st_mode)
                            or (info.st_uid, info.st_gid) != (1000, 100)
                            or stat.S_IMODE(info.st_mode) != 0o666
                            or info.st_nlink != 1
                        ):
                            raise Refusal("unsafe user manager bus")
                finally:
                    if fd is not None:
                        os.close(fd)
            executable = Path(shutil.which("systemctl") or "").resolve(strict=True)
            info = executable.stat()
            if (
                not str(executable).startswith("/nix/store/")
                or not stat.S_ISREG(info.st_mode)
                or info.st_uid != 0
                or info.st_mode & 0o6222
                or not info.st_mode & 0o111
            ):
                raise Refusal("immutable systemctl required for user manager")
        except (OSError, KeyError, ValueError) as error:
            raise Refusal("user manager account/bus unavailable") from error
        return str(executable), {
            "PATH": str(executable.parent),
            "HOME": account.pw_dir,
            "USER": self.user,
            "LOGNAME": self.user,
            "XDG_RUNTIME_DIR": "/run/user/1000",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus",
            # systemd 259 otherwise prefers /run/user/1000/systemd/private,
            # ignoring the explicit session-bus address for manager operations.
            "SYSTEMCTL_FORCE_BUS": "1",
            "LC_ALL": "C",
            "SYSTEMD_COLORS": "0",
            "SYSTEMD_PAGER": "",
        }

    def call(self, *args):
        prefix = self.prefix
        env = {
            **os.environ,
            "LC_ALL": "C",
            "SYSTEMD_COLORS": "0",
            "SYSTEMD_PAGER": "",
        }
        credentials = {}
        if self.user is not None:
            executable, env = self.user_context()
            prefix = [executable, "--user"]
            credentials = {"user": 1000, "group": 100, "extra_groups": []}
        try:
            return subprocess.run(
                prefix + list(args),
                check=True,
                text=True,
                capture_output=True,
                timeout=30,
                env=env,
                cwd="/",
                **credentials,
            ).stdout.strip()
        except (subprocess.SubprocessError, OSError) as error:
            raise Refusal(f"systemd operation failed: {args[0]}") from error

    def show(self, unit, property_name):
        return self.call("show", unit, f"--property={property_name}", "--value")

    def jobs(self):
        return parse_jobs(
            self.call("list-jobs", "--no-legend", "--no-pager", "--plain", "--full")
        )


class Isolation:
    """Fixed Zao authority set. Only the VM consumer currently wires this API.

    User-owned configuration ancestors are not a security boundary against a
    hostile UID 1000. That user and root administrators must not edit units during
    maintenance. Each new immediate artifact directory is root-owned.
    """

    def __init__(self, user, home):
        if os.geteuid() != 0:
            raise Refusal("isolation requires root")
        account = pwd.getpwnam(user)
        if account.pw_uid != 1000 or Path(account.pw_dir) != Path(home):
            raise Refusal("legacy manager must be the declared UID 1000 home")
        self.home = Path(home)
        self.managers = [(Manager(), SYSTEM_UNITS), (Manager(user), USER_UNITS)]
        self.artifacts = OwnedArtifacts("/var/lib/korri-maintenance-isolation")
        self.lock = None
        self.worker_receipt = None

    def __enter__(self):
        # Cooperate with the existing device-check.sh operational lock.
        self.lock = os.open(
            "/run/lock/korri-device-gate.lock",
            os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW,
            0o600,
        )
        st = os.fstat(self.lock)
        if (
            not stat.S_ISREG(st.st_mode)
            or st.st_uid != 0
            or st.st_nlink != 1
            or st.st_mode & 0o022
        ):
            os.close(self.lock)
            raise Refusal("unsafe device gate lock")
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.artifacts.__enter__()
            evidence = self.artifacts.state / "activation-worker.json"
            if str(evidence) in self.artifacts.records:
                self.artifacts.verify(runtime_missing=True)
                self.worker_receipt = json.loads(evidence.read_text())
                if (
                    set(self.worker_receipt) != {"invocation", "cgroup"}
                    or self.worker_receipt["cgroup"]
                    != f"/system.slice/{ACTIVATION_WORKER}"
                ):
                    raise Refusal("invalid recorded activation worker")
        except Exception:
            self.artifacts.__exit__()
            os.close(self.lock)
            self.lock = None
            raise
        return self

    def __exit__(self, *args):
        self.artifacts.__exit__(*args)
        if self.lock is not None:
            os.close(self.lock)
            self.lock = None

    def gate_root(self, user):
        return (
            self.home / ".config/systemd/user.control"
            if user
            else Path("/etc/systemd/system.control")
        )

    def gate_path(self, user, unit):
        return self.gate_root(user) / f"{unit}.d" / GATE_NAME

    def mask_root(self, user):
        return Path(
            "/run/user/1000/systemd/user.control"
            if user
            else "/run/systemd/system.control"
        )

    def permit_path(self, user, unit):
        return PERMITS / (("user-" if user else "system-") + unit)

    def install(self):
        self.artifacts.verify(runtime_missing=True)
        # Refuse collisions across the WHOLE set before the first gate write.
        for manager, units in self.managers:
            for unit in units:
                for path in (
                    self.gate_path(manager.user, unit),
                    self.mask_root(manager.user) / unit,
                    self.permit_path(manager.user, unit),
                ):
                    if (path.exists() or path.is_symlink()) and str(
                        path
                    ) not in self.artifacts.records:
                        raise Refusal(f"unowned isolation collision: {path}")
                fragment = self.gate_root(manager.user) / unit
                if fragment.exists() or fragment.is_symlink():
                    if (
                        not fragment.is_symlink()
                        or os.readlink(fragment) != "/dev/null"
                    ):
                        raise Refusal(f"higher-precedence fragment: {fragment}")
        self.artifacts.directory(PERMITS)
        for manager, units in self.managers:
            self.artifacts.directory(self.gate_root(manager.user))
            self.artifacts.directory(self.mask_root(manager.user))
            for unit in units:
                path = self.gate_path(manager.user, unit)
                self.artifacts.directory(path.parent)
                if str(path) not in self.artifacts.records:
                    self.artifacts.file(
                        path,
                        f"[Unit]\nConditionPathExists={self.permit_path(manager.user, unit)}\n".encode(),
                    )
        # Gates for every unit precede masks. No automatic undo on partial failure.
        for manager, units in self.managers:
            for unit in units:
                path = self.mask_root(manager.user) / unit
                if not path.is_symlink():
                    self.artifacts.symlink(path, "/dev/null")
            manager.call("daemon-reload")
            for unit in units:
                if manager.show(unit, "LoadState") != "masked":
                    raise Refusal(f"mask is not effective: {unit}")

    def own_activation_worker(self, invocation_id):
        """Record a new worker only after close() retires the previous evidence."""
        manager = self.managers[0][0]
        if (
            manager.show(ACTIVATION_WORKER, "InvocationID") != invocation_id
            or len(invocation_id) != 32
        ):
            raise Refusal("activation invocation changed")
        if (
            manager.show(ACTIVATION_WORKER, "FragmentPath")
            != f"/run/systemd/transient/{ACTIVATION_WORKER}"
            or manager.show(ACTIVATION_WORKER, "User") != "root"
            or manager.show(ACTIVATION_WORKER, "KillMode") != "control-group"
        ):
            raise Refusal(
                "activation worker must be an independent transient root cgroup"
            )
        evidence = {
            "invocation": invocation_id,
            "cgroup": manager.show(ACTIVATION_WORKER, "ControlGroup"),
        }
        if evidence["cgroup"] != f"/system.slice/{ACTIVATION_WORKER}":
            raise Refusal("unexpected activation cgroup")
        # Stop authority is process-local and precedes any fallible evidence save.
        # It never grants deletion/adoption rights to the evidence store.
        self.worker_receipt = evidence
        self.artifacts.verify(runtime_missing=True)
        self.artifacts.file(
            self.artifacts.state / "activation-worker.json",
            json.dumps(evidence).encode(),
        )

    def activation_worker(self, stop=False):
        manager = self.managers[0][0]
        active = manager.show(ACTIVATION_WORKER, "ActiveState")
        evidence_path = self.artifacts.state / "activation-worker.json"
        if str(evidence_path) in self.artifacts.records:
            self.artifacts.verify(runtime_missing=True)
            try:
                evidence = json.loads(evidence_path.read_text())
                invocation = manager.show(ACTIVATION_WORKER, "InvocationID")
                if (
                    (invocation and invocation != evidence["invocation"])
                    or evidence["cgroup"] != f"/system.slice/{ACTIVATION_WORKER}"
                    or (not invocation and active not in ("inactive", "failed"))
                ):
                    raise Refusal("activation worker invocation changed")
            except (OSError, ValueError, KeyError, TypeError) as error:
                raise Refusal("invalid activation worker evidence") from error
        elif active not in ("inactive", "failed"):
            raise Refusal("unowned activation worker is running")
        if active not in ("inactive", "failed"):
            if not stop:
                raise Refusal("activation worker is still running")
            manager.call("stop", ACTIVATION_WORKER)
            active = manager.show(ACTIVATION_WORKER, "ActiveState")
        if active not in ("inactive", "failed"):
            raise Refusal("activation worker did not finish")
        root = Path("/sys/fs/cgroup/system.slice") / ACTIVATION_WORKER
        if any(path.read_text().strip() for path in root.rglob("cgroup.procs")):
            raise Refusal("activation descendants remain")
        if authority_job_ids(manager.jobs(), (ACTIVATION_WORKER,)):
            raise Refusal("activation worker job remains")

    def emergency_stop(self):
        """Stop/drain only. No artifact verification, persistence or removal.

        Stopping is not a mask or reboot-closure claim. Attempt every fixed
        authority even if one worker/manager proof fails; uncertainty is returned
        as refusal, never silently converted to successful containment.
        """
        errors = []
        worker_identified = False
        manager = self.managers[0][0]
        try:
            active = manager.show(ACTIVATION_WORKER, "ActiveState")
            if active not in ("inactive", "failed"):
                receipt = self.worker_receipt
                if (
                    receipt is None
                    or manager.show(ACTIVATION_WORKER, "InvocationID")
                    != receipt["invocation"]
                    or (
                        manager.show(ACTIVATION_WORKER, "ControlGroup")
                        != receipt["cgroup"]
                        and not (
                            manager.show(ACTIVATION_WORKER, "SubState") == "exited"
                            and manager.show(ACTIVATION_WORKER, "MainPID") == "0"
                        )
                    )
                    or manager.show(ACTIVATION_WORKER, "FragmentPath")
                    != f"/run/systemd/transient/{ACTIVATION_WORKER}"
                    or manager.show(ACTIVATION_WORKER, "User") != "root"
                    or manager.show(ACTIVATION_WORKER, "KillMode") != "control-group"
                ):
                    raise Refusal(
                        "cannot identify activation worker for emergency stop"
                    )
                worker_identified = True
                manager.call("stop", ACTIVATION_WORKER)
            self.verify_empty_cgroup(f"/system.slice/{ACTIVATION_WORKER}")
            if manager.show(ACTIVATION_WORKER, "ActiveState") not in (
                "inactive",
                "failed",
            ):
                raise Refusal("activation worker remains active")
        except BaseException as error:
            errors.append(error)
        cgroups = []
        for manager, units in self.managers:
            stopped = units + (USER_ACTIVATION_JOBS if manager.user else ())
            activation_jobs = tuple(
                unit
                for unit in SYSTEM_ACTIVATION_JOBS
                if unit != ACTIVATION_WORKER or worker_identified
            )
            affected = stopped + (() if manager.user else activation_jobs)
            for unit in stopped:
                try:
                    cgroups.append(manager.show(unit, "ControlGroup"))
                except BaseException as error:
                    errors.append(error)
            try:
                for job in authority_job_ids(manager.jobs(), affected):
                    manager.call("cancel", job)
            except BaseException as error:
                errors.append(error)
            # One bad unit must not prevent the other independently identified
            # services and sockets from receiving their stop requests.
            for unit in stopped:
                try:
                    manager.call("stop", "--no-block", unit)
                except BaseException as error:
                    errors.append(error)
        deadline = time.monotonic() + 30
        while True:
            try:
                for manager, units in self.managers:
                    stopped = units + (USER_ACTIVATION_JOBS if manager.user else ())
                    affected = stopped + (
                        () if manager.user else SYSTEM_ACTIVATION_JOBS
                    )
                    if authority_job_ids(manager.jobs(), affected):
                        raise Refusal("emergency authority jobs remain")
                    for unit in stopped:
                        if manager.show(unit, "ActiveState") not in (
                            "inactive",
                            "failed",
                        ):
                            raise Refusal("emergency authority remains: " + unit)
                        self.verify_empty_cgroup(manager.show(unit, "ControlGroup"))
                for cgroup in cgroups:
                    self.verify_empty_cgroup(cgroup)
                break
            except BaseException as error:
                if time.monotonic() >= deadline:
                    errors.append(error)
                    break
                time.sleep(0.1)
        if errors:
            detail = (
                str(errors[0])
                if isinstance(errors[0], Refusal)
                else type(errors[0]).__name__
            )
            raise Refusal(
                "emergency containment unknown; stop/drain proof failed: " + detail
            )

    def close(self):
        # Artifact failure must never suppress stopping already-running authority.
        self.emergency_stop()
        self.install()
        self.activation_worker(stop=True)
        permits = [
            name for name in self.artifacts.records if Path(name).parent == PERMITS
        ]
        self.artifacts.restore(permits)
        for manager, units in self.managers:
            # Cancel explicit authority job IDs only; never global `cancel`.
            affected = units + (
                USER_ACTIVATION_JOBS if manager.user else SYSTEM_ACTIVATION_JOBS
            )
            for job in authority_job_ids(manager.jobs(), affected):
                manager.call("cancel", job)
            # Canceling a running job does not terminate its oneshot or children.
            stopped = units + (USER_ACTIVATION_JOBS if manager.user else ())
            if manager.user:
                activation_cgroup = manager.show(
                    "nixos-activation.service", "ControlGroup"
                )
            manager.call("stop", "--no-block", *stopped)
        deadline = time.monotonic() + 30
        while True:
            if all(
                not authority_job_ids(
                    manager.jobs(),
                    units
                    + (
                        USER_ACTIVATION_JOBS if manager.user else SYSTEM_ACTIVATION_JOBS
                    ),
                )
                for manager, units in self.managers
            ):
                break
            if time.monotonic() > deadline:
                raise Refusal("authority jobs did not drain")
            time.sleep(0.1)
        for manager, _ in self.managers:
            manager.call("daemon-reload")
        self.verify_empty_cgroup(activation_cgroup)
        self.verify_closed()
        # Only after the exact invocation, its descendants and affected jobs are
        # finished may a later transient worker reuse the fixed unit name.
        evidence = self.artifacts.state / "activation-worker.json"
        if str(evidence) in self.artifacts.records:
            self.artifacts.restore([evidence])
        self.worker_receipt = None

    @staticmethod
    def verify_empty_cgroup(cgroup):
        if cgroup:
            root = Path("/sys/fs/cgroup") / cgroup.lstrip("/")
            if any(path.read_text().strip() for path in root.rglob("cgroup.procs")):
                raise Refusal(f"authority cgroup populated: {cgroup}")

    def verify_closed(self):
        self.artifacts.verify()
        # A permit created before a failed manifest write is not owned evidence.
        # Masks must stay effective, including after reopening the last manifest.
        for path in PERMITS.iterdir():
            if (
                path != self.permit_path(False, "sunshine.service")
                or str(path) not in self.artifacts.records
            ):
                raise Refusal(f"unowned or unsupported permit: {path}")
        self.activation_worker()
        for manager, units in self.managers:
            if authority_job_ids(
                manager.jobs(),
                units
                + (USER_ACTIVATION_JOBS if manager.user else SYSTEM_ACTIVATION_JOBS),
            ):
                raise Refusal("pending authority jobs")
            for unit in units:
                if manager.show(unit, "LoadState") != "masked" or manager.show(
                    unit, "ActiveState"
                ) not in ("inactive", "failed"):
                    raise Refusal(f"authority is not closed: {unit}")
                self.verify_empty_cgroup(manager.show(unit, "ControlGroup"))
            if manager.user:
                for unit in USER_ACTIVATION_JOBS:
                    if manager.show(unit, "ActiveState") not in ("inactive", "failed"):
                        raise Refusal(f"user activation is still running: {unit}")
                    self.verify_empty_cgroup(manager.show(unit, "ControlGroup"))
            games = manager.call(
                "list-units",
                "korri-game-*",
                "--all",
                "--no-legend",
                "--plain",
                "--no-pager",
            )
            if games:
                raise Refusal("game unit evidence requires separate inspection")
        if self.managers[0][0].show("user@1000.service", "ActiveState") != "active":
            raise Refusal("legacy user manager disappeared")

    def verify_activation_lists(self):
        for name in ("start-list", "restart-list", "reload-list"):
            path = Path("/run/nixos") / name
            if not path.exists() and not path.is_symlink():
                continue
            checked_parents(path)
            st = path.lstat()
            if (
                not stat.S_ISREG(st.st_mode)
                or st.st_uid != 0
                or st.st_nlink != 1
                or st.st_size > 262144
                or st.st_mode & 0o022
            ):
                raise Refusal("unsafe interrupted activation list")
            for unit in path.read_text().splitlines():
                if not unit or len(unit.split()) != 1 or "/" in unit or "." not in unit:
                    raise Refusal("ambiguous interrupted activation list")
                if (
                    unit
                    in SYSTEM_UNITS
                    + USER_UNITS
                    + SYSTEM_ACTIVATION_JOBS
                    + USER_ACTIVATION_JOBS
                ):
                    raise Refusal(
                        "interrupted activation requests require a successful retry"
                    )

    def remove_masks(self):
        self.verify_closed()
        self.verify_activation_lists()
        masks = [
            self.mask_root(manager.user) / unit
            for manager, units in self.managers
            for unit in units
        ]
        self.artifacts.restore(masks)
        for manager, _ in self.managers:
            manager.call("daemon-reload")

    def permit(self, unit):
        # Only Sunshine is exposed by this bounded slice, not launch/identity.
        if unit != "sunshine.service":
            raise Refusal("this slice only supports the Sunshine maintenance permit")
        # Stage and persist the permit while every mask is still effective.
        # remove_masks() is a separate success-only step, never error cleanup.
        self.verify_closed()
        self.verify_activation_lists()
        self.artifacts.file(self.permit_path(False, unit), b"maintenance\n")

    def restore(self):
        """Artifact restoration only. Caller owns acceptance and boot-default proof.

        Not wired to any live CLI. Never invoke after an ambiguous trust cut.
        """
        self.artifacts.verify(runtime_missing=True)
        self.close()
        self.verify_activation_lists()
        self.artifacts.restore()
        for manager, _ in self.managers:
            manager.call("daemon-reload")
