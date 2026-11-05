"""Exercise the real host model, optionally checking headless desktop pixels."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def stop(process):
    if process is None:
        return
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


source, kit, qs = map(Path, sys.argv[1:4])
registry = json.loads((source / "themes.json").read_text())
labwc = Path(sys.argv[4]) if len(sys.argv) > 4 else None
schemes = {}
if labwc:
    from PIL import Image

    schemes = {
        s["name"].lower().replace(" #", "-").replace(" ", "-"): s["colors"]
        for s in json.loads(Path(os.environ["SCHEMES_JSON"]).read_text())
        if not s["name"].startswith("Classic")
    }
with tempfile.TemporaryDirectory(prefix="appearance-host-") as directory:
    root = Path(directory)
    config = root / "config"
    state = root / "state/mountainous"
    runtime = root / "run"
    for path in (config, state, runtime):
        path.mkdir(parents=True, mode=0o700)
    for name in ("Theme.qml", "ThemeCatalog.qml", "ThemePicker.qml", "themes.json"):
        shutil.copyfile(source / name, config / name)
    if labwc:
        for name in ("DesktopPattern.qml", "desktop-art.js"):
            shutil.copyfile(source / name, config / name)
        for theme in registry:
            shutil.copytree(
                source / "themes" / theme["id"] / "patterns",
                config / "themes" / theme["id"] / "patterns",
            )
    shell_source = """import Quickshell
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
        function resolve(theme: string, id: string, mode: string): string {
            return JSON.stringify(ThemeCatalog.resolveAppearance(theme, id, mode));
        }
    }
}
"""
    if labwc:
        shell_source = shell_source.replace(
            "ShellRoot {",
            "ShellRoot {\n    DesktopPattern { id: desktop; screen: Quickshell.screens[0] }",
        )
        shell_source = shell_source.replace(
            "choices: ThemePicker.choices.length",
            "choices: ThemePicker.choices.length, desktopColor: desktop.color.toString(), desktopFile: desktop.file",
        )
    (config / "shell.qml").write_text(shell_source)
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
    if labwc:
        env.update(
            QT_QPA_PLATFORM="wayland",
            WAYLAND_DISPLAY="wayland-0",
            WLR_BACKENDS="headless",
            WLR_RENDERER="pixman",
            WLR_LIBINPUT_NO_DEVICES="1",
        )
    log_path = root / "quickshell.log"
    with log_path.open("w") as log:
        compositor = None
        if labwc:
            compositor_config = root / "labwc"
            compositor_config.mkdir()
            (compositor_config / "autostart").write_text("")
            compositor = subprocess.Popen(
                [str(labwc), "-C", str(compositor_config)],
                env=env,
                stdout=log,
                stderr=log,
            )
            deadline = time.monotonic() + 15
            while not (runtime / "wayland-0").exists():
                if compositor.poll() is not None or time.monotonic() > deadline:
                    stop(compositor)
                    raise AssertionError(log_path.read_text())
                time.sleep(0.05)
        try:
            shell = subprocess.Popen(
                [str(qs), "-p", str(config)], env=env, stdout=log, stderr=log
            )
        except OSError:
            stop(compositor)
            raise
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
                    resolved = json.loads(
                        call(
                            "resolve",
                            theme["id"],
                            choice["id"],
                            "light" if choice["mode"] == "dark" else "dark",
                        ).stdout
                    )
                    assert resolved["id"] == choice["id"], resolved
                    if labwc and theme["id"] == "memphis" and choice["id"] in schemes:
                        expected = schemes[choice["id"]]["Desktop"]
                        actual = json.loads(call("snapshot").stdout)
                        assert (
                            actual["desktopFile"] == ""
                            and actual["desktopColor"] == expected
                        ), actual
                        # Check actual compositor paint, not only the QML property.
                        rgb = tuple(int(expected[i : i + 2], 16) for i in (1, 3, 5))
                        deadline = time.monotonic() + 5
                        while True:
                            shot = root / "desktop.png"
                            subprocess.run(
                                ["grim", str(shot)],
                                env=env,
                                check=True,
                                capture_output=True,
                            )
                            with Image.open(shot) as image:
                                pixel = image.convert("RGB").getpixel(
                                    (image.width // 2, image.height // 2)
                                )
                            if pixel == rgb:
                                break
                            assert time.monotonic() < deadline, (
                                choice["id"],
                                pixel,
                                rgb,
                            )
                            time.sleep(0.05)
                        print("DESKTOP_PIXEL_PASSED", choice["id"], expected, pixel)
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
                    resolved = json.loads(
                        call("resolve", theme["id"], "future-choice", mode).stdout
                    )
                    assert resolved["id"] == fallback, resolved
                    assert (
                        state / "theme-appearance"
                    ).read_text().strip() == "future-choice"
                    (state / "theme-appearance").unlink()
                    await_state(theme["id"], fallback, mode)
            assert (
                json.loads(call("resolve", "memphis", "light", "dark").stdout)["id"]
                == "dark-grey"
            )
            assert (
                json.loads(call("resolve", "unknown-theme", "brick", "light").stdout)
                is None
            )
            print(
                "APPEARANCE_HOST_PASSED: 25 live state/preview choices, old files, unknown IDs"
            )
        finally:
            stop(shell)
            stop(compositor)
            print(log_path.read_text())
