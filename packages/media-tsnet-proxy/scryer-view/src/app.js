// Scryer's media view (ui://scryer/media.html). Two card shapes from one page:
//   search tiles  after scryer_search: each result with Add and Monitor
//   title card    after scryer_title: seasons, what is monitored, what is on disk,
//                 with Monitor and Unmonitor per season and per episode
// Buttons call the app-only tools scryer_add and scryer_monitor. Both end with a
// fresh read of the title, and the view draws only that read: it never shows a
// change that Scryer did not report back. Deletes and restores are not here.
import { App, applyDocumentTheme, applyHostFonts, applyHostStyleVariables } from "@modelcontextprotocol/ext-apps/app-with-deps";
import { plan } from "./plan.js";
import { mediaGrid, pixelSvg } from "./pixel.js";
import {
  KIND_WORDS, SCOPES, classify, failureText, formatSize, libraryBadges, mark, metaLine, plural, sameNames,
  scopeLabel, scopeWords, seasonName, seasonSummary, shortDate, titleSummary, years,
} from "./model.js";

const root = document.getElementById("root");
/** Hydration is re-read this often, for at most this long, while the card is open. */
const POLL_MS = 5000, POLL_FOR_MS = 120_000;

const s = {
  mode: "inline", modes: [], fixedHeight: undefined, dims: undefined, locale: undefined,
  waiting: true, // nothing from the host yet
  asked: undefined, // the tool input: { tool, args } while its result is on the way
  data: undefined, // classify() of the result on screen
  back: undefined, // the search a title was opened from
  loading: undefined, // a title being read after Open: its name
  loadError: undefined,
  writing: undefined, // { key, label } of the one write in flight
  errors: new Map(), // control key -> failure text
  blocked: false, // the host refused the view's own tool calls
  choosing: undefined, // key of the tile or title whose scope choice is open
  open: new Set(), // season numbers open in the full view
  polledSince: undefined, pollTimer: undefined, checkedAt: undefined,
  badPosters: new Set(), // posters that failed to load: the pixel kind stands in
  lastContext: "",
};
const today = () => new Date(Date.now() - new Date().getTimezoneOffset() * 60_000).toISOString().slice(0, 10);
const app = new App({ name: "scryer-media", version: "1.0.0" }, { availableDisplayModes: ["inline", "fullscreen"] });

// ---------- host ----------
function applyContext(ctx) {
  if (!ctx) return;
  if (ctx.theme) applyDocumentTheme(ctx.theme);
  if (ctx.styles?.variables) applyHostStyleVariables(ctx.styles.variables);
  if (ctx.styles?.css?.fonts) applyHostFonts(ctx.styles.css.fonts);
  if (ctx.locale) s.locale = ctx.locale;
  if (ctx.availableDisplayModes) s.modes = ctx.availableDisplayModes;
  if (ctx.displayMode && (s.mode !== "expanded" || ctx.displayMode === "fullscreen")) s.mode = ctx.displayMode;
  if (ctx.containerDimensions) s.dims = ctx.containerDimensions;
  // Inline, hosts such as OpenClaw report the frame's current height and then grow the
  // frame to the height the card reports. Read as fixed, that height would pin the card
  // at its first size. So a height is fixed only in full screen; inline, the card takes
  // its natural height and the host decides how much of it to show.
  s.fixedHeight = s.mode === "fullscreen" && s.dims && "height" in s.dims ? s.dims.height : undefined;
  document.documentElement.classList.toggle("fixed-h", s.fixedHeight !== undefined);
  const inset = ctx.safeAreaInsets;
  if (inset) root.style.padding = `${inset.top}px ${inset.right}px ${inset.bottom}px ${inset.left}px`;
}
app.onhostcontextchanged = (ctx) => { applyContext(ctx); render(); };
app.ontoolinput = ({ arguments: args }) => {
  s.waiting = false;
  s.asked = { args: args ?? {} };
  render();
};
app.ontoolresult = (result) => {
  s.waiting = false;
  s.asked = undefined;
  if (result?.isError) { s.loadError = errorText(result); render(); return; }
  show(classify(result?.structuredContent));
};
app.onerror = (e) => console.error("[scryer media]", e);
addEventListener("resize", () => render());

