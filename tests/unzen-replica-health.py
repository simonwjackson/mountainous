#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Require two available copies across independent bcachefs failure domains."""

import json
import subprocess
import sys

report = json.loads(
    subprocess.check_output(
        ["bcachefs", "fs", "failure-domains", "--json", sys.argv[1]], text=True
    )
)
if report["separation_violated"] or any(
    domain["lost_bytes"] != 0 for domain in report["domains"]
):
    print(json.dumps(report))
    sys.exit(1)
print(json.dumps(report))
