#!/usr/bin/env python3
"""Forced SSH transport for bounded, non-delegating native app builds."""

import os
import re
import sys


def command(original, nix_bin):
    if original == "nix-daemon --stdio":
        return [nix_bin + "/nix-daemon", "--stdio"]
    match = re.fullmatch(
        r"app-native-build (/nix/store/[a-z0-9]{32}-[^/\s]+\.drv)", original
    )
    if not match:
        raise ValueError("Only native app builds and store transport are allowed")
    return [
        nix_bin + "/nix-store",
        "--realise",
        match[1],
        "--max-jobs",
        "2",
        "--cores",
        "4",
        "--option",
        "builders",
        "",
    ]


if __name__ == "__main__":
    try:
        argv = command(os.environ.get("SSH_ORIGINAL_COMMAND", ""), sys.argv[1])
    except ValueError as error:
        sys.exit(str(error))
    os.execv(argv[0], argv)