function errorText(result) {
  const text = result?.content?.find?.((c) => c.type === "text")?.text ?? "";
  try { return JSON.parse(text).message ?? text; } catch { return text || "Scryer did not answer."; }
}
/** Calls one of this server's tools from the view. Throws with the person's words. */
async function call(name, args) {
  let result;
  try { result = await app.callServerTool({ name, arguments: args }); } catch (e) {
    const f = failureText(e);
    if (f.blocked) s.blocked = true;
    throw new Error(f.text);
  }
  if (result?.isError) {
    const f = failureText(errorText(result));
    if (f.blocked) s.blocked = true;
    throw new Error(f.text);
  }
  const data = classify(result?.structuredContent);
  if (data.view === "unknown") throw new Error(`${name} returned nothing the card can draw.`);
  return data;
}

/** Puts a result on screen. A title opens its most useful season in the full view. */
function show(data) {
  s.loadError = undefined;
  if (data.view === "title" && (s.data?.view !== "title" || s.data.title.id !== data.title.id)) {
    s.open = new Set();
    const t = today();
    const first = data.seasons.find((x) => { const n = seasonSummary(x, t); return n.wanted > 0 || n.waiting > 0; }) ?? data.seasons.findLast((x) => x.number !== 0);
    if (first) s.open.add(first.number);
  }
  s.data = data;
  if (data.view === "unknown") s.loadError = "This result has nothing the card can draw.";
  watchHydration();
  render();
}

// ---------- hydration: honest, bounded re-reads ----------
function watchHydration() {
  clearTimeout(s.pollTimer);
  const pending = s.data?.view === "title" && s.data.title.hydration === "pending";
  if (!pending) { s.polledSince = undefined; return; }
  s.polledSince ??= Date.now();
  if (Date.now() - s.polledSince > POLL_FOR_MS) return; // stop; the card says so and offers a check
  s.pollTimer = setTimeout(async () => {
    try {
      const fresh = await call("scryer_title", { titleId: s.data.title.id });
      s.checkedAt = new Date();
      s.data = fresh;
      if (fresh.title.hydration !== "pending") show(fresh); else { render(); watchHydration(); }
    } catch { render(); }
  }, POLL_MS);
}

// ---------- writes ----------
/**
 * Runs one write. While it runs, every other write control waits. On failure the
 * card reads the title again, so what it shows is Scryer's state, not a guess.
 */
async function write(key, errKey, tool, args, after) {
  if (s.writing) return;
  s.writing = { key };
  s.errors.delete(errKey);
  render();
  try {
    const fresh = await call(tool, args);
    after(fresh);
  } catch (e) {
    // A host block is said once, above the card; a Scryer failure is said at the control.
    if (s.blocked) return; // finally still clears the write and redraws
    const id = args.titleId;
    let reread = false;
    try {
      // Read again what this write touched: the title, or for an add, the search itself.
      if (id) { after(await call("scryer_title", { titleId: id })); reread = true; }
      else if (s.data?.view === "search") {
        const fresh = await call("scryer_search", { query: s.data.query });
        if (fresh.view === "search") { s.data.results = fresh.results; reread = true; }
      }
    } catch { /* said below */ }
    s.errors.set(errKey, reread ? `${e.message} The card shows what Scryer reports now.` : `${e.message} The change may or may not have happened; ask in the chat to check.`);
  } finally {
    s.writing = undefined;
    render();
  }
}
/** A title read after a write, folded back into the search tile it came from. */
function intoTile(key) {
  return (fresh) => {
    if (s.data?.view !== "search") return;
    const t = fresh.title, n = titleSummary(fresh.seasons, today());
    s.data.results = s.data.results.map((r) => r.key !== key ? r : {
      ...r,
      library: {
        titleId: t.id, monitored: t.monitored, monitorType: t.monitorType, hydration: t.hydration,
        onDisk: t.kind === "movie" ? (fresh.movie ? { have: fresh.movie.onDisk ? 1 : 0, total: 1 } : undefined) : n.total ? { have: n.disk, total: n.total } : undefined,
      },
    });
  };
}
const intoTitle = (fresh) => { s.data = fresh; watchHydration(); };

