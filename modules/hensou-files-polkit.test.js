// The udisks2 polkit rule (modules/hensou-files.nix), run against fake
// subjects: the active local user may mount, eject and power off
// removable media; nobody else, and nothing else, is decided by it.
// Run: node hensou-files-polkit.test.js <rule.js>
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const rules = [];
const polkit = { Result: { YES: "yes", NO: "no", AUTH_ADMIN: "auth_admin", NOT_HANDLED: null }, addRule: (f) => rules.push(f) };
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8"), { polkit });
assert.equal(rules.length, 1);
const decide = (id, s) => rules[0]({ id }, Object.assign({ local: true, active: true, user: "simon",
    isInGroup: (g) => (s && s.groups ? s.groups : ["users", "wheel"]).includes(g) }, s || {}));
for (const id of ["org.freedesktop.udisks2.filesystem-mount", "org.freedesktop.udisks2.eject-media", "org.freedesktop.udisks2.power-off-drive"])
    assert.equal(decide(id), "yes", id);
for (const id of ["org.freedesktop.udisks2.filesystem-mount-system", "org.freedesktop.udisks2.power-off-drive-system",
    "org.freedesktop.udisks2.eject-media-system", "org.freedesktop.udisks2.modify-device", "org.freedesktop.udisks2.filesystem-mount-other-seat",
    "org.freedesktop.login1.reboot"])
    assert.equal(decide(id), null, id + " is left to its defaults");
assert.equal(decide("org.freedesktop.udisks2.filesystem-mount", { active: false }), null, "an inactive session");
assert.equal(decide("org.freedesktop.udisks2.filesystem-mount", { local: false }), null, "a remote (SSH) session");
assert.equal(decide("org.freedesktop.udisks2.eject-media", { groups: ["nogroup"] }), null, "a system user");
console.log("udisks2 rule: removable media for the active local user only");
