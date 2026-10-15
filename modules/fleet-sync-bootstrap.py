#!/usr/bin/env python3
"""Disable discovery before Syncthing can make its first network connection."""

import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def prepare(binary, directory, settings):
    path = Path(directory) / "config.xml"
    if not path.exists():
        subprocess.run(
            [binary, "generate", "--home", str(directory)],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    tree = ET.parse(path)
    options = tree.getroot().find("options")
    if options is None:
        options = ET.SubElement(tree.getroot(), "options")
    for key in (
        "globalAnnounceEnabled",
        "localAnnounceEnabled",
        "relaysEnabled",
        "natEnabled",
        "urAccepted",
        "autoUpgradeIntervalH",
    ):
        element = options.find(key)
        if element is None:
            element = ET.SubElement(options, key)
        value = settings[key]
        element.text = str(value).lower() if isinstance(value, bool) else str(value)
    for element in list(options.findall("listenAddress")):
        options.remove(element)
    for address in settings["listenAddresses"]:
        ET.SubElement(options, "listenAddress").text = address
    temporary = path.with_suffix(".xml.fleet-sync-new")
    with temporary.open("wb") as stream:
        tree.write(stream, encoding="utf-8", xml_declaration=True)
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)


if __name__ == "__main__":
    prepare(
        sys.argv[1], sys.argv[2], json.loads(Path(sys.argv[3]).read_text())["options"]
    )
