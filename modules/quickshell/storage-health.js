.pragma library
// Pure transport-to-view boundary; also consumed by the offline fixture tests.
function parse(value, now) {
    const rows = [];
    let oldest = now;
    if (!value.trim()) return {state: "error"};
    for (const line of value.trim().split("\n")) {
        const f = line.split("\t");
        if (f.length !== 4 || !f[0] || !f[2]
            || !["ok", "warn", "bad", "unreachable"].includes(f[1])
            || !/^[0-9]{10}$/.test(f[3])) return {state: "error"};
        const time = Number(f[3]) * 1000;
        if (time > now + 120000) return {state: "error"};
        oldest = Math.min(oldest, time);
        rows.push({host: f[0], level: f[1], message: f[2]});
    }
    return {state: ageState("ready", oldest, now), rows: rows, checkedAt: oldest};
}

function ageState(state, checkedAt, now) {
    return state === "ready" && (now - checkedAt > 600000 || now < checkedAt - 120000)
        ? "stale" : state;
}
