import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "storage-health.js" as Health


PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 400
    title: "Server storage"
    scrolls: findings.scrolls

    headerTrailing: PlatinumButton {
        text: panel.checking ? "Checking" : "Check now"
        fixedWidth: PlatinumMetrics.buttonWidth(["Check now", "Checking"])
        enabled: !panel.checking
        onClicked: panel.refresh()
    }

    // When the servers were checked, said in full: it wraps rather
    // than cut the time off.
    PlatinumMenuParts.Line {
        rightInset: frame.rightInset
        text: panel.statusText
        color: panel.state === "error" || panel.state === "stale"
            ? PlatinumTokens.menuWarning : PlatinumTokens.menuTextSecondary
        bottomPadding: 4
    }

    PlatinumMenuParts.Separator { visible: panel.findings.count > 0 }

    // Findings by host. The host is a section label on the text
    // edge; each finding's level is its mark in the gutter and its
    // colour.
    PlatinumMenuList {
        id: findings
        visible: panel.findings.count > 0
        model: panel.findings
        view.section.property: "host"
        view.section.delegate: PlatinumMenuParts.Section {
            required property string section
            width: ListView.view.width
            x: PlatinumTokens.menuTextLeft
            rightInset: frame.rightInset
            topPadding: 6
            text: section
        }

        delegate: Item {
            id: finding
            required property string level
            required property string message
            width: ListView.view.width
            height: findingText.implicitHeight + 6

            PlatinumIcon {
                x: PlatinumTokens.menuGutter + (PlatinumTokens.menuGutterWidth - width) / 2
                y: 3 + (16 - height) / 2
                name: finding.level === "ok" ? "check" : finding.level === "bad" ? "dot" : "ring"
                size: 10
                color: frame.levelColor(finding.level)
            }

            Text {
                id: findingText
                x: PlatinumTokens.menuTextLeft
                y: 3
                width: parent.width - x - frame.rightInset
                text: finding.message
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: frame.levelColor(finding.level)
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
                lineHeight: 1.15
            }
        }
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "Esc or click outside to close"
    }
    function levelColor(level) {
        return level === "bad" ? PlatinumTokens.menuDanger
            : level === "ok" ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuWarning;
    }
}