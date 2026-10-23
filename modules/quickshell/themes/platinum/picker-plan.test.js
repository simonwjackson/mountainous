const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const policy = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + '/picker-plan.js', 'utf8'), policy);
for (const [w, h] of [[1920,1200], [960,600], [240,800], [1200,180], [160,150], [160,80], [80,800], [160,40]]) {
    const p = policy.plan(w, h);
    assert.ok(p.width > 0 && p.width <= w);
    assert.ok(p.height > 0 && p.height <= h);
    assert.ok(p.padding >= 0 && p.gap <= p.padding);
    const overhead = 2 * p.padding + p.headerHeight + (p.headerHeight ? p.gap : 0)
        + p.tabsHeight + (p.tabsHeight ? p.gap : 0);
    assert.ok(p.height - overhead > 0, 'decoration must leave a positive body viewport');
}
// Every structural boundary, one pixel either side.
for (const width of [policy.galleryMinWidth - 1, policy.galleryMinWidth, policy.galleryMinWidth + 1]) {
    for (const height of [policy.galleryMinHeight - 1, policy.galleryMinHeight, policy.galleryMinHeight + 1]) {
        const p = policy.plan(width, height);
        assert.equal(p.thumbnails, width >= policy.galleryMinWidth && height >= policy.galleryMinHeight);
        assert.equal(p.tabsHeight > 0, p.thumbnails);
    }
}
for (const [height, closeInBody] of [[164,true], [165,false], [166,false]]) {
    assert.equal(policy.plan(160,height).closeInBody, closeInBody);
}
assert.equal(policy.plan(160,80).thumbnails, false);
assert.equal(policy.plan(1200,180).thumbnails, false);
assert.equal(policy.plan(80,800).thumbnails, false);
for (const width of [139,140,141]) assert.equal(policy.plan(width,800).stackedOption, width < policy.optionRowMinWidth);
console.log('PICKER_PLAN_TESTS_PASSED');