async function openTitle(titleId, name) {
  if (s.data?.view === "search") s.back = s.data;
  s.loading = name;
  s.loadError = undefined;
  render();
  try {
    const t = await call("scryer_title", { titleId });
    s.loading = undefined;
    show(t);
    openFull();
  } catch (e) {
    s.loading = undefined;
    s.data = s.back; s.back = undefined;
    const key = s.data?.results?.find((r) => r.library?.titleId === titleId)?.key;
    if (key) s.errors.set(key, e.message);
    render();
  }
}
async function openFull() {
  if (s.mode === "fullscreen" || s.mode === "expanded") return;
  if (s.modes.includes("fullscreen")) {
    try { const r = await app.requestDisplayMode({ mode: "fullscreen" }); if (r?.mode === "fullscreen") { s.mode = "fullscreen"; applyContext({}); render(); return; } } catch { /* fall back below */ }
  }
  s.mode = "expanded"; render();
}
async function closeFull() {
  if (s.mode === "expanded") { s.mode = "inline"; render(); return; }
  try { await app.requestDisplayMode({ mode: "inline" }); s.mode = "inline"; applyContext({}); } catch { /* the host keeps its own close */ }
  render();
}

// ---------- model context ----------
/** The model does not see the card. This tells it what is on screen, sent only on change. */
function pushContext() {
  const d = s.data;
  if (!d || d.view === "unknown") return;
  let text;
  if (d.view === "search") {
    text = [`Scryer search card for "${d.query}": ${plural(d.results.length, "result", "results")}.`,
      ...d.results.map((r) => `- ${r.name} (${metaLine(r)}), key ${r.key}${r.library ? `, in library as ${r.library.titleId}, ${r.library.monitored ? (r.library.monitorType ? scopeWords(r.library.monitorType) : "monitored") : "not monitored"}` : ", not in library"}`)].join("\n");
  } else {
    const n = titleSummary(d.seasons, today());
    text = [`Scryer title card: ${d.title.name} (${metaLine(d.title)}), title id ${d.title.id}.`,
      `Monitoring: ${scopeLabel(d.title, n)}. Episodes: ${n.total}, on disk ${n.disk}, wanted ${n.wanted}, upcoming ${n.waiting}, not monitored ${n.off}.`,
      d.title.hydration === "pending" ? "Scryer is still reading this title's episodes." : ""].filter(Boolean).join("\n");
  }
  if (text === s.lastContext) return;
  s.lastContext = text;
  app.updateModelContext({ content: [{ type: "text", text }] }).catch(() => {});
}

