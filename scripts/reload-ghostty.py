"""Reload every Ghostty on this session bus, including non-unique/custom IDs.

GApplication NON_UNIQUE has no well-known bus name, but exports actions on its
unique connection. Discover those connections, identify their executable, then
read their actual object tree. Never activate a well-known name, start a process,
send a key, or change window focus.
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


def call(bus, destination, path, interface, method, parameters=None):
    return bus.call_sync(
        destination,
        path,
        interface,
        method,
        parameters,
        None,
        Gio.DBusCallFlags.NO_AUTO_START,
        1000,
        None,
    ).unpack()


def ghostty_process(pid):
    try:
        return Path(f"/proc/{pid}/exe").readlink().name in (
            "ghostty",
            ".ghostty-wrapped",
        )
    except OSError:
        return False  # Exited between ListNames and the executable lookup.


def action_paths(bus, owner):
    pending = ["/"]
    while pending:
        path = pending.pop()
        (xml,) = call(
            bus, owner, path, "org.freedesktop.DBus.Introspectable", "Introspect"
        )
        node = ET.fromstring(xml)
        if any(i.get("name") == "org.gtk.Actions" for i in node.findall("interface")):
            (actions,) = call(bus, owner, path, "org.gtk.Actions", "List")
            if "reload-config" in actions:
                yield path
        pending.extend(
            path.rstrip("/") + "/" + n.attrib["name"] for n in node.findall("node")
        )


def reload_all(bus, accepts=ghostty_process):
    (names,) = call(
        bus,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "ListNames",
    )
    reloaded = set()
    for owner in names:
        if not owner.startswith(":"):
            continue  # One call per unique connection, never per alias.
        try:
            (pid,) = call(
                bus,
                "org.freedesktop.DBus",
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "GetConnectionUnixProcessID",
                GLib.Variant("(s)", (owner,)),
            )
            if not accepts(pid):
                continue
            for path in action_paths(bus, owner):
                if (pid, path) not in reloaded:
                    call(
                        bus,
                        owner,
                        path,
                        "org.gtk.Actions",
                        "Activate",
                        GLib.Variant("(sava{sv})", ("reload-config", [], {})),
                    )
                    reloaded.add((pid, path))
        except (GLib.Error, ET.ParseError) as error:
            # A terminal closing must not prevent the remaining reloads.
            print(f"desktop-theme: Ghostty {owner}: {error}", file=sys.stderr)
    return reloaded


if __name__ == "__main__":
    try:
        reload_all(Gio.bus_get_sync(Gio.BusType.SESSION, None))
    except GLib.Error as error:
        print(f"desktop-theme: Ghostty reload unavailable: {error}", file=sys.stderr)
        sys.exit(1)
