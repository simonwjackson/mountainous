// argv is never interpreted by a shell, nor expanded by systemd-run.
function validArgv(argv) {
    return Array.isArray(argv) && argv.length > 0 && argv[0] !== ""
        && argv.every(function (arg) { return typeof arg === "string" && arg.indexOf("\0") < 0; });
}

function validMeta(meta) {
    return meta && typeof meta.id === "string" && meta.id !== ""
        && typeof meta.name === "string" && typeof meta.icon === "string"
        && ["app", "webapp", "command"].indexOf(meta.kind) >= 0;
}

function scopeCommand(argv, id, nonce) {
    const slug = id.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 64) || "command";
    return ["env", "-u", "NOTIFY_SOCKET", "-u", "WATCHDOG_USEC", "-u", "WATCHDOG_PID", "systemd-run", "--user", "--scope", "--slice=app.slice", "--collect", "--quiet",
        "--expand-environment=no", "--unit=app-" + slug + "-" + nonce, "--"].concat(argv);
}

function entryArgv(entry) {
    let argv = Array.from(entry.command || []);
    if (!validArgv(argv)) return [];
    if (entry.workingDirectory) argv = ["env", "--chdir=" + entry.workingDirectory].concat(argv);
    if (entry.runInTerminal) argv = ["ghostty", "-e"].concat(argv);
    return argv;
}

function readRecent(text) {
    let rows;
    try { rows = JSON.parse(text); } catch (_) { return []; }
    if (!Array.isArray(rows)) return [];
    const seen = {};
    return rows.filter(function (row) {
        return validMeta(row) && row.kind !== "command" && validArgv(row.argv)
            && typeof row.lastLaunched === "number" && isFinite(row.lastLaunched) && row.lastLaunched > 0;
    }).sort(function (a, b) { return b.lastLaunched - a.lastLaunched; }).filter(function (row) {
        const key = row.kind + ":" + row.id;
        if (Object.prototype.hasOwnProperty.call(seen, key)) return false;
        seen[key] = true;
        return true;
    }).slice(0, 10).map(function (row) {
        return {id: row.id, name: row.name, icon: row.icon, kind: row.kind,
            argv: row.argv.slice(), lastLaunched: row.lastLaunched};
    });
}

function record(recent, argv, meta, now) {
    if (!validMeta(meta) || meta.kind === "command") return recent;
    const next = [{id: meta.id, name: meta.name, icon: meta.icon, kind: meta.kind,
        argv: argv.slice(), lastLaunched: now}].concat(recent.filter(function (row) {
            return row.id !== meta.id || row.kind !== meta.kind;
        }));
    return readRecent(JSON.stringify(next));
}
