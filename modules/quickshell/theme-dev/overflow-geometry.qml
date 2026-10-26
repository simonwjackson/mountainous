import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root
    property int requestedHeight: 130
    QtObject {
        id: bar
        property var plan: ({overflow: ["apple", "bt", "wifi", "vol", "bri", "oci", "disk", "fleet", "builder", "ntf", "battery", "clock", "app", "dictation"]})
        property var dictation: ({canRetry: true})
        property string dictationText: "The recording could not be transcribed."
        property var modelData: Quickshell.screens[0]
        function iconFor(id) { return ""; }
        function valueFor(id) { return "100%"; }
        function anchorFor(id) { return 0; }
    }
    Item {
        width: 320
        height: 600
        PlatinumOverflowMenu {
            id: menu
            bar: bar
            menuWidth: 260
            maxHeight: root.requestedHeight
        }
    }
    function list(item) {
        if (typeof item.positionViewAtIndex === "function") return item;
        for (const child of item.children) {
            const found = root.list(child);
            if (found) return found;
        }
        return null;
    }
    IpcHandler {
        target: "overflowProbe"
        function resize(height: int): void { root.requestedHeight = height; }
        function reveal(index: int): void {
            const view = root.list(menu);
            if (!view) return;
            view.currentIndex = index;
            view.positionViewAtIndex(index, ListView.Contain);
            view.forceLayout();
        }
        function step(): void {
            const view = root.list(menu);
            if (view) view.parent.moveSelection(1);
        }
        function snapshot(): string {
            const view = root.list(menu);
            const rows = [];
            function walk(item) {
                if (item.name !== undefined && item.rowHeight !== undefined) {
                    const pos = item.mapToItem(menu, 0, 0);
                    rows.push({name: item.name, x: pos.x, y: pos.y, width: item.width, height: item.height});
                }
                for (const child of item.children) walk(child);
            }
            walk(menu);
            const pos = view ? view.mapToItem(menu, 0, 0) : {x: 0, y: 0};
            return JSON.stringify({height: menu.height, scrolls: menu.scrolls,
                entries: menu.entries, rows: rows, index: view ? view.currentIndex : -1,
                viewport: {x: pos.x, y: pos.y, width: view ? view.width : menu.width, height: view ? view.height : menu.height}});
        }
    }
}
