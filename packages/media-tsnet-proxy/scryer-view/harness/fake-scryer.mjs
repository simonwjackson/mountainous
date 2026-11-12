// A fake claw-scryer for the harness: the four view tools over in-memory data.
// Development only. It speaks the same structuredContent contract that the Go
// endpoint will serve (see ../README.md), not Scryer's GraphQL.
//
// Knobs (per request, from the harness page's query): delay=<ms> for the view's
// own calls, fail=<tool> (that tool returns the endpoint's transport error and
// changes nothing), hydrate=stuck (a pending title never finishes), home=<fixture
// household> and as=<account> (which libraries exist and whose is proposed).

const TODAY = "2026-11-11";
const day = (base, plusDays) => new Date(Date.parse(`${base}T00:00:00Z`) + plusDays * 864e5).toISOString().slice(0, 10);

const OFFICE_S1 = ["Pilot", "Diversity Day", "Health Care", "The Alliance", "Basketball", "Hot Girl"];
const OFFICE_S2 = ["The Dundies", "Sexual Harassment", "Office Olympics", "The Fire", "Halloween", "The Fight", "The Client", "Performance Review", "Email Surveillance", "Christmas Party", "Booze Cruise", "The Injury", "The Secret", "The Carpet", "Boys and Girls", "Valentine's Day", "Dwight's Speech", "Take Your Daughter to Work Day", "Michael's Birthday", "Drug Testing", "Conflict Resolution", "Casino Night"];
const SHOGUN_S1 = ["Anjin", "Servants of Two Masters", "Tomorrow Is Tomorrow", "The Eightfold Fence", "Broken to the Fist", "Ladies of the Willow World", "A Stick of Time", "The Abyss of Life", "Crimson Sky", "A Dream of a Dream"];
const FRIEREN_S1 = ["The Journey's End", "It Didn't Have to Be Magic...", "Killing Magic", "The Land Where Souls Rest", "Phantoms of the Dead", "The Hero of the Village", "Like a Fairy Tale", "Frieren the Slayer", "Aura the Guillotine", "A Powerful Mage"];

/** Episodes for a season: names (or a count), first air date, days between. */
function season(number, { names, count, first, every = 7, undated = 0 }) {
  const n = names ? names.length : count;
  return {
    number,
    episodes: Array.from({ length: n }, (_, i) => ({
      number: i + 1,
      name: names?.[i],
      airDate: first && i < n - undated ? day(first, i * every) : undefined,
    })),
  };
}

