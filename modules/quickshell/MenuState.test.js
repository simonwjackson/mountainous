// Exercise the actual QML singleton through Qt, including readonly bindings.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "menu-state-"));
try {
    fs.copyFileSync(process.argv[2] || __dirname + "/MenuState.qml", path.join(dir, "MenuState.qml"));
    fs.writeFileSync(path.join(dir, "qmldir"), "singleton MenuState 1.0 MenuState.qml\n");
    fs.writeFileSync(path.join(dir, "test.qml"), `
import QtQuick
import "."
Item {
    function check(value, message) { if (!value) throw new Error(message); }
    Component.onCompleted: {
        try {
            const first = {name: "first"}, second = {name: "second"};
            check(MenuState.current === "" && MenuState.screen === null && MenuState.anchorX === 0, "initially closed");
            MenuState.open("oci", first, 40);
            check(MenuState.current === "oci" && MenuState.screen === first && MenuState.anchorX === 40, "open OCI");
            for (const name of ["bt", "wifi", "vol", "bri", "disk", "ntf", "clock", "more"]) {
                MenuState.open(name, first, 60);
                check(MenuState.current === name, "switch replaces OCI/previous menu");
            }
            MenuState.toggle("more", first, 60);
            check(MenuState.current === "" && MenuState.screen === null && MenuState.anchorX === 0, "toggle open closes and clears anchor");
            MenuState.toggle("oci", first, 80);
            MenuState.toggle("oci", second, 100);
            check(MenuState.current === "oci" && MenuState.screen === second && MenuState.anchorX === 100, "same menu on another screen switches");
            MenuState.open("wifi", second, 120);
            check(MenuState.current === "wifi" && MenuState.screen === second, "hover switch");
            MenuState.close();
            MenuState.close();
            check(MenuState.current === "" && MenuState.screen === null, "close is idempotent (outside click / Escape)");
            MenuState.open("", first, 20);
            check(MenuState.current === "", "empty name stays closed");
            MenuState.open("oci", null, 20);
            check(MenuState.current === "", "no screen stays closed");
            MenuState.open("oci", first, NaN);
            check(MenuState.anchorX === 0, "invalid anchor normalizes to zero");
            let readonly = false;
            try { MenuState.current = "wifi"; } catch (_) { readonly = true; }
            check(readonly && MenuState.current === "oci", "public current is readonly");
            Qt.exit(37); // A distinct success code proves every assertion ran.
        } catch (e) { console.error(e); Qt.exit(1); }
    }
}
`);
    const result = spawnSync(process.env.QML || "qml", [path.join(dir, "test.qml")], {
        encoding: "utf8", timeout: 15000,
        env: {...process.env, QT_QPA_PLATFORM: "offscreen", QT_QUICK_BACKEND: "software"}
    });
    assert.equal(result.status, 37, result.error?.message || result.stdout + result.stderr);
    console.log("MenuState: actual Qt singleton switching, toggling and closing pass");
} finally {
    fs.rmSync(dir, {recursive: true, force: true});
}
