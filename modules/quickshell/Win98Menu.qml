pragma ComponentBehavior: Bound

import Hensou as Kit
import Quickshell
import QtQuick

// A cascading Win98 menu (the Start menu, a popup menu) with Win98's
// keyboard model, as the approved mock checks it.
//
// model: an array of items. An item is { text, icon, shortcut, submenu,
// enabled, checked } or { separator: true }. text marks its access key
// with "&" ("&Programs"); without one the first letter is the key.
//
// Pointer: moving onto an item with a submenu opens it (and closes any
// deeper one); a click on a leaf triggers it. Keys (handleKey, or the
// focused menu itself):
//   Down / Up      next / previous item, wrapping; Up from nothing is the last
//   Right / Enter  open the submenu and select its first item
//   Enter          trigger a leaf
//   Left / Esc     close one level, the parent item still selected; at the
//                  top level they close the menu (closed())
//   a letter       select the next item with that access key, cycling; if
//                  only one item has it, open it (submenu) or trigger it
//
// Roll-out: the top level rolls `roll` ("up" for the Start menu), each
// submenu rolls right, 120 ms, none under Kit.Win98Tokens.reducedMotion or
// when animate is false. The cascade stays inside `bounds` (default: the
// parent): a submenu that would leave on the right opens to the left.
FocusScope {
    id: root

    property var model: []
    property bool big: false           // the top level's rows are 32 u
    property string bandText: ""
    property string bandSubText: ""
    property real widthUnits: 0
    property string roll: "down"
    property bool animate: true
    property Item bounds: parent

    // The open submenus, one index per level, and the keyboard highlight
    // in the deepest open level (-1: none).
    property var path: []
    property int cursor: -1

    signal triggered(var item, var indices)
    signal closed

    readonly property real u: Kit.Win98Tokens.unitFor(QsWindow.window)
    // Where the menu stands in its bounds. mapToItem is not a binding, so
    // this reads the positions it depends on (the menu's and its parent's),
    // and a host that places the menu after creating it moves the cascade.
    readonly property point origin: {
        root.x; root.y;
        if (root.parent) { root.parent.x; root.parent.y; }
        return root.bounds ? root.mapToItem(root.bounds, 0, 0) : Qt.point(0, 0);
    }

    // The top level's size. itemAt() is no binding; the Repeater's count is,
    // and it changes once the level's panel exists.
    implicitWidth: panels.count > 0 && panels.itemAt(0) ? panels.itemAt(0).implicitWidth : 0
    implicitHeight: panels.count > 0 && panels.itemAt(0) ? panels.itemAt(0).implicitHeight : 0
    focus: true

    function itemsAt(level) {
        let items = root.model;
        for (let l = 0; l < level; l++) {
            const it = items[root.path[l]];
            if (!it || !it.submenu) return [];
            items = it.submenu;
        }
        return items || [];
    }
    function selectable(items) {
        const out = [];
        // Separators and disabled items are never selected.
        for (let i = 0; i < items.length; i++) if (items[i] && !items[i].separator && items[i].enabled !== false) out.push(i);
        return out;
    }
    function hasSub(it) { return !!it && !it.separator && it.enabled !== false && !!it.submenu && it.submenu.length > 0; }

    // Show a state directly (galleries, a host restoring a menu).
    function setState(newPath, newCursor) {
        root.path = newPath.slice();
        root.cursor = newCursor;
        root.sync(false);
    }
    function reset() { root.setState([], -1); }
    // The panel drawing one open level (0 = the top), or null.
    function panelAt(level) { return level < levels.count ? panels.itemAt(level) : null; }

    function open(index) {
        root.path = root.path.concat([index]);
        const next = root.selectable(root.itemsAt(root.path.length));
        root.cursor = next.length ? next[0] : -1;
        root.sync(true);
    }
    function trigger(index) {
        const items = root.itemsAt(root.path.length);
        const it = items[index];
        if (!it || it.separator || it.enabled === false) return;
        SoundEvents.requested("menuChoose");
        root.triggered(it, root.path.concat([index]));
        root.closed();
    }

    // Returns true when the key was used.
    function handleKey(key, text) {
        const lv = root.path.length;
        const items = root.itemsAt(lv);
        const nav = root.selectable(items);
        const n = nav.length;
        const pos = nav.indexOf(root.cursor);
        const it = items[root.cursor];
        if (key === Qt.Key_Down) {
            if (n) root.cursor = nav[(pos + 1) % n];
        } else if (key === Qt.Key_Up) {
            if (n) root.cursor = pos < 0 ? nav[n - 1] : nav[(pos - 1 + n) % n];
        } else if ((key === Qt.Key_Right || key === Qt.Key_Return || key === Qt.Key_Enter) && root.hasSub(it)) {
            root.open(root.cursor);
        } else if ((key === Qt.Key_Return || key === Qt.Key_Enter) && it) {
            root.trigger(root.cursor);
        } else if (key === Qt.Key_Left || key === Qt.Key_Escape) {
            if (lv === 0) { root.closed(); return true; }
            const k = root.path[lv - 1];
            root.path = root.path.slice(0, lv - 1);
            root.cursor = k;
            root.sync(false);
        } else if (text && text.length === 1 && /\S/.test(text)) {
            const ch = text.toLowerCase();
            const hits = nav.filter(i => Kit.Win98Tokens.accessKey(items[i].text || "") === ch);
            if (!hits.length) return false;
            const next = hits.find(i => i > root.cursor);
            root.cursor = next !== undefined ? next : hits[0];
            if (hits.length === 1) {
                if (root.hasSub(items[root.cursor])) root.open(root.cursor);
                else root.trigger(root.cursor);
            }
        } else {
            return false;
        }
        return true;
    }

    Keys.onPressed: event => { if (root.handleKey(event.key, event.text)) event.accepted = true; }

    function hover(level, index) {
        const items = root.itemsAt(level);
        const next = root.path.slice(0, level);
        if (root.hasSub(items[index])) next.push(index);
        const changed = next.join("/") !== root.path.join("/");
        const c = next.length === level ? index : -1;
        if (!changed && c === root.cursor) return;
        root.path = next;
        root.cursor = c;
        if (changed) root.sync(true);
    }
    function click(level, index) {
        const items = root.itemsAt(level);
        if (root.hasSub(items[index])) { root.hover(level, index); return; }
        if (level !== root.path.length) root.hover(level, index);
        root.trigger(index);
    }

    // Keep one panel per open level. Panels above the first changed level
    // stay (no second roll-out); the rest are rebuilt.
    ListModel { id: levels }
    function sync(rollNew) {
        const want = [""];
        for (let l = 0; l < root.path.length; l++) want.push(want[l] + "/" + root.path[l]);
        let keep = 0;
        while (keep < levels.count && keep < want.length && levels.get(keep).key === want[keep]) keep++;
        if (levels.count > keep) levels.remove(keep, levels.count - keep);
        for (let l = keep; l < want.length; l++) levels.append({ key: want[l], rolls: rollNew && root.animate });
    }
    Component.onCompleted: {
        levels.append({ key: "", rolls: root.animate });
        root.sync(false);
    }
    onModelChanged: if (levels.count > 0) root.reset()

    Repeater {
        id: panels
        model: levels

        Win98MenuPanel {
            id: panel
            required property int index
            required property bool rolls
            readonly property int level: index
            readonly property Win98MenuPanel parentPanel: index > 0 ? panels.itemAt(index - 1) as Win98MenuPanel : null
            readonly property real boundsWidth: root.bounds ? root.bounds.width : 1e6
            readonly property real boundsHeight: root.bounds ? root.bounds.height : 1e6
            readonly property point origin: root.origin

            items: root.itemsAt(level)
            big: level === 0 && root.big
            bandText: level === 0 ? root.bandText : ""
            bandSubText: level === 0 ? root.bandSubText : ""
            widthUnits: level === 0 ? root.widthUnits : 0
            maxHeight: boundsHeight
            maxWidth: boundsWidth
            // A panel on its way out (index -1) highlights nothing.
            highlighted: level >= 0 && level < root.path.length ? root.path[level] : level === root.path.length ? root.cursor : -1
            roll: !rolls ? "none" : level === 0 ? root.roll : "right"
            width: implicitWidth
            height: implicitHeight
            z: level

            // Right of its parent; left when the right edge is in the way;
            // over the parent when neither side has room. Always inside.
            x: {
                if (!parentPanel) return 0;
                const minX = -origin.x, maxX = boundsWidth - origin.x - width;
                const right = parentPanel.x + parentPanel.width - 3 * root.u;
                const left = parentPanel.x - width + 3 * root.u;
                if (right <= maxX + 0.5) return right;
                if (left >= minX - 0.5) return left;
                return Math.max(minX, Math.min(right, maxX));
            }
            y: {
                if (!parentPanel) return 0;
                let y = parentPanel.y + parentPanel.rowY(root.path[level - 1] || 0) - 3 * root.u;
                y = Math.min(y, boundsHeight - origin.y - height);
                return Math.max(-origin.y, y);
            }

            onHovered: i => root.hover(level, i)
            onClicked: i => root.click(level, i)
        }
    }
}
