import QtQuick
import Quickshell
import Quickshell.Io

// A windowless client of Qt's actual platform theme, not the shell palette.
ShellRoot {
    SystemPalette { id: palette; colorGroup: SystemPalette.Active }
    IpcHandler {
        target: "probe"
        function current(): string {
            return Qt.styleHints.colorScheme + " " + palette.window + " " + palette.windowText;
        }
    }
}
