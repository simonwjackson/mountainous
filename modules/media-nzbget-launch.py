#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Add reversible native startup holds without rewriting NZBGet's configuration.

Admission must first prove no queued post-processing or force-priority jobs.
The binary and normal public path overrides are supplied by the NixOS unit.
"""
import os
from pathlib import Path
import re
import sys


def hold_flags(settings):
    tasks = sorted({int(match.group(1)) for key in settings
                    if (match := re.fullmatch(r"Task(\d+)\..+", key))})
    feeds = sorted({int(match.group(1)) for key in settings
                    if (match := re.fullmatch(r"Feed(\d+)\..+", key))})
    flags = ["--pause", "--option", "NzbDirInterval=0", "--option", "UrlForce=no"]
    # An empty task time creates no scheduler task in NZBGet 26.0.
    for number in tasks:
        flags += ["--option", f"Task{number}.Time="]
    for number in feeds:
        flags += ["--option", f"Feed{number}.Interval=0"]
    # Native startup tasks pause all activities. Original task definitions and
    # credentials stay unchanged in the transferred configuration file.
    for number, command in enumerate(("PauseDownload", "PausePostProcess", "PauseScan"), 1):
        flags += ["--option", f"Task{number}.Time=*", "--option", f"Task{number}.WeekDays=",
                  "--option", f"Task{number}.Command={command}"]
    return flags


def main():
    binary, mode, config = sys.argv[1:4]
    if mode not in ("held", "enabled"):
        raise ValueError("unknown processing mode")
    argv = [binary, "--server", "--configfile", config] + sys.argv[4:]
    if mode == "held":
        settings = dict(tuple(part.strip() for part in line.split("=", 1))
                        for line in Path(config).read_text().splitlines()
                        if line.strip() and not line.lstrip().startswith("#") and "=" in line)
        argv += hold_flags(settings)
    os.execv(binary, argv)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Refused NZBGet startup: unable to apply the processing hold", file=sys.stderr)
        sys.exit(1)
