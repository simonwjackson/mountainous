pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import Quickshell.Io
import QtQuick

// Test-only scene: every Memphis control in every state, one page at a time,
// for screenshots (dev/capture.sh) and the keyboard checks. The shell never
// loads it. Pages: text, controls, fields, frames, menus, lists, icons,
// stress, scenes. The appearance follows Theme.dark like everything else.
//
// The font: W95FA Grid from $MEMPHIS_FONT (the Nix package replaces this).
Scope {
    id: gallery

    property string page: "controls"
    readonly property real u: Kit.MemphisTokens.unitFor(win)

    FontLoader {
        source: "file://" + (Quickshell.env("MEMPHIS_FONT") || "/tmp/memphis-mock/fonts/W95FAGrid.ttf")
    }

    IpcHandler {
        target: "memphisgallery"
        function page(name: string): string { gallery.page = name; return name; }
        function ready(): string { return gallery.page + " dpr=" + (2 / gallery.u) + " dark=" + Kit.MemphisTokens.dark; }
        function motion(reduced: bool): string { Kit.MemphisTokens.reducedMotion = reduced; return String(Kit.MemphisTokens.reducedMotion); }
        // The live test menu (page "keys"): send a key, read the state back.
        function key(name: string): string { return gallery.menuKey(name); }
        function menu(): string { return gallery.menuState(); }
        // Send a key and report, in the same turn, how far the roll-out of
        // the level it opened has run (0 = it starts; 1 = no roll-out).
        function keyReveal(name: string): string {
            gallery.menuKey(name);
            const m = gallery.testMenu;
            const p = m ? m.panelAt(m.path.length) : null;
            return p ? String(p.reveal) : "none";
        }
        // How far the roll-out of an open level has run, 0..1, right now.
        function reveal(level: int): string { const p = gallery.testMenu ? gallery.testMenu.panelAt(level) : null; return p ? String(p.reveal) : "none"; }
        // A label with an access key, as MemphisText draws it (access.sh).
        function access(label: string, bold: bool): string {
            accessProbe.bold = bold;
            accessProbe.text = label;
            return JSON.stringify({ plain: accessProbe.plain, drawn: accessProbe.drawnText, index: accessProbe.accessIndex,
                x: accessProbe.accessX, w: accessProbe.accessWidth, drawnWidth: accessProbe.drawnWidth, u: accessProbe.u,
                prefix: Kit.MemphisTokens.textWidth(accessProbe.plain.slice(0, accessProbe.accessIndex), bold, accessProbe.u),
                prefixTrimmed: Kit.MemphisTokens.textWidth(accessProbe.plain.slice(0, accessProbe.accessIndex).replace(/ +$/, ""), bold, accessProbe.u),
                whole: Kit.MemphisTokens.textWidth(accessProbe.plain, bold, accessProbe.u),
                squeezed: Kit.MemphisTokens.textWidth(accessProbe.plain.replace(/ /g, ""), bold, accessProbe.u) });
        }
        function resetMenu(): string { gallery.triggeredText = ""; gallery.closedCount = 0; if (gallery.testMenu) gallery.testMenu.reset(); return gallery.menuState(); }
    }

    property MemphisMenu testMenu: null
    property string triggeredText: ""
    property int closedCount: 0

    function menuKey(name) {
        if (!testMenu) return "no menu";
        const keys = { Down: Qt.Key_Down, Up: Qt.Key_Up, Left: Qt.Key_Left, Right: Qt.Key_Right, Enter: Qt.Key_Return, Esc: Qt.Key_Escape };
        const used = keys[name] !== undefined ? testMenu.handleKey(keys[name], "") : testMenu.handleKey(0, name);
        return (used ? "used " : "ignored ") + menuState();
    }
    function menuState() {
        if (!testMenu) return "no menu";
        // Names, not indices: path=Programs/Internet cursor=Signal.
        const names = [];
        let items = testMenu.model;
        for (const i of testMenu.path) { names.push(Kit.MemphisTokens.plainText(items[i].text)); items = items[i].submenu; }
        const cur = testMenu.cursor >= 0 && items[testMenu.cursor] ? Kit.MemphisTokens.plainText(items[testMenu.cursor].text) : "-";
        return "path=" + names.join("/") + " cursor=" + cur + " triggered=" + (triggeredText || "-") + " closed=" + closedCount;
    }

    // ---- fixtures (the mock's data.js)
    readonly property var outputs: [
        { name: "Built-in Speakers", vol: 0.42, muted: false, def: true },
        { name: "Galaxy Buds2 Pro", vol: 0.60, muted: false, def: false },
        { name: "U2723QE (HDMI 1)", vol: 0.35, muted: true, def: false }
    ]
    readonly property var programs: [
        { text: "Accessories", icon: "folder", submenu: [{ text: "GVim", icon: "doc" }, { text: "Vim", icon: "doc" }] },
        { text: "Development", icon: "folder", submenu: [{ text: "Zed", icon: "zed" }] },
        { text: "Internet", icon: "folder", submenu: [
            { text: "Chromium", icon: "chromium" }, { text: "Firefox", icon: "firefox" }, { text: "Signal", icon: "signal" },
            { text: "Sunshine", icon: "sun" }, { text: "Syncthing", icon: "sync" }, { text: "Transmission", icon: "tx" }] },
        { text: "Multimedia", icon: "folder", submenu: [{ text: "OBS Studio", icon: "obs" }] },
        { text: "System", icon: "folder", submenu: [{ text: "Ghostty", icon: "term" }, { text: "Htop", icon: "term" }, { text: "NixOS Manual", icon: "doc" }] }
    ]
    readonly property var commands: [
        { text: "New terminal", shortcut: "Super+N" }, { text: "Go to address...", shortcut: "Ctrl+L" },
        { text: "Close window", shortcut: "Super+C" }, { text: "Monocle", shortcut: "Super+M", checked: true },
        { text: "Zen", shortcut: "Super+Shift+M" }, { text: "Mirror workspace", shortcut: "Super+Shift+G", enabled: false },
        { text: "Even / golden split", shortcut: "Super+G" }, { text: "Screenshot", shortcut: "Super+S" },
        { separator: true },
        { text: "Interface scale", icon: "scale", submenu: [{ text: "Scale up", shortcut: "Super+=" }, { text: "Scale down", shortcut: "Super+-" }, { text: "Scale 100%", shortcut: "Super+0" }] },
        { text: "Toggle bars", shortcut: "Super+I" }
    ]
    readonly property var startMenu: [
        { text: "&Programs", icon: "programs", submenu: programs },
        { text: "&Windows", icon: "windows", submenu: [
            { text: "simon@myoko: ~/code/github/simonwjackson/mou...", icon: "term", shortcut: "Page 1" },
            { text: "Memphis - Wikipedia - Chromium", icon: "chromium", shortcut: "Page 1" },
            { text: "Signal", icon: "signal", shortcut: "Page 2" }] },
        { text: "&Commands", icon: "commands", submenu: commands },
        { text: "&Settings", icon: "settings", submenu: [
            { text: "&Display...", icon: "display" }, { separator: true }, { text: "&Bluetooth", icon: "bluetooth-on" },
            { text: "&Wi-Fi", icon: "wifi-4" }, { text: "&Sound", icon: "volume-1" }, { text: "Brigh&tness", icon: "brightness" }] },
        { separator: true },
        { text: "&Run...", icon: "run" },
        { separator: true },
        { text: "&Log Off simon...", icon: "logoff" }
    ]
    readonly property var manyApps: ["Audacity", "Baobab", "Blender", "Bottles", "Calculator", "Celluloid", "Characters", "Cheese", "Chromium", "Clocks",
        "Contacts", "D-Spy", "Darktable", "dconf Editor", "Disks", "Document Scanner", "Element", "Evince", "Eye of GNOME", "Files", "Firefox", "Fonts",
        "Geary", "Ghostty", "GIMP", "Gnumeric", "GVim", "Heroic", "Htop", "Inkscape", "Kdenlive", "KeePassXC", "Krita", "LibreOffice Calc",
        "LibreOffice Impress", "LibreOffice Writer", "Logs", "Lutris", "Maps", "Meld", "Moonlight", "mpv", "Nautilus", "NixOS Manual", "OBS Studio"]
    readonly property string longWord: "nixos-rebuild-switch--flake-github:simonwjackson/mountainous#myoko--show-trace--keep-going"

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: Kit.MemphisTokens.desktop



        // Measured by the access IPC; never shown.
        MemphisText { id: accessProbe; visible: false }

        Loader {
            id: pageLoader
            width: win.width; height: win.height
            sourceComponent: ({
                text: textPage, controls: controlsPage, fields: fieldsPage, frames: framesPage, menus: menusPage,
                lists: listsPage, icons: iconsPage, stress: stressPage, scenes: scenesPage, keys: keysPage
            })[gallery.page] || controlsPage
        }
    }

    // ---- gallery furniture
    // A labelled specimen. The label is grey on the face colour.
    component Spec: Column {
        property string label: ""
        spacing: 4 * gallery.u
        MemphisText { text: parent.label; accessMarks: false; color: Kit.MemphisTokens.gray }
    }
    component Heading: MemphisText { accessMarks: false; bold: true }
    component Page: Rectangle { color: Kit.MemphisTokens.face }

    // ================================================================ text
    // The mock's shots/w95fa-grid-proof.png, rebuilt: regular, drawn bold,
    // a caption and the 2x side band. Its pixels must be exactly the four
    // colours #C0C0C0, #000080, #000000, #FFFFFF in light.
    Component {
        id: textPage
        Page {
            Column {
                x: 6 * gallery.u; y: 4 * gallery.u
                spacing: 4 * gallery.u
                MemphisText { text: "Regular: Start  Built-in Speakers 42% 4:51 PM  a...b a\u2026b \u2190\u2192\u2191\u2193 \u00d7 \u00b7 \u2013 \u2014"; accessMarks: false }
                MemphisText { text: "Bold: Start   Display Properties   simon@myoko"; accessMarks: false; bold: true }
                Rectangle {
                    width: 800 * gallery.u; height: 60 * gallery.u
                    color: Kit.MemphisTokens.caption1
                    Column {
                        x: 6 * gallery.u; y: 4 * gallery.u
                        spacing: 4 * gallery.u
                        MemphisText { text: "Caption: Remote builds"; accessMarks: false; bold: true; color: "#ffffff" }
                        MemphisText { text: "Kamoi Myoko"; accessMarks: false; size: 2; color: "#ffffff" }
                    }
                }
                MemphisText { text: "Access keys: &Programs  &Windows  Brigh&tness  Log &Off  Tom && Jerry" }
                MemphisText { text: "Disabled: &Apply  Mirror workspace"; disabledLook: true }
                Row {
                    spacing: 8 * gallery.u
                    MemphisText { text: "Elided at 120 u: " + gallery.longWord; accessMarks: false; width: 120 * gallery.u }
                    MemphisText { text: "Two lines at 180 u: the hint wraps by word and keeps its keys"; accessMarks: false; wrap: true; width: 180 * gallery.u }
                }
                Rectangle {
                    width: 200 * gallery.u; height: 30 * gallery.u
                    color: Kit.MemphisTokens.win
                    MemphisText { x: 4 * gallery.u; y: 4 * gallery.u; text: "Window text on the field colour"; accessMarks: false; color: Kit.MemphisTokens.winText }
                }
                Rectangle {
                    width: 200 * gallery.u; height: 17 * gallery.u
                    color: Kit.MemphisTokens.selection
                    MemphisText { x: 4 * gallery.u; y: 2 * gallery.u; text: "Selected text"; accessMarks: false; color: Kit.MemphisTokens.selectionText }
                }
            }
        }
    }

    // ================================================================ controls
    Component {
        id: controlsPage
        Page {
            Flow {
                x: 8 * gallery.u; y: 8 * gallery.u
                width: parent.width - 16 * gallery.u
                spacing: 14 * gallery.u

                Spec {
                    label: "Push buttons: default, normal, disabled, pressed, focus, default with focus"
                    Row {
                        spacing: 6 * gallery.u
                        MemphisButton { text: "OK"; isDefault: true }
                        MemphisButton { text: "Cancel" }
                        MemphisButton { text: "&Apply"; enabled: false }
                        MemphisButton { text: "Pressed"; showPressed: true }
                        MemphisButton { text: "&Focus"; showFocus: true }
                        MemphisButton { text: "&Yes"; isDefault: true; showFocus: true }
                    }
                }
                Spec {
                    label: "Small; one role, one width; icon"
                    Row {
                        spacing: 6 * gallery.u
                        MemphisButton { text: "&Retry"; small: true }
                        MemphisButton { text: "&Dismiss"; small: true; enabled: false }
                        MemphisButton { text: "Pair"; small: true; roleLabels: ["Connect", "Disconnect", "Pair", "Cancel"] }
                        MemphisButton { text: "Disconnect"; small: true; roleLabels: ["Connect", "Disconnect", "Pair", "Cancel"] }
                        MemphisButton { text: "&Check now"; iconName: "host"; small: true }
                    }
                }
                Spec {
                    label: "Toolbar buttons (22 u): rest, hover, pressed, open, latched, focus, disabled"
                    Row {
                        spacing: 6 * gallery.u
                        MemphisToolButton { iconName: "display" }
                        MemphisToolButton { iconName: "display"; showHover: true }
                        MemphisToolButton { iconName: "display"; showPressed: true }
                        MemphisToolButton { iconName: "display"; open: true }
                        MemphisToolButton { iconName: "display"; checked: true }
                        MemphisToolButton { iconName: "display"; showFocus: true }
                        MemphisToolButton { iconName: "display"; enabled: false }
                        MemphisToolButton { iconName: "folder"; text: "Programs"; showHover: true }
                    }
                }
                Spec {
                    label: "Tray buttons (20 u) with badges: hover, open, latched builder, focus"
                    Row {
                        spacing: 6 * gallery.u
                        MemphisToolButton { tray: true; iconName: "volume-1" }
                        MemphisToolButton { tray: true; iconName: "volume-1"; showHover: true }
                        MemphisToolButton { tray: true; iconName: "volume-1"; open: true }
                        MemphisToolButton { tray: true; iconName: "builder"; checked: true }
                        MemphisToolButton { tray: true; iconName: "wifi-3"; showFocus: true }
                        MemphisToolButton { tray: true; iconName: "bell"; badge: "3" }
                        MemphisToolButton { tray: true; iconName: "bell"; badge: "99+"; width: 32 * gallery.u }
                        MemphisToolButton { tray: true; iconName: "disk-warn"; badge: "2" }
                        MemphisToolButton { tray: true; iconName: "battery-bolt" }
                    }
                }
                Spec {
                    label: "Check boxes: off, on, pressed, disabled off, disabled on, focus"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisCheckBox { text: "&Mute" }
                        MemphisCheckBox { text: "&Mute"; checked: true }
                        MemphisCheckBox { text: "Pressed"; showPressed: true }
                        MemphisCheckBox { text: "Bluetooth &on"; enabled: false }
                        MemphisCheckBox { text: "Wi-Fi &on"; enabled: false; checked: true }
                        MemphisCheckBox { text: "Accep&t builds"; checked: true; showFocus: true }
                    }
                }
                Spec {
                    label: "Option buttons: off, on, pressed, disabled off, disabled on, focus"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisRadioButton { text: "Windows Standard" }
                        MemphisRadioButton { text: "Dark grey"; checked: true }
                        MemphisRadioButton { text: "Pressed"; showPressed: true }
                        MemphisRadioButton { text: "Off"; enabled: false }
                        MemphisRadioButton { text: "On"; enabled: false; checked: true }
                        MemphisRadioButton { text: "&Focus"; checked: true; showFocus: true }
                    }
                }
                Spec {
                    label: "Trackbars, horizontal: 0, 60, 100, focus, disabled"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisSlider { width: 120 * gallery.u; value: 0 }
                        MemphisSlider { width: 120 * gallery.u; value: 0.6 }
                        MemphisSlider { width: 120 * gallery.u; value: 1 }
                        MemphisSlider { width: 120 * gallery.u; value: 0.42; showFocus: true }
                        MemphisSlider { width: 120 * gallery.u; value: 0.42; enabled: false }
                    }
                }
                Spec {
                    label: "Vertical: 42, 100, focus, disabled"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisSlider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42 }
                        MemphisSlider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 1 }
                        MemphisSlider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42; showFocus: true }
                        MemphisSlider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42; enabled: false }
                    }
                }
                Spec {
                    label: "Scroll bars: top, middle, end, arrow pressed, thumb only room, nothing to scroll"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisScrollBar { height: 100 * gallery.u; size: 0.4; position: 0 }
                        MemphisScrollBar { height: 100 * gallery.u; size: 0.4; position: 0.5 }
                        MemphisScrollBar { height: 100 * gallery.u; size: 0.4; position: 1 }
                        MemphisScrollBar { height: 100 * gallery.u; size: 0.2; position: 0; showPressed: "back" }
                        MemphisScrollBar { height: 100 * gallery.u; size: 0.01; position: 0.3 }
                        MemphisScrollBar { height: 100 * gallery.u; size: 1 }
                        Column {
                            spacing: 6 * gallery.u
                            MemphisScrollBar { orientation: Qt.Horizontal; width: 200 * gallery.u; size: 0.3; position: 0.2 }
                            MemphisScrollBar { orientation: Qt.Horizontal; width: 200 * gallery.u; size: 0.3; position: 1; showPressed: "forward" }
                            MemphisScrollBar { orientation: Qt.Horizontal; width: 200 * gallery.u; size: 1 }
                        }
                    }
                }
                Spec {
                    label: "Level bars: 0, 42, 100, muted 35, on a selected row"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisLevelBar { width: 80 * gallery.u; value: 0 }
                        MemphisLevelBar { width: 80 * gallery.u; value: 0.42 }
                        MemphisLevelBar { width: 80 * gallery.u; value: 1 }
                        MemphisLevelBar { width: 80 * gallery.u; value: 0.35; muted: true }
                        Rectangle {
                            width: 90 * gallery.u; height: 10 * gallery.u
                            color: Kit.MemphisTokens.selection
                            MemphisLevelBar { x: 5 * gallery.u; y: 3 * gallery.u; width: 80 * gallery.u; value: 0.42; onSelection: true }
                        }
                    }
                }
                Spec {
                    label: "Tooltips: one line, several lines"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisToolTip { text: "Click here to begin." }
                        MemphisToolTip { text: "Volume 42%\nBuilt-in Speakers" }
                        MemphisToolTip { text: "OCI egress this month\nfuji 12% (1270 GB)\nyari 3% (307 GB)" }
                    }
                }
            }
        }
    }

    // ================================================================ fields
    Component {
        id: fieldsPage
        Page {
            Flow {
                x: 8 * gallery.u; y: 8 * gallery.u
                width: parent.width - 16 * gallery.u
                spacing: 14 * gallery.u

                Spec {
                    label: "Text fields: empty with caret, text, placeholder, selection, disabled, password"
                    Row {
                        spacing: 8 * gallery.u
                        MemphisTextField { width: 120 * gallery.u; showCaret: true }
                        MemphisTextField { width: 120 * gallery.u; text: "NETGEAR42" }
                        MemphisTextField { width: 120 * gallery.u; placeholder: "Search programs" }
                        MemphisTextField { id: sel; width: 120 * gallery.u; text: "kamoi-5g"; Component.onCompleted: sel.input.select(0, 5) }
                        MemphisTextField { width: 120 * gallery.u; text: "eduroam"; enabled: false }
                        MemphisTextField { width: 120 * gallery.u; text: "secret"; echoMode: TextInput.Password; showCaret: true }
                    }
                }
                Spec {
                    label: "Drop-down lists: closed, focused, disabled, open"
                    Row {
                        spacing: 8 * gallery.u
                        MemphisComboBox { width: 160 * gallery.u; model: ["Memphis", "Mac OS 8 Platinum"] }
                        MemphisComboBox { width: 160 * gallery.u; model: ["Windows Standard", "Dark grey"]; currentIndex: 1; showFocus: true }
                        MemphisComboBox { width: 160 * gallery.u; model: ["Windows Standard", "Dark grey"]; enabled: false }
                        MemphisComboBox { id: openCombo; width: 160 * gallery.u; model: ["Windows Standard", "Dark grey"]; currentIndex: 1; showFocus: true; Component.onCompleted: openCombo.open = true }
                    }
                }
                Item { width: parent.width; height: 40 * gallery.u }
                Spec {
                    label: "Group boxes"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisGroupBox {
                            title: "Volume"
                            width: 140 * gallery.u
                            Column {
                                spacing: 5 * gallery.u
                                MemphisCheckBox { text: "&Mute" }
                                MemphisCheckBox { text: "Show in the &tray"; checked: true }
                            }
                        }
                        MemphisGroupBox {
                            title: "Devices (scanning)"
                            width: 200 * gallery.u
                            height: 60 * gallery.u
                            MemphisText { text: "Looking for devices..."; accessMarks: false; color: Kit.MemphisTokens.gray }
                        }
                        MemphisGroupBox {
                            title: "A group title longer than its box"
                            width: 120 * gallery.u
                            height: 40 * gallery.u
                        }
                    }
                }
                Spec {
                    label: "Status bars: one pane; two panes; a long hint wraps to two lines"
                    Column {
                        spacing: 6 * gallery.u
                        MemphisStatusBar { width: 330 * gallery.u; panes: ["Esc or click outside to close"] }
                        MemphisStatusBar { width: 330 * gallery.u; panes: ["1 device connected", "\u2191\u2193 select \u00b7 Enter action \u00b7 S scan"] }
                        MemphisStatusBar { width: 330 * gallery.u; panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 volume \u00b7 Enter default \u00b7 M mute \u00b7 Tab inputs \u00b7 Shift+Del forget"] }
                    }
                }
                Spec {
                    label: "Property sheet tabs: first, second, focus"
                    Row {
                        spacing: 10 * gallery.u
                        MemphisTabs {
                            width: 200 * gallery.u; height: 70 * gallery.u
                            tabs: ["&Outputs 3", "&Inputs 2"]
                            MemphisText { text: "Outputs"; accessMarks: false }
                        }
                        MemphisTabs {
                            width: 200 * gallery.u; height: 70 * gallery.u
                            tabs: ["&Outputs 3", "&Inputs 2"]; currentIndex: 1
                            MemphisText { text: "Inputs"; accessMarks: false }
                        }
                        MemphisTabs {
                            width: 200 * gallery.u; height: 70 * gallery.u
                            tabs: ["Appearance", "Scale", "Fonts"]; showFocus: true
                            MemphisText { text: "Focus on the tab row"; accessMarks: false }
                        }
                    }
                }
            }
        }
    }

    // ================================================================ frames
    Component {
        id: framesPage
        Item {
            Flow {
                x: 8 * gallery.u; y: 8 * gallery.u
                width: parent.width - 16 * gallery.u
                spacing: 14 * gallery.u

                MemphisWindow {
                    title: "Sound"; iconName: "volume-1"
                    width: 220 * gallery.u; height: 80 * gallery.u
                    MemphisText { text: "Active, with close"; accessMarks: false }
                }
                MemphisWindow {
                    title: "Sound"; iconName: "volume-1"; active: false
                    width: 220 * gallery.u; height: 80 * gallery.u
                    MemphisText { text: "Inactive"; accessMarks: false }
                }
                MemphisWindow {
                    title: "Display Properties"; showHelp: true
                    width: 260 * gallery.u; height: 80 * gallery.u
                    MemphisText { text: "Help and close, no icon"; accessMarks: false }
                }
                MemphisWindow {
                    title: "Display Properties"; showHelp: true; showPressed: "close"
                    width: 260 * gallery.u; height: 80 * gallery.u
                    MemphisText { text: "Close pressed"; accessMarks: false }
                }
                MemphisWindow {
                    title: "OCI egress \u00b7 this month, every profile, projected"; iconName: "oci-normal"
                    width: 180 * gallery.u; height: 80 * gallery.u
                    MemphisText { text: "Long title elides"; accessMarks: false }
                }
                MemphisWindow {
                    title: "Log Off Myoko"
                    width: 300 * gallery.u
                    Column {
                        spacing: 8 * gallery.u
                        Row {
                            spacing: 12 * gallery.u
                            MemphisIcon { name: "logoff" }
                            MemphisText { y: 5.5 * gallery.u; text: "Are you sure you want to log off?"; accessMarks: false }
                        }
                        Row {
                            x: Kit.MemphisTokens.snap((276 * gallery.u - width) / 2, gallery.u)
                            spacing: 6 * gallery.u
                            MemphisButton { text: "&Yes"; isDefault: true; showFocus: true }
                            MemphisButton { text: "&No" }
                        }
                    }
                }
                MemphisWindow {
                    title: "Remote builds"; iconName: "builder"
                    width: 360 * gallery.u
                    Column {
                        spacing: 6 * gallery.u
                        width: 344 * gallery.u
                        Row {
                            spacing: 8 * gallery.u
                            MemphisIcon { name: "ok"; y: gallery.u }
                            Column {
                                spacing: 3 * gallery.u
                                MemphisText { text: "Accepting remote builds"; accessMarks: false; bold: true }
                                MemphisText { text: "At home on AC power."; accessMarks: false }
                            }
                        }
                        MemphisSeparator { width: parent.width }
                        Item {
                            width: parent.width; height: 13 * gallery.u
                            MemphisCheckBox { text: "Accep&t builds"; checked: true; showFocus: true }
                            MemphisText { x: parent.width - width; text: "T"; accessMarks: false; color: Kit.MemphisTokens.gray }
                        }
                        Item {
                            width: parent.width; height: 21 * gallery.u
                            MemphisButton { text: "Use &default (on)"; small: true; widthUnits: 150 }
                            MemphisText { x: parent.width - width; y: 4 * gallery.u; text: "D"; accessMarks: false; color: Kit.MemphisTokens.gray }
                        }
                        Item {
                            width: parent.width; height: 21 * gallery.u
                            MemphisButton { text: "Stop builds"; small: true; widthUnits: 150; enabled: false }
                            MemphisText { x: parent.width - width; y: 4 * gallery.u; text: "X"; accessMarks: false; color: Kit.MemphisTokens.gray }
                        }
                        MemphisStatusBar { width: parent.width; panes: ["Tab move \u00b7 Enter choose \u00b7 Esc close"] }
                    }
                }
                MemphisWindow {
                    title: "Brightness"; iconName: "brightness"
                    width: 310 * gallery.u
                    Column {
                        spacing: 6 * gallery.u
                        width: 294 * gallery.u
                        Row {
                            spacing: 6 * gallery.u
                            MemphisIcon { name: "brightness"; opacity: 0.6; y: 2 * gallery.u }
                            MemphisSlider { width: 200 * gallery.u; value: (60 - 5) / 95; showFocus: true }
                            MemphisText { text: "60%"; accessMarks: false; y: 2 * gallery.u }
                        }
                        MemphisStatusBar { width: parent.width; panes: ["\u2190\u2192 brightness \u00b7 Esc close"] }
                    }
                }
            }
        }
    }

    // ================================================================ menus
    Component {
        id: menusPage
        Item {
            id: menus
            // The Start menu, Programs > Internet open by the keyboard, Signal
            // selected; its bottom on the taskbar line, as the shell shows it.
            MemphisMenu {
                id: start
                x: 2 * gallery.u
                y: 300 * gallery.u
                model: gallery.startMenu
                big: true
                widthUnits: 196
                bandText: "Kamoi"
                bandSubText: "Myoko"
                animate: false
                bounds: menus
                Component.onCompleted: setState([0, 2], 2)
            }
            MemphisMenu {
                x: 560 * gallery.u
                y: 10 * gallery.u
                model: gallery.commands
                animate: false
                bounds: menus
                Component.onCompleted: setState([9], 1)
            }
            MemphisMenu {
                x: 560 * gallery.u
                y: 250 * gallery.u
                model: gallery.commands
                animate: false
                bounds: menus
                Component.onCompleted: setState([], 5)
            }
            // A list taller than its room runs into columns.
            Item {
                id: shortRoom
                x: 900 * gallery.u; y: 470 * gallery.u
                width: 530 * gallery.u; height: 300 * gallery.u
                MemphisMenu {
                    model: gallery.manyApps.map(n => ({ text: n, icon: "doc" }))
                    animate: false
                    bounds: shortRoom
                    Component.onCompleted: setState([], 12)
                }
            }
        }
    }

    // ================================================================ keys
    // One live Start menu for the keyboard checks (ipc key / menu).
    Component {
        id: keysPage
        Item {
            id: keysRoot
            MemphisMenu {
                id: live
                x: 2 * gallery.u
                y: 300 * gallery.u
                model: gallery.startMenu
                big: true
                widthUnits: 196
                bandText: "Kamoi"
                bandSubText: "Myoko"
                bounds: keysRoot
                onTriggered: item => gallery.triggeredText = Kit.MemphisTokens.plainText(item.text)
                onClosed: gallery.closedCount++
                Component.onCompleted: gallery.testMenu = live
                Component.onDestruction: if (gallery.testMenu === live) gallery.testMenu = null
            }
        }
    }

    // ================================================================ lists
    Component {
        id: listsPage
        Page {
            Flow {
                x: 8 * gallery.u; y: 8 * gallery.u
                width: parent.width - 16 * gallery.u
                spacing: 14 * gallery.u

                Spec {
                    label: "Two-line rows with level bars; selected with focus"
                    MemphisListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: gallery.outputs
                        currentIndex: 0
                        showFocus: true
                        delegate: MemphisListRow {
                            required property var modelData
                            title: modelData.name
                            bold: modelData.def
                            mark: modelData.def ? "dot" : "ring"
                            level: modelData.vol
                            muted: modelData.muted
                            value: modelData.muted ? "mute" : Math.round(modelData.vol * 100) + "%"
                        }
                    }
                }
                Spec {
                    label: "Icon and detail rows; selected, not focused"
                    MemphisListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: [
                            { name: "Galaxy Buds2 Pro", detail: "Connected \u00b7 70% \u00b7 B4:9D:02:6E:11:3A", on: true },
                            { name: "MX Master 3S", detail: "Paired \u00b7 55% \u00b7 D2:41:7C:90:0B:E5", on: false },
                            { name: "5C:F3:70:A1:22:9B", detail: "Pairing failed \u00b7 5C:F3:70:A1:22:9B", on: false, failed: true }]
                        currentIndex: 1
                        delegate: MemphisListRow {
                            required property var modelData
                            title: modelData.name
                            detail: modelData.detail
                            bold: modelData.on
                            iconName: modelData.on ? "bluetooth-on" : "bluetooth-off"
                            detailColor: modelData.failed ? Kit.MemphisTokens.danger : Kit.MemphisTokens.gray
                        }
                    }
                }
                Spec {
                    label: "Many rows: scrolls by whole rows"
                    MemphisListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: 14
                        currentIndex: 3
                        showFocus: true
                        delegate: MemphisListRow {
                            required property int index
                            title: ["Built-in Speakers", "Galaxy Buds2 Pro", "U2723QE (HDMI 1)", "HDMI 2", "USB Audio", "Bose SoundLink Flex", "JBL Flip 6", "Jabra Speak 510", "Sony WH-1000XM5", "Line out", "S/PDIF", "Dummy output", "Virtual sink", "Monitor of Built-in"][index]
                            mark: index === 0 ? "dot" : "ring"
                            level: (index * 7 % 10) / 10
                            value: Math.round((index * 7 % 10) * 10) + "%"
                        }
                        Component.onCompleted: reveal(3)
                    }
                }
                Spec {
                    label: "One-line rows with a value column"
                    MemphisListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        rowUnits: 16
                        model: [["fuji", "12%"], ["yari", "3%"], ["zao", "100%"], ["unzen", "0%"], ["kita", "--"]]
                        currentIndex: 2
                        delegate: MemphisListRow {
                            required property var modelData
                            title: modelData[0]
                            value: modelData[1]
                            iconName: "host"
                        }
                    }
                }
                Spec {
                    label: "Empty: says what to do"
                    MemphisListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: 0
                        emptyText: "No devices found. Select Scan to try again."
                        delegate: MemphisListRow {}
                    }
                }
                Spec {
                    label: "One row"
                    MemphisListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: 1
                        currentIndex: 0
                        showFocus: true
                        delegate: MemphisListRow { title: "Built-in Microphone"; mark: "dot"; bold: true; level: 0.8; value: "80%" }
                    }
                }
            }
        }
    }

    // ================================================================ icons
    Component {
        id: iconsPage
        Page {
            Column {
                x: 8 * gallery.u; y: 8 * gallery.u
                spacing: 10 * gallery.u
                Repeater {
                    model: [Kit.MemphisTokens.face, Kit.MemphisTokens.win]
                    Flow {
                        id: iconFlow
                        required property color modelData
                        width: 1420 * gallery.u
                        spacing: 4 * gallery.u
                        Repeater {
                            model: Kit.MemphisIconStore.names
                            Rectangle {
                                id: cell
                                required property string modelData
                                width: 60 * gallery.u; height: 44 * gallery.u
                                color: iconFlow.modelData
                                MemphisIcon {
                                    x: Kit.MemphisTokens.snap((cell.width - width) / 2, gallery.u); y: 4 * gallery.u
                                    name: cell.modelData
                                    color: iconFlow.modelData === Kit.MemphisTokens.win ? Kit.MemphisTokens.winText : Kit.MemphisTokens.text
                                    level: cell.modelData.startsWith("battery") ? 0.62 : undefined
                                }
                                MemphisText {
                                    x: 2 * gallery.u; y: 29 * gallery.u
                                    width: cell.width - 4 * gallery.u
                                    text: cell.modelData; accessMarks: false
                                    color: Kit.MemphisTokens.gray
                                }
                            }
                        }
                    }
                }
                // The tray, as the taskbar will hold it.
                Rectangle {
                    width: 330 * gallery.u; height: 28 * gallery.u
                    color: Kit.MemphisTokens.face
                    MemphisBevel {
                        x: 4 * gallery.u; y: 3 * gallery.u
                        width: trayRow.width + 5 * gallery.u + clock.width + 11 * gallery.u
                        height: 22 * gallery.u
                        variant: "thinSunken"
                        filled: false
                        Row {
                            id: trayRow
                            x: 3 * gallery.u; y: gallery.u
                            MemphisToolButton { tray: true; iconName: "bluetooth-on" }
                            MemphisToolButton { tray: true; iconName: "wifi-4" }
                            MemphisToolButton { tray: true; iconName: "volume-1"; showHover: true }
                            MemphisToolButton { tray: true; iconName: "brightness" }
                            MemphisToolButton { tray: true; iconName: "oci-normal" }
                            MemphisToolButton { tray: true; iconName: "disk-ok" }
                            MemphisToolButton { tray: true; iconName: "builder" }
                            MemphisToolButton { tray: true; iconName: "bell"; badge: "3" }
                            MemphisToolButton { tray: true; iconName: "battery"; }
                        }
                        MemphisText { id: clock; x: trayRow.x + trayRow.width + 6 * gallery.u; y: 4.5 * gallery.u; text: "4:51 PM"; accessMarks: false }
                    }
                }
            }
        }
    }

    // ================================================================ stress
    Component {
        id: stressPage
        Page {
            Flow {
                x: 8 * gallery.u; y: 8 * gallery.u
                width: parent.width - 16 * gallery.u
                spacing: 14 * gallery.u

                Spec {
                    label: "Long word in a window title, a button, a check box, a combo, a field"
                    MemphisWindow {
                        title: gallery.longWord; iconName: "term"
                        width: 220 * gallery.u
                        Column {
                            spacing: 6 * gallery.u
                            width: 204 * gallery.u
                            MemphisButton { text: gallery.longWord; width: parent.width }
                            MemphisCheckBox { text: gallery.longWord; width: parent.width }
                            MemphisComboBox { width: parent.width; model: [gallery.longWord] }
                            MemphisTextField { id: longField; width: parent.width; text: gallery.longWord; Component.onCompleted: longField.input.cursorPosition = 0 }
                            MemphisStatusBar { width: parent.width; panes: [gallery.longWord] }
                        }
                    }
                }
                Spec {
                    label: "Mixed values: zero, negative, very large, missing"
                    MemphisListView {
                        width: 240 * gallery.u; height: 92 * gallery.u
                        rowUnits: 16
                        model: [["zero", "0 GB"], ["negative", "-3 GB"], ["very large", "1,000,000 GB"], ["missing", "--"], [gallery.longWord, "42%"]]
                        currentIndex: 4
                        showFocus: true
                        delegate: MemphisListRow {
                            required property var modelData
                            title: modelData[0]
                            value: modelData[1]
                            valueUnits: 70
                            titleColor: /^-[0-9]/.test(modelData[1]) ? Kit.MemphisTokens.danger : Kit.MemphisTokens.winText
                        }
                    }
                }
                Spec {
                    label: "Narrow: a 160 u window keeps every control"
                    MemphisWindow {
                        title: "Sound"; iconName: "volume-1"
                        width: 160 * gallery.u
                        Column {
                            spacing: 6 * gallery.u
                            width: 144 * gallery.u
                            MemphisSlider { width: parent.width; value: 0.42 }
                            MemphisCheckBox { text: "&Mute"; checked: true }
                            MemphisTabs {
                                width: parent.width; height: 50 * gallery.u
                                tabs: ["&Outputs 14", "&Inputs 2"]
                                padUnits: 6
                            }
                            MemphisStatusBar { width: parent.width; panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 volume \u00b7 M mute"] }
                        }
                    }
                }
                Spec {
                    label: "Menu with a long item and a disabled item highlighted"
                    Item {
                        width: 300 * gallery.u; height: 120 * gallery.u
                        MemphisMenu {
                            animate: false
                            model: [{ text: "&Open " + gallery.longWord }, { text: "&Disabled item", enabled: false }, { separator: true }, { text: "E&xit" }]
                            Component.onCompleted: setState([], 1)
                        }
                    }
                }
                Spec {
                    label: "Tooltip longer than 300 u elides"
                    MemphisToolTip { maxWidthUnits: 300; text: "Remote builds\n" + gallery.longWord }
                }
            }
        }
    }

    // ================================================================ scenes
    // Two windows from the mock, rebuilt from the controls, for side-by-side
    // crops: Sound (state m-sound) and Display Properties (pk-memphis-light).
    Component {
        id: scenesPage
        Item {
            // ---- Sound, 350 u wide
            MemphisWindow {
                id: sound
                x: 20 * gallery.u; y: 20 * gallery.u
                width: 350 * gallery.u
                title: "Sound"; iconName: "volume-1"
                margins: false
                Item {
                    x: 8 * gallery.u; y: 6 * gallery.u
                    width: 350 * gallery.u - 6 * gallery.u - 16 * gallery.u
                    implicitWidth: width
                    implicitHeight: soundBody.height + 10 * gallery.u
                    Column {
                        id: soundBody
                        width: parent.width
                        spacing: 6 * gallery.u
                        Row {
                            spacing: 8 * gallery.u
                            height: 161 * gallery.u
                            // The mock's group is 72 u of content plus 7 u of
                            // padding each side (CSS content-box): 86 u.
                            MemphisGroupBox {
                                y: -gallery.u
                                width: 86 * gallery.u
                                title: "Volume"
                                topUnits: 12
                                Column {
                                    width: 72 * gallery.u
                                    spacing: 5 * gallery.u
                                    MemphisSlider { x: 21 * gallery.u; orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42 }
                                    MemphisText { x: Kit.MemphisTokens.snap((72 * gallery.u - width) / 2, gallery.u); text: "42%"; accessMarks: false }
                                    MemphisCheckBox { x: Kit.MemphisTokens.snap((72 * gallery.u - width) / 2, gallery.u); text: "&Mute" }
                                }
                            }
                            Column {
                                id: rightCol
                                width: soundBody.width - 94 * gallery.u
                                spacing: 3 * gallery.u
                                // 15 u in the mock; the current tab rises 2 u into it.
                                Item {
                                    width: parent.width; height: 13 * gallery.u
                                    MemphisText { text: "Built-in Speakers"; accessMarks: false; bold: true }
                                }
                                MemphisTabs {
                                    width: parent.width
                                    height: 161 * gallery.u - 16 * gallery.u
                                    tabs: ["&Outputs 3", "&Inputs 2"]
                                    padUnits: 6
                                    MemphisListView {
                                        width: rightCol.width - 12 * gallery.u
                                        height: 108 * gallery.u
                                        model: gallery.outputs
                                        currentIndex: 0
                                        showFocus: true
                                        delegate: MemphisListRow {
                                            required property var modelData
                                            title: modelData.name
                                            bold: modelData.def
                                            mark: modelData.def ? "dot" : "ring"
                                            level: modelData.vol
                                            muted: modelData.muted
                                            value: modelData.muted ? "mute" : Math.round(modelData.vol * 100) + "%"
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            width: parent.width
                            height: soundStatus.height + 2 * gallery.u
                            MemphisStatusBar {
                                id: soundStatus
                                y: 2 * gallery.u
                                width: parent.width
                                panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 volume \u00b7 Enter default \u00b7 M mute \u00b7 Tab inputs"]
                            }
                        }
                    }
                }
            }

            // ---- Display Properties, 410 u wide
            MemphisWindow {
                x: 400 * gallery.u; y: 20 * gallery.u
                width: 410 * gallery.u
                title: "Display Properties"; showHelp: true
                margins: false
                Item {
                    id: dp
                    // The current tab rises 2 u into the 6-u body padding.
                    x: 6 * gallery.u; y: 4 * gallery.u
                    width: 410 * gallery.u - 6 * gallery.u - 12 * gallery.u
                    implicitWidth: width
                    implicitHeight: dpCol.height + 10 * gallery.u
                    Column {
                        id: dpCol
                        width: parent.width
                        spacing: 6 * gallery.u
                        MemphisTabs {
                            width: parent.width
                            height: 22 * gallery.u + sheetCol.height + 20 * gallery.u
                            tabs: ["Appearance", "Scale"]
                            padUnits: 0
                            Column {
                                id: sheetCol
                                x: 8 * gallery.u; y: 10 * gallery.u
                                width: dp.width - 16 * gallery.u
                                spacing: 8 * gallery.u
                                MemphisBevel {
                                    width: parent.width; height: 150 * gallery.u
                                    variant: "field"
                                    color: Kit.MemphisTokens.desktop
                                    MemphisWindow {
                                        x: 12 * gallery.u; y: 8 * gallery.u
                                        width: 220 * gallery.u; height: 70 * gallery.u
                                        title: "Inactive Window"; active: false
                                    }
                                    MemphisWindow {
                                        x: 22 * gallery.u; y: 28 * gallery.u
                                        width: 240 * gallery.u; height: 90 * gallery.u
                                        title: "Active Window"; margins: false
                                        Column {
                                            width: 234 * gallery.u
                                            // The mock's menu bar: each word 6 u in from its box.
                                            Row {
                                                height: 17 * gallery.u
                                                Repeater {
                                                    model: ["Normal", "Disabled", "Selected"]
                                                    Rectangle {
                                                        id: word
                                                        required property string modelData
                                                        width: Kit.MemphisTokens.ceilU(Kit.MemphisTokens.textWidth(modelData, false, gallery.u), gallery.u) + 12 * gallery.u
                                                        height: 17 * gallery.u
                                                        color: modelData === "Selected" ? Kit.MemphisTokens.selection : "transparent"
                                                        MemphisText {
                                                            x: 6 * gallery.u; y: 2 * gallery.u
                                                            text: word.modelData; accessMarks: false
                                                            disabledLook: word.modelData === "Disabled"
                                                            color: word.modelData === "Selected" ? Kit.MemphisTokens.selectionText : Kit.MemphisTokens.text
                                                        }
                                                    }
                                                }
                                            }
                                            MemphisBevel {
                                                width: 234 * gallery.u; height: 34 * gallery.u
                                                variant: "field"; color: Kit.MemphisTokens.win
                                                MemphisText { x: 5 * gallery.u; y: 3 * gallery.u; text: "Window Text"; accessMarks: false; color: Kit.MemphisTokens.winText }
                                            }
                                        }
                                    }
                                    // The preview's taskbar.
                                    Rectangle {
                                        x: 2 * gallery.u; y: parent.height - 14 * gallery.u
                                        width: parent.width - 4 * gallery.u; height: 12 * gallery.u
                                        color: Kit.MemphisTokens.face
                                        Rectangle { width: parent.width; height: gallery.u; color: Kit.MemphisTokens.hi }
                                        MemphisBevel { x: 2 * gallery.u; y: 2 * gallery.u; width: 26 * gallery.u; height: 9 * gallery.u }
                                    }
                                    MemphisWindow {
                                        x: 142 * gallery.u; y: 66 * gallery.u
                                        width: 150 * gallery.u; height: 62 * gallery.u
                                        title: "Message Box"; margins: false
                                        Column {
                                            width: 144 * gallery.u
                                            Item {
                                                width: 144 * gallery.u; height: 19 * gallery.u
                                                MemphisText { x: 6 * gallery.u; y: 3 * gallery.u; text: "Message Text"; accessMarks: false }
                                            }
                                            MemphisButton { x: Kit.MemphisTokens.snap((144 * gallery.u - width) / 2, gallery.u); widthUnits: 50; small: true; height: 18 * gallery.u; text: "OK" }
                                        }
                                    }
                                }
                                Row {
                                    spacing: 6 * gallery.u
                                    MemphisText { width: 56 * gallery.u; y: 4 * gallery.u; text: "&Theme:" }
                                    MemphisComboBox { width: sheetCol.width - 62 * gallery.u; model: ["Memphis", "Mac OS 8 Platinum"] }
                                }
                                Row {
                                    spacing: 6 * gallery.u
                                    MemphisText { width: 56 * gallery.u; y: 4 * gallery.u; text: "&Scheme:" }
                                    MemphisComboBox { width: sheetCol.width - 62 * gallery.u; model: ["Windows Standard", "Dark grey"]; currentIndex: Kit.MemphisTokens.dark ? 1 : 0 }
                                }
                                MemphisText {
                                    width: parent.width
                                    wrap: true
                                    accessMarks: false
                                    color: Kit.MemphisTokens.gray
                                    text: "A theme sets the bars, the menus and the font. A scheme sets the colours. Each theme has its own schemes."
                                }
                            }
                        }
                        Row {
                            x: parent.width - width
                            topPadding: 6 * gallery.u
                            spacing: 6 * gallery.u
                            MemphisButton { text: "OK"; isDefault: true }
                            MemphisButton { text: "Cancel" }
                            MemphisButton { text: "&Apply"; enabled: false }
                        }
                    }
                }
            }
        }
    }
}
