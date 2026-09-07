#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3
"""Run only local filesystem tests and the isolated NixOS VM, never a live host."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unit-only", action="store_true")
    parser.add_argument(
        "--log-dir", type=Path, default=Path("/tmp/federation-isolation-check")
    )
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.log_dir.mkdir(parents=True, exist_ok=True)
    commands = [
        [
            sys.executable,
            "-m",
            "unittest",
            "discover",
            "-s",
            "tests",
            "-p",
            "test_federation_isolation.py",
            "-v",
        ]
    ]
    if not args.unit_only:
        lock = json.loads((root / "flake.lock").read_text())
        pin = lock["nodes"][lock["nodes"]["root"]["inputs"]["nixpkgs"]]["locked"]
        source = f"github:{pin['owner']}/{pin['repo']}/{pin['rev']}"
        metadata = subprocess.run(
            ["nix", "flake", "metadata", "--json", source],
            check=True,
            text=True,
            capture_output=True,
        )
        path = json.loads(metadata.stdout)["path"]
        commands.append(
            [
                "nix-build",
                "tests/federation-isolation.nix",
                "--arg",
                "pkgs",
                f'import {path} {{ system = "x86_64-linux"; }}',
                "--no-out-link",
                "-j",
                "2",
            ]
        )
    for number, command in enumerate(commands):
        log = args.log_dir / ("unit.log" if number == 0 else "vm.log")
        with log.open("w") as output:
            result = subprocess.run(
                command, cwd=root, stdout=output, stderr=subprocess.STDOUT
            )
        print(f"{'PASS' if result.returncode == 0 else 'FAIL'}: {log}")
        if result.returncode:
            print(log.read_text()[-3500:])
            return result.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
