import Quickshell
import Quickshell.Io
import QtQuick

// Two slots keep the working Desktop mapped until its replacement is Ready.
// The component is compiled first so a failure includes Qt's exact error text.
Scope {
    id: root
    required property var screen
    required property var context
    property var catalog: ThemeCatalog
    property string requestedName: Theme.name
    property string currentName: "platinum"
    property var desktop: null
    property var pendingComponent: null
    property int generation: 0
    property bool initialized: false
    readonly property int loadedCount: (first.item ? 1 : 0) + (second.item ? 1 : 0)
    property int currentSlot: -1
    signal failed(string name, string error)

    function fail(name, error) {
        root.pendingComponent = null;
        root.failed(name, error);
        // Every screen may reject the same attempt. set is idempotent, and
        // only the primary screen sends the desktop-wide notification.
        Quickshell.execDetached(["desktop-theme", "set", root.currentName]);
        if (root.screen === Quickshell.screens[0])
            Quickshell.execDetached(["notify-send", "Desktop theme could not load", name + ": " + error]);
    }

    function request() {
        const generation = ++root.generation;
        if (root.desktop && root.requestedName === root.currentName) return;
        MenuState.close();
        const name = root.requestedName;
        const theme = root.catalog.find(name);
        if (!theme) { root.fail(name, "Theme is not installed"); return; }
        const component = Qt.createComponent(Qt.resolvedUrl(theme.desktop), Component.Asynchronous);
        root.pendingComponent = component;
        function compiled() {
            if (generation !== root.generation) { component.destroy(); return; }
            if (component.status === Component.Loading) return;
            if (component.status === Component.Error) {
                root.fail(name, component.errorString());
                component.destroy();
                return;
            }
            const slot = root.currentSlot === 0 ? second : first;
            slot.themeName = name;
            slot.attempt = generation;
            slot.setSource(Qt.resolvedUrl(theme.desktop), {screen: root.screen, context: root.context, theme: theme, active: false});
        }
        component.statusChanged.connect(compiled);
        compiled();
    }

    function ready(slot, index) {
        if (slot.attempt !== root.generation) { slot.source = ""; return; }
        const old = root.currentSlot === 0 ? first : second;
        slot.item.screen = Qt.binding(function () { return root.screen; });
        slot.item.context = Qt.binding(function () { return root.context; });
        slot.item.active = true;
        root.currentName = slot.themeName;
        root.currentSlot = index;
        root.desktop = slot.item;
        if (old !== slot) {
            if (old.item) old.item.active = false;
            old.source = "";
        }
        if (root.pendingComponent) root.pendingComponent.destroy();
        root.pendingComponent = null;
    }

    onRequestedNameChanged: if (initialized) request()
    Component.onCompleted: { initialized = true; request(); }
    Component.onDestruction: root.desktop = null

    Loader {
        id: first
        asynchronous: true
        property string themeName: ""
        property int attempt: 0
        onLoaded: root.ready(first, 0)
        onStatusChanged: if (status === Loader.Error) root.fail(themeName, "Desktop could not be created")
    }
    Loader {
        id: second
        asynchronous: true
        property string themeName: ""
        property int attempt: 0
        onLoaded: root.ready(second, 1)
        onStatusChanged: if (status === Loader.Error) root.fail(themeName, "Desktop could not be created")
    }
}
