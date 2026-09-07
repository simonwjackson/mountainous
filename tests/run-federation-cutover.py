#!/usr/bin/env nix
#! nix shell nixpkgs#python3 --command python3
"""Local builds/tests only. Never invokes the operational runner on this host."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--producer-root", required=True)
    parser.add_argument("--selector", required=True)
    parser.add_argument("--retirement", required=True)
    parser.add_argument("--package-only", action="store_true")
    parser.add_argument("--faults-only", action="store_true")
    parser.add_argument("--proofs-only", action="store_true")
    parser.add_argument("--probes-only", action="store_true")
    parser.add_argument(
        "--smoke",
        action="store_true",
        help="One real normal-path VM; not full failure/reboot coverage",
    )
    parser.add_argument(
        "--log-dir", type=Path, default=Path("/tmp/federation-cutover-check")
    )
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.log_dir.mkdir(exist_ok=True, parents=True)
    command = [
        "nix-build",
        "tests/federation-cutover-build.nix",
        "--no-out-link",
        "-j",
        "2",
        "--cores",
        "4",
        "--argstr",
        "producerRoot",
        args.producer_root,
        "--argstr",
        "selector",
        args.selector,
        "--argstr",
        "retirement",
        args.retirement,
    ]
    stages = [("package", command + ["-A", "package"])]
    if not args.package_only:
        target = (
            "probes"
            if args.probes_only
            else "proofs"
            if args.proofs_only
            else "faults"
            if args.faults_only
            else "smoke"
            if args.smoke
            else "vm"
        )
        stages.append((target, command + ["-A", target]))
        if target == "vm":
            stages.extend(
                (name, command + ["-A", name])
                for name in ("probes", "faults", "proofs")
            )
    for name, argv in stages:
        with (args.log_dir / (name + ".log")).open("w") as log:
            process = subprocess.run(
                argv, cwd=root, stdout=subprocess.PIPE, stderr=log, text=True
            )
        (args.log_dir / (name + ".json")).write_text(
            json.dumps({"exit": process.returncode, "output": process.stdout})
        )
        if process.returncode:
            return process.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())
