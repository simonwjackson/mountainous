import Hensou as Kit
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "oci-model.js" as OciModel


PlatinumMenuFrame {
    id: frame
    required property var panel

    preferredWidth: 420
    title: "OCI egress · this month"
    detail: panel.stateText
    scrolls: profiles.scrolls

    readonly property real valueWidth: Kit.PlatinumMetrics.widest(["100.0%", "Failed"])

    // Profiles scroll: a tenancy with many no longer clips.
    PlatinumMenuList {
        id: profiles
        visible: panel.rows.length > 0
        model: ScriptModel { values: panel.rows }

        delegate: PlatinumMenuListRow {
            id: profileRow
            required property var modelData
            readonly property var rule: OciModel.rowRule(modelData)
            width: ListView.view.width
            rightInset: frame.rightInset
            name: rule.name
            detail: rule.failed ? "Usage request failed"
                : modelData.used + " GB / 10240 GB · projected " + modelData.projected + " GB"
            detailColor: rule.failed ? Kit.PlatinumTokens.menuTextSecondary : Kit.PlatinumTokens.menuTextSecondary

            // The profile's own tone, on its own value.
            Text {
                width: frame.valueWidth
                horizontalAlignment: Text.AlignRight
                text: profileRow.rule.value
                color: Kit.PlatinumTokens.menuTone(profileRow.rule.tone)
                font.family: Kit.PlatinumTokens.platinumFont
                font.pixelSize: Kit.PlatinumTokens.platinumText
                font.letterSpacing: Kit.PlatinumTokens.platinumTracking
            }
        }
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "Esc or click outside to close"
    }
}