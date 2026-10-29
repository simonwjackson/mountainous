pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick
import "beszel-model.js" as Model
import "themes/win98/fleet-plan.js" as Plan
import "themes/win98/host-icon.js" as HostIcon

// The Fleet window's body in the Windows 98 form (the approved mock pass 2,
// /tmp/win98-hud-mock): a View menu bar, an Explorer list in a white well
// (Details, with clickable column headers; or Large Icons, with the status
// overlays and Resource Meter bars), and a status bar with the summary and
// the sample's time. Two hosts use it: the standalone Fleet window and the
// glance space. Both share the Beszel owner and its view state (sort, the
// selected host; the host whose Properties sheet is open is `expanded`,
// so its drill-down is the one Beszel fetches) and the Desktop's Win98
// view state (Details or Large Icons, the sheet's tab).
//
// Layout is Plan.plan(width, height): width decides the columns in the
// shared yield order; height the row height, the menu bar (it folds into
// the caption's control menu) and the scroll bar. Every value a row gives
// up stays in the Properties sheet and the row's tooltip.
//
// The menus and the tooltip escape the window: they draw in menuLayer, an
// item over the host's whole surface.
FocusScope {
    id: view

    required property var panel        // panels/Beszel.qml
    required property var prefs        // Win98FleetGlance: view, tab
    property Item menuLayer: null
    // The window's size, in logical px: its width; its height when the host
    // fixes one (-1: natural); the most it may take (-1: no limit).
    property real frameWidth: 400
    property real frameHeight: -1
    property real maxFrameHeight: -1
    property bool active: false
    // The standalone window minimizes; the glance space's Fleet does not.
    property bool canMinimize: false
    property real now: panel.now
    signal escapePressed
    signal closeRequested
    signal minimizeRequested
    signal hostOpened(string name)

    readonly property real u: Kit.Win98Tokens.unitFor(QsWindow.window)
    function units(n) { return n * view.u; }
    function mu(s, bold) { return Math.ceil(Kit.Win98Tokens.textWidth(s, !!bold, view.u) / view.u - 1e-6); }

    // The window around this body, in units: frame and caption (Win98Window).
    readonly property int chromeW: 2 * Kit.Win98Tokens.frame
    readonly property int chromeH: Kit.Win98Tokens.frame + Kit.Win98Tokens.captionHeight + 1 + Kit.Win98Tokens.frame

    readonly property var fleet: panel.fleet
    readonly property bool ready: fleet.state === "ready" && fleet.hosts.length > 0
    readonly property bool icons: view.prefs.view === "icons"

    // ---------------------------------------------------------- measures
    readonly property var measures: {
        const hosts = view.fleet.hosts;
        const names = hosts.length ? hosts.map(function (v) { return v.name; }) : ["hiyori"];
        // Uptime: the widest uptime of a host that is up; a "seen" text only
        // when a host is not (the mock's rule).
        let nameW = 0, fsW = 0, upLong = 0, upShort = 0;
        for (const n of names) nameW = Math.max(nameW, view.mu(n));
        for (const v of hosts) {
            if (!v.trusted) { upLong = Math.max(upLong, view.mu("seen 49m ago")); upShort = Math.max(upShort, view.mu("49m")); continue; }
            if (v.disk.fs !== "/") fsW = Math.max(fsW, Math.min(view.mu(v.disk.fs), Plan.C.FS_MAX) + 3);
            upLong = Math.max(upLong, view.mu(Model.fmtUptime(v.uptime, "long")));
            upShort = Math.max(upShort, view.mu(Model.fmtUptime(v.uptime, "short")));
        }
        const head = {};
        for (const id of Object.keys(Plan.HEAD)) head[id] = Plan.HEAD[id].map(function (t) { return view.mu(t); });
        return {
            // The frame, the body's 2-u sides and the well's 2-u bevel.
            border: view.chromeW + 4 + 4,
            // The caption and frame, the well's bevel, the status bar.
            chrome: view.chromeH + 4 + 22,
            rows: view.ready ? hosts.length : 8,
            nameW: nameW, head: head, fsLabelW: fsW,
            pctW: view.mu("100%"), tempW: view.mu("100°"), failedW: view.mu("14"), notesW: view.mu("14 failed"),
            upLongW: upLong, upShortW: upShort
        };
    }
    readonly property int fw: Math.round(frameWidth / u)

    // The width the window would like. A state without hosts keeps the last
    // ready width, so the window does not jump between states.
    property real lastReadyUnits: 0
    readonly property real planNatural: Math.max(Plan.C.MINW, Plan.plan(9999, null, measures, {}).natural)
    onPlanNaturalChanged: if (ready) lastReadyUnits = planNatural
    readonly property real naturalWidth: (ready ? planNatural : Math.max(planNatural, lastReadyUnits)) * u

    // Large Icons: the grid for this width (the scroll bar's room is paid
    // only while the grid scrolls).
    readonly property var grid: Plan.iconGrid(fw - measures.border - (iconsScroll ? Plan.C.SB : 0), ready ? fleet.hosts.length : 0)
    property bool iconsScroll: false
    readonly property var planOpt: icons && ready ? ({icons: true, iconsH: grid.height}) : ({})
    // The natural height in units, and the height the plan works to.
    readonly property real naturalUnits: Plan.heightPlan(null, measures, planOpt).natural
    readonly property real planUnits: frameHeight >= 0 ? Math.round(frameHeight / u)
        : maxFrameHeight >= 0 && naturalUnits * u > maxFrameHeight + 0.5 ? Math.floor(maxFrameHeight / u) : -1
    readonly property var plan: Plan.plan(fw, planUnits >= 0 ? planUnits : null, measures, planOpt)
    Timer {
        id: iconsSettle
        interval: 0
        onTriggered: view.iconsScroll = view.plan.scrolls
    }
    onPlanChanged: if (icons) iconsSettle.restart()

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

    // ---------------------------------------------------------- text
    readonly property var fleetLook: HostIcon.fleetLook(fleet, panel.stale)
    readonly property string worstTone: fleet.state === "ready" && fleet.problems.length
        ? (fleet.problems.some(function (v) { return v.tone === "danger"; }) ? "danger" : "warning") : "normal"
    // The caption names the problem hosts while the list scrolls.
    function captionText(roomUnits) {
        if (!view.plan.scrolls) return "Fleet";
        return Plan.fit(Model.summaryVariants(view.fleet, true, "Fleet: "), roomUnits, function (s) { return view.mu(s, true); });
    }
    function toneColor(tone, selected) {
        if (selected) return Kit.Win98Tokens.selectionText;
        return tone === "danger" ? Kit.Win98Tokens.danger : tone === "warning" ? Kit.Win98Tokens.warning
            : tone === "muted" || tone === "stale" ? Kit.Win98Tokens.gray : Kit.Win98Tokens.winText;
    }
    function clock(ms) {
        if (!(ms > 0)) return "--";
        const d = new Date(ms);
        return (d.getHours() % 12 || 12) + Qt.formatTime(d, ":mm");
    }
    function tipFor(v) {
        return [v.name + ", " + v.status].concat(v.reasons.map(function (r) { return r.text; })).join("\n");
    }

    // ---------------------------------------------------------- heights (units)
    readonly property int menuH: plan.menuInCap ? 0 : Plan.C.MENU
    readonly property int headH: !icons && ready ? Plan.C.COLH : 0
    readonly property real listContentUnits: !ready ? Plan.C.COLH + 8 * Plan.C.ROW
        : icons ? grid.height : rowNames.length * plan.rowH
    readonly property real listUnits: planUnits >= 0
        ? Math.max(0, planUnits - chromeH - menuH - 4 - headH - 22)
        : listContentUnits
    readonly property real bodyUnits: menuH + 4 + headH + listUnits + 22
    implicitWidth: naturalWidth - chromeW * u
    implicitHeight: bodyUnits * u
    // The window at rest (no menu open), for the glance space's layout.
    readonly property real restHeight: (chromeH + bodyUnits) * u

    // ---------------------------------------------------------- keys
    Timer {
        id: selectionReveal
        interval: 0
        property string selectedName: ""
        onTriggered: view.reveal(selectionReveal.selectedName)
    }
    function move(step) {
        const names = rowNames;
        if (!names.length) return;
        const i = names.indexOf(panel.selected);
        panel.selected = names[Math.max(0, Math.min(names.length - 1, i < 0 ? 0 : i + step))];
        selectionReveal.selectedName = panel.selected;
        selectionReveal.restart();
    }
    function reveal(name) {
        const i = rowNames.indexOf(name);
        if (i < 0) return;
        const top = icons ? units(Plan.C.ICONS_PAD + Math.floor(i / grid.cols) * Plan.C.CELL_H) : units(i * plan.rowH);
        const bottom = top + units(icons ? Plan.C.CELL_H : plan.rowH);
        if (top < list.contentY) list.contentY = top;
        else if (bottom > list.contentY + list.height) list.contentY = Math.min(bottom - list.height, Math.max(0, list.contentHeight - list.height));
    }
    function open(name) {
        if (!name) return;
        panel.selected = name;
        panel.expanded = name;
        view.hostOpened(name);
    }
    function sortBy(key) { panel.sort = panel.sort === key && key !== "name" ? "name" : key; }

    // The window's menus: the View menu (menu bar) and the control menu
    // (the caption icon), which takes the View items when the bar folds.
    property string menuOpen: ""
    property point menuAt: Qt.point(0, 0)
    readonly property var viewItems: [
        { text: "Lar&ge Icons", act: "icons", radio: true, checked: view.icons },
        { text: "&Details", act: "details", radio: true, checked: !view.icons },
        { separator: true },
        { text: "Arrange by &Name", act: "sort:name", radio: true, checked: view.panel.sort === "name" },
        { text: "Arrange by &Status (worst first)", act: "sort:status", radio: true, checked: view.panel.sort === "status" }
    ]
    readonly property var controlItems: view.viewItems.concat([{ separator: true }],
        view.canMinimize ? [{ text: "Mi&nimize", act: "minimize" }] : [],
        [{ text: "&Close", act: "close", bold: true, shortcut: "Esc" }])
    function openMenu(id, at) {
        view.menuAt = at;
        view.menuOpen = id;
        view.forceActiveFocus();
    }
    // The caption icon's press: the control menu under the icon. win: the
    // Win98Window around this body.
    function openControlMenu(win) {
        if (view.menuOpen === "control") { view.menuOpen = ""; return; }
        const f = win && win.frame !== undefined ? win.frame : 0;
        const p = win && view.menuLayer ? win.mapToItem(view.menuLayer, f + view.units(3), f + view.units(Kit.Win98Tokens.captionHeight + 1)) : Qt.point(0, 0);
        view.openMenu("control", p);
    }
    function run(act) {
        view.menuOpen = "";
        if (act === "icons" || act === "details") view.prefs.view = act;
        else if (act.indexOf("sort:") === 0) view.panel.sort = act.slice(5);
        else if (act === "minimize") view.minimizeRequested();
        else if (act === "close") view.closeRequested();
    }

    Keys.onPressed: function (event) {
        const alt = event.modifiers & Qt.AltModifier;
        if (alt && event.key === Qt.Key_V && !view.plan.menuInCap) {
            const p = bar.placeOf("view");
            view.openMenu("view", bar.mapToItem(view.menuLayer, p ? p.x : 0, bar.height));
            event.accepted = true;
        } else if (alt && event.key === Qt.Key_Space) {
            view.openMenu("control", view.mapToItem(view.menuLayer, 0, 0));
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || (view.icons && event.key === Qt.Key_Right)) {
            view.move(view.icons && event.key === Qt.Key_Down ? view.grid.cols : 1); event.accepted = true;
        } else if (event.key === Qt.Key_Up || (view.icons && event.key === Qt.Key_Left)) {
            view.move(view.icons && event.key === Qt.Key_Up ? -view.grid.cols : -1); event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && view.panel.selected !== "") {
            view.open(view.panel.selected); event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            view.escapePressed(); event.accepted = true;
        }
    }

    // ---------------------------------------------------------- menu bar
    Win98MenuBar {
        id: bar
        visible: !view.plan.menuInCap
        width: parent.width
        height: view.units(18)
        menus: [{ id: "view", text: "&View" }]
        openId: view.menuOpen === "view" ? "view" : ""
        onOpened: function (id, x, w) { view.openMenu(id, bar.mapToItem(view.menuLayer, x, bar.height)); }
        onClosed: view.menuOpen = ""
    }

    // ---------------------------------------------------------- the list well
    Win98Bevel {
        id: well
        x: view.units(2)
        y: view.units(view.menuH)
        width: parent.width - view.units(4)
        height: view.units(4 + view.headH + view.listUnits)
        variant: "field"
        color: Kit.Win98Tokens.win

        Win98HeaderView {
            id: headers
            objectName: "fleetHeaders"
            visible: view.headH > 0
            x: view.units(2)
            y: view.units(2)
            width: well.width - view.units(4)
            height: view.units(Plan.C.COLH)
            pad: view.plan.pad
            columns: {
                const out = [{ id: "name", label: "Name", width: view.units(view.plan.nameW), sortKey: "name" }];
                const level = Plan.LEVELS[view.plan.level];
                for (const id of view.plan.cols) out.push({ id: id, width: view.units(view.plan.widths[id]), alignRight: id !== "why",
                    sortKey: id === "notes" || id === "why" ? "status" : id,
                    label: Plan.headLabel(id, level, view.measures, view.plan.widths[id]) });
                if (view.plan.sb > 0) out.push({ id: "sb", width: view.units(view.plan.sb), label: "" });
                return out;
            }
            onClicked: function (key) { view.sortBy(key); }
        }

        Flickable {
            id: list
            x: view.units(2)
            y: view.units(2 + view.headH)
            width: well.width - view.units(4) - (view.plan.sb > 0 ? view.units(view.plan.sb) : 0)
            height: view.units(view.listUnits)
            clip: true
            contentHeight: view.units(view.listContentUnits)
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                enabled: list.contentHeight > list.height
                onWheel: event => list.contentY = Math.max(0, Math.min(list.contentHeight - list.height,
                    list.contentY - Math.sign(event.angleDelta.y) * view.units(view.plan.rowH)))
            }

            // A stale list (Beszel stopped answering): the face's dither
            // under the rows.
            Win98Dither {
                visible: view.panel.stale && view.ready
                width: list.width
                height: Math.max(list.height, list.contentHeight)
                color: Kit.Win98Tokens.face
            }

            // Details: one row per host.
            Column {
                id: rowsColumn
                visible: view.ready && !view.icons
                width: list.width
                Repeater {
                    model: view.ready && !view.icons ? view.rowNames : []
                    FleetRow {
                        required property string modelData
                        hv: view.byName[modelData] || null
                    }
                }
            }

            // Large Icons: one cell per host.
            Item {
                visible: view.ready && view.icons
                width: list.width
                height: view.units(view.grid.height)
                Repeater {
                    model: view.ready && view.icons ? view.rowNames : []
                    IconCell {
                        required property string modelData
                        required property int index
                        hv: view.byName[modelData] || null
                        x: view.units(Plan.C.ICONS_PAD + (index % view.grid.cols) * view.grid.cellW)
                        y: view.units(Plan.C.ICONS_PAD + Math.floor(index / view.grid.cols) * Plan.C.CELL_H)
                        width: view.units(view.grid.cellW)
                    }
                }
            }

            // Loading, unavailable, error and an empty fleet keep the
            // window's eight-row size.
            Column {
                id: message
                visible: !view.ready
                x: view.units(10)
                y: view.units(10)
                width: list.width - view.units(20)
                spacing: view.units(6)
                Win98Icon { visible: view.fleet.state === "loading"; name: "hourglass" }
                Win98Text {
                    width: parent.width
                    wrap: true
                    bold: true
                    accessMarks: false
                    color: Kit.Win98Tokens.winText
                    text: view.fleet.state === "loading" ? "Asking Beszel..."
                        : view.fleet.state === "unavailable" ? "Beszel is not reachable"
                        : view.fleet.state === "error" ? "Beszel answered with an error" : "Beszel lists no hosts"
                }
                Win98Text {
                    width: parent.width
                    wrap: true
                    accessMarks: false
                    color: Kit.Win98Tokens.winText
                    text: view.fleet.state === "loading" ? "One list_systems call to the Beszel hub on rakku. It usually answers in under a second."
                        : view.fleet.state === "unavailable" ? (view.panel.enabled
                            ? "Its hub runs on rakku, so rakku may be down. Without the hub there is no fleet data. The window tries again every minute."
                            : "This desktop has no Beszel token, so there is no fleet data.")
                        : view.fleet.state === "error" ? "The list_systems call returned an error instead of the fleet. The window tries again every minute."
                        : "Add a system in Beszel, and it appears here at its first report."
                }
                Win98Button {
                    objectName: "fleetRetry"
                    visible: (view.fleet.state === "unavailable" && view.panel.enabled) || view.fleet.state === "error"
                    small: true
                    text: view.panel.refreshing ? "Trying..." : "&Try again"
                    enabled: !view.panel.refreshing
                    onClicked: view.panel.refresh()
                }
            }
        }

        Win98ScrollBar {
            visible: view.plan.sb > 0
            x: well.width - view.units(2) - width
            y: view.units(2 + view.headH)
            height: view.units(view.listUnits)
            flickable: list
            step: view.units(view.plan.rowH)
        }
    }

    // ---------------------------------------------------------- status bar
    Item {
        id: status
        y: well.y + well.height + view.units(2)
        width: parent.width
        height: view.units(18)
        readonly property string age: view.panel.stale && view.panel.failing !== ""
            ? "Showing " + view.clock(view.panel.sampledAt) + ". Beszel --, tries again every minute"
            : view.fleet.state === "ready" ? "Updated " + view.clock(view.panel.sampledAt)
            : view.fleet.state === "loading" ? "" : "Tries again every minute"
        readonly property real inner: width
        readonly property real ageW: status.age === "" ? 0 : Math.min(view.units(view.mu(status.age) + 10), Kit.Win98Tokens.snap(inner * 0.45, view.u))
        readonly property string staleText: view.panel.stale
            ? Plan.fit(["Last update " + Model.ago(view.now - view.panel.sampledAt), Model.ago(view.now - view.panel.sampledAt)],
                Math.floor(inner * 0.3 / view.u), function (s) { return view.mu(s); }) : ""
        readonly property real staleW: staleText === "" ? 0 : view.units(view.mu(staleText) + 10)
        readonly property real sumRoom: inner - (ageW > 0 ? ageW + view.units(2) : 0) - (staleW > 0 ? staleW + view.units(2) : 0)
        readonly property bool onePane: sumRoom < view.units(70)
        readonly property string summary: Plan.fit(Model.summaryVariants(view.fleet, view.plan.scrolls, ""),
            Math.floor(((onePane ? inner : sumRoom) - view.units(8)) / view.u), function (s) { return view.mu(s); })
        readonly property string summaryTone: view.fleet.problems.length && view.fleet.state === "ready" ? view.worstTone
            : view.fleet.state === "ready" ? "normal" : "muted"

        Pane {
            id: sumPane
            objectName: "fleetSummary"
            width: status.onePane ? status.width : status.sumRoom
            text: status.summary
            tone: status.summaryTone
        }
        Pane {
            visible: !status.onePane && status.staleW > 0
            x: sumPane.width + view.units(2)
            width: status.staleW
            text: status.staleText
        }
        Pane {
            visible: !status.onePane && status.ageW > 0
            x: status.width - width
            width: status.ageW
            text: status.age
            tone: "muted"
        }
    }

    component Pane: Item {
        id: pane
        property string text: ""
        property string tone: "normal"
        height: status.height
        Win98Bevel { anchors.fill: parent; variant: "thinSunken"; filled: false }
        Win98Text {
            x: view.units(4)
            y: view.units(3)
            width: Math.max(0, Math.min(implicitWidth, pane.width - view.units(8)))
            text: pane.text
            accessMarks: false
            color: pane.tone === "danger" ? Kit.Win98Tokens.danger : pane.tone === "warning" ? Kit.Win98Tokens.warning
                : pane.tone === "muted" ? Kit.Win98Tokens.gray : Kit.Win98Tokens.text
        }
    }

    // ---------------------------------------------------------- one row
    component FleetRow: Item {
        id: row
        property var hv: null
        readonly property bool selected: hv !== null && view.panel.selected === hv.name
        readonly property var level: Plan.LEVELS[view.plan.level]
        readonly property bool stale: hv !== null && !hv.trusted
        objectName: hv ? "row-" + hv.name : "row"
        width: rowsColumn.width
        height: view.units(view.plan.rowH)

        // A host that is not up shows its last values grey; its tone still
        // colours its name and its reason.
        function ink(tone) { return view.toneColor(row.stale && tone === "normal" ? "stale" : tone, row.selected); }

        Rectangle { anchors.fill: parent; color: row.selected ? Kit.Win98Tokens.selection : "transparent" }
        Win98FocusRect {
            visible: row.selected && view.active
            anchors.fill: parent
            color: Kit.Win98Tokens.selectionText
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { view.forceActiveFocus(); if (row.hv) view.open(row.hv.name); }
            onContainsMouseChanged: view.hoverTip(containsMouse && row.hv ? row : null, row.hv ? view.tipFor(row.hv) : "")
        }

        // Name: the host icon, then the name in its tone.
        Item {
            id: nameCell
            width: view.units(view.plan.nameW)
            height: row.height
            Win98HostIcon {
                x: view.units(view.plan.pad)
                y: Kit.Win98Tokens.snap((row.height - height) / 2, view.u)
                hostStatus: row.hv ? row.hv.status : "up"
                tone: row.hv ? row.hv.tone : "normal"
            }
            Win98Text {
                x: view.units(view.plan.pad + 16 + 3 + 1)
                y: Kit.Win98Tokens.snap((row.height - height) / 2, view.u)
                width: Math.max(0, Math.min(implicitWidth, nameCell.width - x - view.units(view.plan.pad)))
                text: row.hv ? row.hv.name : ""
                accessMarks: false
                color: row.hv && row.hv.status !== "up" && row.hv.tone === "muted" && !row.selected
                    ? Kit.Win98Tokens.gray : row.ink(row.hv ? row.hv.tone : "normal")
            }
        }

        Repeater {
            model: view.plan.cols
            Item {
                id: cell
                required property string modelData
                required property int index
                readonly property var hv: row.hv
                readonly property bool bar: Plan.barOn(row.level, modelData)
                readonly property bool metricCol: ["cpu", "mem", "disk"].indexOf(modelData) >= 0
                readonly property var metric: !hv ? null : modelData === "cpu" ? hv.cpu : modelData === "mem" ? hv.mem : modelData === "disk" ? hv.disk : null
                readonly property real inner: width - view.units(2 * view.plan.pad)
                x: {
                    let s = view.units(view.plan.nameW);
                    for (let i = 0; i < index; i++) s += view.units(view.plan.widths[view.plan.cols[i]]);
                    return s;
                }
                width: view.units(view.plan.widths[modelData])
                height: row.height

                // CPU, memory, disk: the filesystem's name (disk), the block
                // bar, the number.
                Row {
                    visible: cell.metricCol && cell.hv !== null
                    anchors.right: parent.right
                    anchors.rightMargin: view.units(view.plan.pad)
                    height: parent.height
                    spacing: view.units(3)
                    Win98Text {
                        visible: cell.modelData === "disk" && cell.bar && !!cell.hv && cell.hv.trusted && cell.hv.disk.fs !== "/"
                        y: Kit.Win98Tokens.snap((row.height - height) / 2, view.u)
                        width: visible ? Math.min(implicitWidth, view.units(Plan.C.FS_MAX)) : 0
                        text: cell.hv ? cell.hv.disk.fs : ""
                        accessMarks: false
                        color: row.selected ? Kit.Win98Tokens.selectionText : Kit.Win98Tokens.gray
                    }
                    Win98LevelBar {
                        visible: cell.bar
                        blocks: true
                        y: Kit.Win98Tokens.snap((row.height - height) / 2, view.u)
                        width: view.units(row.level.bar)
                        height: view.units(10)
                        value: cell.metric && cell.metric.pct !== null ? cell.metric.pct / 100 : NaN
                        tone: cell.modelData === "disk" && cell.metric ? cell.metric.tone : "normal"
                        stale: row.stale
                        onSelection: row.selected
                    }
                    Win98Text {
                        y: Kit.Win98Tokens.snap((row.height - height) / 2, view.u)
                        width: Math.max(implicitWidth, view.units(view.measures.pctW))
                        horizontalAlignment: Text.AlignRight
                        text: cell.metric ? Model.fmtPct(cell.metric.pct) : "--"
                        accessMarks: false
                        color: row.ink(cell.modelData === "disk" && cell.metric && !row.stale ? cell.metric.tone : "normal")
                    }
                }

                // Temp, failed, uptime, notes, the reason: one text.
                Win98Text {
                    readonly property var topReason: cell.hv && cell.hv.reasons.length ? cell.hv.reasons[0] : null
                    readonly property var noteReason: {
                        if (!cell.hv) return null;
                        if (cell.hv.status !== "up") return topReason;
                        for (const r of cell.hv.reasons) if (/failed|°/.test(r.short)) return r;
                        return null;
                    }
                    visible: !cell.metricCol && cell.hv !== null
                    readonly property real room: Math.max(0, cell.inner)
                    x: cell.modelData === "why" ? view.units(view.plan.pad) : cell.width - view.units(view.plan.pad) - width
                    y: Kit.Win98Tokens.snap((row.height - height) / 2, view.u)
                    width: Math.min(implicitWidth, room)
                    accessMarks: false
                    text: {
                        const v = cell.hv;
                        if (!v) return "";
                        switch (cell.modelData) {
                        case "temp": return Model.fmtTemp(v.temp.c);
                        case "failed": return v.failed.n === null ? "--" : String(v.failed.n);
                        case "up":
                            if (v.status === "paused" || v.status === "pending") return v.status;
                            if (v.status === "down") return row.level.up === "long"
                                ? "seen " + Model.agoShort(view.now - v.seen) + " ago" : Model.agoShort(view.now - v.seen);
                            return Model.fmtUptime(v.uptime, row.level.up);
                        case "notes": return noteReason ? noteReason.short : "";
                        case "why": {
                            if (!topReason) return "OK";
                            const more = v.reasons.length > 1 ? " +" + (v.reasons.length - 1) : "";
                            return Plan.fit([topReason.text + more, topReason.short + more, topReason.short],
                                Math.floor(room / view.u), function (s) { return view.mu(s); });
                        }
                        }
                        return "";
                    }
                    color: {
                        const v = cell.hv;
                        if (!v) return Kit.Win98Tokens.winText;
                        switch (cell.modelData) {
                        case "temp": return row.ink(row.stale ? "normal" : v.temp.tone);
                        case "failed": return row.ink(!row.stale && v.failed.n > 0 ? "danger" : "normal");
                        case "up":
                            if (v.status === "paused" || v.status === "pending") return row.ink("muted");
                            if (v.status === "down") return row.ink(v.tone);
                            return row.ink("normal");
                        case "notes": return row.ink(noteReason ? noteReason.tone : "normal");
                        case "why": return row.ink(topReason ? topReason.tone : "normal");
                        }
                        return row.ink("normal");
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- one icon
    component IconCell: Item {
        id: cellItem
        property var hv: null
        readonly property bool selected: hv !== null && view.panel.selected === hv.name
        readonly property bool stale: hv !== null && !hv.trusted
        readonly property var topReason: hv && hv.reasons.length ? hv.reasons[0] : null
        objectName: hv ? "icon-" + hv.name : "icon"
        height: view.units(Plan.C.CELL_H)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { view.forceActiveFocus(); if (cellItem.hv) view.open(cellItem.hv.name); }
            onContainsMouseChanged: view.hoverTip(containsMouse && cellItem.hv ? cellItem : null, cellItem.hv ? view.tipFor(cellItem.hv) : "")
        }
        Row {
            id: art
            x: Kit.Win98Tokens.snap((cellItem.width - width) / 2, view.u)
            y: view.units(3)
            height: view.units(32)
            spacing: view.units(3)
            Win98HostIcon {
                size: 32
                hostStatus: cellItem.hv ? cellItem.hv.status : "up"
                tone: cellItem.hv ? cellItem.hv.tone : "normal"
                selected: cellItem.selected
            }
            // Resource Meter: CPU, memory, disk.
            Row {
                spacing: view.u
                Repeater {
                    model: ["cpu", "mem", "disk"]
                    Win98LevelBar {
                        required property string modelData
                        readonly property var metric: !cellItem.hv ? null : modelData === "cpu" ? cellItem.hv.cpu
                            : modelData === "mem" ? cellItem.hv.mem : cellItem.hv.disk
                        blocks: true
                        vertical: true
                        width: view.units(6)
                        height: view.units(32)
                        value: metric && metric.pct !== null ? metric.pct / 100 : NaN
                        tone: modelData === "disk" && metric ? metric.tone : "normal"
                        stale: cellItem.stale
                    }
                }
            }
        }
        Item {
            id: label
            readonly property real w: Math.min(nameText.implicitWidth + view.units(4), cellItem.width)
            x: Kit.Win98Tokens.snap((cellItem.width - w) / 2, view.u)
            y: art.y + art.height + view.units(3)
            width: w
            height: view.units(13)
            Rectangle { anchors.fill: parent; color: cellItem.selected ? Kit.Win98Tokens.selection : "transparent" }
            Win98FocusRect { visible: cellItem.selected && view.active; anchors.fill: parent; color: Kit.Win98Tokens.selectionText }
            Win98Text {
                id: nameText
                x: view.units(2)
                width: Math.min(implicitWidth, label.width - view.units(4))
                text: cellItem.hv ? cellItem.hv.name : ""
                accessMarks: false
                color: view.toneColor(cellItem.hv ? cellItem.hv.tone : "normal", cellItem.selected)
            }
        }
        Win98Text {
            visible: cellItem.topReason !== null
            x: Kit.Win98Tokens.snap((cellItem.width - width) / 2, view.u)
            y: label.y + label.height
            width: Math.min(implicitWidth, cellItem.width - view.units(4))
            text: cellItem.topReason ? cellItem.topReason.short : ""
            accessMarks: false
            color: view.toneColor(cellItem.topReason ? cellItem.topReason.tone : "normal", false)
        }
    }

    // ---------------------------------------------------------- tooltip
    // Half a second over a row or an icon: its name, status and every
    // reason (what a narrow row gave up).
    property Item tipItem: null
    property string tipText: ""
    function hoverTip(item, text) {
        if (item) { view.tipItem = item; view.tipText = text; tipDelay.restart(); }
        else if (view.tipItem) { view.tipItem = null; tipDelay.stop(); tip.visible = false; }
    }
    Timer {
        id: tipDelay
        interval: 500
        onTriggered: {
            if (!view.tipItem || view.menuOpen !== "" || !view.menuLayer) return;
            const p = view.tipItem.mapToItem(view.menuLayer, view.units(20), view.tipItem.height + view.units(2));
            tip.x = Math.max(0, Math.min(Kit.Win98Tokens.snap(p.x, view.u), view.menuLayer.width - tip.width));
            tip.y = Math.min(Kit.Win98Tokens.snap(p.y, view.u), view.menuLayer.height - tip.height);
            tip.visible = true;
        }
    }
    Win98ToolTip {
        id: tip
        parent: view.menuLayer ? view.menuLayer : view
        visible: false
        z: 10
        text: view.tipText
    }

    // ---------------------------------------------------------- menus
    // A press anywhere else on the surface closes the open menu.
    MouseArea {
        parent: view.menuLayer ? view.menuLayer : view
        visible: view.menuOpen !== ""
        anchors.fill: parent
        z: 19
        onPressed: view.menuOpen = ""
    }
    Loader {
        id: menuLoader
        parent: view.menuLayer ? view.menuLayer : view
        z: 20
        active: view.menuOpen !== ""
        x: view.menuLayer ? Math.max(0, Math.min(view.menuAt.x, view.menuLayer.width - width)) : 0
        y: view.menuLayer ? Math.max(0, Math.min(view.menuAt.y, view.menuLayer.height - height)) : 0
        width: item ? (item as Item).implicitWidth : 0
        height: item ? (item as Item).implicitHeight : 0
        focus: true
        sourceComponent: Win98Menu {
            objectName: "fleetMenu"
            animate: false
            bounds: view.menuLayer
            model: view.menuOpen === "control" ? view.controlItems : view.viewItems
            onTriggered: function (item) { view.run(item.act); }
            onClosed: view.menuOpen = ""
            Component.onCompleted: forceActiveFocus()
        }
    }
    // The menu is the open menu's root, for checks.
    readonly property var menuItem: menuLoader.item
}
