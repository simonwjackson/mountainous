const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const policy = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/display-screens.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), policy);
const screens = [{ name: "DP-3" }, { name: "eDP-1" }, { name: "DP-1" }];
const names = rows => Array.from(rows, r => r.name);
assert.deepEqual(names(policy.desktops(screens, [{name: "eDP-1"}, {name: "DP-1"}], true)), ["eDP-1", "DP-1"]);
// Source unplugged: Hyprland promotes the remaining connector.
assert.deepEqual(names(policy.desktops(screens, [{name: "eDP-1"}, {name: "DP-3"}], true)), ["DP-3", "eDP-1"]);
assert.deepEqual(names(policy.desktops(screens, [], true)), []);
assert.equal(policy.desktops(screens, [], false), screens);
assert.deepEqual(names(policy.desktops([], [], true)), []);
console.log("PASS display screens: mirror/disabled exclusion, hot-plug, previews, empty state");
