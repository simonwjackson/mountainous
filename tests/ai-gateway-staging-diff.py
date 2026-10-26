"""Regression tests for the production-unit equality guard."""

import copy
import pathlib
import runpy
import sys

header = pathlib.Path(sys.argv[1]).read_text().splitlines()[:2]
assert header == [
    "#!/usr/bin/env nix-shell",
    "#!nix-shell -i python3 -p python3 nix git",
]
script = runpy.run_path(sys.argv[1])
compare = script["compare"]
services = script["NEW_SERVICES"]
secrets = script["NEW_SECRETS"]
before = {
    "units": ["cliproxyapi.service"],
    "services": {
        "cliproxyapi": {
            "ExecStart": "/production/bin/cli-proxy-api",
            "environment": {"HOME": "/production"},
        }
    },
    "secrets": {"litellm-env": {"key": "litellm-env"}},
    "tailnetNames": {"decide": {"backend": "http://127.0.0.1:4000"}},
}
after = copy.deepcopy(before)
after["units"].extend(name + ".service" for name in services)
after["services"].update({name: {"ExecStart": "/staging"} for name in services})
after["secrets"].update({name: {"key": name} for name in secrets})
after["tailnetNames"]["ai-staging"] = {"backend": "http://127.0.0.1:8420"}
assert compare(before, after)["status"] == "PASS"
for kind, name, field in [
    ("services", "cliproxyapi", "ExecStart"),
    ("services", "cliproxyapi", "environment"),
    ("secrets", "litellm-env", "key"),
    ("tailnetNames", "decide", "backend"),
]:
    changed = copy.deepcopy(after)
    changed[kind][name][field] = "UNEXPECTED"
    assert compare(before, changed)["status"] == "FAIL"
changed = copy.deepcopy(after)
changed["units"].append("unexpected.service")
assert compare(before, changed)["status"] == "FAIL"
changed = copy.deepcopy(after)
changed["units"].remove("cliproxyapi.service")
assert compare(before, changed)["status"] == "FAIL"
print(
    "PASS: production diff guard rejects ExecStart, environment, secret, name, added/removed unit changes"
)
