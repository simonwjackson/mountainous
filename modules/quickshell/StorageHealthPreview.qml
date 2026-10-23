import Quickshell
import QtQuick

// The storage menu alone, for the offline fixture; see the storage repair
// runbook. It shows StorageHealth's real menu (a MenuFrame) in a window at
// the top right, the place a bar menu takes when its control is not shown.
// No bar and no MenuState: the close box and Escape quit the preview.
Scope {
    StorageHealth {
        id: storage
        shown: true
        onRowsChanged: console.log("storage-health preview: " + rows.length + " rows, " + state)
        onStateChanged: console.log("storage-health preview state: " + state)
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: 6; right: 6 }
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        color: "transparent"
        implicitWidth: menu.item ? menu.item.width + 2 : 400
        implicitHeight: menu.item ? menu.item.height + 2 : 100

        onDevicePixelRatioChanged: if (devicePixelRatio > 0) Theme.pixelRatio = devicePixelRatio

        Loader {
            id: menu
            sourceComponent: storage.menu
            onLoaded: {
                item.maxHeight = Qt.binding(function () {
                    return (win.screen ? win.screen.height : 800) - 24;
                });
                item.closeRequested.connect(function () { Qt.quit(); });
            }
        }

        Shortcut {
            sequence: "Escape"
            context: Qt.WindowShortcut
            onActivated: Qt.quit()
        }
    }
}
