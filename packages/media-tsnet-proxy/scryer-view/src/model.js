// Pure data rules for the Scryer media view. No DOM here, so tests can run in Node.
//
// The view draws only what the claw-scryer tools return in structuredContent:
//   scryer_search  -> { view: "search", query, results: Candidate[] }
//   scryer_title, scryer_add, scryer_monitor -> { view: "title", title, seasons, movie?, done? }
// The action tools always end with a fresh read of the title, so the view never
// draws a change that Scryer did not report back.

export const KINDS = ["movie", "series", "anime"];
export const KIND_WORDS = { movie: "Movie", series: "Series", anime: "Anime" };

/** Whole-show monitoring scopes, in the skill's words. ADVANCED and NONE are not offered as choices. */
export const SCOPES = [
  { type: "ALL_EPISODES", label: "All episodes" },
  { type: "FUTURE_EPISODES", label: "Future episodes" },
  { type: "MISSING_AND_FUTURE_EPISODES", label: "Missing and future" },
];
const SCOPE_WORDS = {
  ALL_EPISODES: "All episodes",
  FUTURE_EPISODES: "Future episodes only",
  MISSING_AND_FUTURE_EPISODES: "Missing and future episodes",
  ADVANCED: "Chosen seasons",
  NONE: "Not monitored",
};
export const scopeWords = (type) => SCOPE_WORDS[type] ?? "Not monitored";
/**
 * The whole-show line. A recorded scope names itself; without one (common in
 * Scryer), the words come from the title flag and the episodes' own flags.
 */
export function scopeLabel(title, n) {
  if (title.monitorType && title.monitorType !== "NONE") return scopeWords(title.monitorType);
  if (!title.monitored && n.monitored === 0) return "Not monitored";
  if (n.total > 0 && n.monitored === n.total) return "All episodes monitored";
  if (n.monitored === 0) return title.monitored ? "Monitored, no episodes yet" : "Not monitored";
  return "Some episodes monitored";
}

const str = (v) => (typeof v === "string" && v.trim() ? v.trim() : undefined);
const int = (v) => (Number.isInteger(v) ? v : undefined);
const kindOf = (v) => (KINDS.includes(v) ? v : undefined);
/** Posters are https only; anything else is ignored, and the pixel kind stands in. */
export const safePoster = (v) => {
  const s = str(v);
  if (!s) return undefined;
  try { return new URL(s).protocol === "https:" ? s : undefined; } catch { return undefined; }
};

function library(v) {
  if (!v || typeof v !== "object" || !str(v.titleId)) return undefined;
  return {
    titleId: v.titleId,
    monitored: v.monitored === true,
    monitorType: str(v.monitorType), // Scryer leaves it unset on many titles; words then come from the flags
    hydration: str(v.hydration) ?? "ready",
    onDisk: v.onDisk && int(v.onDisk.have) !== undefined && int(v.onDisk.total) !== undefined ? { have: v.onDisk.have, total: v.onDisk.total } : undefined,
  };
}

/** @returns {object | undefined} a clean candidate, or undefined when it has no key or name. */
export function candidate(v) {
  if (!v || typeof v !== "object" || !str(v.key) || !str(v.name)) return undefined;
  return {
    key: v.key, name: str(v.name), kind: kindOf(v.kind), year: int(v.year), endYear: int(v.endYear),
    ongoing: v.ongoing === true, network: str(v.network), seasons: int(v.seasons), runtime: int(v.runtimeMinutes),
    overview: str(v.overview), poster: safePoster(v.poster), library: library(v.library),
  };
}

function episode(v) {
  if (!v || typeof v !== "object" || !str(v.id) || int(v.number) === undefined) return undefined;
  return {
    id: v.id, number: v.number, name: str(v.name), airDate: /^\d{4}-\d{2}-\d{2}$/.test(v.airDate ?? "") ? v.airDate : undefined,
    monitored: v.monitored === true, onDisk: v.onDisk === true, quality: str(v.file?.quality), size: int(v.file?.sizeBytes),
  };
}

/** Reads a tool's structuredContent. Unknown shapes become { view: "unknown" }. */
export function classify(sc) {
  if (sc?.view === "search")
    return { view: "search", query: str(sc.query) ?? "", results: (Array.isArray(sc.results) ? sc.results : []).map(candidate).filter(Boolean) };
  if (sc?.view === "title" && sc.title && str(sc.title.id)) {
    const t = sc.title;
    const seasons = (Array.isArray(sc.seasons) ? sc.seasons : [])
      .filter((s) => int(s?.number) !== undefined)
      .map((s) => ({ number: s.number, episodes: (Array.isArray(s.episodes) ? s.episodes : []).map(episode).filter(Boolean).sort((a, b) => a.number - b.number) }))
      .sort((a, b) => (a.number === 0) - (b.number === 0) || a.number - b.number); // specials last
    return {
      view: "title",
      title: {
        id: t.id, name: str(t.name) ?? "Untitled", kind: kindOf(t.kind), year: int(t.year), endYear: int(t.endYear), ongoing: t.ongoing === true,
        network: str(t.network), overview: str(t.overview), poster: safePoster(t.poster), monitored: t.monitored === true,
        monitorType: str(t.monitorType), hydration: str(t.hydration) ?? "ready",
      },
      seasons,
      movie: sc.movie && typeof sc.movie === "object" ? { onDisk: sc.movie.onDisk === true, quality: str(sc.movie.file?.quality), size: int(sc.movie.file?.sizeBytes) } : undefined,
      done: str(sc.done?.action),
    };
  }
  return { view: "unknown" };
}

