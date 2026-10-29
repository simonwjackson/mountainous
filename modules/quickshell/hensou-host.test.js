const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const scope = {};
const source = process.argv[2] || path.join(__dirname, 'hensou-host.js');
vm.runInNewContext(fs.readFileSync(source, 'utf8').replace(/^\.pragma library\s*/, ''), scope);
for (const window of [null, undefined, {}, {devicePixelRatio: 0}, {devicePixelRatio: -1}, {devicePixelRatio: Infinity}])
    assert.equal(scope.devicePixelRatio(window), 1.5);
const first = {devicePixelRatio: 1.5}, second = {devicePixelRatio: 1};
assert.equal(scope.devicePixelRatio(first), 1.5);
assert.equal(scope.devicePixelRatio(second), 1);
second.devicePixelRatio = 2;
assert.equal(scope.devicePixelRatio(first), 1.5, 'second window cannot replace first metrics');
assert.equal(scope.devicePixelRatio(second), 2);
console.log('HENSOU_HOST_METRICS_PASSED');
