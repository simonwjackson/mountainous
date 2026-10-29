import Hensou as Kit
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts


PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 340
    title: "Brightness"
    scrolls: screens.scrolls

    // The one level. The track's left end is the dim minimum, not
    // zero, so the whole drag is the whole range the keys reach.
    PlatinumSlider {
        rightInset: frame.rightInset
        icon: "brightness"
        hasValue: panel.shownLevel >= 0
        enabled: panel.shownLevel >= 0
        ratio: panel.shownLevel < 0 ? 0
            : (panel.shownLevel - panel.minimum) / (panel.maximum - panel.minimum)
        valueText: panel.shownLevel >= 0 ? panel.shownLevel + "%" : "--"
        onMoved: function (ratio) {
            panel.dragging = true;
            panel.setLevel(panel.minimum + ratio * (panel.maximum - panel.minimum));
        }
        onReleased: panel.dragging = false
    }

    PlatinumMenuParts.Separator {}

    PlatinumMenuParts.Empty {
        visible: panel.rows.length === 0
        rightInset: frame.rightInset
        text: "No screen here can change its brightness."
    }

    PlatinumMenuList {
        id: screens
        visible: panel.rows.length > 0
        model: ScriptModel { values: panel.rows }

        delegate: PlatinumMenuListRow {
            required property var modelData
            width: ListView.view.width
            rightInset: frame.rightInset
            mark: modelData.follows ? "dot" : "ring"
            markDim: !modelData.follows
            name: modelData.label
            nameColor: modelData.follows ? Kit.PlatinumTokens.menuText : Kit.PlatinumTokens.menuTextSecondary
            // Why a screen does not follow is the one fact a user
            // can act on.
            detail: modelData.follows ? modelData.detail : "Keeps its own brightness"
        }
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "←→ brightness · Esc close"
    }

    Shortcut { sequence: "Left"; context: Qt.WindowShortcut; onActivated: panel.step(-1) }
    Shortcut { sequence: "Right"; context: Qt.WindowShortcut; onActivated: panel.step(1) }
}