"""Export the real kit's public QML palette functions as JSON for seam checks."""

import json
import subprocess
import sys

result = subprocess.run(
    ["qmltestrunner", "-input", sys.argv[1], "-o", "-,txt"],
    capture_output=True,
    text=True,
    check=False,
)
if result.returncode:
    sys.exit(result.stdout + result.stderr)
palettes = {}
for line in result.stdout.splitlines():
    if "HENSOU_PALETTE:" not in line:
        continue
    row = json.loads(line.partition("HENSOU_PALETTE:")[2])
    theme = palettes.setdefault(row["theme"], {})
    assert row["id"] not in theme, (row["theme"], row["id"], "duplicate palette")
    assert set(row["palettes"]) == {"off", "on"}, row
    assert row["mode"] in ("light", "dark"), row
    theme[row["id"]] = dict(row["palettes"], mode=row["mode"])
assert len(palettes.get("platinum", {})) == 3, palettes.keys()
assert len(palettes.get("memphis", {})) == 22, palettes.keys()
print(json.dumps(palettes, sort_keys=True))
