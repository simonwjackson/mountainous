#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 openssh
import json
import os
from pathlib import Path
import shlex
import subprocess

manifest = json.loads(Path("/tmp/unzen-zao-benchmark-inputs.json").read_text())
options = ["-F", "/dev/null", "-i", str(Path.home() / ".ssh/id_rsa"), "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=10"]
env = dict(os.environ, NIX_SSHOPTS=shlex.join(options))
store = "ssh-ng://simonwjackson@aka"
paths = [*manifest["input_outputs"], "/nix/store/gnsdbdn3v70f5yfyxbvwjhml1vbnx5qa-bcachefs-6.18.53-1.39.6"]
print("Preparing exact cached build inputs and comparison output on Aka; no build timing yet", flush=True)
subprocess.run(["nix", "copy", "--derivation", "--to", store, manifest["derivation"]], env=env, check=True, timeout=1800)
# Scoped import of our own Zao-built artifacts over already trusted SSH.
subprocess.run(["nix", "copy", "--no-check-sigs", "--to", store, *paths], env=env, check=True, timeout=1800)
subprocess.run(["nix", "store", "verify", "--no-trust", "--recursive", *paths], check=True, timeout=1800)
subprocess.run(["nix", "store", "verify", "--no-trust", "--recursive", "--store", store, *paths], env=env, check=True, timeout=1800)
subprocess.run(["scp", *options, "/tmp/run-bcachefs-build-benchmark.py", "simonwjackson@aka:/tmp/run-bcachefs-build-benchmark.py"], check=True, timeout=30)
print("AKA_BENCHMARK_INPUTS_READY", flush=True)