// ---------- render helpers ----------
const esc = (t) => String(t).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const attr = (o) => Object.entries(o).filter(([, v]) => v !== undefined && v !== false).map(([k, v]) => (v === true ? k : `${k}="${esc(v)}"`)).join(" ");
const spinner = `<span class="spin" aria-hidden="true"></span>`;
const chevron = (dir) => `<svg class="chev" viewBox="0 0 16 16" aria-hidden="true"><path d="${dir < 0 ? "M10 3 5 8l5 5" : dir > 0 ? "M6 3l5 5-5 5" : "M3 6l5 5 5-5"}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;

/**
 * A write button. While its own write runs it says what it is doing; while another
 * runs it waits. After a host policy block, writes stay off and say why once.
 */
function writeButton({ key, act, label, busyLabel, primary, data = {}, aria }) {
  const mine = s.writing?.key === key;
  const off = Boolean(s.writing) || s.blocked;
  return `<button ${attr({ class: primary ? "btn primary" : "btn", "data-act": act, "data-key": key, disabled: off, "aria-busy": mine ? "true" : undefined, "aria-label": aria, ...Object.fromEntries(Object.entries(data).map(([k, v]) => [`data-${k}`, v])) })}>${mine ? `${spinner}${esc(busyLabel)}` : esc(label)}</button>`;
}
const errorLine = (key) => (s.errors.has(key) ? `<p class="fail" role="alert">${esc(s.errors.get(key))}</p>` : "");
const blockedNote = () => (s.blocked ? `<p class="notice" role="status"><span>This chat does not let the card change Scryer. Ask in the chat instead.</span></p>` : "");

/** The poster's place: the poster when Scryer has one, else the kind in pixels and the year. */
function art(t, size) {
  if (t.poster && !s.badPosters.has(t.poster)) return `<div class="art" data-poster aria-hidden="true"><img src="${esc(t.poster)}" alt="" loading="lazy" decoding="async" referrerpolicy="no-referrer"></div>`;
  if (!t.kind) return `<div class="art" aria-hidden="true"><span class="skeleton fill"></span></div>`;
  return `<div class="art" data-size="${size}" aria-hidden="true">${pixelSvg(mediaGrid(t.kind), "glyph")}${t.year !== undefined ? `<span class="art-year">${t.year}</span>` : ""}</div>`;
}
function badges(list) {
  if (!list.length) return "";
  return `<ul class="badges">${list.map((b) => `<li class="badge" data-tone="${b.tone}">${b.tone === "busy" ? spinner : ""}${esc(b.text)}</li>`).join("")}</ul>`;
}
function overview(text, lines) {
  if (!text) return "";
  return `<details class="overview" style="--lines:${lines}"><summary><span class="clamp">${esc(text)}</span><span class="more">Show more</span></summary><p>${esc(text)}</p></details>`;
}

/** The scope choice for a whole show: the three exact scopes, seasons, or (when in library) stop. */
function scopeChoice(key, { titleId, candidateKey, current, inLibrary, monitored }) {
  const opts = SCOPES.map((o) => writeButton({
    key: `${key}:${o.type}`, act: inLibrary ? "scope" : "add", label: o.label, busyLabel: inLibrary ? "Saving…" : "Adding…",
    primary: o.type === current, data: { title: titleId, cand: candidateKey, type: o.type, err: key },
  })).join("");
  const seasons = inLibrary
    ? (s.data?.view === "title" ? "" : `<button class="btn" data-act="open" data-title="${esc(titleId)}">Choose seasons</button>`)
    : writeButton({ key: `${key}:seasons`, act: "add-pick", label: "Choose seasons", busyLabel: "Adding…", data: { cand: candidateKey, err: key } });
  const stop = inLibrary && monitored ? writeButton({ key: `${key}:NONE`, act: "scope", label: "Stop monitoring", busyLabel: "Saving…", data: { title: titleId, type: "NONE", err: key } }) : "";
  return `<div class="choice" role="group" aria-label="Monitor which episodes?"><p class="choice-q">Monitor which episodes?</p><div class="choice-opts">${opts}${seasons}${stop}<button class="btn quiet" data-act="cancel">Cancel</button></div></div>`;
}

// ---------- search tiles ----------
function tileActions(c) {
  const lib = c.library, key = c.key;
  if (!lib) {
    const monitor = c.kind === "movie"
      ? writeButton({ key: `${key}:monitor`, act: "add", label: "Monitor", busyLabel: "Adding…", data: { cand: key, type: "ALL_EPISODES", err: key }, aria: `Add and monitor ${c.name}` })
      : `<button class="btn" data-act="choose" data-key="${esc(key)}:choose" data-choose="${esc(key)}" ${s.writing || s.blocked ? "disabled" : ""} aria-expanded="${s.choosing === key}" aria-label="Monitor ${esc(c.name)}">Monitor</button>`;
    const add = writeButton({ key: `${key}:add`, act: "add", label: "Add", busyLabel: "Adding…", data: { cand: key, type: "NONE", err: key }, aria: `Add ${c.name} without monitoring` });
    return monitor + add;
  }
  const open = `<button class="btn" data-act="open" data-key="${esc(key)}:open" data-title="${esc(lib.titleId)}" data-name="${esc(c.name)}">Open</button>`;
  if (lib.monitored && lib.monitorType !== "NONE")
    return open + writeButton({ key: `${key}:unmonitor`, act: "scope", label: "Unmonitor", busyLabel: "Saving…", data: { title: lib.titleId, type: "NONE", err: key, tile: key }, aria: `Stop monitoring ${c.name}` });
  if (c.kind === "movie")
    return open + writeButton({ key: `${key}:monitor`, act: "scope", label: "Monitor", busyLabel: "Saving…", data: { title: lib.titleId, type: "ALL_EPISODES", err: key, tile: key }, aria: `Monitor ${c.name}` });
  return open + `<button class="btn" data-act="choose" data-key="${esc(key)}:choose" data-choose="${esc(key)}" ${s.writing || s.blocked ? "disabled" : ""} aria-expanded="${s.choosing === key}">Monitor</button>`;
}
function tile(c, twin) {
  const meta = metaLine(c);
  return `<article class="tile" data-tile="${esc(c.key)}" aria-label="${esc(c.year ? `${c.name} (${c.year})` : c.name)}"><div class="tile-grid">
    ${art(c, "tile")}
    <div class="tile-head">
      <h3 class="tile-title">${esc(c.name)}</h3>
      <p class="tile-meta${twin ? " twin" : ""}">${esc(meta)}</p>
    </div>
    <div class="tile-body">${badges(libraryBadges(c.library, c.kind))}${overview(c.overview, 2)}</div>
    <div class="tile-actions">${tileActions(c)}</div>
    ${s.choosing === c.key ? `<div class="tile-extra">${scopeChoice(c.key, { titleId: c.library?.titleId, candidateKey: c.key, current: c.library?.monitorType, inLibrary: Boolean(c.library), monitored: c.library?.monitored })}</div>` : ""}
    ${s.errors.has(c.key) ? `<div class="tile-extra">${errorLine(c.key)}</div>` : ""}
  </div></article>`;
}
function skeletonTile() {
  return `<article class="tile is-wait" aria-hidden="true"><div class="tile-grid"><div class="art"><span class="skeleton fill"></span></div>
    <div class="tile-head"><span class="skeleton line w60"></span><span class="skeleton line w40"></span></div>
    <div class="tile-body"><span class="skeleton line w90"></span><span class="skeleton line w70"></span></div></div></article>`;
}
function searchHtml(p) {
  const d = s.data, twins = sameNames(d.results);
  const head = `<header class="bar">
      <h1 class="bar-title">${d.results.length ? `${plural(d.results.length, "result", "results")} for “${esc(d.query)}”` : `No results for “${esc(d.query)}”`}</h1>
    </header>`;
  if (!d.results.length)
    return `<section class="card">${head}<p class="empty">Scryer found no movie, series or anime with that name. Try the original title or a year.</p></section>`;
  const tiles = d.results.slice(0, p.shown).map((c) => tile(c, twins.has(c.key))).join("");
  const more = p.more ? `<footer class="foot"><button class="btn" data-act="full">Show all ${d.results.length} results</button></footer>` : "";
  return `<section class="card ${p.kind}" data-cols="${p.columns}">${head}${blockedNote()}<div class="tiles scroll-${p.scroll}" data-scroll="list">${tiles}</div>${more}</section>`;
}

// ---------- title card ----------
/** One season's episodes as marks: on disk, wanted, upcoming, not monitored. */
function strip(season, t) {
  const n = seasonSummary(season, t);
  if (!n.total) return `<span class="strip-none">No episodes listed yet</span>`;
  return `<span class="strip" role="img" aria-label="${esc(countWords(n))}">${season.episodes.map((e) => `<i data-m="${mark(e, t)}"></i>`).join("")}</span>`;
}
/** The counts, each word led by its own mark, so the strip needs no legend. */
function counts(n, short) {
  const part = (m, v, word) => (v ? `<span class="count"><i data-m="${m}" aria-hidden="true"></i>${v} ${word}</span>` : "");
  return `<span class="counts">${part("disk", n.disk, short ? "on disk" : `of ${n.total} on disk`)}${part("wanted", n.wanted, "wanted")}${part("waiting", n.waiting, "upcoming")}${part("off", n.off, "not monitored")}</span>`;
}
function countWords(n) {
  return [n.disk && `${n.disk} on disk`, n.wanted && `${n.wanted} wanted`, n.waiting && `${n.waiting} upcoming`, n.off && `${n.off} not monitored`].filter(Boolean).join(", ");
}
function seasonButtons(season, n, titleId) {
  const name = seasonName(season.number), key = `season:${season.number}`;
  const on = writeButton({ key: `${key}:on`, act: "season", label: n.state === "some" ? "Monitor all" : "Monitor", busyLabel: "Saving…", data: { season: season.number, on: "1", title: titleId, err: key }, aria: `Monitor every episode of ${name}` });
  const off = writeButton({ key: `${key}:off`, act: "season", label: "Unmonitor", busyLabel: "Saving…", data: { season: season.number, on: "0", title: titleId, err: key }, aria: `Stop monitoring ${name}` });
  if (n.state === "empty") return "";
  return `<span class="season-acts">${n.state === "all" ? off : n.state === "none" ? on : on + off}</span>`;
}
function seasonRow(season, titleId, t, inPage) {
  const n = seasonSummary(season, t), name = seasonName(season.number), open = s.open.has(season.number);
  const toggle = inPage
    ? `<button class="season-name" data-act="season-open" data-n="${season.number}" data-key="open:${season.number}" aria-expanded="${open}">${chevron(open ? 0 : 1)}<span>${name}</span><span class="season-total">${plural(n.total, "episode", "episodes")}</span></button>`
    : `<span class="season-name"><span>${name}</span><span class="season-total">${plural(n.total, "episode", "episodes")}</span></span>`;
  return `<li class="season" data-state="${n.state}">
    <div class="season-row">${toggle}${seasonButtons(season, n, titleId)}${strip(season, t)}${counts(n, false)}</div>
    ${errorLine(`season:${season.number}`)}
    ${inPage && open ? episodes(season, titleId, t) : ""}
  </li>`;
}
function episodeToggle(e, titleId, label) {
  const key = `ep:${e.id}`, mine = s.writing?.key === key;
  return `<button ${attr({ class: "tick", role: "switch", "aria-checked": String(e.monitored), "data-act": "episode", "data-key": key, "data-ep": e.id, "data-on": e.monitored ? "0" : "1", "data-title": titleId, "data-err": key, disabled: Boolean(s.writing) || s.blocked, "aria-busy": mine ? "true" : undefined, "aria-label": `Monitor ${label}` })}>${mine ? spinner : `<span class="box" aria-hidden="true"></span>`}<span class="tick-word">${mine ? "Saving…" : e.monitored ? "Monitored" : "Not monitored"}</span></button>`;
}
function fileCell(e, t) {
  if (e.onDisk) return `<span class="file"><i data-m="disk" aria-hidden="true"></i>${esc([e.quality, formatSize(e.size)].filter(Boolean).join(", ") || "On disk")}</span>`;
  const m = mark(e, t);
  return `<span class="file muted"><i data-m="${m}" aria-hidden="true"></i>${m === "wanted" ? "Wanted" : m === "waiting" ? "Upcoming" : "Not on disk"}</span>`;
}
function episodes(season, titleId, t) {
  if (!season.episodes.length) return `<p class="empty">Scryer lists no episodes for this season yet.</p>`;
  const rows = season.episodes.map((e) => {
    const code = `${season.number === 0 ? "Special" : `S${season.number}`} E${e.number}`;
    const label = `${code}${e.name ? `, ${e.name}` : ""}`;
    return `<li class="ep" data-m="${mark(e, t)}">
      <span class="ep-n">${e.number}</span>
      <span class="ep-name">${e.name ? esc(e.name) : `<span class="muted">Episode ${e.number}</span>`}</span>
      <span class="ep-date">${e.airDate ? esc(shortDate(e.airDate, s.locale)) : `<span class="muted">No date</span>`}</span>
      ${fileCell(e, t)}
      ${episodeToggle(e, titleId, label)}
      ${s.errors.has(`ep:${e.id}`) ? `<span class="ep-fail">${errorLine(`ep:${e.id}`)}</span>` : ""}
    </li>`;
  }).join("");
  return `<ol class="eps">${rows}</ol>`;
}
/** The whole-show line: the scope in words, and the control that changes it. */
function scopeLine(d) {
  const t = d.title, key = `title:${t.id}`;
  if (t.kind === "movie") {
    const m = d.movie;
    const state = m?.onDisk ? `On disk${m.quality || m.size ? `, ${esc([m.quality, formatSize(m.size)].filter(Boolean).join(", "))}` : ""}` : t.monitored ? "Wanted: not on disk yet" : "Not on disk";
    const btn = t.monitored
      ? writeButton({ key: `${key}:NONE`, act: "scope", label: "Unmonitor", busyLabel: "Saving…", data: { title: t.id, type: "NONE", err: key } })
      : writeButton({ key: `${key}:ALL_EPISODES`, act: "scope", label: "Monitor", busyLabel: "Saving…", primary: true, data: { title: t.id, type: "ALL_EPISODES", err: key } });
    return `<div class="scope"><p><b>${t.monitored ? "Monitored" : "Not monitored"}</b><span class="muted">${state}</span></p><span class="scope-acts">${btn}</span></div>${errorLine(key)}`;
  }
  const choosing = s.choosing === key;
  return `<div class="scope"><p><b>${esc(scopeLabel(t, titleSummary(d.seasons, today())))}</b>${t.monitorType === "ADVANCED" ? `<span class="muted">New seasons stay unmonitored</span>` : ""}</p>
    <span class="scope-acts"><button class="btn" data-act="choose" data-key="${key}:choose" data-choose="${key}" aria-expanded="${choosing}" ${s.writing || s.blocked ? "disabled" : ""}>Change</button></span></div>
    ${choosing ? scopeChoice(key, { titleId: t.id, current: t.monitorType, inLibrary: true, monitored: t.monitored }) : ""}${errorLine(key)}`;
}
function hydrationNote(t) {
  if (t.hydration === "failed") return `<p class="fail" role="alert">Scryer could not read this title's episodes. Ask in the chat to refresh its metadata.</p>`;
  if (t.hydration !== "pending") return "";
  const stopped = s.polledSince && Date.now() - s.polledSince > POLL_FOR_MS;
  const checked = s.checkedAt ? ` Last checked ${s.checkedAt.toLocaleTimeString(s.locale, { hour: "numeric", minute: "2-digit" })}.` : "";
  return `<p class="notice" role="status">${stopped ? "" : spinner}<span>Scryer is still reading this title's episodes.${stopped ? ` It has not finished after two minutes.${checked}` : " The card checks again every few seconds."}${stopped ? ` <button class="link" data-act="reload">Check now</button>` : ""}</span></p>`;
}
function titleHtml(p) {
  const d = s.data, t = d.title, day = today(), page = p.kind === "page";
  const n = titleSummary(d.seasons, day);
  // The host draws its own close; the view adds only the way back to the search it came from.
  const back = s.back ? `<nav class="bar nav"><button class="btn quiet back" data-act="back">${chevron(-1)}Back to results for “${esc(s.back.query)}”</button></nav>` : "";
  const head = `<header class="title-head">${art(t, page ? "page" : "card")}
      <div class="title-words"><h1>${esc(t.name)}</h1><p class="tile-meta">${esc(metaLine({ ...t, seasons: t.kind === "movie" ? undefined : d.seasons.filter((x) => x.number !== 0).length }))}</p>
      ${t.kind !== "movie" && n.total ? `<p class="title-counts">${counts(n, false)}</p>` : ""}</div></header>`;
  const seasons = d.seasons.slice(0, p.shown);
  const list = t.kind === "movie" ? "" : !d.seasons.length
    ? (t.hydration === "pending" ? `<ul class="seasons is-wait" aria-hidden="true">${"<li class=\"season\"><span class=\"skeleton line w40\"></span><span class=\"skeleton line w90\"></span></li>".repeat(3)}</ul>` : `<p class="empty">Scryer lists no seasons for this title yet.</p>`)
    : `<ul class="seasons eps-${p.episodes}">${seasons.map((x) => seasonRow(x, t.id, day, page)).join("")}</ul>`;
  const foot = !page && t.kind !== "movie" && d.seasons.length
    ? `<footer class="foot"><button class="btn" data-act="full">${p.more ? `Show all ${d.seasons.length} seasons and episodes` : "Show episodes"}</button></footer>`
    : "";
  return `<section class="card title ${p.kind} scroll-${p.scroll}" aria-busy="${t.hydration === "pending"}">
    ${back}${head}${blockedNote()}${hydrationNote(t)}${scopeLine(d)}
    ${page ? overview(t.overview, 3) : ""}
    <div class="title-body" data-scroll="list">${list}</div>${foot}
  </section>`;
}

