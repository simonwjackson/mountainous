// The engine test copies this entry point to its isolated runtime root.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root
    property int requestedWidth: 160
    property int requestedHeight: 80
    QtObject {
        id: state
        property var choices: ThemePicker.choices
        property string currentTheme: "platinum"
        property string currentMode: "dark"
        property bool soundsEnabled: true
        function setSounds(enabled) { soundsEnabled = enabled; }
        property bool extraDark: false
        property bool applying: false
        property string error: ""
        property int applied: 0
        function apply(theme, mode, extra) {
            currentMode = mode;
            extraDark = extra;
            applied++;
        }
        function close() {
        }
        function preview(theme, mode) {
            return ThemePicker.preview(theme, mode);
        }
    }
    PlatinumPickerView {
        id: picker
        model: state
        anchors.bottom: false
        anchors.right: false
        implicitWidth: root.requestedWidth
        implicitHeight: root.requestedHeight
    }
    function find(name, item) {
        item = item || picker.contentItem;
        if (item.objectName === name && item.visible)
            return item;
        for (const child of item.children) {
            const result = root.find(name, child);
            if (result)
                return result;
        }
        return null;
    }
    function geometry(item, body) {
        const point = item.mapToItem(picker.contentItem, 0, 0);
        let parent = item.parent;
        while (parent && parent !== body.contentItem)
            parent = parent.parent;
        return {
            name: item.objectName,
            x: point.x,
            y: point.y,
            width: item.width,
            height: item.height,
            inBody: parent === body.contentItem,
            contentY: item.mapToItem(body.contentItem, 0, 0).y
        };
    }
    IpcHandler {
        target: "geometry"
        function resize(width: int, height: int): void {
            root.requestedWidth = width;
            root.requestedHeight = height;
        }
        function focus(name: string): void {
            const item = root.find(name);
            if (item)
                item.forceActiveFocus();
        }
        function scroll(y: real): void {
            const body = root.find("pickerBody");
            body.contentY = Math.max(0, Math.min(y, Math.max(0, body.contentHeight - body.height)));
        }
        function populate(count: int): void {
            const choices = ThemePicker.choices;
            state.choices = Array.from({
                length: count
            }, function (_, i) {
                return choices[i % choices.length];
            });
        }
        function fail(): void {
            state.error = "The appearance could not be changed. Check the desktop preference service and try again.";
        }
        function snapshot(): string {
            const body = root.find("pickerBody");
            if (!body)
                return "{}";
            const items = [];
            function walk(item) {
                if (item.visible && item.objectName.indexOf("picker") === 0)
                    items.push(root.geometry(item, body));
                for (const child of item.children)
                    walk(child);
            }
            walk(picker.contentItem);
            return JSON.stringify({
                width: picker.width,
                height: picker.height,
                items: items,
                body: Object.assign(root.geometry(body, body), {
                    contentHeight: body.contentHeight,
                    scrollY: body.contentY
                }),
                thumbnails: picker.plan.thumbnails,
                closeInBody: picker.plan.closeInBody,
                choiceCount: state.choices.length
            });
        }
    }
}
