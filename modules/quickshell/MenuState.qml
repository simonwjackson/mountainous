pragma Singleton
import QtQml

QtObject {
    id: root

    // One atomic selection prevents mismatched name/screen/anchor bindings.
    property var _selection: ({
            name: "",
            screen: null,
            anchorX: 0
        })
    readonly property string current: _selection.name
    readonly property var screen: _selection.screen
    readonly property real anchorX: _selection.anchorX

    signal opened(string name)

    function open(name, screen, anchorX) {
        if (typeof name !== "string" || name.length === 0 || !screen) {
            close();
            return;
        }
        const changed = root.current !== name || root.screen !== screen;
        root._selection = {
            name: name,
            screen: screen,
            // -1 means no control anchor; MenuHost places this menu top right.
            anchorX: anchorX === -1 ? -1 : typeof anchorX === "number" && Number.isFinite(anchorX) ? Math.max(0, anchorX) : 0
        };
        if (changed) root.opened(name);
    }

    function close() {
        root._selection = {
            name: "",
            screen: null,
            anchorX: 0
        };
    }

    function toggle(name, screen, anchorX) {
        if (root.current === name && root.screen === screen)
            root.close();
        else
            root.open(name, screen, anchorX);
    }
}
