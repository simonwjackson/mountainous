// Parse the backend's actual emitted file with the production QML model.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const text = fs.readFileSync(process.argv[3], "utf8");
const raw = JSON.parse(text);
assert.deepEqual(Object.keys(raw).sort(), ["defaults", "fallback", "pages", "version"]);
assert.equal(raw.version, 1);
assert.deepEqual(raw.fallback, { cap: 1, floating: false, gap: 8 });
assert(!Array.isArray(raw.pages));
assert(!Array.isArray(raw.defaults));
assert.deepEqual(Object.keys(raw.defaults).sort(), ["DP-1", "DP-4"]);
for (const [id, page] of Object.entries(raw.pages)) {
    assert(Number(id) > 0);
    assert.deepEqual(Object.keys(page).sort(), ["cap", "floating", "gap", "monitor", "own", "zen"]);
    assert(Number.isInteger(page.cap) && page.cap >= 1 && page.cap <= 3);
    assert(Number.isInteger(page.gap) && page.gap >= 0 && page.gap <= 48 && page.gap % 4 === 0);
    for (const key of ["floating", "own", "zen"]) assert.equal(typeof page[key], "boolean");
    assert.equal(typeof page.monitor, "string");
}
const parsed = model.parse(text);
assert(parsed, "the production model accepts the state file");
assert.deepEqual(JSON.parse(JSON.stringify(parsed)), { fallback: raw.fallback, defaults: raw.defaults, pages: raw.pages });
const view = model.view(parsed, "DP-4", 1, [1, 3, 4, 5]);
assert(view.available);
assert.equal(view.page.gap, 20);
assert.equal(view.page.zen, true);
assert.equal(view.def.gap, 16);
console.log("page-layout state: production model accepts backend JSON");
