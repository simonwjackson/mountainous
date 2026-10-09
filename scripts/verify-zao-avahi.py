#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Verify Zao's live Avahi build, printer discovery, resolution, and CPU use."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def command(*args):
    return subprocess.check_output(args, text=True, timeout=20).strip()


def sample(pid):
    text = Path(f"/proc/{pid}/stat").read_text()
    fields = text[text.rfind(")") + 2 :].split()
    ticks = int(fields[11]) + int(fields[12])
    status = Path(f"/proc/{pid}/status").read_text().splitlines()
    rss = next(
        line.split(":", 1)[1].strip() for line in status if line.startswith("VmRSS:")
    )
    return time.monotonic(), ticks, rss


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-package", required=True, type=Path)
    parser.add_argument("--seconds", type=int, default=300)
    parser.add_argument("--interval", type=int, default=10)
    parser.add_argument("--max-cpu", type=float, default=20)
    args = parser.parse_args()
    if args.seconds < 1 or args.interval < 1:
        parser.error("seconds and interval must be positive")

    assert command("hostname") == "zao", "Run this verifier on Zao"
    assert command("systemctl", "is-active", "avahi-daemon.service") == "active"
    pid = int(
        command("systemctl", "show", "avahi-daemon.service", "-p", "MainPID", "--value")
    )
    executable = Path(os.readlink(f"/proc/{pid}/exe"))
    assert executable.parent.parent == args.expected_package.resolve(), (
        "Avahi runs a different package"
    )

    browsing = command(
        "avahi-browse", "--resolve", "--parsable", "--terminate", "_ipp._tcp"
    )
    printer_records = [
        line
        for line in browsing.splitlines()
        if line.startswith("=")
        and ";zao.local;" in line
        and "rp=printers/Office_Printer" in line
    ]
    assert printer_records, "Office_Printer is not advertised and resolved through mDNS"
    resolution = command("getent", "ahostsv4", "zao.local")
    resolved = {line.split()[0] for line in resolution.splitlines()}
    addresses = json.loads(command("ip", "--json", "address", "show"))
    local_addresses = {
        address["local"]
        for interface in addresses
        for address in interface.get("addr_info", [])
        if address["family"] == "inet"
    }
    assert resolved & local_addresses, "zao.local does not resolve to this host"
    assert "Office_Printer" in command("lpstat", "-d", "-p", "Office_Printer")

    print(
        json.dumps(
            {
                "pid": pid,
                "executable": str(executable),
                "printerRecords": len(printer_records),
                "localResolution": sorted(resolved),
            },
            sort_keys=True,
        ),
        flush=True,
    )
    start, ticks, rss = sample(pid)
    previous = (start, ticks, rss)
    samples = []
    while time.monotonic() - start < args.seconds:
        remaining = args.seconds - (time.monotonic() - start)
        time.sleep(min(args.interval, max(0, remaining)))
        assert (
            int(
                command(
                    "systemctl",
                    "show",
                    "avahi-daemon.service",
                    "-p",
                    "MainPID",
                    "--value",
                )
            )
            == pid
        ), "Avahi restarted during measurement"
        current = sample(pid)
        elapsed = current[0] - previous[0]
        percent = (current[1] - previous[1]) / os.sysconf("SC_CLK_TCK") / elapsed * 100
        item = {
            "elapsedSeconds": round(current[0] - start, 2),
            "percentOfOneCore": round(percent, 3),
            "rss": current[2],
        }
        samples.append(item)
        print(json.dumps(item, sort_keys=True), flush=True)
        assert percent <= args.max_cpu, f"Avahi exceeded {args.max_cpu}% of one core"
        previous = current

    print(
        json.dumps(
            {
                "passed": True,
                "seconds": round(previous[0] - start, 2),
                "maximumCpuPercent": max(s["percentOfOneCore"] for s in samples),
                "memoryBefore": rss,
                "memoryAfter": previous[2],
            },
            sort_keys=True,
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