// ---------- waiting, loading, errors ----------
function loadingHtml() {
  const q = s.asked?.args?.query;
  if (s.loading) return `<section class="card"><header class="bar"><h1 class="bar-title">${spinner}Opening ${esc(s.loading)}…</h1></header></section>`;
  if (q !== undefined)
    return `<section class="card" aria-busy="true"><header class="bar"><h1 class="bar-title">${spinner}Searching Scryer for “${esc(q)}”…</h1></header><div class="tiles">${skeletonTile().repeat(2)}</div></section>`;
  return `<section class="card" aria-busy="true"><header class="bar"><h1 class="bar-title">${spinner}Reading the title from Scryer…</h1></header><div class="tiles">${skeletonTile()}</div></section>`;
}
function errorHtml() {
  return `<section class="card"><div class="fail-block" role="alert"><p><b>Scryer did not answer.</b></p><p>${esc(s.loadError)}</p><p class="muted">Nothing changed. Ask again in the chat to retry.</p></div></section>`;
}

// ---------- render ----------
let lastKind;
function render() {
  if (s.waiting) return;
  let html;
  if (s.loading || (!s.data && !s.loadError)) html = loadingHtml();
  else if (!s.data || s.data.view === "unknown") html = errorHtml();
  else {
    const width = document.documentElement.clientWidth || innerWidth;
    const count = s.data.view === "search" ? s.data.results.length : s.data.seasons.length;
    const p = plan({ view: s.data.view, mode: s.mode, width, height: s.fixedHeight, canFullscreen: s.modes.includes("fullscreen"), count });
    html = s.data.view === "search" ? searchHtml(p) : titleHtml(p);
    if (lastKind !== undefined && lastKind !== p.kind) document.scrollingElement?.scrollTo(0, 0);
    lastKind = p.kind;
  }
  // Keep focus and scroll across a redraw: a write redraws the whole card.
  const focusKey = document.activeElement?.dataset?.key;
  const list = root.querySelector('[data-scroll="list"]');
  const listTop = list?.scrollTop;
  root.innerHTML = html;
  const next = root.querySelector('[data-scroll="list"]');
  if (next && listTop !== undefined) next.scrollTop = listTop;
  if (focusKey) (root.querySelector(`[data-key="${CSS.escape(focusKey)}"]`) ?? root.querySelector(`[data-key^="${CSS.escape(focusKey.split(":").slice(0, -1).join(":"))}"]`))?.focus({ preventScroll: true });
  pushContext();
}

