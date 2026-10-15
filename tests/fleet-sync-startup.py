"""All paths used by the shipped pre-start commands must enter its closure."""
import json
import shlex
import sys
from pathlib import Path

for command in json.loads(Path(sys.argv[1]).read_text()):
    for argument in shlex.split(command):
        path = argument.removeprefix("+")
        if path.startswith("/nix/store/"):
            assert Path(path).exists(), f"Startup dependency missing from closure: {path}"
