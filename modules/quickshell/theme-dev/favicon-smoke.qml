import Quickshell
import QtQuick

// Load the real image adapter in Qt, without a compositor or live browser.
// In particular, Image's implicit size properties are read-only at runtime.
ShellRoot {
    readonly property string pixel: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
    WindowIcon { id: small; implicitSize: 16; fallbackSource: pixel; smooth: false }
    WindowIcon { id: large; implicitSize: 32; fallbackSource: pixel }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (small.status !== Image.Ready || large.status !== Image.Ready) return;
            if (small.width !== 16 || small.height !== 16 || large.width !== 32 || large.height !== 32)
                throw new Error("WindowIcon changed the surface's icon size");
            console.log("FAVICON_ICON_SMOKE_READY");
            Qt.quit();
        }
    }
}
