import assert from "node:assert/strict";
import { test } from "node:test";
import { readFile } from "node:fs/promises";
import { EPISODE_TABLE_MIN_WIDTH, INLINE_RESULTS, INLINE_SEASONS, PIN_MIN_HEIGHT, TWO_COLUMN_MIN_WIDTH, plan } from "../src/plan.js";
import { chosenLibrary, libraryChoices, classify, failureText, libraryBadges, mark, metaLine, safePoster, sameNames, seasonSummary, years } from "../src/model.js";
import { createFake } from "../harness/fake-scryer.mjs";

const frame = (o) => ({ view: "search", mode: "inline", width: 400, height: undefined, canFullscreen: true, count: 10, ...o });

test("inline shows the first few; the rest stay one tap away", () => {
  assert.deepEqual([plan(frame({})).shown, plan(frame({})).more], [INLINE_RESULTS, 10 - INLINE_RESULTS]);
  assert.equal(plan(frame({ view: "title" })).shown, INLINE_SEASONS);
  assert.equal(plan(frame({ count: 2 })).more, 0);
  const full = plan(frame({ mode: "fullscreen" }));
  assert.deepEqual([full.shown, full.more], [10, 0]);
  // A host without a full view grows the card in place; nothing becomes unreachable.
  assert.equal(plan(frame({ canFullscreen: false })).open, "in-place");
  assert.equal(plan(frame({ mode: "expanded" })).shown, 10);
});

test("width thresholds, one pixel either side", () => {
  assert.equal(plan(frame({ mode: "fullscreen", width: TWO_COLUMN_MIN_WIDTH - 1 })).columns, 1);
  assert.equal(plan(frame({ mode: "fullscreen", width: TWO_COLUMN_MIN_WIDTH })).columns, 2);
  assert.equal(plan(frame({ width: 2000 })).columns, 1, "inline is always one column");
  assert.equal(plan(frame({ view: "title", mode: "fullscreen", width: EPISODE_TABLE_MIN_WIDTH - 1 })).episodes, "stack");
  assert.equal(plan(frame({ view: "title", mode: "fullscreen", width: EPISODE_TABLE_MIN_WIDTH })).episodes, "table");
  assert.equal(plan(frame({ view: "title" })).episodes, "none");
});

test("a short fixed frame scrolls the whole card; a growing frame does not", () => {
  assert.equal(plan(frame({ height: PIN_MIN_HEIGHT - 1 })).scroll, "card");
  assert.equal(plan(frame({ height: PIN_MIN_HEIGHT })).scroll, "list");
  assert.equal(plan(frame({ height: undefined })).scroll, "list");
});

test("each episode has exactly one mark", () => {
  const today = "2026-11-11";
  assert.equal(mark({ onDisk: true, monitored: false, airDate: "2020-01-01" }, today), "disk");
  assert.equal(mark({ onDisk: false, monitored: true, airDate: "2020-01-01" }, today), "wanted");
  assert.equal(mark({ onDisk: false, monitored: true, airDate: "2026-11-12" }, today), "waiting");
  assert.equal(mark({ onDisk: false, monitored: true, airDate: undefined }, today), "waiting", "no date is upcoming, never missing");
  assert.equal(mark({ onDisk: false, monitored: false, airDate: "2020-01-01" }, today), "off");
  const n = seasonSummary({ episodes: [{ onDisk: true, monitored: true, airDate: "2020-01-01" }, { onDisk: false, monitored: false }] }, today);
  assert.deepEqual([n.disk, n.off, n.monitored, n.state], [1, 1, 1, "some"]);
});

test("same names are found across case, accents and a leading The", () => {
  const twins = sameNames([{ key: "a", name: "The Office" }, { key: "b", name: "Office" }, { key: "c", name: "Shōgun" }, { key: "d", name: "Shogun" }, { key: "e", name: "Dune: Part Two" }]);
  assert.deepEqual([...twins].sort(), ["a", "b", "c", "d"]);
});

test("the meta line carries what tells titles apart", () => {
  assert.equal(metaLine({ kind: "series", year: 2005, endYear: 2013, network: "NBC", seasons: 9 }), "Series, 2005–2013, NBC, 9 seasons");
  assert.equal(metaLine({ kind: "series", year: 2024, ongoing: true, network: "FX", seasons: 0 }), "Series, 2024–, FX");
  assert.equal(metaLine({ kind: "movie", year: 1984, runtime: 137 }), "Movie, 1984, 137 min");
  assert.equal(years({ kind: "series", year: 2000, endYear: 2000 }), "2000");
});

test("only https posters are kept", () => {
  assert.equal(safePoster("https://image.tmdb.org/t/p/w342/x.jpg"), "https://image.tmdb.org/t/p/w342/x.jpg");
  assert.equal(safePoster("http://example.com/x.jpg"), undefined);
  assert.equal(safePoster("javascript:alert(1)"), undefined);
});

test("badges never claim more than the library says", () => {
  assert.deepEqual(libraryBadges(undefined), []);
  const b = libraryBadges({ titleId: "t", monitored: false, monitorType: "NONE", hydration: "pending" }).map((x) => x.text);
  assert.deepEqual(b, ["In library", "Reading episodes", "Not monitored"]);
});

test("failures read as the person's words", () => {
  assert.equal(failureText(new Error("The session's current tool policy does not allow this operation")).blocked, true);
  assert.equal(failureText("Scryer unavailable; do not retry a mutation without reading its state").text, "Scryer did not answer.");
  assert.equal(failureText("No title with id x.").text, "No title with id x.");
});

