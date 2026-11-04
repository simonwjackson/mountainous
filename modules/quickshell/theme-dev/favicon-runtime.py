#!/usr/bin/env python3
"""Exercise production favicon discovery/decoding with Chromium and Qt at 1.5x.
Pass the source directory; CHROMIUM and QS name the pinned executables.
No external network, compositor, desktop profile or Python packages are used.
"""

import http.server
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zlib

source = pathlib.Path(sys.argv[1])
work = pathlib.Path(tempfile.mkdtemp(prefix="mountainous-favicon-sharp-"))
print("Evidence:", work, flush=True)
for directory in ["runtime", "home", "config/chromium", "data/applications", "shell"]:
    (work / directory).mkdir(parents=True)
(work / "runtime").chmod(0o700)
for name in ["CdpBrowser.qml", "WindowIcon.qml", "cdp-target.js", "favicon.js"]:
    shutil.copy(source / name, work / "shell" / name)


def ico():
    blocks = []
    for size in [16, 32]:
        pixels = bytes([40, 40, 255, 255]) * (size * size)
        mask = bytes(((size + 31) // 32) * 4 * size)
        blocks.append(
            struct.pack(
                "<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, len(pixels), 0, 0, 0, 0
            )
            + pixels
            + mask
        )
    entries = b""
    offset = 38
    for size, block in zip([16, 32], blocks):
        entries += struct.pack("<BBBBHHII", size, size, 0, 0, 1, 32, len(block), offset)
        offset += len(block)
    return struct.pack("<HHH", 0, 1, 2) + entries + b"".join(blocks)


def png(size):
    def chunk(kind, data):
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data))
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(
            b"IDAT", zlib.compress((b"\0" + bytes([40, 255, 40, 255]) * size) * size)
        )
        + chunk(b"IEND", b"")
    )


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        resources = {
            "/multi.ico": ("image/x-icon", ico()),
            "/32.png": ("image/png", png(32)),
            "/16.png": ("image/png", png(16)),
            "/icons/64.png": ("image/png", png(64)),
            "/icons/manifest.json": (
                "application/json",
                b'{"icons":[{"src":"64.png","sizes":"64x64"}]}',
            ),
        }
        if self.path == "/missing.ico":
            self.send_response(404)
            self.end_headers()
            return
        kind, content = resources.get(
            self.path,
            (
                "text/html",
                b'<title>Sharp icons</title><link rel="icon" href="/multi.ico"><link rel="apple-touch-icon" sizes="32x32" href="/32.png"><link rel="manifest" href="/icons/manifest.json">',
            ),
        )
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.end_headers()
        try:
            self.wfile.write(content)
        except BrokenPipeError:
            pass

    def log_message(self, *_):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
origin = f"http://127.0.0.1:{server.server_port}"
installed = work / "installed.png"
installed.write_bytes(png(512))
app_id = "chrome-ompifgpmddkgmclendfeacglnodjjndh-Default"
(work / "data/applications" / (app_id + ".desktop")).write_text(
    f"[Desktop Entry]\nType=Application\nName=Installed app\nExec=true\nIcon={installed}\n"
)
env = os.environ.copy()
for key in [
    "HYPRLAND_INSTANCE_SIGNATURE",
    "WAYLAND_DISPLAY",
    "DISPLAY",
    "DBUS_SESSION_BUS_ADDRESS",
]:
    env.pop(key, None)
env.update(
    HOME=str(work / "home"),
    XDG_CONFIG_HOME=str(work / "config"),
    XDG_RUNTIME_DIR=str(work / "runtime"),
    XDG_DATA_HOME=str(work / "data"),
    XDG_DATA_DIRS=str(work / "data"),
    QT_QPA_PLATFORM="offscreen",
    QT_SCALE_FACTOR="1.5",
    QT_QUICK_BACKEND="software",
    MOUNTAINOUS_BROWSER_INTEGRATION="1",
)
with (work / "chromium.log").open("w") as chromium_log:
    chrome = subprocess.Popen(
        [
            os.environ["CHROMIUM"],
            "--headless",
            "--no-sandbox",
            "--disable-gpu",
            "--disable-background-networking",
            "--disable-component-update",
            "--no-first-run",
            "--no-default-browser-check",
            "--remote-debugging-port=0",
            "--user-data-dir=" + str(work / "config/chromium"),
            origin,
        ],
        env=env,
        stdout=chromium_log,
        stderr=subprocess.STDOUT,
    )
