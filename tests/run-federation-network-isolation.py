#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3
"""Build only the isolated network VM from the root nixpkgs lock reference."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--log-dir", type=Path, default=Path("/tmp/federation-network-isolation-check")
    )
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.log_dir.mkdir(parents=True, exist_ok=True)
    lock = json.loads((root / "flake.lock").read_text())
    pin = lock["nodes"][lock["nodes"]["root"]["inputs"]["nixpkgs"]]["locked"]
    source = f"github:{pin['owner']}/{pin['repo']}/{pin['rev']}"
    metadata = subprocess.run(
        ["nix", "flake", "metadata", "--json", source],
        check=True,
        text=True,
        capture_output=True,
    )
    resolved = json.loads(metadata.stdout)
    assert resolved["locked"]["narHash"] == pin["narHash"], "locked source hash changed"
    (args.log_dir / "pin.json").write_text(
        json.dumps({"pin": pin, "path": resolved["path"]}, indent=2) + "\n"
    )
    command = [
        "nix-build",
        "tests/federation-network-isolation.nix",
        "--arg",
        "pkgs",
        f'import {resolved["path"]} {{ system = "x86_64-linux"; }}',
        "--no-out-link",
        "-j",
        "2",
    ]
    log = args.log_dir / "vm.log"
    with log.open("w") as output:
        result = subprocess.run(
            command, cwd=root, stdout=output, stderr=subprocess.STDOUT
        )
    print(f"{'PASS' if result.returncode == 0 else 'FAIL'}: {log}")
    if result.returncode:
        print(log.read_text()[-6000:])
    else:
        print(log.read_text().splitlines()[-1])
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
