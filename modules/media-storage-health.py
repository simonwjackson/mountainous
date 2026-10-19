"""Read the managed filesystem views, not merely their mount table entries.

A successful range-root stat can hide an ESTALE bindfs branch. Read each branch
before its union. One readdir batch per root avoids walking the media library.
The systemd caller bounds this read-only probe; it never repairs mounts.
"""

import os
import stat
import subprocess
import sys


def check(paths):
    mounts = set()
    with open("/proc/self/mountinfo") as handle:
        for line in handle:
            mounts.add(line.split()[4].replace("\\040", " ").replace("\\134", "\\"))
    if not paths:
        raise ValueError("no managed storage paths configured")
    for path in paths:
        if path not in mounts:
            raise ValueError(f"not a mountpoint: {path}")
        if not stat.S_ISDIR(os.stat(path).st_mode):
            raise ValueError(f"not a directory: {path}")
        with os.scandir(path) as entries:
            next(entries, None)


if __name__ == "__main__":
    try:
        if sys.argv[1:2] == ["--read"]:
            check(sys.argv[2:])
        else:
            # wait(timeout) uses waitpid/clock reads, not POSIX timer_create,
            # which Transmission's unchanged syscall sandbox forbids.
            subprocess.run(
                [sys.executable, __file__, "--read", *sys.argv[1:]],
                check=True,
                timeout=20,
            )
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"Media storage unavailable: {error}")
