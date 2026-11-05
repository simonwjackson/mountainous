// DEV FIXTURE (not delivered): a desktop provider that speaks Hensou's
// desktop protocol (crates/desktop-protocol) for the shell's checks, where
// Hensou's own hensou-desktop-stub binary is not packaged. It answers like
// the stub (the same fixture icons, moves kept, the same replies) and adds
// fixture sets for the stress cases, and logs every message it receives.
//
//   node provider.js <socket> <log> [fixture]
//
// fixture: "stub" (default; hensou-desktop-stub's icons), "stress" (long
// and unbreakable names, unavailable icons, an empty Trash, and more icons
// than the grid holds, cascaded 12 px apart as the provider does), "empty"
// (no icons). Write a fixture name to <socket>.fixture and the provider
// resends a Snapshot with it.
const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");

const [socketPath, logPath, initial] = process.argv.slice(2);
const GRID = { cell_width: 80, cell_height: 72 };
let fixture = initial || "stub";
let snap = false;
let icons = [];
const clients = new Set();

function icon(id, kind, label, generic, row, extra) {
    return Object.assign({
        id, kind, label, art: { type: "generic", kind: generic, path: "" },
        position: { x: 16, y: 16 + row * GRID.cell_height }, available: true, reason: null,
        full: kind === "trash" ? true : null, ejectable: kind === "volume" ? true : null
    }, extra || {});
}

function fixtures(name, theme, screen) {
    const memphis = theme === "win98";
    if (name === "empty") return [];
    const base = [
        icon("computer", "computer", memphis ? "My Computer" : "Myoko", "computer", 0),
        icon("ssh-hosts", "ssh-hosts", memphis ? "Network Neighborhood" : "SSH Hosts", "folder", 1),
        icon("trash", "trash", memphis ? "Recycle Bin" : "Trash", "trash", 2),
        icon("file:notes.txt", "file", "notes.txt", "text", 3),
        icon("file:Projects", "folder", "Projects", "folder", 4),
        icon("file:krita.desktop", "launcher", "Krita", "application", 5, { art: { type: "lettermark", letter: "K", tint: "#3a6ea5" } }),
        icon("file:Docs link", "alias", "Docs link", "folder", 6),
    ];
    if (!memphis) base.push(icon("volume:sdb1", "volume", "USB", "volume", 7));
    if (name !== "stress") return base;
    // The stress set: the longest names, one word with no break, missing
    // and unavailable icons, every generic kind, and a cascade.
    const usable = screen && screen.usable ? screen.usable : { width: 1920, height: 1130 };
    const rows = Math.max(1, Math.floor((usable.height - 16) / GRID.cell_height));
    const out = base.map((i) => Object.assign({}, i));
    out.find((i) => i.id === "trash").full = false;
    const extra = [
        ["file:long", "file", "Quarterly report for the mountain cabin renovation (final, final v3).pdf", "document"],
        ["file:word", "file", "Supercalifragilisticexpialidocious_backup_2026-11-05.tar.zst", "archive"],
        ["file:a", "file", "a", "text"],
        ["file:photo", "file", "Shiretoko at dusk.jpg", "image"],
        ["file:song", "file", "Kamoi — side A.flac", "audio"],
        ["file:clip", "file", "clip.mp4", "video"],
        ["file:gone", "alias", "Broken alias", "folder", { available: false, reason: "The original item could not be found." }],
        ["file:app", "launcher", "Zed", "application", { art: { type: "themed", path: "/run/current-system/sw/share/icons/hicolor/48x48/apps/zed.png" } }],
    ];
    extra.forEach((e, k) => out.push(icon(e[0], e[1], e[2], e[3], 0, Object.assign({ position: { x: 16 + GRID.cell_width * (1 + Math.floor(k / rows)), y: 16 + (k % rows) * GRID.cell_height } }, e[4] || {}))));
    // More icons than the column holds: the provider cascades the rest.
    for (let k = 0; k < 6; k++)
        out.push(icon("file:cascade-" + k, "file", "Scan " + (k + 1) + ".png", "image", 0,
            { position: { x: 16 + GRID.cell_width * 3 + 12 * k, y: 16 + 12 * k } }));
    return out;
}

function log(direction, message) {
    fs.appendFileSync(logPath, direction + " " + JSON.stringify(message) + "\n");
}

