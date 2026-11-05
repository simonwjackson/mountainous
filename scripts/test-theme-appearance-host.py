"""Exercise the real Quickshell host/catalog/picker model without a compositor."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

source, kit, qs = map(Path, sys.argv[1:4])
registry = json.loads((source / "themes.json").read_text())
with tempfile.TemporaryDirectory(prefix="appearance-host-") as directory:
    root = Path(directory)
    config = root / "config"
    state = root / "state/mountainous"
    runtime = root / "run"
    for path in (config, state, runtime):
        path.mkdir(parents=True, mode=0o700)
    for name in ("Theme.qml", "ThemeCatalog.qml", "ThemePicker.qml", "themes.json"):
        shutil.copyfile(source / name, config / name)
    (config / "shell.qml").write_text("""import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    IpcHandler {
        target: "test"
        function snapshot(): string {
            return JSON.stringify({name: Theme.name, mode: Theme.mode,
                appearance: Theme.appearance, extra: Theme.extraState,
                currentAppearance: ThemePicker.currentAppearance,
                choices: ThemePicker.choices.length});
        }
        function preview(theme: string, id: string): string { return ThemePicker.preview(theme, id); }
    }
}
""")
    env = os.environ | {
        "HOME": str(root),
        "XDG_STATE_HOME": str(root / "state"),
        "XDG_CONFIG_HOME": str(config),
        "XDG_RUNTIME_DIR": str(runtime),
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QUICK_BACKEND": "software",
        "QML2_IMPORT_PATH": str(kit) + ":" + os.environ.get("QML2_IMPORT_PATH", ""),
        "QML_IMPORT_PATH": str(kit) + ":" + os.environ.get("QML_IMPORT_PATH", ""),
    }
    log_path = root / "quickshell.log"
    with log_path.open("w") as log:
        shell = subprocess.Popen(
            [str(qs), "-p", str(config)], env=env, stdout=log, stderr=log
        )
        try:

            def call(*arguments):
                return subprocess.run(
                    [str(qs), "-p", str(config), "ipc", "call", "test", *arguments],
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=3,
                    check=False,
                )

            def await_state(name, appearance, mode):
                deadline = time.monotonic() + 15
                last = None
                while time.monotonic() < deadline:
                    response = call("snapshot")
                    try:
                        last = json.loads(response.stdout)
                    except json.JSONDecodeError:
                        time.sleep(0.05)
                        continue
                    if (last["name"], last["appearance"], last["mode"]) == (
                        name,
                        appearance,
                        mode,
                    ):
                        assert last["choices"] == 25, last
                        assert last["currentAppearance"] == appearance, last
                        return
                    time.sleep(0.05)
                raise AssertionError(
                    (name, appearance, mode, last, log_path.read_text())
                )

            def write(name, value):
                temporary = state / (name + ".new")
                temporary.write_text(value + "\n")
                temporary.replace(state / name)

            await_state("platinum", "dark-grey", "dark")
            for theme in registry:
                write("theme-name", theme["id"])
                write("theme-extra", "on")
                for choice in theme["appearances"]:
                    # A known ID wins over a contradictory old mode.
                    write("theme", "light" if choice["mode"] == "dark" else "dark")
                    write("theme-appearance", choice["id"])
                    await_state(theme["id"], choice["id"], choice["mode"])
                    preview = call("preview", theme["id"], choice["id"])
                    assert preview.returncode == 0 and preview.stdout.strip().endswith(
                        choice["thumbnail"]
                    ), preview
                for mode in ("light", "dark"):
                    write("theme", mode)
                    write("theme-appearance", "future-choice")
                    fallback = (
                        "dark-grey"
                        if mode == "dark"
                        else "standard"
                        if theme["id"] == "memphis"
                        else "light"
                    )
                    await_state(theme["id"], fallback, mode)
                    assert (
                        state / "theme-appearance"
                    ).read_text().strip() == "future-choice"
                    (state / "theme-appearance").unlink()
                    await_state(theme["id"], fallback, mode)
            print(
                "APPEARANCE_HOST_PASSED: 25 live state/preview choices, old files, unknown IDs"
            )
        finally:
            shell.terminate()
            try:
                shell.wait(timeout=5)
            except subprocess.TimeoutExpired:
                shell.kill()
                shell.wait()
            print(log_path.read_text())
