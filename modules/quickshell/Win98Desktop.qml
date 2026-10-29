pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "lanes.js" as Lanes
import "app-model.js" as AppModel
import "battery.js" as BatteryRule
import "oci-model.js" as OciModel
import "builder-gate.js" as Gate
import "themes/win98/tray-model.js" as Tray
import "themes/win98/start-model.js" as StartModel
import "themes/win98/taskbar-plan.js" as Plan
import "themes/win98/host-icon.js" as HostIcon
import "themes/win98/task-model.js" as TaskModel
import "themes/win98/session-model.js" as Session
import "beszel-model.js" as FleetModel
import "page-names.js" as PageNames
import "glance-registry.js" as GlanceRegistry

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
    readonly property string diagnostics: " bar=" + Kit.Win98Tokens.face + " edge=bottom"

    readonly property var shell: context.shell
    readonly property real u: Kit.Win98Tokens.unitFor(taskbar)

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

    readonly property var menuIds: ["start", "layout", "dict", "bt", "wifi", "vol", "bri", "oci", "disk", "builder", "ntf", "clock", "more", "tasks",
        "glance", "fleetmenu"]
    // Opened by the Desktop itself, never by hovering onto a control: the
    // dialogs and the two context menus (Win98's context menus stayed put).
    readonly property var ownIds: ["logoff", "shutdown", "sysprops", "winmenu", "tbmenu"]

    function canOpen(id) {
        if (id === "fleet" || id === "fleetmenu") return fleetGlance.present;
        if (id === "glance") return fleetGlance.glanceShown;
        if (id === "layout") return desktop.layoutShown;
        if (id === "oci") return context.oci.enabled;
        if (id === "disk") return context.storage.enabled;
        if (id === "builder") return context.builderGate.enabled;
        if (id === "dict") return context.dictation.barVisible;
        if (id === "find" || id === "address") return omniView.want() === id;
        if (id === "winmenu") return desktop.menuRow !== null;
        if (id === "bat" || id === "") return false;
        return menuIds.indexOf(id) >= 0 || ownIds.indexOf(id) >= 0;
    }

    function openMenu(id, byKeyboard) {
        if (!desktop.canOpen(id)) return;
        // The tray's Fleet icon is the Fleet window's control, not a menu.
        if (id === "fleet") { MenuState.close(); fleetGlance.toggleFleet(); return; }
        desktop.tipId = "";
        desktop.taskbarFocus = "";
        desktop.keyboardOpened = !!byKeyboard;
        desktop.anchorId = taskbar.overflowed(id) ? "more"
            : id === "fleetmenu" ? (taskbar.overflowed("fleet") ? "more" : "fleet")
            : id === "glance" && !taskbar.placeOf("glance") ? (taskbar.plan.structure === "start" ? "start" : "more") : "";
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
        if (desktop.openId === "" || desktop.openId === id || desktop.ownIds.indexOf(desktop.openId) >= 0) return;
        if (desktop.openId === "find" || desktop.openId === "address") return;
        if (desktop.menuIds.indexOf(id) < 0 || !desktop.canOpen(id)) return;
        desktop.openMenu(id, false);
    }
    // Opened from the tray chevron: the window stands where the chevron is.
    function openFromOverflow(id) {
        if (!id) { desktop.closeMenu(); return; }
        desktop.openMenu(id, false);
        if (id !== "fleet") desktop.anchorId = taskbar.plan.structure === "start" ? "start" : "more";
    }
    // What the taskbar has no room for, as menu items: the tray controls,
    // then (compact) the windows, then the clock and the battery readouts.
    // The tray chevron shows these; in the last structure Start's Taskbar
    // cascade does.
    function overflowItems(withWindows) {
        const p = taskbar.plan, out = [];
        const label = function (s) { return String(s).replace(/&/g, "&&"); };
        for (const id of p.trayOut) {
            if (id === "bat") continue;
            out.push({ text: Tray.LABEL[id], icon: id === "fleet" ? "host" : desktop.trayIcon(id), action: "open", control: id,
                shortcut: label(Tray.overflowValue(id, id === "layout" ? desktop.layoutData() : desktop.trayData)) });
        }
        // The Glance button and a minimized Fleet, when the bar has no room
        // for their band (compact, start): before the windows.
        if (p.extrasOut.length) {
            if (out.length) out.push({ separator: true });
            for (const id of p.extrasOut) {
                if (id === "glance") out.push({ text: "Glance", icon: "glance", action: "open", control: "glance", shortcut: "Win+W" });
                else out.push({ text: label(fleetGlance.buttonText), icon: "host", action: "restorefleet" });
            }
        }
        if (withWindows && p.taskOut.length) {
            if (out.length) out.push({ separator: true });
            let last = null;
            for (const i of Plan.overflowWindows(desktop.lane.map(function (t) { return { page: desktop.pageOf(t) }; }), p.taskOut)) {
                const t = desktop.lane[i];
                // Pages are never numbered: a separator between two pages.
                if (last !== null && desktop.pageOf(t) !== last) out.push({ separator: true });
                last = desktop.pageOf(t);
                out.push({ text: label((t && t.title) || "(untitled)"), icon: desktop.winIcon(t) || "doc",
                    shortcut: desktop.windowHint(t), action: "window", window: i });
            }
        }
        if (p.clockOut || p.trayOut.indexOf("bat") >= 0) {
            if (out.length) out.push({ separator: true });
            if (p.clockOut) out.push({ text: "Date/Time", icon: "doc", action: "open", control: "clock",
                shortcut: desktop.clock.time + " " + desktop.clock.ampm });
            if (p.trayOut.indexOf("bat") >= 0 && desktop.battery.present)
                out.push({ text: "Battery", icon: Tray.batteryIcon(desktop.batteryRule.indicator), action: "", control: "",
                    shortcut: Tray.tooltip("bat", desktop.trayData) });
        }
        return out;
    }

    Connections {
        target: MenuState
        function onCurrentChanged() {
            if (MenuState.current === "") desktop.anchorId = "";
        }
    }
    onActiveChanged: if (!active) { tipId = ""; taskbarFocus = ""; cycleState = null; popupId = ""; }

    //------------------------------------------------------------------
    // Windows and pages
    //------------------------------------------------------------------
    // Win98 kept a minimized window's button on the taskbar. Minimize is the
    // shared hide (WindowHider), which lanes.js leaves off every taskbar,
    // so this lane is the Win98 taskbar's own (task-model.js): the windows
    // shown on this screen plus the hidden ones whose home is here, each in
    // its home page's band. lanes.js and Platinum are unchanged.
    readonly property string here: screen ? screen.name : ""
    readonly property var rows: shell.windowRows || []
    readonly property var hider: shell.hider || null
    // The page this screen shows (for windows whose home is unknown).
    readonly property int shownPage: {
        for (const r of desktop.rows) if (r.screen === desktop.here && r.page > 0 && Lanes.isShown(r.toplevel)) return r.page;
        const p = typeof shell.shownPageOn === "function" ? shell.shownPageOn(desktop.here) : -1;
        return p > 0 ? p : 1;
    }
    readonly property var laneEntries: shell.windowRows !== undefined
        ? TaskModel.lane(desktop.rows, desktop.hider ? desktop.hider.state : null, desktop.here, {
            screens: Quickshell.screens.map(function (s) { return s.name; }), fallbackPage: desktop.shownPage })
        : shell.windowsOn(screen).map(function (t) { return { row: { toplevel: t, address: "", appId: desktop.appIdOf(t) }, home: Lanes.pageOf(t), minimized: false }; })
    readonly property var lane: laneEntries.map(function (e) { return e.row.toplevel; })
    readonly property int showingPage: {
        for (const t of desktop.lane) if (Lanes.isShown(t)) return Lanes.pageOf(t);
        return -1;
    }
    function entryOf(t) {
        const i = t ? desktop.lane.indexOf(t) : -1;
        return i >= 0 ? desktop.laneEntries[i] : null;
    }
    // A window's band: its page, or a minimized window's home page.
    function pageOf(t) { const e = desktop.entryOf(t); return e ? e.home : Lanes.pageOf(t); }
    function isMinimized(t) { const e = desktop.entryOf(t); return !!e && e.minimized; }
    function addressOf(t) { const e = desktop.entryOf(t); return e ? e.row.address : ""; }
    // What a menu row says beside a window: never its page (Simon: pages
    // are ephemeral, not places), only that it is minimized.
    function windowHint(t) { return desktop.isMinimized(t) ? "Minimized" : ""; }
    // An app's name, for naming pages by their apps (page-names.js). A
    // harness may supply names (appNames: app id -> name).
    property var appNames: ({})
    function appName(appId) {
        if (!appId) return "";
        if (desktop.appNames[appId]) return desktop.appNames[appId];
        DesktopEntries.applications.values;
        const e = DesktopEntries.heuristicLookup(appId);
        return e && e.name ? e.name : appId;
    }
    function appIdOf(t) {
        const wl = t ? t.wayland : null;
        return wl && wl.appId ? wl.appId : "";
    }
    // The Win98 icon for a window's app, or "" to use the icon theme.
    function winIcon(t) { return StartModel.appIcon(desktop.appIdOf(t), ""); }
    // Bring a window forward; a minimized one is restored (only it).
    function activateWindow(t) {
        if (desktop.isMinimized(t)) { desktop.restoreWindow(desktop.addressOf(t)); return; }
        const wl = t ? t.wayland : null;
        if (wl) wl.activate();
    }
    function closeWindow(t) {
        const wl = t ? t.wayland : null;
        if (wl) wl.close();
    }
    // A click on a window button: the active window minimizes (Win98), a
    // minimized one restores, any other comes forward.
    function clickWindow(t) {
        if (!t) return;
        if (desktop.isMinimized(t)) desktop.restoreWindow(desktop.addressOf(t));
        else if (t.activated) desktop.minimizeWindow(desktop.addressOf(t));
        else desktop.activateWindow(t);
    }
    function rowFor(address) {
        const k = AppModel.key(address);
        if (k === "") return null;
        for (const r of desktop.rows) if (r.address === k) return r;
        return null;
    }
    function minimizeWindow(address) { if (desktop.hider && address) desktop.hider.hideWindow(address); }
    function restoreWindow(address, after) {
        if (desktop.hider && address) desktop.hider.showWindow(address, desktop.shownPage, true, after || "");
    }
    // Win98 maximize is Hyprland's maximized fullscreen state (the usable
    // area, the taskbar stays); fullscreen state 2 covers everything.
    function fullscreenOf(r) {
        const o = r && r.toplevel ? r.toplevel.lastIpcObject || {} : {};
        return typeof o.fullscreen === "number" ? o.fullscreen : 0;
    }
    function focusThen(address, lua) {
        const k = AppModel.key(address);
        if (k === "") return;
        Quickshell.execDetached(["hyprctl", "--instance", "0", "--batch",
            'dispatch hl.dsp.focus({ window = "address:0x' + k + '" }) ; dispatch ' + lua]);
    }
    readonly property string maximizeLua: 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'
    readonly property string fullscreenLua: 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'

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

    // The Layout control (panels/PageLayout.qml): this screen's page. It
    // hides while the state file is unread or the screen shows no page.
    readonly property var layout: context.layout || null
    readonly property bool layoutShown: !!desktop.layout && desktop.layout.available
    // Its words, read only when asked (a tooltip, the chevron's menu): not
    // in trayData, whose every change rebuilds the taskbar's plan and with
    // it an open Start menu, and the state file is rewritten whenever a
    // page comes or goes.
    function layoutData() {
        const p = desktop.layout ? desktop.layout.page : null;
        return { layout: p ? { floating: p.floating, cap: p.cap, gap: p.gap, zen: p.zen } : { floating: false, cap: 1, gap: 0, zen: false } };
    }

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
            fleet: desktop.fleetTray,
            clock: { date: Qt.formatDateTime(c.now, "dddd, MMMM d, yyyy") }
        };
    }

    // The tray's icons, in order. A control hides only when its hardware or
    // service is missing; Start > Settings still opens those windows.
    readonly property var trayIds: {
        const c = context, out = [];
        if (desktop.layoutShown) out.push("layout");
        if (dictation.barVisible) out.push("dict");
        if (c.bluetooth.adapter !== null) out.push("bt");
        if (c.wifi.device !== null) out.push("wifi");
        if (c.sound.available) out.push("vol");
        if (c.brightness.available) out.push("bri");
        if (c.oci.enabled) out.push("oci");
        if (c.storage.enabled) out.push("disk");
        if (fleetGlance.present) out.push("fleet");
        if (gate.enabled) out.push("builder");
        out.push("ntf");
        if (desktop.battery.present) out.push("bat");
        return out;
    }

    function trayIcon(id) {
        const d = desktop.trayData;
        if (id === "layout") return Tray.layoutIcon(desktop.layout ? desktop.layout.glyph : "");
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
        return Tray.tooltip(id, id === "layout" ? desktop.layoutData() : desktop.trayData);
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
    // Recent Applications (Launcher records every launch) and the pinned web
    // apps (desktop entries webapp-<id>, modules/web-apps.nix), as
    // Platinum's Apple menu reads them. A harness may replace either.
    property var recent: Launcher.recent
    property var webApps: DesktopEntries.applications.values
        .filter(function (e) { return e && e.id && e.id.indexOf("webapp-") === 0; })
        .map(function (e) { return { id: e.id.slice(7), name: e.name, icon: e.icon, entry: e }; })
    readonly property var startModel: StartModel.top(
        StartModel.programs(desktop.apps),
        StartModel.windows(desktop.lane.map(function (t) {
            return { title: t.title, page: desktop.pageOf(t), hint: desktop.windowHint(t), icon: desktop.winIcon(t) || "doc" };
        })),
        StartModel.commands(desktop.commandRows),
        desktop.userName,
        taskbar.plan.structure === "start" ? desktop.overflowItems(false) : [],
        { favorites: StartModel.favorites(desktop.webApps), documents: StartModel.documents(desktop.recent), host: desktop.hostName })

    function runStart(item) {
        MenuState.close();
        if (!item) return;
        if (item.action === "app") { const a = desktop.apps[item.app]; if (a && a.entry) Launcher.launchEntry(a.entry); }
        else if (item.action === "webapp") desktop.launchWebApp(desktop.webApps[item.webapp]);
        else if (item.action === "recent") desktop.launchRecent(desktop.recent[item.recent]);
        else if (item.action === "window") desktop.activateWindow(desktop.lane[item.window]);
        else if (item.action === "command") context.omniBar.run(desktop.commandRows[item.row]);
        else if (item.action === "run") omniView.openScope("all");
        else if (item.action === "find") omniView.openScope(item.scope);
        else if (item.action === "picker") ThemePicker.open(desktop.screen);
        else if (item.action === "system") desktop.openMenu("sysprops", false);
        else if (item.action === "open") desktop.openMenu(item.control, false);
        else if (item.action === "restorefleet") fleetGlance.restore();
        else if (item.action === "logoff") desktop.openMenu("logoff", false);
        else if (item.action === "shutdown") desktop.openShutDown();
        else if (item.action === "lock") desktop.sessionLater("lock");
    }
    function logOff() {
        MenuState.close();
        desktop.runSession("logout");
    }

    // The omni service's Win98 view: the Find window and IE's Open dialog
    // (Win98OmniView.qml). Claimed while this Desktop is active.
    Win98OmniView { id: omniView; desktop: desktop }
    readonly property var omni: context.omniBar
    readonly property bool omniClaimed: omniView.claimed
    function findAction(kind, arg) { omniView.findAction(kind, arg); }

    // Launches go through Launcher, exactly as Platinum's do: a web app
    // from its desktop entry's command with web-app metadata (launchEntry
    // when it has none), a recent item from its recorded argv.
    function launchWebApp(app) {
        if (!app) return;
        const meta = { id: "webapp-" + app.id, name: app.name || app.id, icon: app.icon || "", kind: "webapp" };
        const argv = app.entry && app.entry.command ? Array.from(app.entry.command) : [];
        if (argv.length > 0) Launcher.launch(argv, meta);
        else if (app.entry) Launcher.launchEntry(app.entry);
    }
    function launchRecent(e) {
        if (!e) return;
        Launcher.launch(e.argv, { id: e.id, name: e.name, icon: e.icon || "", kind: e.kind });
    }

    //------------------------------------------------------------------
    // Session: Lock, Shut Down Myoko, Log Off
    //------------------------------------------------------------------
    // The same commands as Platinum's runSession. hypridle locks before
    // sleep. Short-lived system helpers, not apps, so not through Launcher;
    // each argv is a literal (launcher-model.test.js).
    function runSession(what) {
        switch (what) {
        case "lock": Quickshell.execDetached(["loginctl", "lock-session"]); break;
        case "sleep": Quickshell.execDetached(["systemctl", "suspend"]); break;
        case "logout": Quickshell.execDetached(["hyprctl", "--instance", "0", "dispatch", "hl.dsp.exit()"]); break;
        case "restart": Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "shutdown": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        }
    }
    // The Shut Down dialog opens on the last choice OK'd, as Win98's did;
    // the choice is kept in $XDG_STATE_HOME/mountainous/win98-shut-down.
    readonly property var shutChoices: Session.shutdownChoices(desktop.userName)
    property string shutChoice: "standby"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/mountainous"
    FileView {
        id: shutFile
        path: desktop.stateDir + "/win98-shut-down"
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
    }
    function openShutDown() {
        desktop.shutChoice = Session.initialChoice(shutFile.loaded ? shutFile.text() : "");
        desktop.openMenu("shutdown", true);
    }
    function confirmShutDown(id) {
        const c = desktop.shutChoices.find(function (x) { return x.id === id; });
        MenuState.close();
        if (!c) return;
        shutFile.setText(c.id + "\n");
        desktop.sessionLater(c.what);
    }
    // Session and menu actions run once the menu or dialog that chose them
    // is gone, from timers this Desktop owns: a theme swap that destroys
    // the Desktop cancels them (never Qt.callLater into a view that can go).
    Timer {
        id: sessionDispatch
        interval: 0
        property string pending: ""
        onTriggered: {
            const what = sessionDispatch.pending;
            sessionDispatch.pending = "";
            if (what !== "") desktop.runSession(what);
        }
    }
    function sessionLater(what) { sessionDispatch.pending = what; sessionDispatch.restart(); }
    Timer {
        id: menuDispatch
        interval: 0
        property var pending: null
        onTriggered: {
            const a = menuDispatch.pending;
            menuDispatch.pending = null;
            if (a) desktop.perform(a.act, a.page, a.address);
        }
    }

    //------------------------------------------------------------------
    // The window menu and the taskbar's own menu
    //------------------------------------------------------------------
    // The window menu's window and where a context menu opens, in this
    // screen's logical px: its top-left (it moves up to stay above the
    // taskbar, and left to stay on the screen).
    property string menuAddress: ""
    property var menuPoint: ({ x: 0, y: 0 })
    readonly property var menuRow: desktop.rowFor(desktop.menuAddress)
    readonly property var menuEntry: {
        const k = desktop.menuAddress;
        for (const e of desktop.laneEntries) if (e.row.address === k) return e;
        return null;
    }
    readonly property var windowMenuItems: {
        const r = desktop.menuRow;
        if (!r) return [];
        const e = desktop.menuEntry;
        const minimized = e ? e.minimized : !!(desktop.hider && desktop.hider.isHidden(r));
        const page = e ? e.home : r.page;
        return TaskModel.windowMenu({
            minimized: minimized,
            maximized: !minimized && desktop.fullscreenOf(r) > 0,
            move: PageNames.movePages(TaskModel.pageWindows(desktop.laneEntries, desktop.appName), r.address, page, desktop.shownPage,
                typeof shell.pageIds === "function" ? shell.pageIds() : [])
        });
    }
    // The windows IPC (shell.qml: a caption's icon, Alt+Space) and a
    // taskbar button's right click. x, y: this screen's logical px.
    function windowMenu(address, x, y) {
        const r = desktop.rowFor(address);
        if (!r || !desktop.active) return;
        desktop.menuAddress = r.address;
        desktop.menuPoint = { x: x, y: y };
        desktop.openMenu("winmenu", true);
    }
    function taskbarMenu(x, y) {
        if (!desktop.active) return;
        desktop.menuPoint = { x: x, y: y };
        desktop.openMenu("tbmenu", true);
    }
    readonly property string frontApp: {
        const w = context.frontWindow;
        const r = w ? desktop.rowFor(shell.addressOf ? shell.addressOf(w) : "") : null;
        return r ? r.appId : (w ? desktop.appIdOf(w) : "");
    }
    readonly property var taskbarMenuItems: {
        const shown = desktop.laneEntries.filter(function (e) { return !e.minimized; });
        const front = desktop.frontApp;
        return TaskModel.taskbarMenu({
            shown: shown.length,
            others: front === "" ? shown.length : shown.filter(function (e) { return e.row.appId !== front; }).length,
            hidden: desktop.hider ? desktop.hider.hiddenCount : 0
        });
    }
    // A chosen item runs on the next turn of the event loop, once the menu
    // that emitted it is gone (as Platinum's perform).
    function runMenu(item) {
        MenuState.close();
        if (!item || !item.act) return;
        menuDispatch.pending = { act: item.act, page: item.page || 0, address: desktop.menuAddress };
        menuDispatch.restart();
    }
    function perform(act, page, address) {
        const r = desktop.rowFor(address);
        const e = r ? desktop.laneEntries.find(function (x) { return x.row.address === r.address; }) : null;
        const minimized = e ? e.minimized : !!(r && desktop.hider && desktop.hider.isHidden(r));
        switch (act) {
        case "restore":
            if (!r) return;
            if (minimized) desktop.restoreWindow(r.address);
            else if (desktop.fullscreenOf(r) === 1) desktop.focusThen(r.address, desktop.maximizeLua);
            else if (desktop.fullscreenOf(r) > 1) desktop.focusThen(r.address, desktop.fullscreenLua);
            break;
        case "move":
            if (!r || !(page > 0)) return;
            if (minimized) { if (desktop.hider) desktop.hider.setHome(r.address, page); }
            else if (typeof shell.moveToPage === "function") shell.moveToPage(r.address, page);
            break;
        case "minimize": if (r) desktop.minimizeWindow(r.address); break;
        case "maximize":
            if (!r) return;
            if (minimized) desktop.restoreWindow(r.address, desktop.maximizeLua);
            else desktop.focusThen(r.address, desktop.maximizeLua);
            break;
        case "close": if (r && typeof shell.closeWindow === "function") shell.closeWindow(r.address); break;
        case "minimizeAll": if (desktop.hider) desktop.hider.hideScreen(desktop.here); break;
        case "minimizeOthers":
            if (!desktop.hider) return;
            if (desktop.frontApp !== "") desktop.hider.hideOthers(desktop.frontApp, desktop.here);
            else desktop.hider.hideScreen(desktop.here);
            break;
        case "restoreAll": if (desktop.hider) desktop.hider.showAll(desktop.shownPage); break;
        case "find": context.omniBar.enterRoot(); break;
        }
    }

    //------------------------------------------------------------------
    // Held Super+Tab: Win98's Cool Switch, over windows
    //------------------------------------------------------------------
    // shell.qml drops stale messages (AppModel.accept) and sends the rest
    // to the focused screen's Desktop. The quick press already focused the
    // last window; position 2 is the window after it. Super up commits.
    property var cycleState: null
    property int cyclePosition: 1
    readonly property string cycleTarget: cycleState ? AppModel.cycleTarget(cycleState, cyclePosition) : ""
    function cycle(action, position) {
        if (action === "cancel") { desktop.cycleState = null; return; }
        if (!desktop.cycleState) {
            if (action === "commit" && position <= 1) return;
            desktop.cycleState = AppModel.windowCycleStart(desktop.rows, shell.mru || []);
            MenuState.close();
        }
        desktop.cyclePosition = position;
        if (action !== "commit") return;
        const target = desktop.cycleTarget;
        desktop.cycleState = null;
        console.debug("[win98] window cycle commit " + target);
        if (target !== "") desktop.activateAddress(target);
    }
    // A window by address: a hidden one is restored (alone), any other
    // comes forward through the shell.
    function activateAddress(address) {
        const r = desktop.rowFor(address);
        if (!r) return;
        if (desktop.hider && desktop.hider.isHidden(r)) desktop.restoreWindow(r.address);
        else if (typeof shell.activate === "function") shell.activate(r.address);
    }

    //------------------------------------------------------------------
    // The volume and brightness pop-up
    //------------------------------------------------------------------
    // A change shows the value above its tray icon for 1.5 s, Platinum's
    // tag rules: none for the values the owners load at start (each value
    // arms 2 s after its owner has one, and again when the output device
    // changes), and none while a menu or window is open on this screen
    // (it shows the value). The harness's state sheets disarm it too.
    property string popupId: ""
    property bool volArmed: false
    property bool briArmed: false
    readonly property bool volPresent: context.sound.available === true
    readonly property bool briPresent: context.brightness.available === true
    readonly property int volLevel: context.sound.volumePercent
    readonly property bool volMuted: context.sound.muted === true
    readonly property var volSink: context.sound.defaultSink
    readonly property int briLevel: Math.max(0, Math.min(100, context.brightness.shownLevel))
    Timer { id: volArm; interval: 2000; running: true; onTriggered: desktop.volArmed = desktop.volPresent }
    Timer { id: briArm; interval: 2000; running: true; onTriggered: desktop.briArmed = desktop.briPresent }
    Timer { id: popupTimer; interval: 1500; onTriggered: desktop.popupId = "" }
    function disarm(which) {
        if (which !== "bri") { desktop.volArmed = false; volArm.restart(); }
        if (which !== "vol") { desktop.briArmed = false; briArm.restart(); }
        desktop.popupId = "";
    }
    onVolPresentChanged: disarm("vol")
    onVolSinkChanged: disarm("vol")
    onBriPresentChanged: disarm("bri")
    onPreviewChanged: disarm("")
    function showPopup(id) {
        if (!desktop.active || !shell.chromeVisible || desktop.openId !== "") return;
        if (id === "vol" ? !(desktop.volArmed && desktop.volPresent) : !(desktop.briArmed && desktop.briPresent)) return;
        desktop.tipId = "";
        desktop.popupId = id;
        popupTimer.restart();
    }
    onVolLevelChanged: showPopup("vol")
    onVolMutedChanged: showPopup("vol")
    onBriLevelChanged: showPopup("bri")
    onOpenIdChanged: if (openId !== "") { popupId = ""; popupTimer.stop(); }

    // The open menu or window's root item, and the other surfaces' boxes,
    // for checks.
    readonly property var openItem: menuHost.openItem
    readonly property var shutDownItem: shutDownScreen.dialog
    readonly property var coolSwitchItem: coolSwitch.box
    readonly property var popupItem: volumePopup.box
    readonly property var taskbarItem: taskbar.contentItem

    // For the harness and checks: the taskbar's plan and where things are.
    function taskbarPlan() { return taskbar.plan; }
    function debugPlaces() {
        const out = {};
        for (const id in taskbar.places) {
            const p = taskbar.placeOf(id);
            if (p) out[id] = p;
        }
        out.tasksArea = taskbar.tasksArea;
        out.dividers = taskbar.dividers();
        out.focusOrder = menuHost.focusOrder;
        out.barHeight = taskbar.barHeight;
        out.width = taskbar.width;
        out.height = taskbar.height;
        out.implicitHeight = taskbar.implicitHeight;
        out.dpr = taskbar.devicePixelRatio;
        out.faceY = taskbar.faceY;
        return out;
    }

    //------------------------------------------------------------------
    // Fleet: the tray's Fleet icon, the Fleet window and the glance space
    // (the same semantics as the Platinum Desktop's)
    //------------------------------------------------------------------
    readonly property bool fleetShown: fleetGlance.shown
    readonly property bool fleetDetailShown: fleetGlance.detailShown
    function toggleFleet() { fleetGlance.toggleFleet(); }
    function toggleGlance() { fleetGlance.toggleGlance(); }
    function showGlance() { fleetGlance.showGlance(); }
    function hideGlance() { fleetGlance.hideGlance(); }
    function restoreFleet() { fleetGlance.restore(); }
    readonly property var fleetGlance: fleetViews

    readonly property var beszel: fleetViews.beszel
    readonly property var fleetLook: beszel ? HostIcon.fleetLook(beszel.fleet, beszel.stale) : ({ status: "down", tone: "muted" })
    readonly property string fleetButtonText: fleetViews.buttonText
    readonly property var fleetTray: {
        const b = desktop.beszel;
        if (!b) return { summary: "Fleet", short: "", stale: false, age: "" };
        const f = b.fleet, n = f.problems.length;
        return {
            summary: FleetModel.summaryVariants(f, true, "Fleet: ")[0],
            short: f.state === "ready" ? (n ? n + (n === 1 ? " problem" : " problems") : "ok") : f.state === "loading" ? "..." : "--",
            stale: b.stale,
            age: "Last update " + FleetModel.ago(b.now - b.sampledAt)
        };
    }
    // The taskbar's extra buttons (taskbar-plan.js extras).
    readonly property var taskExtras: {
        const out = [];
        if (fleetViews.windowShown && fleetViews.minimized) out.push({ id: "fleet", label: fleetViews.buttonText });
        if (fleetViews.glanceShown) out.push({ id: "glance", label: "Glance", bold: true });
        return out;
    }
    // The Glance menu (the Glance button) and the Fleet icon's menu.
    readonly property var glanceMenu: [
        { text: "&Hide Glance", bold: true, shortcut: "Win+W", act: "hide" },
        { text: "&Arrange Accessories", act: "arrange", enabled: GlanceState.hasPlaces },
        { separator: true },
        { text: "Desk accessories", enabled: false }
    ].concat(GlanceRegistry.ids().map(function (id) {
        return { text: GlanceRegistry.label(id), act: "toggle", arg: id, checked: GlanceState.enabled(id) };
    }))
    readonly property var fleetMenu: [
        { text: fleetViews.windowShown && !fleetViews.minimized ? "&Close Fleet" : "&Open Fleet", bold: true, shortcut: "Win+B", act: "fleet" },
        { text: fleetViews.glanceShown ? "Hide &Glance" : "Show &Glance", shortcut: "Win+W", act: "glance" }
    ]
    function runFleetMenu(item) {
        MenuState.close();
        if (!item) return;
        if (item.act === "hide") fleetViews.hideGlance();
        else if (item.act === "arrange") GlanceState.cleanUp();
        else if (item.act === "toggle") GlanceState.setEnabled(item.arg, !GlanceState.enabled(item.arg));
        else if (item.act === "fleet") fleetViews.toggleFleet();
        else if (item.act === "glance") fleetViews.toggleGlance();
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
        id: menuHost
        desktop: desktop
        taskbar: taskbar
        enabled: desktop.active && desktop.shell.chromeVisible
    }

    Win98TipWindow {
        desktop: desktop
        taskbar: taskbar
    }

    // Shut Down Myoko over the whole screen's checker, the taskbar too.
    Win98ShutDownScreen {
        id: shutDownScreen
        desktop: desktop
    }

    // Held Super+Tab.
    Win98CoolSwitch {
        id: coolSwitch
        desktop: desktop
        taskbar: taskbar
    }

    // A volume or brightness change.
    Win98VolumePopup {
        id: volumePopup
        desktop: desktop
        taskbar: taskbar
    }

    // Win98's caption animation for windows: minimize, restore, maximize.
    readonly property var motionLayer: motionLayerItem
    Win98MotionLayer {
        id: motionLayerItem
        desktop: desktop
        taskbar: taskbar
    }

    Win98FleetGlance {
        id: fleetViews
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
