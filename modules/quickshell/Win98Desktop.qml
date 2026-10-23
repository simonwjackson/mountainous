pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "lanes.js" as Lanes
import "battery.js" as BatteryRule
import "oci-model.js" as OciModel
import "builder-gate.js" as Gate
import "themes/win98/tray-model.js" as Tray
import "themes/win98/start-model.js" as StartModel

// One screen's Windows 98 chrome: one bottom taskbar (Start, a band per
// page with its window buttons, the dictation band, the tray and the
// clock), the one window that shows whichever menu or tray window is open,
// the tooltip, and the Display Properties picker. No top bar and no dock.
//
// It reads the shared per-screen data owners in `context` and owns none.
// The selection is the shared MenuState: one menu or window at a time,
// across screens. See docs/plans/desktop-themes.md, phase 2.
Scope {
    id: desktop

    required property var screen
    required property var context
    required property var theme
    property bool active: false
    readonly property string diagnostics: " bar=" + Win98Tokens.face + " edge=bottom"

    readonly property var shell: context.shell
    readonly property real u: Win98Tokens.u

    //------------------------------------------------------------------
    // The Desktop contract (ThemeDesktop, the chrome IPC)
    //------------------------------------------------------------------
    function reveal() {
        shell.chromeVisible = true;
        shell.chromeAccessVisible = true;
    }
    function hide() { shell.chromeAccessVisible = false; }
    // Super+O letters, Ctrl+Esc (start) and the picker (theme). A control
    // the tray has no room for opens from the tray chevron's place.
    function open(control) {
        if (control === "theme") { ThemePicker.open(screen); return; }
        if (control === "start") { desktop.openMenu("start", true); return; }
        if (!desktop.canOpen(control)) return;
        if (control === "builder") shell.builderKeyboard = true;
        desktop.openMenu(control, true);
    }

    //------------------------------------------------------------------
    // Selection
    //------------------------------------------------------------------
    // The menu or window open on this screen, or "".
    readonly property string openId: MenuState.screen === screen ? MenuState.current : ""
    // The tray chevron's place, when a window opened from it (OCI from »).
    property string anchorId: ""
    // The control the keyboard opened; its window takes focus at once and
    // the taskbar keeps the keyboard when it closes with Esc.
    property bool keyboardOpened: false
    // Taskbar keyboard focus (after Esc from a keyboard-opened Start menu,
    // as Win98 left it on the Start button), or "".
    property string taskbarFocus: ""
    // The tooltip's control, or "".
    property string tipId: ""

    // Draw a state without the pointer (state sheets and the harness only;
    // the shell never sets it): { hover, press, focus, tip, flash, drag }.
    property var preview: ({})

    readonly property var menuIds: ["start", "dict", "bt", "wifi", "vol", "bri", "oci", "disk", "builder", "ntf", "clock", "more", "tasks"]

    function canOpen(id) {
        if (id === "oci") return context.oci.enabled;
        if (id === "disk") return context.storage.enabled;
        if (id === "builder") return context.builderGate.enabled;
        if (id === "dict") return context.dictation.barVisible;
        if (id === "bat" || id === "") return false;
        return menuIds.indexOf(id) >= 0 || id === "logoff";
    }

    function openMenu(id, byKeyboard) {
        if (!desktop.canOpen(id)) return;
        desktop.tipId = "";
        desktop.taskbarFocus = "";
        desktop.keyboardOpened = !!byKeyboard;
        desktop.anchorId = taskbar.overflowed(id) ? "more" : "";
        if (id !== "builder") shell.builderKeyboard = false;
        shell.chromeAccessVisible = false;
        MenuState.open(id, screen, -1);
    }
    function closeMenu() {
        MenuState.close();
    }
    // A press on a taskbar control: open its menu, or close it when open.
    function press(id) {
        if (desktop.openId === id) { desktop.closeMenu(); return; }
        desktop.openMenu(id, false);
    }
    // The pointer arrived on a control while another menu is open here:
    // that control's menu takes over (Win98 did this only inside menu
    // bars; the approved mock extends it to Start and the tray).
    function enter(id) {
        if (desktop.openId === "" || desktop.openId === id || desktop.openId === "logoff") return;
        if (desktop.menuIds.indexOf(id) < 0 || !desktop.canOpen(id)) return;
        desktop.openMenu(id, false);
    }
    // Opened from the tray chevron: the window stands where the chevron is.
    function openFromOverflow(id) {
        desktop.openMenu(id, false);
        desktop.anchorId = "more";
    }

    Connections {
        target: MenuState
        function onCurrentChanged() {
            if (MenuState.current === "") desktop.anchorId = "";
        }
    }
    onActiveChanged: if (!active) { tipId = ""; taskbarFocus = ""; }

    //------------------------------------------------------------------
    // Windows and pages (the dock's lane; shared code, not a fork)
    //------------------------------------------------------------------
    readonly property var lane: shell.windowsOn(screen)
    readonly property int showingPage: {
        for (const t of desktop.lane) if (Lanes.isShown(t)) return shell.pageOf(t);
        return -1;
    }
    function appIdOf(t) {
        const wl = t ? t.wayland : null;
        return wl && wl.appId ? wl.appId : "";
    }
    // The Win98 icon for a window's app, or "" to use the icon theme.
    function winIcon(t) { return StartModel.appIcon(desktop.appIdOf(t), ""); }
    function activateWindow(t) {
        const wl = t ? t.wayland : null;
        if (wl) wl.activate();
    }
    function closeWindow(t) {
        const wl = t ? t.wayland : null;
        if (wl) wl.close();
    }
    // A click on a page number shows that page.
    function showPage(page) {
        if (shell.showPage) { shell.showPage(page); return; }
        Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch",
            "hl.dsp.focus({ workspace = " + page + " })"]);
    }

    //------------------------------------------------------------------
    // The tray's data, from the shared owners
    //------------------------------------------------------------------
    // UPower's battery. A harness may replace it.
    property var battery: {
        const dev = UPower.displayDevice;
        return {
            present: dev !== null && dev.isPresent,
            percent: dev ? Math.round(dev.percentage * 100) : 0,
            charging: dev ? dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge : false,
            full: dev ? dev.state === UPowerDeviceState.FullyCharged : false,
            onBattery: UPower.onBattery
        };
    }
    readonly property var batteryRule: BatteryRule.rule(battery.percent, battery.charging, battery.full, battery.onBattery)

    readonly property var gate: context.builderGate
    readonly property var builderLook: {
        const s = gate.sample, p = gate.pending, e = gate.actionError;
        const tone = Gate.tone(s, p, e);
        return {
            off: Gate.mark(s, p) === "off",
            grey: tone === "muted" || tone === "quiet",
            wait: !!p,
            warn: tone === "warning",
            unknown: s.kind === "error" && !p && !e,
            // A manual choice latches the button (sunken over the dither),
            // as a Win98 toolbar button stays down.
            latched: s.kind === "ready" && s.value.choice !== null && s.value.choice !== undefined && !p
        };
    }

    readonly property var dictation: context.dictation
    readonly property string dictText: Tray.dictationText(dictation.statusText, dictation.backendLabel,
        dictation.queueCount, dictation.queueText || (dictation.queueCount + " takes"))

    readonly property var clock: Tray.clock(context.now)

    readonly property var trayData: {
        const c = context;
        const net = c.wifi.connectedNetwork;
        const sink = c.sound.defaultSink;
        const items = c.notifications.items || [];
        return {
            bt: { present: c.bluetooth.adapter !== null, on: !!c.bluetooth.adapter && c.bluetooth.adapter.enabled, count: c.bluetooth.connectedCount },
            wifi: { present: c.wifi.device !== null, hw: c.wifi.hardwareEnabled, enabled: c.wifi.radioEnabled,
                name: net ? net.name : "", signal: net ? net.signalStrength : 0 },
            vol: { muted: c.sound.muted, percent: c.sound.volumePercent, name: sink ? c.sound.nodeLabel(sink) : "" },
            bri: { level: c.brightness.shownLevel },
            oci: { state: c.oci.state, stateText: c.oci.stateText,
                rows: c.oci.rows.map(function (r) { return { name: r.name, value: OciModel.rowRule(r).value }; }) },
            disk: { state: c.storage.state, label: c.storage.label, statusText: c.storage.statusText, issues: c.storage.issues.length },
            ntf: { view: c.notifications.view.kind, count: c.notifications.count,
                urgent: items.filter(function (i) { return i.urgency === 2; }).length,
                badgeKind: c.centre.badge.kind, badgeText: c.centre.badge.text || "" },
            bat: { percent: desktop.battery.percent, onBattery: desktop.battery.onBattery, indicator: desktop.batteryRule.indicator },
            builder: { ready: gate.sample.kind === "ready", pending: gate.pending,
                running: gate.sample.kind === "ready" ? gate.sample.value.running : 0,
                tooltip: Gate.tooltip(gate.sample, gate.pending, gate.actionError),
                barText: Gate.barText(gate.sample, gate.pending, gate.actionError, "wide") },
            dict: { text: desktop.dictText },
            clock: { date: Qt.formatDateTime(c.now, "dddd, MMMM d, yyyy") }
        };
    }

    // The tray's icons, in order. A control hides only when its hardware or
    // service is missing; Start > Settings still opens those windows.
    readonly property var trayIds: {
        const c = context, out = [];
        if (dictation.barVisible) out.push("dict");
        if (c.bluetooth.adapter !== null) out.push("bt");
        if (c.wifi.device !== null) out.push("wifi");
        if (c.sound.available) out.push("vol");
        if (c.brightness.available) out.push("bri");
        if (c.oci.enabled) out.push("oci");
        if (c.storage.enabled) out.push("disk");
        if (gate.enabled) out.push("builder");
        out.push("ntf");
        if (desktop.battery.present) out.push("bat");
        return out;
    }

    function trayIcon(id) {
        const d = desktop.trayData;
        if (id === "dict") return Tray.micIcon(dictation.state);
        if (id === "bt") return d.bt.on ? "bluetooth-on" : "bluetooth-off";
        if (id === "wifi") return Tray.wifiIcon(!d.wifi.hw || !d.wifi.enabled, Tray.wifiLevel(d.wifi.name !== "", d.wifi.signal));
        if (id === "vol") return Tray.volumeIcon(d.vol.muted, d.vol.percent);
        if (id === "bri") return "brightness";
        if (id === "oci") return Tray.ociIcon(context.oci.tone);
        if (id === "disk") return Tray.diskIcon(d.disk.state, context.storage.worst);
        if (id === "builder") return Tray.builderIcon(desktop.builderLook);
        if (id === "ntf") return Tray.bellIcon(d.ntf.view, d.ntf.count);
        if (id === "bat") return Tray.batteryIcon(desktop.batteryRule.indicator);
        return "";
    }
    function badge(id) { return Tray.badge(id, desktop.trayData); }
    function tooltip(id) {
        if (id.indexOf("win") === 0) {
            const t = desktop.lane[Number(id.slice(3))];
            return t ? (t.title || "(untitled)") : "";
        }
        if (id.indexOf("page") === 0) return "Page " + id.slice(4);
        return Tray.tooltip(id, desktop.trayData);
    }

    //------------------------------------------------------------------
    // The Start menu
    //------------------------------------------------------------------
    property string userName: Quickshell.env("USER") || "simon"
    // The machine's name, for the Start menu's band and Log Off's caption.
    property string hostName: Quickshell.env("HOSTNAME") || ""
    readonly property string hostLabel: hostName === "" ? "" : hostName.charAt(0).toUpperCase() + hostName.slice(1)
    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: if (desktop.hostName === "") desktop.hostName = text().trim()
    }
    property var apps: {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (!e || e.noDisplay) continue;
            out.push({ id: e.id || "", name: e.name || e.id || "", categories: e.categories ? [...e.categories] : [], entry: e });
        }
        return out;
    }
    readonly property var commandRows: context.omniBar.commandRows || []
    readonly property var startModel: StartModel.top(
        StartModel.programs(desktop.apps),
        StartModel.windows(desktop.lane.map(function (t) {
            return { title: t.title, page: shell.pageOf(t), icon: desktop.winIcon(t) || "doc" };
        })),
        StartModel.commands(desktop.commandRows),
        desktop.userName)

    function runStart(item) {
        MenuState.close();
        if (!item) return;
        if (item.action === "app") { const a = desktop.apps[item.app]; if (a && a.entry) a.entry.execute(); }
        else if (item.action === "window") desktop.activateWindow(desktop.lane[item.window]);
        else if (item.action === "command") context.omniBar.run(desktop.commandRows[item.row]);
        else if (item.action === "run") context.omniBar.enterRoot();
        else if (item.action === "picker") ThemePicker.open(desktop.screen);
        else if (item.action === "open") desktop.openMenu(item.control, false);
        else if (item.action === "logoff") desktop.openMenu("logoff", false);
    }
    function logOff() {
        MenuState.close();
        Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch", "hl.dsp.exit()"]);
    }

    // The open menu or window's root item (the MenuHost sets it), for checks.
    property var openItem: null

    // For the harness and checks: the taskbar's plan and where things are.
    function taskbarPlan() { return taskbar.plan; }
    function debugPlaces() {
        const out = {};
        for (const id in taskbar.places) {
            const p = taskbar.placeOf(id);
            if (p) out[id] = p;
        }
        out.barHeight = taskbar.barHeight;
        out.width = taskbar.width;
        out.height = taskbar.height;
        out.implicitHeight = taskbar.implicitHeight;
        out.dpr = taskbar.devicePixelRatio;
        out.faceY = taskbar.faceY;
        return out;
    }

    //------------------------------------------------------------------
    // Surfaces
    //------------------------------------------------------------------
    Win98Taskbar {
        id: taskbar
        desktop: desktop
        visible: desktop.active && desktop.shell.chromeVisible
    }

    Win98MenuHost {
        desktop: desktop
        taskbar: taskbar
        enabled: desktop.active && desktop.shell.chromeVisible
    }

    Win98TipWindow {
        desktop: desktop
        taskbar: taskbar
    }

    // The registry selects this theme's picker. The shared model persists
    // across Desktop swaps; the view is destroyed with its theme.
    readonly property var pickerView: pickerLoader.item
    Loader {
        id: pickerLoader
        active: desktop.active && ThemePicker.visible && ThemePicker.screen === desktop.screen
        function loadView() {
            if (active) setSource(Qt.resolvedUrl(desktop.theme.picker), {screen: desktop.screen, model: ThemePicker});
        }
        onActiveChanged: loadView()
        Component.onCompleted: loadView()
    }
}