test("classify drops what it cannot draw", () => {
  assert.equal(classify({ view: "nope" }).view, "unknown");
  const s = classify({ view: "search", query: "x", results: [{ key: "k", name: "N", kind: "alien" }, { name: "no key" }] });
  assert.equal(s.results.length, 1);
  assert.equal(s.results[0].kind, undefined);
  const t = classify({ view: "title", title: { id: "t" }, seasons: [{ number: 0, episodes: [] }, { number: 2, episodes: [{ id: "b", number: 2 }, { id: "a", number: 1 }] }, { number: 1, episodes: [] }] });
  assert.deepEqual(t.seasons.map((x) => x.number), [1, 2, 0], "specials last");
  assert.deepEqual(t.seasons[1].episodes.map((e) => e.id), ["a", "b"]);
});

test("the fake keeps exact scope: one season changes only that season", async () => {
  const fake = createFake();
  const before = (await fake.call("scryer_title", { titleId: "t-office-us" })).structuredContent;
  const after = (await fake.call("scryer_monitor", { titleId: "t-office-us", seasonNumber: 4, monitored: true })).structuredContent;
  for (const s of after.seasons) {
    const was = before.seasons.find((x) => x.number === s.number);
    if (s.number === 4) assert.ok(s.episodes.every((e) => e.monitored));
    else assert.deepEqual(s.episodes.map((e) => e.monitored), was.episodes.map((e) => e.monitored));
  }
  assert.equal(after.title.monitorType, "ADVANCED");
  const failed = await fake.call("scryer_monitor", { titleId: "t-office-us", seasonNumber: 5, monitored: true }, { fail: "scryer_monitor" }, true);
  assert.equal(failed.isError, true);
  const reread = (await fake.call("scryer_title", { titleId: "t-office-us" })).structuredContent;
  assert.ok(reread.seasons.find((x) => x.number === 5).episodes.every((e) => !e.monitored), "a failed write changes nothing");
});


test("cards retain and name the library returned by Scryer", () => {
  const title = classify({ view: "title", title: { id: "t", name: "Test", kind: "movie", libraryName: "Family Movies" }, seasons: [] });
  assert.equal(title.title.libraryName, "Family Movies");
  const search = classify({ view: "search", results: [{ key: "k", name: "Test", library: { titleId: "t", libraryName: "Laure Movies" } }] });
  assert.equal(libraryBadges(search.results[0].library, "movie")[0].text, "Laure Movies");
});

test("the view draws whatever libraries the endpoint lists, and knows no names", async () => {
  const none = classify({ view: "search", results: [] });
  assert.deepEqual(none.libraries, { movie: [], series: [], anime: [] }, "an older endpoint without the list still draws");
  const some = libraryChoices({ movie: [{ id: "a", name: "Alpha", suggested: true }, { id: "b", name: "Beta" }, { name: "no id" }], series: "nonsense" });
  assert.deepEqual(some.movie.map((l) => [l.id, l.suggested]), [["a", true], ["b", false]]);
  assert.deepEqual(some.series, []);
  // The proposal holds until the person picks; a pick that is not in the list is ignored.
  assert.equal(chosenLibrary(some.movie).id, "a");
  assert.equal(chosenLibrary(some.movie, "b").id, "b");
  assert.equal(chosenLibrary(some.movie, "gone").id, "a");
  assert.equal(chosenLibrary([{ id: "x", name: "Only", suggested: false }]).id, "x", "one library needs no proposal");
  assert.equal(chosenLibrary([{ id: "x", name: "X", suggested: false }, { id: "y", name: "Y", suggested: false }]), undefined, "several and no proposal: the person must pick");
  const src = await readFile(new URL("../src/app.js", import.meta.url), "utf8") + await readFile(new URL("../src/model.js", import.meta.url), "utf8");
  for (const word of ["Simon", "Laure", "Family", "\"mine\"", "\"family\""]) assert.ok(!src.includes(word), `the view must not name ${word}`);
});

test("the fake proposes by account and by hint, for any household", async () => {
  const names = (sc, kind) => sc.libraries[kind].map((l) => l.name + (l.suggested ? "*" : ""));
  const search = async (args, knobs) => (await createFake().call("scryer_search", { query: "Dune", ...args }, knobs)).structuredContent;
  assert.deepEqual(names(await search({}, {}), "movie"), ["Simon Movies*", "Family Movies"]);
  assert.deepEqual(names(await search({}, { as: "laure" }), "series"), ["Laure Series*", "Family Series"]);
  assert.deepEqual(names(await search({ library: "family" }, { as: "laure" }), "movie"), ["Family Movies*", "Laure Movies"]);
  assert.deepEqual(names(await search({}, { home: "one", as: "pat" }), "movie"), ["Movies*"]);
  assert.deepEqual(names(await search({}, { home: "nopick", as: "pat" }), "movie"), ["Downstairs Movies", "Upstairs Movies"]);
  // An add goes to the named library, and to no other.
  const api = createFake();
  const list = (await api.call("scryer_search", { query: "Dune" }, { as: "laure" })).structuredContent.libraries.movie;
  const added = (await api.call("scryer_add", { key: "tmdb:841", monitorType: "NONE", libraryId: list.find((l) => l.name === "Family Movies").id }, { as: "laure" })).structuredContent;
  assert.equal(added.title.libraryName, "Family Movies");
  assert.equal((await createFake().call("scryer_add", { key: "tmdb:841", monitorType: "NONE", libraryId: "lib-movie-nope" }, {})).isError, true);
  assert.equal((await createFake().call("scryer_add", { key: "tmdb:841", monitorType: "NONE" }, { home: "nopick" })).isError, true, "several and no proposal: nothing is added");
});
