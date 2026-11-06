// picker-plan.js: Display Properties' insets, one unit either side of the
// threshold. Run: node picker-plan.test.js picker-plan.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const P = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/picker-plan.js", "utf8")
    .replace(/^\.pragma library\s*$/m, ""), P);

const T = P.COMPACT_WIDTH;
assert.equal(T, 200);
let i = P.insets(T - 1);
assert.equal(i.compact, true, "one unit under the threshold: compact");
assert.deepEqual([i.body, i.sheet], [P.COMPACT.body, P.COMPACT.sheet]);
i = P.insets(T);
assert.equal(i.compact, false, "at the threshold: wide");
assert.deepEqual([i.body, i.sheet], [P.WIDE.body, P.WIDE.sheet]);
i = P.insets(T + 1);
assert.equal(i.compact, false, "one unit over: wide");
assert.deepEqual([i.body, i.sheet], [6, 8]);
// Compact insets are smaller, so a narrow dialog gives its lists the room.
assert.ok(P.COMPACT.body < P.WIDE.body && P.COMPACT.sheet < P.WIDE.sheet);
// The smallest and the largest dialogs.
assert.equal(P.insets(0).compact, true);
assert.equal(P.insets(410).compact, false);

console.log("MEMPHIS_PICKER_PLAN_PASSED");