// ---------- events ----------
root.addEventListener("click", (e) => {
  const b = e.target.closest("[data-act]");
  if (!b || b.disabled) return;
  const d = b.dataset;
  switch (d.act) {
    case "choose": s.choosing = s.choosing === d.choose ? undefined : d.choose; render(); break;
    case "cancel": s.choosing = undefined; render(); break;
    case "add": {
      s.choosing = undefined;
      write(d.key, d.err, "scryer_add", addArgs(d.cand, d.type), intoTile(d.cand));
      break;
    }
    case "add-pick": {
      // A new show with chosen seasons: add it unmonitored, then open its card to choose.
      s.choosing = undefined;
      write(d.key, d.err, "scryer_add", addArgs(d.cand, "NONE"), (fresh) => { intoTile(d.cand)(fresh); queueMicrotask(() => openTitle(fresh.title.id, fresh.title.name)); });
      break;
    }
    case "scope": {
      s.choosing = undefined;
      const after = s.data?.view === "search" ? intoTile(d.tile ?? d.err) : intoTitle;
      write(d.key, d.err, "scryer_monitor", { titleId: d.title, monitorType: d.type }, after);
      break;
    }
    case "season":
      write(d.key, d.err, "scryer_monitor", { titleId: d.title, seasonNumber: Number(d.season), monitored: d.on === "1" }, intoTitle);
      break;
    case "episode":
      write(d.key, d.err, "scryer_monitor", { titleId: d.title, episodeIds: [d.ep], monitored: d.on === "1" }, intoTitle);
      break;
    case "season-open": {
      const n = Number(d.n);
      if (s.open.has(n)) s.open.delete(n); else s.open.add(n);
      render();
      break;
    }
    case "open": openTitle(d.title, d.name ?? "the title"); break;
    case "back": s.data = s.back; s.back = undefined; render(); break;
    case "full": openFull(); break;
    case "close": closeFull(); break;
    case "reload": s.polledSince = Date.now(); watchHydration(); render(); break;
  }
});
/** The add tool names the result by its key; the name and year go with it as labels. */
function addArgs(key, monitorType) {
  const c = s.data?.results?.find((r) => r.key === key);
  return { key, name: c?.name ?? key, ...(c?.year !== undefined ? { year: c.year } : {}), monitorType };
}
// A poster that does not load (offline, outside the tailnet, CSP) falls back to the pixel kind.
root.addEventListener("error", (e) => {
  const img = e.target;
  if (img?.tagName === "IMG" && img.closest(".art")) { s.badPosters.add(img.getAttribute("src")); render(); }
}, true);
app.connect().then(() => { applyContext(app.getHostContext()); render(); });
