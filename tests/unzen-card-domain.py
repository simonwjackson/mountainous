#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
"""Assign the shared PCIe-card failure domain through the mounted kernel API."""

from pathlib import Path
import sys

filesystem = Path(sys.argv[1])
label = sys.argv[2]
if not label.startswith("card."):
    raise RuntimeError("Refuse to change an onboard failure domain")
members = [
    member
    for member in filesystem.glob("dev-*")
    if (member / "label").read_text().strip() == label
]
if len(members) != 1 or not (members[0] / "block").exists():
    raise RuntimeError("Expected exactly one online card member")
if (members[0] / "durability").read_text().strip() != "1":
    raise RuntimeError("Unexpected member durability")
option = members[0] / "failure_domain"
option.write_text("pcie-card\n")
if option.read_text().strip() != "pcie-card":
    raise RuntimeError("Failure domain assignment did not persist")
print(f"{label}: failure_domain=pcie-card")
