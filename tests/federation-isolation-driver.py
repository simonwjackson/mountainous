"""Guest-only test consumer. This is deliberately not a live operations CLI."""

import errno
import importlib.util
import json
import os
from pathlib import Path
import socket
import stat
import subprocess
import sys
import time

assert Path("/etc/isolation-vm-fixture").read_text() == "isolated fixture only\n"
assert os.uname().nodename == "machine"
spec = importlib.util.spec_from_file_location(
    "isolation", os.environ["ISOLATION_MODULE"]
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def run(*args):
    return subprocess.run(
        args, check=True, capture_output=True, text=True
    ).stdout.strip()


with m.Isolation("operator", Path("/home/operator")) as gate:
    command = sys.argv[1]
    if command == "manager-contract":
        credentials = (os.getresuid(), os.getresgid(), os.getgroups())
        manager = gate.managers[1][0]
        assert manager.call("show", "--property=Version", "--value") == "259"
        assert isinstance(manager.jobs(), list)
        assert manager.show("default.target", "LoadState") == "loaded"
        assert gate.managers[0][0].show("user@1000.service", "ActiveState") == "active"
        for user in ("root", "absent-user", ""):
            try:
                m.Manager(user).call("--version")
            except m.Refusal:
                pass
            else:
                raise AssertionError("unknown account accepted")
        executable = Path("/run/untrusted-systemctl")
        executable.mkdir()
        (executable / "systemctl").write_text("#!/bin/sh\nexit 0\n")
        (executable / "systemctl").chmod(0o755)
        original_path = os.environ["PATH"]
        os.environ["PATH"] = str(executable)
        try:
            try:
                manager.call("--version")
            except m.Refusal:
                pass
            else:
                raise AssertionError("mutable manager executable accepted")
        finally:
            os.environ["PATH"] = original_path
            (executable / "systemctl").unlink()
            executable.rmdir()
        runtime = Path("/run/user/1000")
        # /run/user/1000 is a tmpfs mount. Move its parent, not the mountpoint.
        ancestor = runtime.parent
        displaced = Path("/run/user.saved")
        ancestor.rename(displaced)
        ancestor.symlink_to(displaced)
        try:
            try:
                manager.call("--version")
            except m.Refusal:
                pass
            else:
                raise AssertionError("symlink runtime ancestor accepted")
        finally:
            ancestor.unlink()
            displaced.rename(ancestor)
        runtime.chmod(0o755)
        try:
            try:
                manager.call("--version")
            except m.Refusal:
                pass
            else:
                raise AssertionError("nonprivate runtime accepted")
        finally:
            runtime.chmod(0o700)
        bus, saved = runtime / "bus", runtime / "bus.saved"
        bus.rename(saved)
        try:
            for kind in (
                "missing",
                "symlink",
                "file",
                "fifo",
                "directory",
                "owner",
                "mode",
                "hardlink",
                "disconnected",
            ):
                listener = None
                if kind == "symlink":
                    bus.symlink_to(saved)
                elif kind == "file":
                    bus.write_bytes(b"not a bus")
                elif kind == "fifo":
                    os.mkfifo(bus)
                elif kind == "directory":
                    bus.mkdir()
                elif kind in ("owner", "mode", "hardlink", "disconnected"):
                    listener = socket.socket(socket.AF_UNIX)
                    listener.bind(str(bus))
                    os.chown(bus, 0 if kind == "owner" else 1000, 100)
                    bus.chmod(0o600 if kind == "mode" else 0o666)
                    if kind == "hardlink":
                        os.link(bus, runtime / "bus.link")
                try:
                    try:
                        # Even correct socket metadata cannot turn connection
                        # refusal into an empty job inventory.
                        manager.jobs() if kind == "disconnected" else manager.call(
                            "--version"
                        )
                    except m.Refusal:
                        pass
                    else:
                        raise AssertionError("unsafe/unknown bus accepted: " + kind)
                finally:
                    if listener is not None:
                        listener.close()
                    if kind == "directory":
                        bus.rmdir()
                    elif kind != "missing":
                        bus.unlink()
                    if kind == "hardlink":
                        (runtime / "bus.link").unlink()
        finally:
            saved.rename(bus)
        assert isinstance(manager.jobs(), list)
        assert (os.getresuid(), os.getresgid(), os.getgroups()) == credentials
        print(
            "PASS actual UID1000:GID100 empty groups and explicit authenticated bus; root caller retained; unsafe/failed bus refused",
            flush=True,
        )
    elif command == "baseline":
        for manager, units in gate.managers:
            for unit in units:
                if manager.user and unit == "sunshine.service":
                    assert manager.show(unit, "LoadState") == "masked"
                else:
                    assert manager.show(unit, "ActiveState") == "active", unit
        path = Path("/home/operator/.config/systemd/user/sunshine.service")
        Path("/var/lib/fixture-sunshine-inode").write_text(str(path.lstat().st_ino))
        management_units = ["sshd.service", "management.service", "user@1000.service"]
        pids = {
            unit: gate.managers[0][0].show(unit, "MainPID") for unit in management_units
        }
        connection = subprocess.Popen(
            [
                "ssh",
                "-F",
                "/dev/null",
                "-i",
                "/etc/fixture-key",
                "-o",
                "StrictHostKeyChecking=no",
                "root@localhost",
                "sleep infinity",
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(1)
        assert connection.poll() is None
        pids["connection"] = connection.pid
        Path("/run/fixture-management-pids").write_text(json.dumps(pids))
    elif command == "preflight-collision":
        directory = Path("/run/systemd/system.control")
        directory.mkdir(exist_ok=True)
        path = directory / "korrid.service"
        path.symlink_to("/dev/null")
        inode = path.lstat().st_ino
        try:
            gate.close()
        except m.Refusal:
            pass
        else:
            raise AssertionError("accepted an unowned high-precedence mask")
        assert path.lstat().st_ino == inode
        for manager, units in gate.managers:
            for unit in units:
                assert not gate.gate_path(manager.user, unit).exists()
        path.unlink()
        directory.rmdir()
    elif command == "ordinary-mask":
        manager = gate.managers[0][0]
        manager.call("mask", "--runtime", "korrid.service")
        manager.call("daemon-reload")
        assert manager.show("korrid.service", "LoadState") == "loaded"
        assert Path("/run/systemd/system/korrid.service").readlink() == Path(
            "/dev/null"
        )
        manager.call("unmask", "--runtime", "korrid.service")
    elif command == "assert-management":
        pids = json.loads(Path("/run/fixture-management-pids").read_text())
        for unit, pid in pids.items():
            if unit == "connection":
                assert Path(f"/proc/{pid}").is_dir()
                assert Path(f"/proc/{pid}/comm").read_text().strip() == "ssh"
            else:
                assert gate.managers[0][0].show(unit, "MainPID") == pid, unit
    elif command == "independent-supervisor":
        caller = Path("/run/user/1000/fixture-caller-pid").read_text().strip()
        assert caller.isdigit() and Path(f"/proc/{caller}").exists()
        gate.close()
        Path("/run/fixture-supervisor-caller").write_text(caller)
        Path("/run/fixture-supervisor-ready").touch()
        deadline = time.monotonic() + 30
        while Path(f"/proc/{caller}").exists():
            assert time.monotonic() < deadline, "actual requesting caller did not exit"
            time.sleep(0.1)
        gate.verify_closed()
        Path("/run/fixture-supervisor-done").touch()
    elif command == "queue":
        for manager, units in gate.managers:
            manager.call("stop", "korrid-control.socket", "korrid.service")
            directory = (
                Path(
                    "/run/user/1000/systemd/user"
                    if manager.user
                    else "/run/systemd/system"
                )
                / "korrid.service.d"
            )
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "queue.conf").write_text(
                "[Unit]\nAfter=fixture-blocker.service\n"
            )
            manager.call("daemon-reload")
            manager.call("start", "--no-block", "fixture-blocker.service")
            manager.call("start", "--no-block", "korrid.service")
            assert any(job[1] == "korrid.service" for job in manager.jobs())
    elif command == "close":
        gate.close()
    elif command == "assert-closed":
        gate.verify_closed()
        for manager, units in gate.managers:
            for unit in units:
                for path in (
                    gate.gate_path(manager.user, unit),
                    gate.gate_path(manager.user, unit).parent,
                ):
                    info = path.lstat()
                    assert info.st_uid == 0 and not stat.S_IMODE(info.st_mode) & 0o022
        assert os.geteuid() == 0
    elif command == "seed-interrupted":
        directory = Path("/run/nixos")
        directory.mkdir(exist_ok=True)
        path = directory / "start-list"
        assert not path.exists() or not path.read_bytes()
        path.write_text("korrid.service\n")
        gate.close()
        assert path.read_text() == "korrid.service\n"
    elif command == "own-worker":
        gate.own_activation_worker(
            gate.managers[0][0].show(m.ACTIVATION_WORKER, "InvocationID")
        )
    elif command == "refuse-release":
        try:
            gate.remove_masks()
        except m.Refusal:
            pass
        else:
            raise AssertionError("released masks with an active activation worker")
        for manager, units in gate.managers:
            for unit in units:
                assert manager.show(unit, "LoadState") == "masked"
    elif command == "retirement-write-failure":
        evidence = gate.artifacts.state / "activation-worker.json"
        before = evidence.read_bytes()
        state = str(gate.artifacts.state)
        run("mount", "--bind", state, state)
        try:
            run("mount", "-o", "remount,bind,ro", state)
            try:
                gate.close()
            except OSError as error:
                assert error.errno == errno.EROFS, error
            else:
                raise AssertionError("retirement on read-only evidence succeeded")
            assert evidence.read_bytes() == before
            for manager, units in gate.managers:
                for unit in units:
                    assert manager.show(unit, "LoadState") == "masked"
        finally:
            run("umount", state)
    elif command == "assert-worker-retired":
        gate.verify_closed()
        assert not (gate.artifacts.state / "activation-worker.json").exists()
    elif command == "assert-user-activation-drained":
        manager = gate.managers[1][0]
        unit = "nixos-activation.service"
        assert manager.show(unit, "ActiveState") in ("inactive", "failed")
        for name in ("pid", "child"):
            pid = (
                Path(f"/run/user/1000/fixture-user-activation-{name}")
                .read_text()
                .strip()
            )
            assert not Path(f"/proc/{pid}").exists(), (name, pid)
        assert not any(job[1] == unit for job in manager.jobs())
    elif command == "permit-write-failure":
        gate.close()
        # The real state filesystem becomes read-only; /run permits stay writable.
        # No patched writer or fabricated systemctl response is involved.
        state = str(gate.artifacts.state)
        run("mount", "--bind", state, state)
        try:
            run("mount", "-o", "remount,bind,ro", state)
            try:
                gate.permit("sunshine.service")
            except OSError as error:
                assert error.errno == errno.EROFS, error
            else:
                raise AssertionError("permit manifest write unexpectedly succeeded")
            assert gate.permit_path(False, "sunshine.service").exists()
        finally:
            run("umount", state)
        try:
            gate.remove_masks()
        except m.Refusal:
            pass
        else:
            raise AssertionError("unmasked after failed permit persistence")
    elif command == "assert-failed-permit-reopened":
        for operation in (gate.remove_masks, gate.close):
            try:
                operation()
            except m.Refusal:
                pass
            else:
                raise AssertionError("accepted an unrecorded failed permit")
        for manager, units in gate.managers:
            for unit in units:
                assert manager.show(unit, "LoadState") == "masked", unit
                assert manager.show(unit, "ActiveState") in ("inactive", "failed"), unit
                assert gate.gate_path(manager.user, unit).exists()
    elif command == "reject-unmasked-permit":
        try:
            gate.permit("sunshine.service")
        except m.Refusal:
            pass
        else:
            raise AssertionError("created a permit without effective masks")
        assert not gate.permit_path(False, "sunshine.service").exists()
    elif command == "assert-worker-drained":
        manager = gate.managers[0][0]
        assert manager.show("korri-maintenance-activation.service", "ActiveState") in (
            "inactive",
            "failed",
        )
        assert not any(
            Path(
                "/sys/fs/cgroup/system.slice/korri-maintenance-activation.service"
            ).rglob("cgroup.procs")
        )
    elif command == "unmask":
        gate.remove_masks()
    elif command in ("assert-gated", "assert-other-gates"):
        gate.artifacts.verify(runtime_missing=True)
        for manager, units in gate.managers:
            for unit in units:
                if (
                    command == "assert-other-gates"
                    and not manager.user
                    and unit == "sunshine.service"
                ):
                    continue
                if manager.show(unit, "LoadState") == "masked":
                    continue
                manager.call("start", unit)
                assert manager.show(unit, "ActiveState") == "inactive", unit
                assert manager.show(unit, "ConditionResult") == "no", unit
        run(
            "systemctl",
            "is-active",
            "sshd.service",
            "management.service",
            "user@1000.service",
        )
    elif command == "permit-sunshine":
        gate.permit("sunshine.service")
        gate.remove_masks()
        gate.managers[0][0].call("start", "sunshine.service")
    elif command == "collision":
        # A same-content replacement must still be refused and leave every gate.
        path = gate.gate_path(False, "korrid.service")
        original = path.read_bytes()
        path.write_bytes(b"foreign\n")
        try:
            gate.restore()
        except m.Refusal:
            pass
        else:
            raise AssertionError("foreign gate was removed")
        assert gate.gate_path(False, "sunshine.service").exists()
        path.write_bytes(original)
    elif command == "restore":
        gate.restore()
    elif command == "restored":
        path = Path("/home/operator/.config/systemd/user/sunshine.service")
        assert path.readlink() == Path("/dev/null")
        assert path.lstat().st_ino == int(
            Path("/var/lib/fixture-sunshine-inode").read_text()
        )
        for manager, units in gate.managers:
            for unit in units:
                assert not gate.gate_path(manager.user, unit).exists()
        run("systemctl", "start", "korrid.service", "sunshine.service")
        run(
            "systemctl",
            "is-active",
            "korrid.service",
            "sunshine.service",
            "sshd.service",
            "management.service",
            "user@1000.service",
        )
    else:
        raise AssertionError(command)
