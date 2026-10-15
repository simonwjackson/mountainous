"""The updater must retain the SSH host pins in its deployed closure."""
import json
import shlex
import sys
from pathlib import Path

command = shlex.split(Path(sys.argv[1]).read_text())
config_path = Path(command[command.index("--config") + 1])
config = json.loads(config_path.read_text())
pins = Path(config["builder"]["knownHosts"])
assert pins.exists(), f"Updater SSH pins missing from closure: {pins}"
assert any(
    line.startswith(config["builder"]["alias"] + " ssh-ed25519 ")
    for line in pins.read_text().splitlines()
), "Updater builder has no pinned SSH host key"
