#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Admit first Scryer start or readable existing state. Delegate ARR unchanged."""
import importlib.util
import os
from pathlib import Path
import stat
import sys

spec = importlib.util.spec_from_file_location("arr_state", Path(__file__).with_name("media-arr-state-ready.py"))
arr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(arr)
# Preserve the existing validation API used by the state command and tests.
globals().update({name: value for name, value in vars(arr).items() if not name.startswith("_")})


def validate_scryer(directory):
    directory = Path(directory)
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError("invalid state directory")
    if not list(directory.iterdir()):
        return
    database = directory / "scryer.db"
    descriptor = os.open(database, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode) or not os.read(descriptor, 1):
            raise ValueError("invalid database")
    finally:
        os.close(descriptor)


def main():
    if sys.argv[1] == "scryer":
        validate_scryer(Path("/var/lib/scryer"))
        print("Application state passed startup validation")
    else:
        arr.main()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Refused startup: application state is missing or invalid", file=sys.stderr)
        sys.exit(1)
