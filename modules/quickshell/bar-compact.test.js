const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2] || __dirname + "/bar-plan.js", "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const metrics = JSON.parse(fs.readFileSync(process.argv[3] || __dirname + "/bar-fixtures.json", "utf8")).failedDictationMetrics;
const readouts = {bt: "btCount", vol: "volumeNumber", bri: "brightnessNumber", oci: "ociLabel", disk: "diskLabel", fleet: "fleetCount", builder: "builderLabel", ntf: "notificationCount"};
for (const input of [metrics, {...metrics, chordWidth: 600}, {...metrics, batteryWidth: 0}]) {
    for (let width = 1; width <= 400; width++) {
        const p = model.plan(width, input);
        const edge = p.edge === undefined ? 6 : p.edge;
        const pad = p.pad;
        const items = [];
        if (!p.centred && p.show.clock !== false) items.push({id: "clock", width: p.centreW});
        for (const id of p.controls) {
            const c = input.controls.find(c => c.id === id);
            const readout = p.show[readouts[id]] !== false ? c.readoutWidth : Math.min(c.readoutWidth, c.compactReadoutWidth || 0);
            items.push({id, width: 2 * pad + c.iconWidth + (readout > 0 ? 6 + readout : 0)});
        }
        if (p.overflow.length) items.push({id: "more", width: 2 * pad + (p.overflowIconWidth ?? input.overflowWidth)});
        if (input.batteryWidth > 0 && p.show.battery !== false) items.push({id: "battery", width: 2 * pad + input.batteryWidth});
        if (p.show.app !== false) items.push({id: "app", width: 2 * pad + input.appIconWidth + (p.show.appName ? 6 + input.appNameWidth : 0)});
        let x = width - edge - items.reduce((sum, i) => sum + i.width, 0) - p.gap * Math.max(0, items.length - 1);
        for (const item of items) {
            if (item.id === "more") {
                assert.ok(x >= -1e-6, `» starts at ${x} at width ${width}`);
                assert.ok(x + item.width <= width + 1e-6, `» ends off screen at ${width}`);
                assert.ok(item.width > 0);
            }
            x += item.width + p.gap;
        }
        const markVisible = p.show.mark !== false;
        assert.ok(markVisible || p.overflow[0] === "apple", `Apple menu reachable at ${width}`);
        if (markVisible) assert.ok(edge + 2 * pad + input.markWidth <= width, `mountain on screen at ${width}`);
        for (const id of [...input.controls.map(c => c.id), "clock", "app", ...(input.batteryWidth ? ["battery"] : [])]) {
            const inline = input.controls.some(c => c.id === id) ? p.controls.includes(id) : p.show[id] !== false;
            assert.ok(inline || p.overflow.includes(id), `${id} unreachable at ${width}`);
        }
        assert.ok(p.show.dictationActions || p.overflow.includes("dictation"), `dictation reachable at ${width}`);
        if (width >= 36) assert.equal(markVisible, true, "mountain keeps its full size while two marks fit");
    }
}
console.log("bar-compact: 1–400px sweeps, » geometry and every capability reachable (including Apple below 36px)");