/** Everything Scryer's metadata search could find. `library` marks what is already added. */
const CATALOG = [
  { key: "tvdb:73244", name: "The Office", kind: "series", year: 2005, endYear: 2013, network: "NBC", overview: "A mockumentary on a group of typical office workers, where the workday consists of ego clashes, inappropriate behavior and tedium.",
    seasons: [season(1, { names: OFFICE_S1, first: "2005-03-24" }), season(2, { names: OFFICE_S2, first: "2005-09-20" }), season(3, { count: 25, first: "2006-09-21" }), season(4, { count: 19, first: "2007-09-27" }), season(5, { count: 28, first: "2008-09-25" }), season(6, { count: 26, first: "2009-09-17" }), season(7, { count: 26, first: "2010-09-23" }), season(8, { count: 24, first: "2011-09-22" }), season(9, { count: 25, first: "2012-09-20" }), season(0, { count: 3, first: "2006-07-13", every: 30 })] },
  { key: "tvdb:78107", name: "The Office", kind: "series", year: 2001, endYear: 2003, network: "BBC Two", overview: "The everyday lives of office employees in the Slough branch of the Wernham Hogg paper company, filmed as a documentary.",
    seasons: [season(1, { count: 6, first: "2001-07-09" }), season(2, { count: 6, first: "2002-09-30" }), season(0, { count: 2, first: "2003-12-26", every: 1 })] },
  { key: "tvdb:446113", name: "The Office", kind: "series", year: 2024, ongoing: true, network: "Prime Video", overview: "When the head office of Flinley Crate Co. announces it will close the branch, manager Hannah Howard promises to keep her team together.",
    seasons: [season(1, { count: 8, first: "2024-10-18", every: 0 })] },
  { key: "tmdb:438631", name: "Dune", kind: "movie", year: 2021, runtime: 155, overview: "Paul Atreides, a brilliant and gifted young man born into a great destiny beyond his understanding, must travel to the most dangerous planet in the universe.", file: { quality: "2160p", sizeBytes: 54_200_000_000 } },
  { key: "tmdb:841", name: "Dune", kind: "movie", year: 1984, runtime: 137, overview: "In the year 10,191, the most precious substance in the universe is the spice Melange. Paul Atreides must lead the Fremen against the Harkonnens." },
  { key: "tmdb:693134", name: "Dune: Part Two", kind: "movie", year: 2024, runtime: 167, overview: "Paul Atreides unites with Chani and the Fremen while on a path of revenge against the conspirators who destroyed his family." },
  { key: "tvdb:71489", name: "Frank Herbert's Dune", kind: "series", year: 2000, endYear: 2000, network: "Sci Fi", overview: "A three-part miniseries of the novel: the noble House Atreides takes over the desert planet Arrakis, the only source of the spice.",
    seasons: [season(1, { names: ["Part 1", "Part 2", "Part 3"], first: "2000-12-03", every: 1 })] },
  { key: "tvdb:367239", name: "Dune: Prophecy", kind: "series", year: 2024, ongoing: true, network: "HBO", overview: "Ten thousand years before the ascension of Paul Atreides, two Harkonnen sisters combat forces that threaten the future of humankind.",
    seasons: [season(1, { count: 6, first: "2024-11-17" }), season(2, { count: 6, first: "2026-11-23", undated: 4 })] },
  { key: "tvdb:390430", name: "Shōgun", kind: "series", year: 2024, ongoing: true, network: "FX", overview: "When a mysterious European ship is found marooned in a nearby fishing village, Lord Yoshii Toranaga discovers secrets that could tip the scales of power.",
    seasons: [season(1, { names: SHOGUN_S1, first: "2024-02-27" }), season(2, { count: 10, first: "2026-11-24", undated: 7 })] },
  { key: "tvdb:77924", name: "Shōgun", kind: "series", year: 1980, endYear: 1980, network: "NBC", overview: "An English navigator is shipwrecked in feudal Japan and rises to become a samurai in the service of a powerful lord.",
    seasons: [season(1, { count: 5, first: "1980-09-15", every: 1 })] },
  { key: "tvdb:424536", name: "Frieren: Beyond Journey's End", kind: "anime", year: 2023, ongoing: true, network: "Nippon TV", overview: "The elf mage Frieren and her fellow adventurers have defeated the Demon King. Decades later, she sets out to understand the people she travelled with.",
    seasons: [season(1, { names: FRIEREN_S1, first: "2023-09-29" })] },
  { key: "tvdb:357888", name: "Ascendance of a Bookworm: I'll Do Anything to Become a Librarian!", kind: "anime", year: 2019, ongoing: true, network: "Tokyo MX", overview: "A bookworm reborn in a world where books are a luxury of the nobility resolves to make her own, whatever it takes.",
    seasons: [season(1, { count: 14, first: "2019-10-03" }), season(2, { count: 12, first: "2020-04-05" }), season(3, { count: 10, first: "2022-04-11" })] },
  { key: "tvdb:999001", name: "Weltschmerzensgeldforderungsverfahren", kind: "series", year: 2022, endYear: 2022, network: "ZDFneo", overview: undefined,
    seasons: [season(1, { count: 4, first: "2022-03-01" })] },
];

/** The library: what is added, and per episode what is monitored and on disk. */
function makeLibrary() {
  const lib = new Map();
  const add = (key, id, init) => { const t = { id, key, monitorType: "NONE", hydration: "ready", eps: new Map(), ...init }; lib.set(id, t); return t; };
  const office = add("tvdb:73244", "t-office-us", { monitorType: "ADVANCED" });
  forEach("tvdb:73244", (s, e) => office.eps.set(`${s}x${e}`, {
    monitored: s === 2 || s === 3,
    onDisk: s === 1 || (s === 2 && ![9, 14, 15, 21].includes(e)),
    file: { quality: s === 1 ? "720p" : "1080p", sizeBytes: (s === 1 ? 0.62 : 1.31) * 1e9 },
  }));
  const shogun = add("tvdb:390430", "t-shogun", { monitorType: "FUTURE_EPISODES" });
  forEach("tvdb:390430", (s, e) => shogun.eps.set(`${s}x${e}`, { monitored: s === 2, onDisk: s === 1, file: { quality: "2160p", sizeBytes: 7.9e9 } }));
  add("tvdb:424536", "t-frieren", { monitorType: "ALL_EPISODES", hydration: "pending", reads: 0 });
  add("tmdb:438631", "t-dune-2021", { monitorType: "ALL_EPISODES", movieOnDisk: true });
  add("tmdb:693134", "t-dune-2", { monitorType: "ALL_EPISODES", movieOnDisk: false });
  return lib;
}
function forEach(key, fn) {
  for (const s of CATALOG.find((c) => c.key === key).seasons) for (const e of s.episodes) fn(s.number, e.number);
}

