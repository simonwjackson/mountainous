"""Real GApplications on a private bus: unique, NON_UNIQUE and custom IDs."""

import importlib.util
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

if sys.argv[1] == "--application":
    name, unique, output = sys.argv[2:]
    app = Gio.Application(
        application_id=name,
        flags=(
            Gio.ApplicationFlags.DEFAULT_FLAGS
            if unique == "yes"
            else Gio.ApplicationFlags.NON_UNIQUE
        ),
    )
    action = Gio.SimpleAction.new("reload-config", None)
    action.connect("activate", lambda *_: Path(output).write_text("reloaded"))
    app.add_action(action)
    app.register(None)
    Path(output + ".ready").touch()
    GLib.MainLoop().run()
    sys.exit()

spec = importlib.util.spec_from_file_location("reload", sys.argv[1])
reload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reload)
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
children = []
with tempfile.TemporaryDirectory() as directory:
    try:
        # An empty session never creates an application or acquires its name.
        assert reload.reload_all(bus) == set()
        assert reload.ghostty_process(os.getpid()) is False
        assert reload.ghostty_process(2147483647) is False
        for i, (name, unique) in enumerate(
            (
                ("com.mitchellh.ghostty", "yes"),
                ("com.mitchellh.ghostty", "no"),
                ("com.mitchellh.ghostty", "no"),
                ("io.github.simonwjackson.mountainous.term", "no"),
                ("test.custom.Ghostty", "yes"),
                ("test.unrelated.Application", "yes"),
            )
        ):
            output = str(Path(directory) / str(i))
            child = subprocess.Popen(
                [sys.executable, __file__, "--application", name, unique, output]
            )
            children.append(child)
            for _ in range(100):
                if Path(output + ".ready").exists():
                    break
                assert child.poll() is None
                time.sleep(0.02)
            assert Path(output + ".ready").exists()
        accepted = {child.pid for child in children[:-1]}
        targets = reload.reload_all(bus, accepts=accepted.__contains__)
        assert len(targets) == 5, targets
        for _ in range(100):
            if all((Path(directory) / str(i)).exists() for i in range(5)):
                break
            time.sleep(0.02)
        assert all(
            (Path(directory) / str(i)).read_text() == "reloaded" for i in range(5)
        )
        assert not (Path(directory) / "5").exists()
        print("PASS: 5 application instances reloaded; unrelated app untouched")
    finally:
        for child in children:
            child.terminate()
        for child in children:
            child.wait(timeout=5)
print("processes left: 0")
