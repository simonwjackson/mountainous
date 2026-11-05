import Quickshell
import Quickshell.Io
import QtQuick

// The only I/O seam for the token renderer. Coalesce changes while a request
// runs; late replies cannot replace a different window's icon. No shell, cookies
// or synchronous UI work. An empty result deliberately leaves today's icon.
Item {
    id: root
    property string source: ""
    property int pixels: 24
    property string theme: "platinum-light"
    property string cachedSource: ""
    readonly property string requestKey: source !== "" ? JSON.stringify([source, pixels, theme]) : ""
    readonly property string helper: Quickshell.env("MOUNTAINOUS_PLATINUM_ICON") || "mountainous-platinum-icon"

    onRequestKeyChanged: {
        root.cachedSource = "";
        if (!job.running) start.restart();
    }
    Component.onCompleted: start.restart()

    Timer {
        id: start
        interval: 0
        onTriggered: {
            if (root.requestKey === "" || job.running) return;
            job.activeKey = root.requestKey;
            job.command = [root.helper, root.source, String(root.pixels), root.theme];
            job.running = true;
        }
    }
    Process {
        id: job
        property string activeKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (job.activeKey === root.requestKey && /^\/[^\n\r]+\.png$/.test(path))
                    root.cachedSource = "file://" + path;
            }
        }
        onExited: {
            if (root.requestKey !== job.activeKey) start.restart();
        }
    }
    Timer {
        interval: 15000
        running: job.running
        onTriggered: job.running = false
    }
}