function write(socket, message) {
    log(">", message);
    socket.write(JSON.stringify(message) + "\n");
}

function changed(upsert, removed) {
    const message = { type: "changed", upsert, removed };
    for (const c of clients) if (c.subscribed) write(c.socket, message);
}

function handle(client, m) {
    log("<", m);
    const s = client.socket;
    switch (m.type) {
    case "hello":
        if (m.major !== 1) {
            write(s, { type: "error", code: "version", message: "provider speaks 1.x", ids: [] });
            s.end();
            return;
        }
        write(s, { type: "hello", major: 1, minor: 0 });
        return;
    case "subscribe": {
        client.subscribed = true;
        client.theme = m.theme;
        client.screen = m.screen;
        const moved = new Map(icons.map((i) => [i.id, i.position]));
        icons = fixtures(fixture, m.theme, m.screen).map((i) => (moved.has(i.id) && fixture !== "stress" ? Object.assign(i, { position: moved.get(i.id) }) : i));
        write(s, { type: "snapshot", icons, snap, grid: GRID });
        return;
    }
    case "move": {
        const up = [];
        for (const [id, p] of m.moves) {
            const i = icons.find((x) => x.id === id);
            if (!i) continue;
            i.position = snap ? { x: 16 + Math.round((p.x - 16) / GRID.cell_width) * GRID.cell_width, y: 16 + Math.round((p.y - 16) / GRID.cell_height) * GRID.cell_height } : p;
            up.push(i);
        }
        changed(up, []);
        return;
    }
    case "check-trash":
        write(s, { type: "confirm-needed", request: m.request, ids: m.ids, confirmation: { type: "move-to-trash", count: m.ids.length } });
        return;
    case "check-empty-trash":
        write(s, { type: "confirm-needed", request: m.request, ids: ["trash"], confirmation: { type: "empty-trash", count: 3 } });
        return;
    case "trash":
    case "delete-permanently":
        icons = icons.filter((i) => !m.ids.includes(i.id));
        changed([], m.ids);
        return;
    case "empty-trash": {
        const t = icons.find((i) => i.id === "trash");
        if (t) { t.full = false; changed([t], []); }
        return;
    }
    case "drop":
        if (m.target === "trash") {
            write(s, { type: "confirm-needed", request: 0, ids: m.ids, confirmation: { type: "move-to-trash", count: m.ids.length } });
        }
        return;
    case "eject":
        write(s, { type: "error", code: "busy", message: "The volume is in use by ghostty.", ids: [m.id] });
        return;
    case "set-snap":
        snap = m.snap === true;
        for (const c of clients) if (c.subscribed) write(c.socket, { type: "snap", snap });
        return;
    case "arrange":
        icons.forEach((i, row) => { i.position = { x: 16, y: 16 + row * GRID.cell_height }; });
        changed(icons, []);
        return;
    case "rename": {
        const i = icons.find((x) => x.id === m.id);
        if (i) { i.label = m.name; changed([i], []); }
        return;
    }
    }
}

try { fs.unlinkSync(socketPath); } catch (e) { /* none yet */ }
fs.mkdirSync(path.dirname(socketPath), { recursive: true });
const server = net.createServer((socket) => {
    const client = { socket, subscribed: false, theme: "platinum", screen: null };
    clients.add(client);
    let buffer = "";
    socket.on("data", (data) => {
        buffer += data.toString("utf8");
        let at;
        while ((at = buffer.indexOf("\n")) >= 0) {
            const line = buffer.slice(0, at);
            buffer = buffer.slice(at + 1);
            try { handle(client, JSON.parse(line)); } catch (e) { log("!", { error: String(e), line }); }
        }
    });
    socket.on("close", () => clients.delete(client));
    socket.on("error", () => clients.delete(client));
});
server.listen(socketPath, () => console.log("provider listening on " + socketPath));

// A new fixture: a fresh snapshot to every subscriber.
const fixtureFile = socketPath + ".fixture";
setInterval(() => {
    let want;
    try { want = fs.readFileSync(fixtureFile, "utf8").trim(); } catch (e) { return; }
    fs.unlinkSync(fixtureFile);
    fixture = want;
    icons = [];
    for (const c of clients) if (c.subscribed) {
        icons = fixtures(fixture, c.theme, c.screen);
        write(c.socket, { type: "snapshot", icons, snap, grid: GRID });
    }
}, 100);