export function createFake() {
  let lib = makeLibrary();
  let next = 1;
  const byKey = (key) => [...lib.values()].find((t) => t.key === key);
  const cat = (key) => CATALOG.find((c) => c.key === key);

  function readTitle(t, knobs) {
    const c = cat(t.key);
    // Hydration finishes on the second read after adding (unless the knob holds it).
    if (t.hydration === "pending") {
      t.reads = (t.reads ?? 0) + 1;
      if (t.reads > 2 && knobs.hydrate !== "stuck") {
        t.hydration = "ready";
        forEach(t.key, (s, e) => t.eps.has(`${s}x${e}`) || t.eps.set(`${s}x${e}`, { monitored: monitoredFor(t.monitorType, c, s, e), onDisk: false }));
      }
    }
    const monitored = c.kind === "movie" ? t.monitorType !== "NONE" : t.monitorType !== "NONE" && [...t.eps.values()].some((e) => e.monitored);
    const title = { id: t.id, libraryName: t.libraryName ?? (c.kind === "anime" ? "Anime" : `Simon ${c.kind === "movie" ? "Movies" : "Series"}`), name: c.name, kind: c.kind, year: c.year, endYear: c.endYear, ongoing: c.ongoing ?? false, network: c.network, overview: c.overview, poster: null, monitored: c.kind === "movie" ? t.monitorType !== "NONE" : monitored || t.monitorType === "FUTURE_EPISODES", monitorType: t.monitorType, hydration: t.hydration };
    if (c.kind === "movie") return { view: "title", title, seasons: [], movie: { onDisk: Boolean(t.movieOnDisk), file: t.movieOnDisk ? c.file : null } };
    const seasons = t.hydration === "pending" ? [] : c.seasons.map((s) => ({
      number: s.number,
      episodes: s.episodes.map((e) => {
        const st = t.eps.get(`${s.number}x${e.number}`) ?? { monitored: false, onDisk: false };
        return { id: `${t.id}-${s.number}x${e.number}`, number: e.number, name: e.name ?? null, airDate: e.airDate ?? null, monitored: st.monitored, onDisk: st.onDisk, file: st.onDisk ? st.file ?? { quality: "1080p", sizeBytes: 1.2e9 } : null };
      }),
    }));
    return { view: "title", title, seasons };
  }
  function monitoredFor(type, c, s, e) {
    if (type === "ALL_EPISODES") return true;
    const ep = c.seasons.find((x) => x.number === s)?.episodes.find((x) => x.number === e);
    const future = !ep?.airDate || ep.airDate > TODAY;
    if (type === "FUTURE_EPISODES") return future;
    if (type === "MISSING_AND_FUTURE_EPISODES") return true;
    return false;
  }
  function summary(t) {
    const r = readTitle(t, { hydrate: "stuck" }); // a search never advances hydration
    const eps = r.seasons.flatMap((s) => s.episodes);
    return {
      titleId: t.id, libraryName: r.title.libraryName, monitored: r.title.monitored, monitorType: t.monitorType, hydration: t.hydration,
      onDisk: r.movie ? { have: r.movie.onDisk ? 1 : 0, total: 1 } : eps.length ? { have: eps.filter((e) => e.onDisk).length, total: eps.length } : null,
    };
  }
  const fold = (s) => s.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

  /**
   * Fixture households (knob home=...). The view must draw any of them: it knows
   * no library names. `as` is the signed-in account (knob as=..., default simon).
   *   three   a library per person plus a shared one (default)
   *   one     one library per kind: no question is asked
   *   plain   several, none named after the account: Scryer's default is proposed
   *   nopick  several, no default and none the account's: the person must pick
   */
  const HOMES = {
    three: { movie: ["Simon Movies", "Family Movies", "Laure Movies"], series: ["Simon Series", "Family Series", "Laure Series"], anime: ["Anime"], default: "Family", people: ["simon", "laure"] },
    one: { movie: ["Movies"], series: ["Shows"], anime: ["Anime"] },
    plain: { movie: ["Movies", "Kids Movies", "Documentaries with a rather long library name"], series: ["Shows", "Kids Shows"], anime: ["Anime"], default: "" },
    nopick: { movie: ["Upstairs Movies", "Downstairs Movies"], series: ["Upstairs Shows", "Downstairs Shows"], anime: ["Anime"] },
  };
  function libraries(knobs, hint) {
    const home = HOMES[knobs.home] ?? HOMES.three, as = (knobs.as ?? "simon").toLowerCase();
    const has = (name, word) => name.toLowerCase().split(/[^a-z0-9]+/).includes(word);
    const out = {};
    for (const kind of ["movie", "series", "anime"]) {
      // As the endpoint does from Scryer's grants: an account is offered the shared libraries and its own.
      const names = (home[kind] ?? []).filter((n) => !(home.people ?? []).some((p) => p !== as && has(n, p)));
      const hinted = hint ? names.filter((n) => has(n, hint.toLowerCase())) : [];
      const own = names.filter((n) => has(n, as));
      const dflt = home.default === undefined ? [] : names.filter((n) => (home.default ? has(n, home.default.toLowerCase()) : n === names[0]));
      const pick = hinted.length === 1 ? hinted[0] : own.length === 1 ? own[0] : dflt[0] ?? (names.length === 1 ? names[0] : undefined);
      out[kind] = [...names.filter((n) => n === pick), ...names.filter((n) => n !== pick).sort()].map((n) => ({ id: `lib-${kind}-${n.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`, name: n, suggested: n === pick }));
    }
    return out;
  }

  const tools = {
    scryer_search({ query, library }, knobs = {}) {
      const q = fold(String(query ?? "").trim());
      const results = q ? CATALOG.filter((c) => fold(c.name).includes(q)) : [];
      return {
        view: "search", query,
        results: results.map((c) => ({
          key: c.key, name: c.name, kind: c.kind, year: c.year, endYear: c.endYear ?? null, ongoing: c.ongoing ?? false, network: c.network ?? null,
          seasons: c.seasons ? c.seasons.filter((s) => s.number !== 0).length : null, runtimeMinutes: c.runtime ?? null, overview: c.overview ?? null, poster: null,
          library: byKey(c.key) ? summary(byKey(c.key)) : null,
        })),
        libraries: libraries(knobs, library),
      };
    },
    scryer_title({ titleId }, knobs) {
      const t = lib.get(titleId);
      if (!t) throw new Error(`No title with id ${titleId}.`);
      return readTitle(t, knobs);
    },
    scryer_add({ key, monitorType, libraryId }, knobs = {}) {
      const c = cat(key);
      if (!c) throw new Error(`Scryer has no search result ${key}.`);
      let t = byKey(key);
      if (!t) {
        const list = libraries(knobs)[c.kind];
        const target = libraryId ? list.find((l) => l.id === libraryId) : list.length === 1 ? list[0] : list.find((l) => l.suggested && knobs.home !== "plain");
        if (libraryId && !target) throw new Error("This Scryer account cannot add to that library; nothing was added.");
        if (!target) throw new Error(`Choose a library: ${list.map((l) => l.name).join(", ")}. Nothing was added.`);
        t = { id: `t-new-${next++}`, key, libraryName: target.name, monitorType: monitorType ?? "NONE", hydration: c.kind === "movie" ? "ready" : "pending", reads: 0, eps: new Map() };
        lib.set(t.id, t);
      }
      return { ...readTitle(t, knobs), done: { action: "add", libraryName: t.libraryName } };
    },
    scryer_monitor({ titleId, monitorType, seasonNumber, episodeIds, monitored }, knobs) {
      const t = lib.get(titleId);
      if (!t) throw new Error(`No title with id ${titleId}.`);
      const c = cat(t.key);
      if (monitorType) {
        t.monitorType = monitorType;
        if (c.kind !== "movie") forEach(t.key, (s, e) => { const st = t.eps.get(`${s}x${e}`) ?? { onDisk: false }; t.eps.set(`${s}x${e}`, { ...st, monitored: monitoredFor(monitorType, c, s, e) }); });
      } else {
        const hit = (s, e) => (seasonNumber !== undefined ? s === seasonNumber : (episodeIds ?? []).includes(`${t.id}-${s}x${e}`));
        forEach(t.key, (s, e) => { if (hit(s, e)) { const st = t.eps.get(`${s}x${e}`) ?? { onDisk: false }; t.eps.set(`${s}x${e}`, { ...st, monitored: Boolean(monitored) }); } });
        t.monitorType = [...t.eps.values()].some((e) => e.monitored) ? "ADVANCED" : "NONE";
      }
      return { ...readTitle(t, knobs), done: { action: "monitor" } };
    },
  };

  return {
    reset() { lib = makeLibrary(); next = 1; },
    /** One tools/call. Returns an MCP CallToolResult. */
    async call(name, args, knobs = {}, fromApp = false) {
      if (fromApp && knobs.delay) await new Promise((r) => setTimeout(r, Number(knobs.delay)));
      if (fromApp && knobs.fail === name)
        return { isError: true, content: [{ type: "text", text: JSON.stringify({ kind: "transport", message: "Scryer unavailable; do not retry a mutation without reading its state" }) }] };
      const fn = tools[name];
      if (!fn) return { isError: true, content: [{ type: "text", text: `Unknown tool ${name}` }] };
      try {
        const sc = fn(args ?? {}, knobs);
        return { content: [{ type: "text", text: JSON.stringify(sc) }], structuredContent: sc };
      } catch (e) {
        return { isError: true, content: [{ type: "text", text: JSON.stringify({ message: e.message }) }] };
      }
    },
  };
}
