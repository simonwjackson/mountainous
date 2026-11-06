import Quickshell
import QtQuick

// One app's dbusmenu (a StatusNotifierItem's menu), loaded and kept as
// plain entries for the theme menus (tray-model.js sniMenu, menu-models.js
// sniRows):
//   [{ text, enabled, separator, check: "none" | "checkbox" | "radio",
//      checked, children: [...] | undefined, ref (the QsMenuEntry) }]
// Each submenu loads through its own opener, three levels deep at most.
// The owner keeps the tree alive while the menu is open and until its
// chosen entry has run (ref.triggered()).
Item {
    id: root

    property var menu: null
    property int depth: 0
    readonly property int maxDepth: 3

    QsMenuOpener {
        id: opener
        menu: root.menu
    }
    readonly property var children_: opener.children ? opener.children.values : []

    // Child trees, one per entry that has children.
    Instantiator {
        id: subs
        model: root.depth < root.maxDepth ? root.children_ : []
        delegate: Loader {
            required property var modelData
            active: !!modelData && modelData.hasChildren
            source: "SniMenuTree.qml"
            onLoaded: { item.depth = root.depth + 1; item.menu = modelData; }
        }
    }

    function checkName(t) {
        return t === QsMenuButtonType.CheckBox ? "checkbox" : t === QsMenuButtonType.RadioButton ? "radio" : "none";
    }

    readonly property var entries: {
        subs.count;
        const out = [];
        for (let i = 0; i < root.children_.length; i++) {
            const e = root.children_[i];
            if (!e) continue;
            if (e.isSeparator) { out.push({ separator: true }); continue; }
            const row = { text: e.text, enabled: e.enabled, separator: false, check: root.checkName(e.buttonType),
                checked: e.checkState === Qt.Checked, ref: e };
            if (e.hasChildren) {
                const l = subs.objectAt(i);
                row.children = l && l.item ? l.item.entries : [];
            }
            out.push(row);
        }
        return out;
    }
}
