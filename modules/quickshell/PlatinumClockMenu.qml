import Hensou as Kit
import Quickshell
import QtQuick
import QtQuick.Layouts

// The clock's menu: the full date, then the bar's appearance. The bar's
// clock gives up its date first when the bar is narrow; the date stays
// one click away here.
//
// "Extra dark" turns the bar black in dark mode. The desktop-theme command
// owns the choice and Kit.PlatinumTokens.qml reads it back, so the check box shows what
// is stored, not what was clicked. In light mode the row stays, disabled,
// and says why.
PlatinumMenuFrame {
    id: frame

    property date now: new Date()

    function toggleExtra() {
        if (Theme.dark) Quickshell.execDetached(["desktop-theme", "extra", "toggle"]);
    }

    readonly property real keyWidth: Kit.PlatinumMetrics.smallWidth("E")

    preferredWidth: Math.max(220, Kit.PlatinumMetrics.even(Kit.PlatinumTokens.menuTextLeft
        + Kit.PlatinumMetrics.width(frame.title) + Kit.PlatinumTokens.menuGap + 16 + Kit.PlatinumTokens.menuRightInset + 4))
    title: Qt.formatDate(frame.now, "dddd, MMMM d, yyyy")
    detail: {
        const hour = frame.now.getHours() % 12 || 12;
        return hour + Qt.formatTime(frame.now, ":mm") + (frame.now.getHours() < 12 ? " AM" : " PM");
    }

    PlatinumMenuParts.Separator {}

    PlatinumMenuCheckRow {
        text: "Extra dark"
        rightInset: frame.rightInset
        checked: Theme.extraDark
        enabled: Theme.dark
        onToggled: frame.toggleExtra()

        // Its key, on the right edge, as in the builder menu.
        Text {
            width: frame.keyWidth
            horizontalAlignment: Text.AlignRight
            text: "E"
            color: Theme.dark ? Kit.PlatinumTokens.menuTextSecondary : Kit.PlatinumTokens.menuTextOff
            font.family: Kit.PlatinumTokens.platinumFont
            font.pixelSize: Kit.PlatinumTokens.platinumSmall
        }
    }

    PlatinumMenuParts.Line {
        visible: !Theme.dark
        rightInset: frame.rightInset
        text: "Only applies in dark mode."
    }

    PlatinumButton {
        Layout.leftMargin: Kit.PlatinumTokens.menuTextLeft
        Layout.rightMargin: frame.rightInset
        Layout.topMargin: Kit.PlatinumTokens.menuGap
        text: "Desktop theme…"
        onClicked: { const screen = MenuState.screen; MenuState.close(); ThemePicker.open(screen); }
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: Theme.dark ? "E extra dark · Esc close" : "Esc close"
    }

    Shortcut {
        sequence: "E"
        context: Qt.WindowShortcut
        enabled: Theme.dark
        onActivated: frame.toggleExtra()
    }
}
