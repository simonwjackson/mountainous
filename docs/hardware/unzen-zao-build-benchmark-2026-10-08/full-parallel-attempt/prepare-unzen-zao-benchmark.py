#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 openssh
import json
import os
from pathlib import Path
import shlex
import subprocess

DRV = "/nix/store/98klz3frilgg1k4d1i2xxar32dqdjxky-bcachefs-6.18.53-1.39.6.drv"
options = ["-F", "/dev/null", "-i", str(Path.home() / ".ssh/id_rsa"), "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "HostKeyAlias=unzen-first-boot", "-o", "UserKnownHostsFile=/tmp/unzen-first-boot-known_hosts", "-o", "ConnectTimeout=10"]
env = dict(os.environ, NIX_SSHOPTS=shlex.join(options))
raw = json.loads(subprocess.check_output(["nix", "derivation", "show", DRV], text=True))
data = next(iter(raw.get("derivations", raw).values()))
inputs = data["inputs"]["drvs"]
installables = ["/nix/store/" + path + "^" + ",".join(value["outputs"]) for path, value in inputs.items()]
print("Realizing build inputs before timing", flush=True)
paths = subprocess.check_output(["nix", "build", "--no-link", "--print-out-paths", "--builders", "", *installables], text=True, timeout=1800).splitlines()
print("Copying exact derivation and input closures to Unzen before timing", flush=True)
subprocess.run(["nix", "copy", "--derivation", "--to", "ssh-ng://root@192.168.1.114", DRV], env=env, check=True, timeout=1800)
# These are our own Zao-built inputs, transferred only over pinned SSH.
# Signature bypass applies to this import, not Unzen's global trust policy.
subprocess.run(["nix", "copy", "--no-check-sigs", "--to", "ssh-ng://root@192.168.1.114", *paths], env=env, check=True, timeout=1800)
subprocess.run(["nix", "store", "verify", "--no-trust", "--recursive", *paths], check=True, timeout=1800)
subprocess.run(["nix", "store", "verify", "--no-trust", "--recursive", "--store", "ssh-ng://root@192.168.1.114", *paths], env=env, check=True, timeout=1800)
subprocess.run(["scp", *options, "/tmp/run-bcachefs-build-benchmark.py", "root@192.168.1.114:/tmp/run-bcachefs-build-benchmark.py"], check=True, timeout=30)
Path("/tmp/unzen-zao-benchmark-inputs.json").write_text(json.dumps({"derivation": DRV, "input_outputs": paths}, indent=2) + "\n")
print("BENCHMARK_INPUTS_READY", flush=True)
