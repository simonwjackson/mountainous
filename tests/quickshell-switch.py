#!/usr/bin/env python3
"""Offline switch-policy proof using the evaluated unit and production Hjem hook.

No user manager is contacted. Executable adapters record the hook's commands.
The NixOS changed-unit pass is modelled from the generated X-* policy; this is
not a live switch-to-configuration integration test.
"""

import configparser
import json
import os
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text())
hook = Path(sys.argv[2]).resolve()
unit = configparser.ConfigParser(interpolation=None, strict=False)
unit.read_string(config["quickshellUnit"])
restart_if_changed = unit.getboolean("Service", "X-RestartIfChanged", fallback=True)
assert not restart_if_changed
assert not unit.getboolean("Service", "X-ReloadIfChanged", fallback=False)
assert not config["restartIfChanged"] and not config["reloadIfChanged"]
assert config["restartTriggers"] == []
assert "hjem-activate@%i.service" in config["hjemReloadAfter"]
assert "hjem-activate@%i.service" in config["hjemReloadRequires"]
assert len(config["hjemReloadPost"]) == 1

with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    events = work / "events"
    bus = socket.socket(socket.AF_UNIX)
    bus.bind(str(work / "bus"))
    try:

        def executable(name, body):
            file = work / name
            file.write_text("#!" + sys.executable + "\n" + body)
            file.chmod(0o700)

        executable("loginctl", 'import os\nprint(os.environ["TEST_RUNTIME"])\n')
        executable(
            "systemctl",
            """import os, sys
from pathlib import Path
args = sys.argv[1:]
assert args[0] == '--user' and args[-1] == 'quickshell.service', args
assert os.environ['XDG_RUNTIME_DIR'] == os.environ['TEST_RUNTIME']
assert os.environ['DBUS_SESSION_BUS_ADDRESS'] == 'unix:path=' + os.environ['TEST_RUNTIME'] + '/bus'
action = args[1]
if action in ('is-active', 'is-failed'):
    sys.exit(0 if os.environ['TEST_STATE'] == action[3:] else 1)
assert action in ('reset-failed', 'restart'), args
with Path(os.environ['TEST_EVENTS']).open('a') as stream:
    stream.write(('start:hook' if action == 'restart' else action) + '\\n')
""",
        )
        env = {
            **os.environ,
            "PATH": str(work) + ":" + os.environ["PATH"],
            "TEST_RUNTIME": str(work),
            "TEST_EVENTS": str(events),
        }

        def run(label, restart_if_changed, state="active", user="simon"):
            events.write_text("")
            # Nixpkgs do_user_switch/handle_modified_unit, for a changed active
            # NixOS-owned service: before sysinit-reactivation/Hjem activation.
            if restart_if_changed and state == "active":
                events.write_text("start:nixos-user-switch\n")
            with events.open("a") as stream:
                stream.write("hjem-activate:linked\n")
            subprocess.run(
                ["bash", str(hook), user], env={**env, "TEST_STATE": state}, check=True
            )
            trace = events.read_text().splitlines()
            starts = [event for event in trace if event.startswith("start:")]
            print(f"{label}: starts={len(starts)} trace={trace}")
            return trace, starts

        before, starts = run("before / changed active unit", True)
        assert len(starts) == 2
        assert before.index(starts[0]) < before.index("hjem-activate:linked")
        after, starts = run("after / changed active unit", restart_if_changed)
        assert len(starts) == 1
        assert after.index("hjem-activate:linked") < after.index(starts[0])
        # Repeated switches must not accumulate restart requests.
        for index in range(3):
            _, starts = run(f"after / repeat {index + 1}", restart_if_changed)
            assert len(starts) == 1
        _, starts = run("hook / failed at invocation", restart_if_changed, "failed")
        assert len(starts) == 1
        for state in ("inactive", "activating", "deactivating"):
            _, starts = run("after / " + state, False, state)
            assert not starts
        _, starts = run("after / other user", False, user="other")
        assert not starts
        (work / "bus").unlink()
        _, starts = run("after / no user bus", False)
        assert not starts
    finally:
        bus.close()
print(
    "QUICKSHELL_SWITCH_POLICY_PASSED: 2 -> 1 start; sole start follows complete links"
)
