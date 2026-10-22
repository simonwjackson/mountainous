"""Local check: cmd_verify reads names with Unicode line separators,
backslashes and newlines, and catches a changed file."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import types

d = tempfile.mkdtemp()
pool = os.path.join(d, "pool")
os.makedirs(pool)
names = ["plain.txt", "sep\u2028here", "nel\x85x", "back\\slash", "new\nline"]
for n in names:
    with open(os.path.join(pool, n), "w") as f:
        f.write(n)
manifest = subprocess.run(
    f"cd {pool} && find . -type f -printf '%P\\0' | sort -z | xargs -0 sha256sum",
    shell=True, capture_output=True, check=True,
).stdout
open(os.path.join(d, "m.sha256"), "wb").write(manifest)
state = os.path.join(d, "state")
os.makedirs(state)
open(os.path.join(state, "format.json"), "w").write("{}")
cfg = os.path.join(d, "c.json")
json.dump({"mountPoint": pool}, open(cfg, "w"))
os.environ.update(TOWADA_CONFIG=cfg, TOWADA_STATE=state)
spec = importlib.util.spec_from_file_location("tc", sys.argv[1])
tc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tc)
tc.cmd_verify(types.SimpleNamespace(manifest=os.path.join(d, "m.sha256")))
assert os.path.exists(os.path.join(state, "verify.json"))
os.remove(os.path.join(state, "verify.json"))
open(os.path.join(pool, "nel\x85x"), "w").write("changed")
try:
    tc.cmd_verify(types.SimpleNamespace(manifest=os.path.join(d, "m.sha256")))
except SystemExit as e:
    assert e.code == 1
    print("PASS: tricky names parsed; changed file caught")
else:
    raise AssertionError("changed file not caught")
