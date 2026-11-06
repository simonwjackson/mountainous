import Hensou as Kit
import QtQuick

// Dictation as a Memphis window: what the recorder is doing, and Retry and
// Dismiss after a failure (Retry only when a take can be sent again). The
// shared Dictation owns the takes.
MemphisWindow {
    id: root

    required property var dictation
    required property string text

    readonly property bool failed: dictation.state === "failed"
    title: "Dictation"
    iconName: "mic-recording"
    onCloseClicked: MenuState.close()

    Column {
        width: root.bodyWidth
        spacing: 6 * root.u

        Row {
            spacing: 6 * root.u
            MemphisIcon { name: root.failed ? "mic-failed" : root.dictation.state === "working" ? "mic-working" : "mic-recording" }
            MemphisText {
                y: Kit.MemphisTokens.snap((16 * root.u - height) / 2, root.u)
                text: root.text
                accessMarks: false
                bold: true
                color: root.failed ? Kit.MemphisTokens.danger : Kit.MemphisTokens.text
            }
        }
        Item {
            visible: root.failed
            width: parent.width
            height: visible ? 23 * root.u : 0
            Row {
                x: parent.width - width
                spacing: 6 * root.u
                MemphisButton {
                    id: retry
                    visible: root.dictation.canRetry
                    text: "&Retry"
                    isDefault: true
                    focus: visible
                    onClicked: { MenuState.close(); root.dictation.retryFailed(); }
                }
                MemphisButton {
                    id: dismiss
                    text: "&Dismiss"
                    isDefault: !root.dictation.canRetry
                    focus: !root.dictation.canRetry
                    onClicked: { MenuState.close(); root.dictation.dismissFailure(); }
                }
            }
        }
        MemphisText {
            visible: !root.failed
            width: parent.width
            wrap: true
            text: "The taskbar shows the take while it records."
            accessMarks: false
            color: Kit.MemphisTokens.gray
        }
    }

    Shortcut { sequence: "R"; context: Qt.WindowShortcut; enabled: root.failed && root.dictation.canRetry; onActivated: retry.clicked() }
    Shortcut { sequence: "D"; context: Qt.WindowShortcut; enabled: root.failed; onActivated: dismiss.clicked() }
}
