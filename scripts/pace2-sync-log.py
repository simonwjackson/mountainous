#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Project a Pace sync log to outcome and warning codes; never expose figures."""
import json
import re
import sys


def parse_sync_line(line):
    if "bank sync outcome=" not in line:
        return None
    outcome = re.search(r'outcome=("[^"]*"|[A-Za-z]+)', line)
    warnings = re.search(r'warnings=(\[[^\]]*\])', line)
    if outcome is None or warnings is None:
        raise ValueError("sync log lacks outcome or warning codes")
    raw = outcome.group(1)
    outcome = json.loads(raw) if raw.startswith('"') else raw
    warnings = json.loads(warnings.group(1))
    if outcome not in ("complete", "partial", "failed"):
        raise ValueError("unknown sync outcome")
    if not isinstance(warnings, list) or not all(isinstance(code, str) for code in warnings):
        raise ValueError("invalid warning codes")
    return {"outcome": outcome, "warnings": warnings}


if __name__ == "__main__":
    for line in sys.stdin:
        report = parse_sync_line(line)
        if report is not None:
            print(json.dumps(report))
