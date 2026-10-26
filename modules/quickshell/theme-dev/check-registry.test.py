#!/usr/bin/env python3
"""Every installed entry must declare a supported Pyxamp face."""

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1]).resolve()
validator = (
    Path(sys.argv[2]) if len(sys.argv) > 2 else root / "theme-dev/check-boundaries.py"
)
original = json.loads((root / "themes.json").read_text())
with tempfile.TemporaryDirectory() as directory:
    staged = Path(directory) / "shell"
    shutil.copytree(root, staged, symlinks=True)
    registry = staged / "themes.json"
    registry.chmod(0o600)
    for index, theme in enumerate(original):
        for value in (None, "unknown", "", 1):
            entries = json.loads(json.dumps(original))
            if value is None:
                entries[index].pop("pyxampFace", None)
            else:
                entries[index]["pyxampFace"] = value
            registry.write_text(json.dumps(entries))
            result = subprocess.run(
                [sys.executable, str(validator), str(staged)],
                check=False,
                capture_output=True,
                text=True,
            )
            assert result.returncode != 0, (theme["id"], value, "accepted invalid face")
            assert "pyxampFace" in result.stderr, result.stderr
    registry.write_text(json.dumps(original))
    subprocess.run([sys.executable, str(validator), str(staged)], check=True)
print("THEME_REGISTRY_TESTS_PASSED: missing/invalid faces rejected on every entry")
