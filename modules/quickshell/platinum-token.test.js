// Delivery and caller contracts. Real decoding/process/DPR tests live in
// theme-dev/favicon-runtime.py; renderer/cache tests use the same packaged CLI.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const dir = process.argv[2] || __dirname;
const read = name => fs.readFileSync(path.join(dir, name), "utf8");
const icon = read("WindowIcon.qml"), helper = read("PlatinumToken.qml");
assert.match(icon, /property bool platinumToken: false/, "Win98 must not opt in implicitly");
assert.match(icon, /root\.platinumToken && CdpTarget\.isBrowser\(CdpTarget\.appIdOf\(root\.toplevel\)\)/, "only Chromium gets generated tokens");
assert.match(icon, /source: root\.tokenReady \? "" : root\.siteIcon \? root\.favicon : root\.fallbackSource/, "keep today's image until the token is decoded");
assert.match(icon, /width: root\.pixels \/ root\.pixelRatio/);
assert.match(icon, /height: root\.pixels \/ root\.pixelRatio/);
assert.match(icon, /smooth: false\s+mipmap: false/);
assert.match(helper, /job\.command = \[root\.helper, root\.source, String\(root\.pixels\), root\.theme\]/, "argv, never shell interpolation");
assert.match(helper, /job\.activeKey === root\.requestKey/, "late helper replies cannot replace current metadata");
assert.match(helper, /interval: 15000/, "bounded helper lifetime");
for (const name of ["PlatinumAppIcon.qml", "PlatinumFindMenu.qml", "PlatinumGoToAddress.qml"])
    assert.match(read(name), /WindowIcon\s*\{\s*platinumToken: true/, name);
for (const name of ["PlatinumCascadeMenu.qml", "PlatinumStripTile.qml"])
    assert.match(read(name), /PlatinumAppIcon\s*\{/, name);
for (const name of ["Win98Taskbar.qml", "Win98FindWindow.qml", "Win98CoolSwitch.qml"])
    assert.doesNotMatch(read(name), /platinumToken\s*:\s*true/, name);
console.log("PLATINUM_TOKEN_CONTRACTS_PASSED: shared strip/menu/Find path, async fallback, stale replies, exact device pixels, Win98 opt-out");