/** An episode that has not aired yet, or has no date, cannot be missing; it is upcoming. */
export const aired = (ep, today) => ep.airDate !== undefined && ep.airDate <= today;

/**
 * Each episode's mark in a season strip. One mark, one meaning:
 *   disk     on disk (whether or not it is monitored)
 *   wanted   monitored, aired, not on disk
 *   waiting  monitored, not aired yet
 *   off      not monitored and not on disk
 */
export function mark(ep, today) {
  if (ep.onDisk) return "disk";
  if (!ep.monitored) return "off";
  return aired(ep, today) ? "wanted" : "waiting";
}

export function seasonSummary(season, today) {
  const n = { total: season.episodes.length, disk: 0, wanted: 0, waiting: 0, off: 0, monitored: 0 };
  for (const ep of season.episodes) {
    n[mark(ep, today)]++;
    if (ep.monitored) n.monitored++;
  }
  n.state = n.total === 0 ? "empty" : n.monitored === 0 ? "none" : n.monitored === n.total ? "all" : "some";
  return n;
}

export function titleSummary(seasons, today) {
  const n = { total: 0, disk: 0, wanted: 0, waiting: 0, off: 0, monitored: 0 };
  for (const s of seasons) {
    const x = seasonSummary(s, today);
    for (const k of Object.keys(n)) n[k] += x[k];
  }
  return n;
}

export const seasonName = (n) => (n === 0 ? "Specials" : `Season ${n}`);
export const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;

/** "2005–2013", "2024–", "2021". En dash, no spaces, as in a reference book. */
export function years(t) {
  if (t.year === undefined) return undefined;
  if (t.kind === "movie") return String(t.year);
  if (t.ongoing) return `${t.year}–`;
  if (t.endYear !== undefined && t.endYear !== t.year) return `${t.year}–${t.endYear}`;
  return String(t.year);
}

/**
 * The facts that tell two titles apart, in order of how often they decide it:
 * the kind, the years, the network, the length. Joined with commas.
 */
export function metaLine(t) {
  const parts = [KIND_WORDS[t.kind], years(t), t.network];
  if (t.kind === "movie" && t.runtime) parts.push(`${t.runtime} min`);
  else if (t.seasons) parts.push(plural(t.seasons, "season", "seasons"));
  return parts.filter(Boolean).join(", ");
}

const fold = (s) => s.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/^the\s+/, "").replace(/[^a-z0-9]+/g, " ").trim();
/** Keys of results whose name another result also has (remakes, US and UK versions). */
export function sameNames(results) {
  const seen = new Map();
  for (const r of results) seen.set(fold(r.name), (seen.get(fold(r.name)) ?? 0) + 1);
  return new Set(results.filter((r) => seen.get(fold(r.name)) > 1).map((r) => r.key));
}

/** The state words on a search tile. Empty for a title that is not in the library. */
export function libraryBadges(lib, kind) {
  if (!lib) return [];
  const out = [{ text: "In library", tone: "plain" }];
  if (lib.hydration === "pending") out.push({ text: "Reading episodes", tone: "busy" });
  else if (lib.hydration === "failed") out.push({ text: "Episodes did not load", tone: "bad" });
  if (lib.monitored && lib.monitorType !== "NONE") out.push({ text: !lib.monitorType || lib.monitorType === "ALL_EPISODES" ? "Monitored" : `Monitored: ${scopeWords(lib.monitorType).toLowerCase()}`, tone: "good" });
  else out.push({ text: "Not monitored", tone: "plain" });
  if (kind === "movie" && lib.onDisk) out.push({ text: lib.onDisk.have ? "On disk" : "Not on disk", tone: "plain" });
  else if (lib.onDisk && lib.onDisk.total > 0) out.push({ text: `${lib.onDisk.have} of ${lib.onDisk.total} on disk`, tone: "plain" });
  return out;
}

export function formatSize(bytes) {
  if (bytes === undefined) return undefined;
  const gb = bytes / 1e9;
  return gb >= 1 ? `${gb.toFixed(gb >= 10 ? 0 : 1)} GB` : `${Math.round(bytes / 1e6)} MB`;
}
export function shortDate(iso, locale) {
  if (!iso) return undefined;
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d)).toLocaleDateString(locale ?? "en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
}

/** The person's message for a failed tool call. A host policy block gets its own words. */
export function failureText(err) {
  const raw = String(err?.message ?? err ?? "");
  if (/tool policy|not allow/i.test(raw)) return { blocked: true, text: "This chat does not let the card change Scryer. Ask in the chat instead." };
  // The endpoint's transport words are for the model; the person needs what it means.
  if (!raw || /unavailable|timed? ?out|deadline|HTTP 5\d\d|did not answer/i.test(raw)) return { blocked: false, text: "Scryer did not answer." };
  return { blocked: false, text: raw.replace(/^Error:\s*/, "") };
}
