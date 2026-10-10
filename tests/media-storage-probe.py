#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Exercise an import writer with the application's actual 0002 mask."""
import os
from pathlib import Path
import sys

os.umask(0o002)
path = Path(sys.argv[1])
path.write_bytes(b"fixture-import-data")
# Imports preserve source modification times, not only file contents.
os.utime(path, ns=(1700000000000000000, 1700000000000000000))
renamed = path.with_name(path.name + ".renamed")
path.rename(renamed)
renamed.rename(path)
assert path.read_bytes() == b"fixture-import-data"
assert path.stat().st_mtime_ns == 1700000000000000000
