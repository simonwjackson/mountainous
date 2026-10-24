import QtQuick
import "beszel-model.js" as Model
import "fleet-plan.js" as Plan

// The Fleet windoid's body, as in the approved mock (/tmp/hud-mock): a
// Finder info header with the fleet's light and summary, bevelled column
// headers, one row per host and a disclosure triangle that opens a host's
// drill-down, then a footer with the sample's time. Two hosts use it: the
// standalone Fleet window and the glance space. Both share the Beszel owner
// and its view state (sort, selected and expanded host).
//
// Layout is Plan.plan(frameWidth, frameHeight): width decides the columns,
// height the row height, the summary's place and the scroll bar. Every
// value a narrow row gives up stays in the drill-down.
FocusScope {
    id: view

    required property var panel
    // The windoid's size: its width; its height when the reader set one
    // (-1: natural); and the most it may take (-1: no limit).
    property real frameWidth: 400
    property real frameHeight: -1
    property real maxFrameHeight: -1
    // The windoid's own chrome (PlatinumWindoid.chromeWidth/Height).
    property real frameChromeWidth: 4 * h
    property real frameChromeHeight: 16 + 5 * h
    property bool growable: false
    property real now: panel.now
    signal escapePressed
    signal grown(real dx, real dy)
    signal growFinished

    readonly property real h: PlatinumTokens.hair
    readonly property var fleet: panel.fleet
    readonly property bool ready: fleet.state === "ready" && fleet.hosts.length > 0

    // ---------------------------------------------------------- measures
    FontMetrics { id: f14; font.family: PlatinumTokens.platinumFont; font.pixelSize: PlatinumTokens.platinumText; font.letterSpacing: PlatinumTokens.platinumTracking }
    FontMetrics { id: f12; font.family: PlatinumTokens.platinumFont; font.pixelSize: PlatinumTokens.platinumSmall; font.letterSpacing: PlatinumTokens.platinumTracking }
    FontMetrics { id: f11; font.family: PlatinumTokens.platinumFont; font.pixelSize: PlatinumTokens.platinumHint; font.letterSpacing: PlatinumTokens.platinumTracking }
    function w14(s) { return Math.ceil(f14.advanceWidth(s)); }
    function w12(s) { return Math.ceil(f12.advanceWidth(s)); }
    function w11(s) { return Math.ceil(f11.advanceWidth(s)); }

    readonly property var measures: {
        const hosts = fleet.hosts;
        const names = hosts.length ? hosts.map(function (v) { return v.name; }) : ["hiyori"];
        let nameW = 0, fsW = 0, upLong = w12("seen 49m ago"), upShort = w12("49m");
        for (const n of names) nameW = Math.max(nameW, w14(n));
        for (const v of hosts) {
            if (v.trusted && v.disk.fs !== "/") fsW = Math.max(fsW, Math.min(w11(v.disk.fs), 70) + 4);
            if (v.trusted) {
                upLong = Math.max(upLong, w12(Model.fmtUptime(v.uptime, "long")));
                upShort = Math.max(upShort, w12(Model.fmtUptime(v.uptime, "short")));
            }
        }
        const head = {};
        for (const id of Object.keys(Plan.HEAD)) head[id] = Plan.HEAD[id].map(function (t) { return w12(t); });
        return {
            border: frameChromeWidth,
            chrome: frameChromeHeight - Plan.C.TITLE + 2 * h,
            rows: ready ? hosts.length : 8,
            nameW: Math.min(nameW, 120), head: head, fsLabelW: fsW,
            pctW: w12("100%"), tempW: w12("100°"), failedW: w12("14"), notesW: w12("14 failed"),
            upLongW: upLong, upShortW: upShort
        };
    }

    // The width the window would like. A state without hosts keeps the last
    // ready width, so the window does not jump between states.
    property real lastReadyWidth: 0
    readonly property real planNatural: Plan.plan(9999, null, measures, {}).natural
    onPlanNaturalChanged: if (ready) lastReadyWidth = planNatural
    readonly property real naturalWidth: ready ? planNatural : Math.max(planNatural, lastReadyWidth)

    // The open host's drill-down height, read after layout (not bound, so
    // the plan and the drill-down never form a loop).
    property real detailHeight: 0
    // The natural height, from the plan's own row height (not the drawn
    // rows), so the plan never depends on itself.
    readonly property real naturalFrameH: frameChromeHeight + Plan.C.INFO + h + Plan.C.COLH + h + Plan.C.FOOT
        + (ready ? fleet.hosts.length * Plan.C.ROW + (panel.expanded !== "" ? detailHeight : 0) : messageH)
    readonly property real planH: frameHeight >= 0 ? frameHeight
        : maxFrameHeight >= 0 && naturalFrameH > maxFrameHeight + 0.5 ? maxFrameHeight : -1
    readonly property var plan: Plan.plan(frameWidth, planH >= 0 ? planH : null, measures,
        {detailH: panel.expanded !== "" ? detailHeight : 0})

    // ---------------------------------------------------------- rows
    readonly property var rows: Model.sortHosts(fleet.hosts, panel.sort)
    readonly property var byName: {
        const out = {};
        for (const v of rows) out[v.name] = v;
        return out;
    }
    // The Repeater's model changes only when the order or the hosts do, so
    // a refresh never rebuilds the rows or moves the scroll position.
    property var rowNames: []
    onRowsChanged: {
        const names = rows.map(function (v) { return v.name; });
        if (JSON.stringify(names) !== JSON.stringify(rowNames)) rowNames = names;
    }
    Component.onCompleted: rowNames = rows.map(function (v) { return v.name; })

    // ---------------------------------------------------------- summary
    readonly property bool summaryNames: plan.scrolls
    readonly property var summaryVariants: Model.summaryVariants(fleet, summaryNames, "")
    readonly property string summaryAll: Model.summaryVariants(fleet, true, "")[0]
    readonly property string summaryTone: fleet.state === "ready"
        ? (fleet.problems.length ? (fleet.problems.some(function (v) { return v.tone === "danger"; }) ? "danger" : "warning") : "normal")
        : "muted"
    readonly property string lightShape: fleet.state === "loading" ? "pending" : fleet.state === "ready" ? "up" : "down"
    readonly property string lightTone: panel.stale ? "muted" : fleet.tone
    // The windoid's title when the summary moves into it (short window,
    // or WindowShade): "Fleet: 1 problem: unzen".
    readonly property bool summaryInTitle: plan.infoInTitle
    function titleText(room) {
        return Plan.fit(Model.summaryVariants(fleet, true, "Fleet: "), room, function (s) { return w12(s); });
    }
    function toneColor(tone) {
        return tone === "danger" ? PlatinumTokens.menuDanger : tone === "warning" ? PlatinumTokens.menuWarning
            : tone === "muted" || tone === "quiet" ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuText;
    }
    function clock(ms) {
        if (!(ms > 0)) return "--";
        const d = new Date(ms);
        return (d.getHours() % 12 || 12) + Qt.formatTime(d, ":mm");
    }

    // ---------------------------------------------------------- heights
    readonly property real infoH: plan.infoInTitle ? 0 : Plan.C.INFO
    readonly property real colsH: h + Plan.C.COLH
    readonly property real footH: h + Plan.C.FOOT
    readonly property real messageH: Math.max(8 * Plan.C.ROW, message.implicitHeight)
    readonly property real listContentH: ready ? rowsColumn.implicitHeight : messageH
    readonly property real listH: planH >= 0
        ? Math.max(0, planH - frameChromeHeight - infoH - colsH - footH)
        : listContentH
    readonly property real bodyHeight: infoH + colsH + listH + footH
    // The body at rest (no host open), for the glance space's layout.
    readonly property real restBodyHeight: Plan.C.INFO + colsH + footH
        + (ready ? fleet.hosts.length * Plan.C.ROW : messageH)
    implicitWidth: naturalWidth - frameChromeWidth
    implicitHeight: bodyHeight

    readonly property real innerW: width - plan.sb

    // ---------------------------------------------------------- keys
    function move(step) {
        const names = rowNames;
        if (!names.length) return;
        const i = names.indexOf(panel.selected);
        panel.selected = names[Math.max(0, Math.min(names.length - 1, i < 0 ? 0 : i + step))];
        Qt.callLater(view.reveal, panel.selected);
    }
    function reveal(name) {
        const item = rowItems[name];
        if (!item) return;
        const top = item.y, bottom = item.y + Plan.C.ROW;
        if (top < list.contentY) list.contentY = top;
        else if (bottom > list.contentY + list.height) list.contentY = Math.min(bottom - list.height, Math.max(0, list.contentHeight - list.height));
    }
    property var rowItems: ({})

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Down) { view.move(1); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { view.move(-1); event.accepted = true; }
        else if ((event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && panel.selected !== "") {
            if (panel.expanded !== panel.selected || event.key !== Qt.Key_Right) panel.toggleExpanded(panel.selected);
            Qt.callLater(view.reveal, panel.selected);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && panel.expanded !== "") {
            panel.selected = panel.expanded;
            panel.expanded = "";
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            view.escapePressed();
            event.accepted = true;
        }
    }

    // ---------------------------------------------------------- info header
    Item {
        id: info
        visible: !view.plan.infoInTitle
        width: parent.width
        height: view.infoH
        Rectangle { width: parent.width; height: view.h; color: PlatinumTokens.bevelLight }
        Rectangle { y: parent.height - view.h; width: parent.width; height: view.h; color: PlatinumTokens.bevelDark }

        PlatinumStatusLight {
            id: infoLight
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            shape: view.lightShape
            tone: view.lightTone
        }
        Text {
            id: summary
            x: infoLight.x + infoLight.width + 7
            anchors.verticalCenter: parent.verticalCenter
            readonly property real room: Math.max(0, (staleNote.visible ? staleNote.x - 8 : info.width - 8) - x)
            width: Math.min(implicitWidth, room)
            text: Plan.fit(view.summaryVariants, room, function (s) { return view.w12(s); })
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: view.toneColor(view.summaryTone)
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
        // The last refreshes failed: a sunken badge says how old the values are.
        PlatinumBevel {
            id: staleNote
            visible: view.panel.stale && width > 24
            sunken: true
            edged: false
            color: PlatinumTokens.well
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 16
            width: Math.min(staleText.implicitWidth + 12, Math.max(0, info.width - 8 - (infoLight.x + 12 + 7 + view.w12(view.summaryVariants[view.summaryVariants.length - 1])) - 8))
            Text {
                id: staleText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 12)
                elide: Text.ElideRight
                text: "Last update " + Model.ago(view.now - view.panel.sampledAt)
                color: PlatinumTokens.menuText
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumHint
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }
    }

    // ---------------------------------------------------------- list
    Item {
        id: body
        y: view.infoH
        width: parent.width
        height: view.colsH + view.listH
        Rectangle { width: parent.width; height: view.h; color: PlatinumTokens.menuEdge }
        Rectangle { y: view.colsH; width: parent.width; height: view.listH; color: PlatinumGlanceTokens.listSurface }

        // Column headers: raised buttons; the sorted one sinks.
        Row {
            id: headers
            y: view.h
            height: Plan.C.COLH
            width: parent.width

            component Head: PlatinumBevel {
                id: head
                property string sortKey: ""
                property string label: ""
                property bool alignRight: false
                property bool sorted: view.panel.sort === sortKey
                height: Plan.C.COLH - view.h
                edged: false
                sunken: sorted || area.pressed
                color: sorted || area.pressed ? PlatinumTokens.well : PlatinumTokens.menuSurface
                default property alias extra: extraBox.data
                Text {
                    visible: head.label !== ""
                    x: head.alignRight ? parent.width - width - view.plan.pad : view.plan.pad
                    width: Math.min(implicitWidth, Math.max(0, parent.width - 2 * view.plan.pad))
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: head.label
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumSmall
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                Item { id: extraBox; anchors.fill: parent }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: head.sortKey !== ""
                    onClicked: view.panel.sort = head.sortKey
                }
            }

            Head { width: Plan.C.TRI }
            Head {
                width: Plan.C.LAMP
                sortKey: "status"
                PlatinumStatusLight { anchors.centerIn: parent; size: 9; shape: "up"; tone: "muted" }
            }
            Head { width: view.plan.nameW; sortKey: "name"; label: "Name" }
            Repeater {
                model: view.plan.cols
                Head {
                    required property string modelData
                    width: view.plan.widths[modelData]
                    sortKey: modelData === "notes" || modelData === "why" ? "status" : modelData
                    alignRight: modelData !== "why"
                    label: Plan.headLabel(modelData, Plan.LEVELS[view.plan.level], view.measures, width)
                }
            }
            Head { width: view.plan.sb; visible: view.plan.sb > 0 }
        }
        Rectangle { y: view.colsH - view.h; width: parent.width; height: view.h; color: PlatinumTokens.menuEdge }

        Flickable {
            id: list
            y: view.colsH
            width: view.innerW
            height: view.listH
            clip: true
            contentHeight: view.listContentH
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            // The disabled stipple over a stale list.
            PlatinumPattern {
                visible: view.panel.stale && view.ready
                width: list.width
                height: Math.max(list.height, list.contentHeight)
                cell: 1
                ink: PlatinumGlanceTokens.listSorted
                z: -1
            }

            Column {
                id: rowsColumn
                width: list.width
                visible: view.ready
                Repeater {
                    model: view.ready ? view.rowNames : []
                    Column {
                        id: entry
                        required property string modelData
                        readonly property var hv: view.byName[modelData] || null
                        width: rowsColumn.width
                        Component.onCompleted: { const m = Object.assign({}, view.rowItems); m[modelData] = entry; view.rowItems = m; }
                        PlatinumFleetRow {
                            visible: entry.hv !== null
                            width: parent.width
                            hv: entry.hv
                            plan: view.plan
                            panel: view.panel
                            now: view.now
                            focusRing: view.activeFocus
                            onClicked: { view.forceActiveFocus(); view.panel.toggleExpanded(entry.modelData); }
                        }
                        Loader {
                            width: parent.width
                            active: entry.hv !== null && view.panel.expanded === entry.modelData
                            sourceComponent: PlatinumFleetDetail {
                                hv: entry.hv
                                detail: view.panel.details[entry.modelData] || null
                                now: view.now
                                leftInset: Plan.C.TRI + Plan.C.LAMP + view.plan.pad
                                onImplicitHeightChanged: Qt.callLater(function () { view.detailHeight = implicitHeight; })
                                Component.onCompleted: Qt.callLater(function () { view.detailHeight = implicitHeight; })
                            }
                        }
                    }
                }
            }

            // Loading, unavailable, error and an empty fleet keep the
            // window's eight-row size.
            Column {
                id: message
                visible: !view.ready
                x: 34
                y: 14
                width: list.width - x - 12
                spacing: 8
                Text {
                    visible: view.fleet.state !== "loading"
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: view.fleet.state === "unavailable" ? "Beszel is not reachable"
                        : view.fleet.state === "error" ? "Beszel answered with an error" : "Beszel lists no hosts"
                    color: PlatinumTokens.menuText
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumText
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                PlatinumBarberPole {
                    visible: view.fleet.state === "loading"
                    width: Math.min(220, parent.width)
                }
                Text {
                    width: Math.min(parent.width, view.w12("0") * 46)
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                    text: view.fleet.state === "loading" ? "One list_systems call to the Beszel hub on rakku. It usually answers in under a second."
                        : view.fleet.state === "unavailable" ? (view.panel.enabled
                            ? "Its hub runs on rakku, so rakku may be down. Without the hub there is no fleet data. The window tries again every minute."
                            : "This desktop has no Beszel token, so there is no fleet data.")
                        : view.fleet.state === "error" ? "The list_systems call returned an error instead of the fleet. The window tries again every minute."
                        : "Add a system in Beszel, and it appears here at its first report."
                    color: PlatinumTokens.menuTextSecondary
                    font.family: PlatinumTokens.platinumFont
                    font.pixelSize: PlatinumTokens.platinumSmall
                    font.letterSpacing: PlatinumTokens.platinumTracking
                }
                PlatinumButton {
                    visible: (view.fleet.state === "unavailable" && view.panel.enabled) || view.fleet.state === "error"
                    text: view.panel.refreshing ? "Trying…" : "Try again"
                    fixedWidth: PlatinumMetrics.buttonWidth(["Try again", "Trying…"])
                    enabled: !view.panel.refreshing
                    onClicked: view.panel.refresh()
                }
            }
        }

        PlatinumScrollBar {
            visible: view.plan.sb > 0 && needed
            flickable: list
            x: parent.width - width
            y: view.colsH
            height: view.listH
        }
    }

    // ---------------------------------------------------------- footer
    Item {
        id: foot
        y: body.y + body.height
        width: parent.width
        height: view.footH
        Rectangle { width: parent.width; height: view.h; color: PlatinumTokens.menuEdge }
        Text {
            x: 8
            y: view.h + (Plan.C.FOOT - height) / 2
            width: Math.max(0, (grow.visible ? grow.x : parent.width) - x - 4)
            elide: Text.ElideRight
            text: view.panel.stale && view.panel.failing !== ""
                ? "Showing " + view.clock(view.panel.sampledAt) + ". Beszel --, tries again every minute"
                : view.ready || (view.fleet.state === "ready") ? "Updated " + view.clock(view.panel.sampledAt)
                : view.fleet.state === "loading" ? ""
                : "Tries again every minute"
            color: PlatinumTokens.menuTextSecondary
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumHint
            font.letterSpacing: PlatinumTokens.platinumTracking
        }
        // The grow box: drag to resize the Fleet window.
        Item {
            id: grow
            visible: view.growable
            width: 15
            height: Plan.C.FOOT
            y: view.h
            anchors.right: parent.right
            Rectangle { width: view.h; height: parent.height; color: PlatinumTokens.menuEdge }
            Rectangle {
                x: parent.width - 3 - width; y: parent.height - 3 - height
                width: 7; height: 7; color: "transparent"
                border.width: view.h; border.color: PlatinumTokens.menuTextSecondary
            }
            Rectangle {
                x: parent.width - 6 - width; y: parent.height - 6 - height
                width: 4; height: 4; color: PlatinumTokens.menuSurface
                border.width: view.h; border.color: PlatinumTokens.menuTextSecondary
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.SizeFDiagCursor
                preventStealing: true
                property real pressX: 0
                property real pressY: 0
                onPressed: function (mouse) { pressX = mouse.x; pressY = mouse.y; }
                onPositionChanged: function (mouse) { if (pressed) view.grown(mouse.x - pressX, mouse.y - pressY); }
                onReleased: view.growFinished()
            }
        }
    }
}
