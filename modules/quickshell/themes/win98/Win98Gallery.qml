pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Test-only scene: every Win98 control in every state, one page at a time,
// for screenshots (dev/capture.sh) and the keyboard checks. The shell never
// loads it. Pages: text, controls, fields, frames, menus, lists, icons,
// stress, scenes. The appearance follows Theme.dark like everything else.
//
// The font: W95FA Grid from $WIN98_FONT (the Nix package replaces this).
Scope {
    id: gallery

    property string page: "controls"
    readonly property real u: Win98Tokens.u

    FontLoader {
        source: "file://" + (Quickshell.env("WIN98_FONT") || "/tmp/win98-mock/fonts/W95FAGrid.ttf")
    }

    IpcHandler {
        target: "win98gallery"
        function page(name: string): string { gallery.page = name; return name; }
        function ready(): string { return gallery.page + " dpr=" + Win98Tokens.pixelRatio + " dark=" + Win98Tokens.dark; }
        function motion(reduced: bool): string { Win98Tokens.reducedMotion = reduced; return String(Win98Tokens.reducedMotion); }
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
        function resetMenu(): string { gallery.triggeredText = ""; gallery.closedCount = 0; if (gallery.testMenu) gallery.testMenu.reset(); return gallery.menuState(); }
    }

    property Win98Menu testMenu: null
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
        for (const i of testMenu.path) { names.push(Win98Tokens.plainText(items[i].text)); items = items[i].submenu; }
        const cur = testMenu.cursor >= 0 && items[testMenu.cursor] ? Win98Tokens.plainText(items[testMenu.cursor].text) : "-";
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
            { text: "Windows 98 - Wikipedia - Chromium", icon: "chromium", shortcut: "Page 1" },
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
        color: Win98Tokens.desktop
        onDevicePixelRatioChanged: if (devicePixelRatio > 0) Win98Tokens.pixelRatio = devicePixelRatio
        Component.onCompleted: if (devicePixelRatio > 0) Win98Tokens.pixelRatio = devicePixelRatio

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
        Win98Text { text: parent.label; accessMarks: false; color: Win98Tokens.gray }
    }
    component Heading: Win98Text { accessMarks: false; bold: true }
    component Page: Rectangle { color: Win98Tokens.face }

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
                Win98Text { text: "Regular: Start  Built-in Speakers 42% 4:51 PM  a...b a\u2026b \u2190\u2192\u2191\u2193 \u00d7 \u00b7 \u2013 \u2014"; accessMarks: false }
                Win98Text { text: "Bold: Start   Display Properties   simon@myoko"; accessMarks: false; bold: true }
                Rectangle {
                    width: 800 * gallery.u; height: 60 * gallery.u
                    color: Win98Tokens.caption1
                    Column {
                        x: 6 * gallery.u; y: 4 * gallery.u
                        spacing: 4 * gallery.u
                        Win98Text { text: "Caption: Remote builds"; accessMarks: false; bold: true; color: "#ffffff" }
                        Win98Text { text: "Kamoi Myoko"; accessMarks: false; size: 2; color: "#ffffff" }
                    }
                }
                Win98Text { text: "Access keys: &Programs  &Windows  Brigh&tness  Log &Off  Tom && Jerry" }
                Win98Text { text: "Disabled: &Apply  Mirror workspace"; disabledLook: true }
                Row {
                    spacing: 8 * gallery.u
                    Win98Text { text: "Elided at 120 u: " + gallery.longWord; accessMarks: false; width: 120 * gallery.u }
                    Win98Text { text: "Two lines at 180 u: the hint wraps by word and keeps its keys"; accessMarks: false; wrap: true; width: 180 * gallery.u }
                }
                Rectangle {
                    width: 200 * gallery.u; height: 30 * gallery.u
                    color: Win98Tokens.win
                    Win98Text { x: 4 * gallery.u; y: 4 * gallery.u; text: "Window text on the field colour"; accessMarks: false; color: Win98Tokens.winText }
                }
                Rectangle {
                    width: 200 * gallery.u; height: 17 * gallery.u
                    color: Win98Tokens.selection
                    Win98Text { x: 4 * gallery.u; y: 2 * gallery.u; text: "Selected text"; accessMarks: false; color: Win98Tokens.selectionText }
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
                        Win98Button { text: "OK"; isDefault: true }
                        Win98Button { text: "Cancel" }
                        Win98Button { text: "&Apply"; enabled: false }
                        Win98Button { text: "Pressed"; showPressed: true }
                        Win98Button { text: "&Focus"; showFocus: true }
                        Win98Button { text: "&Yes"; isDefault: true; showFocus: true }
                    }
                }
                Spec {
                    label: "Small; one role, one width; icon"
                    Row {
                        spacing: 6 * gallery.u
                        Win98Button { text: "&Retry"; small: true }
                        Win98Button { text: "&Dismiss"; small: true; enabled: false }
                        Win98Button { text: "Pair"; small: true; roleLabels: ["Connect", "Disconnect", "Pair", "Cancel"] }
                        Win98Button { text: "Disconnect"; small: true; roleLabels: ["Connect", "Disconnect", "Pair", "Cancel"] }
                        Win98Button { text: "&Check now"; iconName: "host"; small: true }
                    }
                }
                Spec {
                    label: "Toolbar buttons (22 u): rest, hover, pressed, open, latched, focus, disabled"
                    Row {
                        spacing: 6 * gallery.u
                        Win98ToolButton { iconName: "display" }
                        Win98ToolButton { iconName: "display"; showHover: true }
                        Win98ToolButton { iconName: "display"; showPressed: true }
                        Win98ToolButton { iconName: "display"; open: true }
                        Win98ToolButton { iconName: "display"; checked: true }
                        Win98ToolButton { iconName: "display"; showFocus: true }
                        Win98ToolButton { iconName: "display"; enabled: false }
                        Win98ToolButton { iconName: "folder"; text: "Programs"; showHover: true }
                    }
                }
                Spec {
                    label: "Tray buttons (20 u) with badges: hover, open, latched builder, focus"
                    Row {
                        spacing: 6 * gallery.u
                        Win98ToolButton { tray: true; iconName: "volume-1" }
                        Win98ToolButton { tray: true; iconName: "volume-1"; showHover: true }
                        Win98ToolButton { tray: true; iconName: "volume-1"; open: true }
                        Win98ToolButton { tray: true; iconName: "builder"; checked: true }
                        Win98ToolButton { tray: true; iconName: "wifi-3"; showFocus: true }
                        Win98ToolButton { tray: true; iconName: "bell"; badge: "3" }
                        Win98ToolButton { tray: true; iconName: "bell"; badge: "99+"; width: 32 * gallery.u }
                        Win98ToolButton { tray: true; iconName: "disk-warn"; badge: "2" }
                        Win98ToolButton { tray: true; iconName: "battery-bolt" }
                    }
                }
                Spec {
                    label: "Check boxes: off, on, pressed, disabled off, disabled on, focus"
                    Row {
                        spacing: 10 * gallery.u
                        Win98CheckBox { text: "&Mute" }
                        Win98CheckBox { text: "&Mute"; checked: true }
                        Win98CheckBox { text: "Pressed"; showPressed: true }
                        Win98CheckBox { text: "Bluetooth &on"; enabled: false }
                        Win98CheckBox { text: "Wi-Fi &on"; enabled: false; checked: true }
                        Win98CheckBox { text: "Accep&t builds"; checked: true; showFocus: true }
                    }
                }
                Spec {
                    label: "Option buttons: off, on, pressed, disabled off, disabled on, focus"
                    Row {
                        spacing: 10 * gallery.u
                        Win98RadioButton { text: "Windows Standard" }
                        Win98RadioButton { text: "Dark grey"; checked: true }
                        Win98RadioButton { text: "Pressed"; showPressed: true }
                        Win98RadioButton { text: "Off"; enabled: false }
                        Win98RadioButton { text: "On"; enabled: false; checked: true }
                        Win98RadioButton { text: "&Focus"; checked: true; showFocus: true }
                    }
                }
                Spec {
                    label: "Trackbars, horizontal: 0, 60, 100, focus, disabled"
                    Row {
                        spacing: 10 * gallery.u
                        Win98Slider { width: 120 * gallery.u; value: 0 }
                        Win98Slider { width: 120 * gallery.u; value: 0.6 }
                        Win98Slider { width: 120 * gallery.u; value: 1 }
                        Win98Slider { width: 120 * gallery.u; value: 0.42; showFocus: true }
                        Win98Slider { width: 120 * gallery.u; value: 0.42; enabled: false }
                    }
                }
                Spec {
                    label: "Vertical: 42, 100, focus, disabled"
                    Row {
                        spacing: 10 * gallery.u
                        Win98Slider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42 }
                        Win98Slider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 1 }
                        Win98Slider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42; showFocus: true }
                        Win98Slider { orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42; enabled: false }
                    }
                }
                Spec {
                    label: "Scroll bars: top, middle, end, arrow pressed, thumb only room, nothing to scroll"
                    Row {
                        spacing: 10 * gallery.u
                        Win98ScrollBar { height: 100 * gallery.u; size: 0.4; position: 0 }
                        Win98ScrollBar { height: 100 * gallery.u; size: 0.4; position: 0.5 }
                        Win98ScrollBar { height: 100 * gallery.u; size: 0.4; position: 1 }
                        Win98ScrollBar { height: 100 * gallery.u; size: 0.2; position: 0; showPressed: "back" }
                        Win98ScrollBar { height: 100 * gallery.u; size: 0.01; position: 0.3 }
                        Win98ScrollBar { height: 100 * gallery.u; size: 1 }
                        Column {
                            spacing: 6 * gallery.u
                            Win98ScrollBar { orientation: Qt.Horizontal; width: 200 * gallery.u; size: 0.3; position: 0.2 }
                            Win98ScrollBar { orientation: Qt.Horizontal; width: 200 * gallery.u; size: 0.3; position: 1; showPressed: "forward" }
                            Win98ScrollBar { orientation: Qt.Horizontal; width: 200 * gallery.u; size: 1 }
                        }
                    }
                }
                Spec {
                    label: "Level bars: 0, 42, 100, muted 35, on a selected row"
                    Row {
                        spacing: 10 * gallery.u
                        Win98LevelBar { width: 80 * gallery.u; value: 0 }
                        Win98LevelBar { width: 80 * gallery.u; value: 0.42 }
                        Win98LevelBar { width: 80 * gallery.u; value: 1 }
                        Win98LevelBar { width: 80 * gallery.u; value: 0.35; muted: true }
                        Rectangle {
                            width: 90 * gallery.u; height: 10 * gallery.u
                            color: Win98Tokens.selection
                            Win98LevelBar { x: 5 * gallery.u; y: 3 * gallery.u; width: 80 * gallery.u; value: 0.42; onSelection: true }
                        }
                    }
                }
                Spec {
                    label: "Tooltips: one line, several lines"
                    Row {
                        spacing: 10 * gallery.u
                        Win98ToolTip { text: "Click here to begin." }
                        Win98ToolTip { text: "Volume 42%\nBuilt-in Speakers" }
                        Win98ToolTip { text: "OCI egress this month\nfuji 12% (1270 GB)\nyari 3% (307 GB)" }
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
                        Win98TextField { width: 120 * gallery.u; showCaret: true }
                        Win98TextField { width: 120 * gallery.u; text: "NETGEAR42" }
                        Win98TextField { width: 120 * gallery.u; placeholder: "Search programs" }
                        Win98TextField { id: sel; width: 120 * gallery.u; text: "kamoi-5g"; Component.onCompleted: sel.input.select(0, 5) }
                        Win98TextField { width: 120 * gallery.u; text: "eduroam"; enabled: false }
                        Win98TextField { width: 120 * gallery.u; text: "secret"; echoMode: TextInput.Password; showCaret: true }
                    }
                }
                Spec {
                    label: "Drop-down lists: closed, focused, disabled, open"
                    Row {
                        spacing: 8 * gallery.u
                        Win98ComboBox { width: 160 * gallery.u; model: ["Windows 98", "Mac OS 8 Platinum"] }
                        Win98ComboBox { width: 160 * gallery.u; model: ["Windows Standard", "Dark grey"]; currentIndex: 1; showFocus: true }
                        Win98ComboBox { width: 160 * gallery.u; model: ["Windows Standard", "Dark grey"]; enabled: false }
                        Win98ComboBox { id: openCombo; width: 160 * gallery.u; model: ["Windows Standard", "Dark grey"]; currentIndex: 1; showFocus: true; Component.onCompleted: openCombo.open = true }
                    }
                }
                Item { width: parent.width; height: 40 * gallery.u }
                Spec {
                    label: "Group boxes"
                    Row {
                        spacing: 10 * gallery.u
                        Win98GroupBox {
                            title: "Volume"
                            width: 140 * gallery.u
                            Column {
                                spacing: 5 * gallery.u
                                Win98CheckBox { text: "&Mute" }
                                Win98CheckBox { text: "Show in the &tray"; checked: true }
                            }
                        }
                        Win98GroupBox {
                            title: "Devices (scanning)"
                            width: 200 * gallery.u
                            height: 60 * gallery.u
                            Win98Text { text: "Looking for devices..."; accessMarks: false; color: Win98Tokens.gray }
                        }
                        Win98GroupBox {
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
                        Win98StatusBar { width: 330 * gallery.u; panes: ["Esc or click outside to close"] }
                        Win98StatusBar { width: 330 * gallery.u; panes: ["1 device connected", "\u2191\u2193 select \u00b7 Enter action \u00b7 S scan"] }
                        Win98StatusBar { width: 330 * gallery.u; panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 volume \u00b7 Enter default \u00b7 M mute \u00b7 Tab inputs \u00b7 Shift+Del forget"] }
                    }
                }
                Spec {
                    label: "Property sheet tabs: first, second, focus"
                    Row {
                        spacing: 10 * gallery.u
                        Win98Tabs {
                            width: 200 * gallery.u; height: 70 * gallery.u
                            tabs: ["&Outputs 3", "&Inputs 2"]
                            Win98Text { text: "Outputs"; accessMarks: false }
                        }
                        Win98Tabs {
                            width: 200 * gallery.u; height: 70 * gallery.u
                            tabs: ["&Outputs 3", "&Inputs 2"]; currentIndex: 1
                            Win98Text { text: "Inputs"; accessMarks: false }
                        }
                        Win98Tabs {
                            width: 200 * gallery.u; height: 70 * gallery.u
                            tabs: ["Appearance", "Scale", "Fonts"]; showFocus: true
                            Win98Text { text: "Focus on the tab row"; accessMarks: false }
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

                Win98Window {
                    title: "Sound"; iconName: "volume-1"
                    width: 220 * gallery.u; height: 80 * gallery.u
                    Win98Text { text: "Active, with close"; accessMarks: false }
                }
                Win98Window {
                    title: "Sound"; iconName: "volume-1"; active: false
                    width: 220 * gallery.u; height: 80 * gallery.u
                    Win98Text { text: "Inactive"; accessMarks: false }
                }
                Win98Window {
                    title: "Display Properties"; showHelp: true
                    width: 260 * gallery.u; height: 80 * gallery.u
                    Win98Text { text: "Help and close, no icon"; accessMarks: false }
                }
                Win98Window {
                    title: "Display Properties"; showHelp: true; showPressed: "close"
                    width: 260 * gallery.u; height: 80 * gallery.u
                    Win98Text { text: "Close pressed"; accessMarks: false }
                }
                Win98Window {
                    title: "OCI egress \u00b7 this month, every profile, projected"; iconName: "oci-normal"
                    width: 180 * gallery.u; height: 80 * gallery.u
                    Win98Text { text: "Long title elides"; accessMarks: false }
                }
                Win98Window {
                    title: "Log Off Myoko"
                    width: 300 * gallery.u
                    Column {
                        spacing: 8 * gallery.u
                        Row {
                            spacing: 12 * gallery.u
                            Win98Icon { name: "logoff" }
                            Win98Text { y: 5.5 * gallery.u; text: "Are you sure you want to log off?"; accessMarks: false }
                        }
                        Row {
                            x: Win98Tokens.snap((276 * gallery.u - width) / 2)
                            spacing: 6 * gallery.u
                            Win98Button { text: "&Yes"; isDefault: true; showFocus: true }
                            Win98Button { text: "&No" }
                        }
                    }
                }
                Win98Window {
                    title: "Remote builds"; iconName: "builder"
                    width: 360 * gallery.u
                    Column {
                        spacing: 6 * gallery.u
                        width: 344 * gallery.u
                        Row {
                            spacing: 8 * gallery.u
                            Win98Icon { name: "ok"; y: gallery.u }
                            Column {
                                spacing: 3 * gallery.u
                                Win98Text { text: "Accepting remote builds"; accessMarks: false; bold: true }
                                Win98Text { text: "At home on AC power."; accessMarks: false }
                            }
                        }
                        Win98Separator { width: parent.width }
                        Item {
                            width: parent.width; height: 13 * gallery.u
                            Win98CheckBox { text: "Accep&t builds"; checked: true; showFocus: true }
                            Win98Text { x: parent.width - width; text: "T"; accessMarks: false; color: Win98Tokens.gray }
                        }
                        Item {
                            width: parent.width; height: 21 * gallery.u
                            Win98Button { text: "Use &default (on)"; small: true; widthUnits: 150 }
                            Win98Text { x: parent.width - width; y: 4 * gallery.u; text: "D"; accessMarks: false; color: Win98Tokens.gray }
                        }
                        Item {
                            width: parent.width; height: 21 * gallery.u
                            Win98Button { text: "Stop builds"; small: true; widthUnits: 150; enabled: false }
                            Win98Text { x: parent.width - width; y: 4 * gallery.u; text: "X"; accessMarks: false; color: Win98Tokens.gray }
                        }
                        Win98StatusBar { width: parent.width; panes: ["Tab move \u00b7 Enter choose \u00b7 Esc close"] }
                    }
                }
                Win98Window {
                    title: "Brightness"; iconName: "brightness"
                    width: 310 * gallery.u
                    Column {
                        spacing: 6 * gallery.u
                        width: 294 * gallery.u
                        Row {
                            spacing: 6 * gallery.u
                            Win98Icon { name: "brightness"; opacity: 0.6; y: 2 * gallery.u }
                            Win98Slider { width: 200 * gallery.u; value: (60 - 5) / 95; showFocus: true }
                            Win98Text { text: "60%"; accessMarks: false; y: 2 * gallery.u }
                        }
                        Win98StatusBar { width: parent.width; panes: ["\u2190\u2192 brightness \u00b7 Esc close"] }
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
            Win98Menu {
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
            Win98Menu {
                x: 560 * gallery.u
                y: 10 * gallery.u
                model: gallery.commands
                animate: false
                bounds: menus
                Component.onCompleted: setState([9], 1)
            }
            Win98Menu {
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
                x: 800 * gallery.u; y: 10 * gallery.u
                width: 620 * gallery.u; height: 300 * gallery.u
                Win98Menu {
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
            Win98Menu {
                id: live
                x: 2 * gallery.u
                y: 300 * gallery.u
                model: gallery.startMenu
                big: true
                widthUnits: 196
                bandText: "Kamoi"
                bandSubText: "Myoko"
                bounds: keysRoot
                onTriggered: item => gallery.triggeredText = Win98Tokens.plainText(item.text)
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
                    Win98ListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: gallery.outputs
                        currentIndex: 0
                        showFocus: true
                        delegate: Win98ListRow {
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
                    Win98ListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: [
                            { name: "Galaxy Buds2 Pro", detail: "Connected \u00b7 70% \u00b7 B4:9D:02:6E:11:3A", on: true },
                            { name: "MX Master 3S", detail: "Paired \u00b7 55% \u00b7 D2:41:7C:90:0B:E5", on: false },
                            { name: "5C:F3:70:A1:22:9B", detail: "Pairing failed \u00b7 5C:F3:70:A1:22:9B", on: false, failed: true }]
                        currentIndex: 1
                        delegate: Win98ListRow {
                            required property var modelData
                            title: modelData.name
                            detail: modelData.detail
                            bold: modelData.on
                            iconName: modelData.on ? "bluetooth-on" : "bluetooth-off"
                            detailColor: modelData.failed ? Win98Tokens.danger : Win98Tokens.gray
                        }
                    }
                }
                Spec {
                    label: "Many rows: scrolls by whole rows"
                    Win98ListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: 14
                        currentIndex: 3
                        showFocus: true
                        delegate: Win98ListRow {
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
                    Win98ListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        rowUnits: 16
                        model: [["fuji", "12%"], ["yari", "3%"], ["zao", "100%"], ["unzen", "0%"], ["kita", "--"]]
                        currentIndex: 2
                        delegate: Win98ListRow {
                            required property var modelData
                            title: modelData[0]
                            value: modelData[1]
                            iconName: "host"
                        }
                    }
                }
                Spec {
                    label: "Empty: says what to do"
                    Win98ListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: 0
                        emptyText: "No devices found. Select Scan to try again."
                        delegate: Win98ListRow {}
                    }
                }
                Spec {
                    label: "One row"
                    Win98ListView {
                        width: 240 * gallery.u; height: 108 * gallery.u
                        model: 1
                        currentIndex: 0
                        showFocus: true
                        delegate: Win98ListRow { title: "Built-in Microphone"; mark: "dot"; bold: true; level: 0.8; value: "80%" }
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
                    model: [Win98Tokens.face, Win98Tokens.win]
                    Flow {
                        id: iconFlow
                        required property color modelData
                        width: 1420 * gallery.u
                        spacing: 4 * gallery.u
                        Repeater {
                            model: Win98IconStore.names
                            Rectangle {
                                id: cell
                                required property string modelData
                                width: 60 * gallery.u; height: 44 * gallery.u
                                color: iconFlow.modelData
                                Win98Icon {
                                    x: Win98Tokens.snap((cell.width - width) / 2); y: 4 * gallery.u
                                    name: cell.modelData
                                    color: iconFlow.modelData === Win98Tokens.win ? Win98Tokens.winText : Win98Tokens.text
                                    level: cell.modelData.startsWith("battery") ? 0.62 : undefined
                                }
                                Win98Text {
                                    x: 2 * gallery.u; y: 29 * gallery.u
                                    width: cell.width - 4 * gallery.u
                                    text: cell.modelData; accessMarks: false
                                    color: Win98Tokens.gray
                                }
                            }
                        }
                    }
                }
                // The tray, as the taskbar will hold it.
                Rectangle {
                    width: 330 * gallery.u; height: 28 * gallery.u
                    color: Win98Tokens.face
                    Win98Bevel {
                        x: 4 * gallery.u; y: 3 * gallery.u
                        width: trayRow.width + 5 * gallery.u + clock.width + 11 * gallery.u
                        height: 22 * gallery.u
                        variant: "thinSunken"
                        filled: false
                        Row {
                            id: trayRow
                            x: 3 * gallery.u; y: gallery.u
                            Win98ToolButton { tray: true; iconName: "bluetooth-on" }
                            Win98ToolButton { tray: true; iconName: "wifi-4" }
                            Win98ToolButton { tray: true; iconName: "volume-1"; showHover: true }
                            Win98ToolButton { tray: true; iconName: "brightness" }
                            Win98ToolButton { tray: true; iconName: "oci-normal" }
                            Win98ToolButton { tray: true; iconName: "disk-ok" }
                            Win98ToolButton { tray: true; iconName: "builder" }
                            Win98ToolButton { tray: true; iconName: "bell"; badge: "3" }
                            Win98ToolButton { tray: true; iconName: "battery"; }
                        }
                        Win98Text { id: clock; x: trayRow.x + trayRow.width + 6 * gallery.u; y: 4.5 * gallery.u; text: "4:51 PM"; accessMarks: false }
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
                    Win98Window {
                        title: gallery.longWord; iconName: "term"
                        width: 220 * gallery.u
                        Column {
                            spacing: 6 * gallery.u
                            width: 204 * gallery.u
                            Win98Button { text: gallery.longWord; width: parent.width }
                            Win98CheckBox { text: gallery.longWord; width: parent.width }
                            Win98ComboBox { width: parent.width; model: [gallery.longWord] }
                            Win98TextField { width: parent.width; text: gallery.longWord }
                            Win98StatusBar { width: parent.width; panes: [gallery.longWord] }
                        }
                    }
                }
                Spec {
                    label: "Mixed values: zero, negative, very large, missing"
                    Win98ListView {
                        width: 240 * gallery.u; height: 92 * gallery.u
                        rowUnits: 16
                        model: [["zero", "0 GB"], ["negative", "-3 GB"], ["very large", "1,000,000 GB"], ["missing", "--"], [gallery.longWord, "42%"]]
                        currentIndex: 4
                        showFocus: true
                        delegate: Win98ListRow {
                            required property var modelData
                            title: modelData[0]
                            value: modelData[1]
                            valueUnits: 70
                            titleColor: modelData[1].startsWith("-") ? Win98Tokens.danger : Win98Tokens.winText
                        }
                    }
                }
                Spec {
                    label: "Narrow: a 160 u window keeps every control"
                    Win98Window {
                        title: "Sound"; iconName: "volume-1"
                        width: 160 * gallery.u
                        Column {
                            spacing: 6 * gallery.u
                            width: 144 * gallery.u
                            Win98Slider { width: parent.width; value: 0.42 }
                            Win98CheckBox { text: "&Mute"; checked: true }
                            Win98Tabs {
                                width: parent.width; height: 50 * gallery.u
                                tabs: ["&Outputs 14", "&Inputs 2"]
                                padUnits: 6
                            }
                            Win98StatusBar { width: parent.width; panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 volume \u00b7 M mute"] }
                        }
                    }
                }
                Spec {
                    label: "Menu with a long item and a disabled item highlighted"
                    Item {
                        width: 300 * gallery.u; height: 120 * gallery.u
                        Win98Menu {
                            animate: false
                            model: [{ text: "&Open " + gallery.longWord }, { text: "&Disabled item", enabled: false }, { separator: true }, { text: "E&xit" }]
                            Component.onCompleted: setState([], 1)
                        }
                    }
                }
                Spec {
                    label: "Tooltip longer than 300 u elides"
                    Win98ToolTip { maxWidthUnits: 300; text: "Remote builds\n" + gallery.longWord }
                }
            }
        }
    }

    // ================================================================ scenes
    // Two windows from the mock, rebuilt from the controls, for side-by-side
    // crops: Sound (state m-sound) and Display Properties (pk-win98-light).
    Component {
        id: scenesPage
        Item {
            // ---- Sound, 350 u wide
            Win98Window {
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
                            Win98GroupBox {
                                y: -gallery.u
                                width: 86 * gallery.u
                                title: "Volume"
                                topUnits: 12
                                Column {
                                    width: 72 * gallery.u
                                    spacing: 5 * gallery.u
                                    Win98Slider { x: 21 * gallery.u; orientation: Qt.Vertical; height: 100 * gallery.u; value: 0.42 }
                                    Win98Text { x: Win98Tokens.snap((72 * gallery.u - width) / 2); text: "42%"; accessMarks: false }
                                    Win98CheckBox { x: Win98Tokens.snap((72 * gallery.u - width) / 2); text: "&Mute" }
                                }
                            }
                            Column {
                                id: rightCol
                                width: soundBody.width - 94 * gallery.u
                                spacing: 3 * gallery.u
                                // 15 u in the mock; the current tab rises 2 u into it.
                                Item {
                                    width: parent.width; height: 13 * gallery.u
                                    Win98Text { text: "Built-in Speakers"; accessMarks: false; bold: true }
                                }
                                Win98Tabs {
                                    width: parent.width
                                    height: 161 * gallery.u - 16 * gallery.u
                                    tabs: ["&Outputs 3", "&Inputs 2"]
                                    padUnits: 6
                                    Win98ListView {
                                        width: rightCol.width - 12 * gallery.u
                                        height: 108 * gallery.u
                                        model: gallery.outputs
                                        currentIndex: 0
                                        showFocus: true
                                        delegate: Win98ListRow {
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
                            Win98StatusBar {
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
            Win98Window {
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
                        Win98Tabs {
                            width: parent.width
                            height: 22 * gallery.u + sheetCol.height + 20 * gallery.u
                            tabs: ["Appearance", "Scale"]
                            padUnits: 0
                            Column {
                                id: sheetCol
                                x: 8 * gallery.u; y: 10 * gallery.u
                                width: dp.width - 16 * gallery.u
                                spacing: 8 * gallery.u
                                Win98Bevel {
                                    width: parent.width; height: 150 * gallery.u
                                    variant: "field"
                                    color: Win98Tokens.desktop
                                    Win98Window {
                                        x: 12 * gallery.u; y: 8 * gallery.u
                                        width: 220 * gallery.u; height: 70 * gallery.u
                                        title: "Inactive Window"; active: false
                                    }
                                    Win98Window {
                                        x: 22 * gallery.u; y: 28 * gallery.u
                                        width: 240 * gallery.u; height: 90 * gallery.u
                                        title: "Active Window"; margins: false
                                        Column {
                                            width: 234 * gallery.u
                                            Row {
                                                height: 17 * gallery.u
                                                Item { width: 60 * gallery.u; height: 17 * gallery.u; Win98Text { x: 6 * gallery.u; y: 2 * gallery.u; text: "Normal"; accessMarks: false } }
                                                Item { width: 60 * gallery.u; height: 17 * gallery.u; Win98Text { x: 6 * gallery.u; y: 2 * gallery.u; text: "Disabled"; accessMarks: false; disabledLook: true } }
                                                Rectangle { width: 60 * gallery.u; height: 17 * gallery.u; color: Win98Tokens.selection; Win98Text { x: 6 * gallery.u; y: 2 * gallery.u; text: "Selected"; accessMarks: false; color: Win98Tokens.selectionText } }
                                            }
                                            Win98Bevel {
                                                width: 234 * gallery.u; height: 34 * gallery.u
                                                variant: "field"; color: Win98Tokens.win
                                                Win98Text { x: 5 * gallery.u; y: 3 * gallery.u; text: "Window Text"; accessMarks: false; color: Win98Tokens.winText }
                                            }
                                        }
                                    }
                                    Win98Window {
                                        x: 142 * gallery.u; y: 66 * gallery.u
                                        width: 150 * gallery.u; height: 62 * gallery.u
                                        title: "Message Box"; margins: false
                                        Column {
                                            width: 144 * gallery.u
                                            Win98Text { x: 6 * gallery.u; y: 0; height: 19 * gallery.u; text: "Message Text"; accessMarks: false }
                                            Win98Button { x: Win98Tokens.snap((144 * gallery.u - width) / 2); widthUnits: 50; small: true; height: 18 * gallery.u; text: "OK" }
                                        }
                                    }
                                }
                                Row {
                                    spacing: 6 * gallery.u
                                    Win98Text { width: 56 * gallery.u; y: 4 * gallery.u; text: "&Theme:" }
                                    Win98ComboBox { width: sheetCol.width - 62 * gallery.u; model: ["Windows 98", "Mac OS 8 Platinum"] }
                                }
                                Row {
                                    spacing: 6 * gallery.u
                                    Win98Text { width: 56 * gallery.u; y: 4 * gallery.u; text: "&Scheme:" }
                                    Win98ComboBox { width: sheetCol.width - 62 * gallery.u; model: ["Windows Standard", "Dark grey"]; currentIndex: Win98Tokens.dark ? 1 : 0 }
                                }
                                Win98Text {
                                    width: parent.width
                                    wrap: true
                                    accessMarks: false
                                    color: Win98Tokens.gray
                                    text: "A theme sets the bars, the menus and the font. A scheme sets the colours. Each theme has its own schemes."
                                }
                            }
                        }
                        Row {
                            x: parent.width - width
                            spacing: 6 * gallery.u
                            Win98Button { text: "OK"; isDefault: true }
                            Win98Button { text: "Cancel" }
                            Win98Button { text: "&Apply"; enabled: false }
                        }
                    }
                }
            }
        }
    }
}
