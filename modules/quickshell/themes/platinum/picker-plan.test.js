const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const policy = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + '/picker-plan.js', 'utf8'), policy);
for (const [w, h] of [[1920,1200], [960,600], [240,800], [1200,180], [160,150], [299,299], [300,300], [301,301]]) {
    const p = policy.plan(w, h);
    assert.ok(p.width > 0 && p.width <= w);
    assert.ok(p.height > 0 && p.height <= h);
    assert.ok(p.padding >= 2 && p.gap <= p.padding);
    assert.equal(p.showNote, h >= 300);
}
console.log('PICKER_PLAN_TESTS_PASSED');
