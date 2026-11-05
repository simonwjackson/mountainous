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
assert.match(icon, /source: root\.tokenReady \|\| root\.boxedArt \? "" : root\.siteIcon \? root\.favicon : root\.fallbackSource/, "keep today's image until the token is decoded");
// The Control Strip: one optical size. A site icon's token has opaque
// bounds of opticalExtent px; until it arrives, or with no site icon, the
// build-time strip token draws 1:1. Nothing in the strip is scaled.
assert.match(icon, /readonly property bool boxedArt: root\.artPixels > 0 && \(root\.opticalExtent > 0 \? !root\.tokenReady : !root\.siteIcon\)/);
assert.match(icon, /extent: root\.opticalExtent/);
assert.match(icon, /width: root\.artPixels \/ root\.pixelRatio/);
assert.match(icon, /sourceSize: Qt\.size\(width, height\)\s+smooth: false/);
assert.match(read("PlatinumStripTile.qml"), /artPixels: tile\.g\.canvas\.size\s+opticalExtent: tile\.g\.extent/, "the strip draws its tokens 1:1 at one optical size");
assert.match(read("PlatinumAppIcon.qml"), /Quickshell\.iconPath\("mountainous\.strip\." \+ root\.name, true\)/, "the build-time strip token first");
assert.match(icon, /width: root\.pixels \/ root\.pixelRatio/);
assert.match(icon, /height: root\.pixels \/ root\.pixelRatio/);
assert.match(icon, /smooth: false\s+mipmap: false/);
assert.match(helper, /job\.command = \[root\.helper, root\.source, String\(root\.pixels\), root\.theme\]\s*\.concat\(root\.extent > 0 \? \["--extent", String\(root\.extent\)\] : \[\]\)/, "argv, never shell interpolation");
assert.match(helper, /JSON\.stringify\(\[source, pixels, theme, extent\]\)/, "a new extent is a new request");
assert.match(helper, /job\.activeKey === root\.requestKey/, "late helper replies cannot replace current metadata");
assert.match(helper, /interval: 15000/, "bounded helper lifetime");
for (const name of ["PlatinumAppIcon.qml", "PlatinumFindMenu.qml", "PlatinumGoToAddress.qml"])
    assert.match(read(name), /WindowIcon\s*\{\s*platinumToken: true/, name);
for (const name of ["PlatinumCascadeMenu.qml", "PlatinumStripTile.qml"])
    assert.match(read(name), /PlatinumAppIcon\s*\{/, name);
for (const name of ["Win98Taskbar.qml", "Win98FindWindow.qml", "Win98CoolSwitch.qml"])
    assert.doesNotMatch(read(name), /platinumToken\s*:\s*true/, name);
console.log("PLATINUM_TOKEN_CONTRACTS_PASSED: shared strip/menu/Find path, async fallback, stale replies, exact device pixels, Win98 opt-out");
