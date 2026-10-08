#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 openssh
from pathlib import Path
import subprocess

options = ["-F", "/dev/null", "-i", str(Path.home() / ".ssh/id_rsa"), "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3"]
result = "/tmp/bcachefs-build-benchmark-aka-20261008"
try:
    subprocess.run(["ssh", *options, "simonwjackson@aka", "nix-shell /tmp/run-bcachefs-build-benchmark.py --result-dir " + result], check=True, timeout=3600)
finally:
    subprocess.run(["scp", *options, "-r", "simonwjackson@aka:" + result, "/tmp/"], check=False, timeout=90)