try:
    for _ in range(100):
        port_file = work / "config/chromium/DevToolsActivePort"
        if port_file.exists():
            break
        if chrome.poll() is not None:
            raise RuntimeError((work / "chromium.log").read_text())
        time.sleep(0.1)
    (work / "shell/shell.qml").write_text(
        """import Quickshell
import QtQuick
import QtQuick.Window
ShellRoot {
    id: root
    property int stage: 0
    Window { visible: true; width: 160; height: 96
    WindowIcon { id: small; implicitSize: 16; toplevel: ({address: "a", appId: "chromium-browser", title: "Sharp icons - Chromium"}); fallbackSource: "ORIGIN/32.png" }
    WindowIcon { id: large; implicitSize: 32; toplevel: small.toplevel; fallbackSource: small.fallbackSource }
    WindowIcon { id: pwa; implicitSize: 16; toplevel: ({appId: "APP_ID", title: "Unmatched installed app"}) }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (root.stage === 0 && small.source.toString() === "ORIGIN/32.png" && large.source.toString() === "ORIGIN/icons/64.png" && small.frames.length && large.frames.length && pwa.nativePixels === 512) {
                if (small.pixels !== 24 || large.pixels !== 48 || small.implicitWidth !== 32 || large.implicitWidth !== 64 || !small.smooth || !large.smooth) throw new Error("wrong physical sizing/downscale");
                console.log("DECLARED_AND_MANIFEST_READY", small.pixels, large.pixels);
                if (pwa.source.toString() !== "INSTALLED_URI") throw new Error("installed PWA did not use Icon=");
                console.log("INSTALLED_PWA_READY", pwa.nativePixels);
                const p = CdpBrowser.pages[0];
                CdpBrowser.pageIcons = {};
                CdpBrowser.pages = [Object.assign({}, p, {ws: "", favicon: "ORIGIN/multi.ico"})];
                root.stage = 1;
            } else if (root.stage === 1 && small.frames.length === 2 && small.status === Image.Ready && small.currentFrame === 1) {
                if (small.nativePixels !== 32 || small.implicitWidth !== 32 || !small.smooth) throw new Error("wrong native ICO frame");
                console.log("ICO_BEST_FRAME_READY", small.currentFrame, small.nativePixels);
                CdpBrowser.pages = CdpBrowser.pages.map(function(p) { return Object.assign({}, p, {favicon: "ORIGIN/16.png"}); });
                root.stage = 2;
            } else if (root.stage === 2 && small.nativePixels === 16 && small.status === Image.Ready) {
                if (small.smooth || small.width !== 16 || small.implicitWidth !== 16) throw new Error("small raster must stay in its slot with nearest sampling");
                console.log("LOW_RES_NEAREST_READY");
                CdpBrowser.pages = CdpBrowser.pages.map(function(p) { return Object.assign({}, p, {favicon: "ORIGIN/missing.ico"}); });
                root.stage = 3;
            } else if (root.stage === 3 && small.failedSource !== "" && small.status === Image.Ready && small.source.toString() === small.fallbackSource) {
                console.log("FAVICON_ERROR_FALLBACK_READY");
                CdpBrowser.pages = CdpBrowser.pages.map(function(p) { return Object.assign({}, p, {favicon: ""}); });
                root.stage = 4;
            } else if (root.stage === 4 && small.favicon === "" && small.status === Image.Ready && small.source.toString() === small.fallbackSource) {
                console.log("NO_FAVICON_FALLBACK_READY");
                Qt.quit();
            }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.log("FAVICON_TIMEOUT", root.stage, JSON.stringify(CdpBrowser.pageIcons)); Qt.quit(); } }
}
""".replace("ORIGIN", origin)
        .replace("APP_ID", app_id)
        .replace("INSTALLED_URI", installed.as_uri())
    )
    result = subprocess.run(
        [os.environ.get("QS", "qs"), "-p", str(work / "shell/shell.qml"), "--no-color"],
        env=env,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=20,
    )
    (work / "quickshell.log").write_text(result.stdout)
    print(result.stdout)
    assert result.returncode == 0
    for marker in [
        "DECLARED_AND_MANIFEST_READY 24 48",
        "ICO_BEST_FRAME_READY 1 32",
        "INSTALLED_PWA_READY 512",
        "LOW_RES_NEAREST_READY",
        "FAVICON_ERROR_FALLBACK_READY",
        "NO_FAVICON_FALLBACK_READY",
    ]:
        assert marker in result.stdout, marker
finally:
    chrome.terminate()
    try:
        chrome.wait(timeout=5)
    except subprocess.TimeoutExpired:
        chrome.kill()
        chrome.wait()
    server.shutdown()
