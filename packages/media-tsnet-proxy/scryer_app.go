package main

// The Scryer media MCP App: one view (ui://scryer/media.html) and four tools that
// return the view's structuredContent. Search and title reads are visible to the
// model and the view; add and monitor are visible to the view only (its buttons).
// Every write ends with a fresh read of the title, so the view draws only what
// Scryer reports. Nothing here deletes, restores or touches files.

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

//go:embed scryer-view/dist/media.html
var scryerViewHTML string

const (
	scryerViewURI  = "ui://scryer/media.html"
	scryerViewMIME = "text/html;profile=mcp-app"
)

func scryerViewMeta(visibility ...string) map[string]any {
	return map[string]any{
		"ui":             map[string]any{"resourceUri": scryerViewURI, "visibility": visibility},
		"ui/resourceUri": scryerViewURI, // hosts written before the nested key
	}
}

// scryerAppTools are listed after scryer_graphql, which stays unchanged.
func scryerAppTools() []any {
	// Annotations are honest hints a host may use to skip a confirmation prompt:
	// reads are read-only; add and monitor change only monitoring, are repeatable,
	// and never delete or reach outside Scryer.
	read := map[string]any{"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	write := map[string]any{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
	tool := func(name, description, schema string, visibility ...string) map[string]any {
		hints := write
		if name == "scryer_search" || name == "scryer_title" {
			hints = read
		}
		return map[string]any{"name": name, "description": description, "inputSchema": json.RawMessage(schema), "annotations": hints, "_meta": scryerViewMeta(visibility...)}
	}
	return []any{
		tool("scryer_search", "Search Scryer's metadata providers for movies, series and anime by name, and show the results as cards with library state (in library, monitored, on disk). Use it to identify the exact title; same names in different years are common. The person can add or monitor from the card, and the card asks which library when there is more than one. The reply lists the libraries this account can add to and which one the card suggests (the person's own by default). When the person said who it is for (the family, the kids, someone else), pass `library` with words from that library's name so the card suggests it instead.",
			`{"type":"object","properties":{"query":{"type":"string","minLength":1,"maxLength":200},"library":{"type":"string","minLength":1,"maxLength":100,"description":"Optional. Words from the name of the library to suggest on the card, for example the shared family library. Omit to suggest the person's own."}},"required":["query"],"additionalProperties":false}`, "model", "app"),
		tool("scryer_title", "Show one library title as a card: seasons, what is monitored, what is on disk. The person can monitor or unmonitor seasons and episodes from the card. titleId is Scryer's title id.",
			`{"type":"object","properties":{"titleId":{"type":"string","minLength":1,"maxLength":100}},"required":["titleId"],"additionalProperties":false}`, "model", "app"),
		tool("scryer_add", "The card's Add and Monitor buttons: add one search result to one library at an exact monitoring scope. libraryId is one of the libraries scryer_search listed for that kind.",
			`{"type":"object","properties":{"key":{"type":"string","minLength":1,"maxLength":100},"name":{"type":"string","minLength":1,"maxLength":300},"year":{"type":"integer"},"libraryId":{"type":"string","minLength":1,"maxLength":100},"monitorType":{"enum":["NONE","ALL_EPISODES","FUTURE_EPISODES","MISSING_AND_FUTURE_EPISODES"]}},"required":["key","name","monitorType"],"additionalProperties":false}`, "app"),
		tool("scryer_monitor", "The card's Monitor and Unmonitor buttons: change monitoring of one title, one season, or named episodes, then read the title again.",
			`{"type":"object","properties":{"titleId":{"type":"string","minLength":1,"maxLength":100},"monitorType":{"enum":["NONE","ALL_EPISODES","FUTURE_EPISODES","MISSING_AND_FUTURE_EPISODES"]},"seasonNumber":{"type":"integer","minimum":0},"episodeIds":{"type":"array","items":{"type":"string","minLength":1,"maxLength":100},"minItems":1,"maxItems":100},"monitored":{"type":"boolean"}},"required":["titleId"],"additionalProperties":false}`, "app"),
	}
}

func (a *scryerApp) resource() map[string]any {
	return map[string]any{"uri": scryerViewURI, "name": "scryer-media", "title": "Scryer", "description": "Search results and title cards for Scryer, with Add and Monitor buttons.", "mimeType": scryerViewMIME, "_meta": scryerResourceMeta(a.origin)}
}

func scryerResourceMeta(posterOrigin string) map[string]any {
	ui := map[string]any{"prefersBorder": false}
	if posterOrigin != "" {
		ui["csp"] = map[string]any{"resourceDomains": []string{posterOrigin}}
	}
	return map[string]any{"ui": ui}
}

// ---------- GraphQL ----------

// appError is a failure the person reads on the card. Transport errors keep the
// endpoint's wording, which the view turns into "Scryer did not answer".
type appError struct{ message string }

func (e appError) Error() string { return e.message }

// gql runs one operation and decodes data into out. GraphQL errors fail the call.
func (s *scryerClient) gql(ctx context.Context, query string, variables map[string]any, out any) error {
	body, _ := json.Marshal(map[string]any{"query": query, "variables": variables})
	reply, failed := s.execute(ctx, body)
	if failed {
		m, _ := reply.(map[string]any)
		if msg, ok := m["message"].(string); ok {
			return appError{msg}
		}
		if status, ok := m["status"]; ok {
			return appError{fmt.Sprintf("Scryer unavailable (HTTP %v); do not retry a mutation without reading its state", status)}
		}
		return appError{"Scryer unavailable; do not retry a mutation without reading its state"}
	}
	var envelope struct {
		Data   json.RawMessage
		Errors []struct{ Message string }
	}
	raw, _ := reply.(json.RawMessage)
	if json.Unmarshal(raw, &envelope) != nil {
		return appError{"Scryer returned invalid JSON"}
	}
	if len(envelope.Errors) > 0 {
		return appError{envelope.Errors[0].Message}
	}
	if json.Unmarshal(envelope.Data, out) != nil {
		return appError{"Scryer returned an unexpected shape"}
	}
	return nil
}

const searchQuery = `query($q:String!,$n:Int!){searchMetadataMulti(query:$q,limit:$n){movies{...M} series{...M} anime{...M}}}
fragment M on MetadataSearchItemPayload{tvdbId tmdbId name year status overview runtimeMinutes posterUrl popularity}`

const libraryQuery = `query($s:String!,$v:[String!]!){titlesByExternalIds(source:$s,values:$v){id libraryName facet monitored monitorType metadataFetchedAt episodesOwned episodesTotal mediaFiles{role} externalIds{source value}}}`

const titleQuery = `query($id:ID!){title(id:$id){id name libraryName facet monitored monitorType year overview posterUrl network contentStatus metadataFetchedAt
mediaFiles{episodeId sizeBytes qualityLabel role}
collections{id collectionType collectionIndex monitored episodes{id episodeNumber airDate title monitored sizeBytes mediaAvailability{state primaryQualityLabel}}}}}`

type searchItem struct {
	TvdbID         string   `json:"tvdbId"`
	TmdbID         *int     `json:"tmdbId"`
	Name           string   `json:"name"`
	Year           *int     `json:"year"`
	Status         *string  `json:"status"`
	Overview       *string  `json:"overview"`
	RuntimeMinutes *int     `json:"runtimeMinutes"`
	PosterURL      *string  `json:"posterUrl"`
	Popularity     *float64 `json:"popularity"`
}

type libraryTitle struct {
	LibraryName       string  `json:"libraryName"`
	ID                string  `json:"id"`
	Facet             string  `json:"facet"`
	Monitored         bool    `json:"monitored"`
	MonitorType       *string `json:"monitorType"`
	MetadataFetchedAt *string `json:"metadataFetchedAt"`
	EpisodesOwned     *int    `json:"episodesOwned"`
	EpisodesTotal     *int    `json:"episodesTotal"`
	MediaFiles        []struct {
		Role string `json:"role"`
	} `json:"mediaFiles"`
	ExternalIDs []struct {
		Source string `json:"source"`
		Value  string `json:"value"`
	} `json:"externalIds"`
}

type scryerTitle struct {
	LibraryName       string  `json:"libraryName"`
	ID                string  `json:"id"`
	Name              string  `json:"name"`
	Facet             string  `json:"facet"`
	Monitored         bool    `json:"monitored"`
	MonitorType       *string `json:"monitorType"`
	Year              *int    `json:"year"`
	Overview          *string `json:"overview"`
	PosterURL         *string `json:"posterUrl"`
	Network           *string `json:"network"`
	ContentStatus     *string `json:"contentStatus"`
	MetadataFetchedAt *string `json:"metadataFetchedAt"`
	MediaFiles        []struct {
		EpisodeID    *string `json:"episodeId"`
		SizeBytes    int64   `json:"sizeBytes"`
		QualityLabel *string `json:"qualityLabel"`
		Role         string  `json:"role"`
	} `json:"mediaFiles"`
	Collections []struct {
		ID              string `json:"id"`
		CollectionType  string `json:"collectionType"`
		CollectionIndex string `json:"collectionIndex"`
		Monitored       bool   `json:"monitored"`
		Episodes        []struct {
			ID                string  `json:"id"`
			EpisodeNumber     *string `json:"episodeNumber"`
			AirDate           *string `json:"airDate"`
			Title             *string `json:"title"`
			Monitored         bool    `json:"monitored"`
			SizeBytes         *int64  `json:"sizeBytes"`
			MediaAvailability struct {
				State               string  `json:"state"`
				PrimaryQualityLabel *string `json:"primaryQualityLabel"`
			} `json:"mediaAvailability"`
		} `json:"episodes"`
	} `json:"collections"`
}

// ---------- mapping to the view's contract ----------

var facetKind = map[string]string{"MOVIE": "movie", "SERIES": "series", "ANIME": "anime"}
var kindFacet = map[string]string{"movie": "MOVIE", "series": "SERIES", "anime": "ANIME"}

type scryerApp struct {
	client *scryerClient
	// The Scryer origin that serves /images/... posters, e.g. https://scryer.example.ts.net.
	origin string
}

func (a *scryerApp) poster(path *string) any {
	if path == nil || *path == "" {
		return nil
	}
	p := *path
	if strings.HasPrefix(p, "/") && a.origin != "" {
		return a.origin + p
	}
	if strings.HasPrefix(p, "https://") {
		return p
	}
	return nil
}

func ongoing(status *string) bool {
	return status != nil && strings.EqualFold(*status, "Continuing")
}

// candidateKey names a search result: facet, id source, id. The add tool parses it back.
var keyPattern = regexp.MustCompile(`^(movie|series|anime):(tvdb|tmdb):([0-9]{1,12})$`)

func candidateKey(kind string, item searchItem) string {
	if kind != "movie" && item.TvdbID != "" {
		return kind + ":tvdb:" + item.TvdbID
	}
	if item.TmdbID != nil {
		return kind + ":tmdb:" + strconv.Itoa(*item.TmdbID)
	}
	if item.TvdbID != "" {
		return kind + ":tvdb:" + item.TvdbID
	}
	return ""
}

func monitorTypeOf(t *string) any {
	if t == nil || *t == "" {
		return nil // Scryer has no recorded scope; the view words it from the episodes
	}
	return *t
}

func (a *scryerApp) search(ctx context.Context, query, libraryHint string) (map[string]any, error) {
	var found struct {
		Multi struct {
			Movies []searchItem `json:"movies"`
			Series []searchItem `json:"series"`
			Anime  []searchItem `json:"anime"`
		} `json:"searchMetadataMulti"`
	}
	if err := a.client.gql(ctx, searchQuery, map[string]any{"q": query, "n": 6}, &found); err != nil {
		return nil, err
	}
	type hit struct {
		kind string
		item searchItem
		key  string
	}
	var hits []hit
	ids := map[string][]string{}
	for kind, list := range map[string][]searchItem{"movie": found.Multi.Movies, "series": found.Multi.Series, "anime": found.Multi.Anime} {
		for _, item := range list {
			if key := candidateKey(kind, item); key != "" {
				hits = append(hits, hit{kind, item, key})
				m := keyPattern.FindStringSubmatch(key)
				ids[m[2]] = append(ids[m[2]], m[3])
			}
		}
	}
	pop := func(h hit) float64 {
		if h.item.Popularity == nil {
			return 0
		}
		return *h.item.Popularity
	}
	sort.SliceStable(hits, func(i, j int) bool { return pop(hits[i]) > pop(hits[j]) })
	// Which results are already in the library, by provider id and facet.
	library := map[string]libraryTitle{}
	for _, source := range []string{"tvdb", "tmdb"} {
		if len(ids[source]) == 0 {
			continue
		}
		var lib struct {
			Titles []libraryTitle `json:"titlesByExternalIds"`
		}
		if err := a.client.gql(ctx, libraryQuery, map[string]any{"s": source, "v": ids[source]}, &lib); err != nil {
			return nil, err
		}
		for _, t := range lib.Titles {
			for _, id := range t.ExternalIDs {
				if id.Source == source {
					library[facetKind[t.Facet]+":"+source+":"+id.Value] = t
				}
			}
		}
	}
	results := []any{}
	for _, h := range hits {
		r := map[string]any{"key": h.key, "name": h.item.Name, "kind": h.kind, "year": h.item.Year, "ongoing": ongoing(h.item.Status),
			"overview": h.item.Overview, "poster": a.poster(h.item.PosterURL), "runtimeMinutes": nil, "library": nil}
		if h.kind == "movie" {
			r["runtimeMinutes"] = h.item.RuntimeMinutes
		}
		if t, ok := library[h.key]; ok {
			lib := map[string]any{"titleId": t.ID, "libraryName": t.LibraryName, "monitored": t.Monitored, "monitorType": monitorTypeOf(t.MonitorType), "hydration": hydration(t.Facet, t.MetadataFetchedAt), "onDisk": nil}
			if t.Facet == "MOVIE" {
				have := 0
				for _, f := range t.MediaFiles {
					if f.Role == "primary" {
						have = 1
					}
				}
				lib["onDisk"] = map[string]int{"have": have, "total": 1}
			} else if t.EpisodesTotal != nil && *t.EpisodesTotal > 0 && t.EpisodesOwned != nil {
				lib["onDisk"] = map[string]int{"have": *t.EpisodesOwned, "total": *t.EpisodesTotal}
			}
			r["library"] = lib
		}
		results = append(results, r)
	}
	// Where an add can go, and which library the card proposes first.
	byFacet, err := a.manageable(ctx)
	if err != nil {
		return nil, err
	}
	choices, hintMatched := libraryChoices(byFacet, a.client.username, libraryHint)
	view := map[string]any{"view": "search", "query": query, "results": results, "libraries": choices}
	if strings.TrimSpace(libraryHint) != "" && !hintMatched {
		view["libraryHintUnmatched"] = libraryHint
	}
	return view, nil
}

func hydration(facet string, fetchedAt *string) string {
	if facet != "MOVIE" && (fetchedAt == nil || *fetchedAt == "") {
		return "pending"
	}
	return "ready"
}

func (a *scryerApp) readTitle(ctx context.Context, id string) (*scryerTitle, error) {
	var got struct {
		Title *scryerTitle `json:"title"`
	}
	if err := a.client.gql(ctx, titleQuery, map[string]any{"id": id}, &got); err != nil {
		return nil, err
	}
	if got.Title == nil {
		return nil, appError{"Scryer has no title with that id."}
	}
	return got.Title, nil
}

func seasonOf(collectionType, index string) (int, bool) {
	if collectionType == "SPECIALS" {
		return 0, true
	}
	if collectionType != "SEASON" {
		return 0, false
	}
	n, err := strconv.Atoi(index)
	return n, err == nil && n >= 0
}

func (a *scryerApp) titleView(t *scryerTitle, pendingOverride bool) map[string]any {
	kind := facetKind[t.Facet]
	state := hydration(t.Facet, t.MetadataFetchedAt)
	if pendingOverride {
		state = "pending"
	}
	title := map[string]any{"id": t.ID, "name": t.Name, "libraryName": t.LibraryName, "kind": kind, "year": t.Year, "ongoing": ongoing(t.ContentStatus), "network": t.Network,
		"overview": t.Overview, "poster": a.poster(t.PosterURL), "monitored": t.Monitored, "monitorType": monitorTypeOf(t.MonitorType), "hydration": state}
	out := map[string]any{"view": "title", "title": title, "seasons": []any{}}
	if kind == "movie" {
		movie := map[string]any{"onDisk": false, "file": nil}
		for _, f := range t.MediaFiles {
			if f.Role == "primary" && f.EpisodeID == nil {
				movie["onDisk"] = true
				movie["file"] = map[string]any{"quality": f.QualityLabel, "sizeBytes": f.SizeBytes}
			}
		}
		out["movie"] = movie
		return out
	}
	seasons := []any{}
	for _, c := range t.Collections {
		n, ok := seasonOf(c.CollectionType, c.CollectionIndex)
		if !ok {
			continue
		}
		episodes := []any{}
		for _, e := range c.Episodes {
			num, err := strconv.Atoi(strings.TrimSpace(deref(e.EpisodeNumber)))
			if err != nil {
				continue
			}
			onDisk := e.MediaAvailability.State == "AVAILABLE"
			var file any
			if onDisk {
				file = map[string]any{"quality": e.MediaAvailability.PrimaryQualityLabel, "sizeBytes": e.SizeBytes}
			}
			episodes = append(episodes, map[string]any{"id": e.ID, "number": num, "name": e.Title, "airDate": e.AirDate, "monitored": e.Monitored, "onDisk": onDisk, "file": file})
		}
		seasons = append(seasons, map[string]any{"number": n, "episodes": episodes})
	}
	out["seasons"] = seasons
	return out
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// ---------- writes ----------

var allowedScopes = map[string]bool{"NONE": true, "ALL_EPISODES": true, "FUTURE_EPISODES": true, "MISSING_AND_FUTURE_EPISODES": true}

// ---------- libraries ----------
//
// Nothing about libraries is fixed here: no names, no count, no owner list. The
// choices are whatever Scryer lets the signed-in account add titles to, and the
// suggestion is derived from that account's own name. On a Scryer with one
// library per kind there is no choice and no question.

type scryerLibrary struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Slug      string `json:"slug"`
	Facet     string `json:"facet"`
	IsDefault bool   `json:"isDefault"`
}

const librariesQuery = `query{me{libraryPermissions{libraryId permissions}} libraries(permission:MANAGE_TITLES){id name slug facet isDefault}}`

// manageable lists the libraries a card may add to, by facet, by name: those the
// account was explicitly granted MANAGE_TITLES on. An app-wide admin can reach
// every library, including other people's; the grants say which are meant for
// this account. An account with no grant on any listed library (a plain admin on
// a simple install) gets everything Scryer lets it manage.
func (a *scryerApp) manageable(ctx context.Context) (map[string][]scryerLibrary, error) {
	var result struct {
		Me *struct {
			LibraryPermissions []struct {
				LibraryID   string   `json:"libraryId"`
				Permissions []string `json:"permissions"`
			} `json:"libraryPermissions"`
		} `json:"me"`
		Libraries []scryerLibrary `json:"libraries"`
	}
	if err := a.client.gql(ctx, librariesQuery, nil, &result); err != nil {
		return nil, err
	}
	granted := map[string]bool{}
	if result.Me != nil {
		for _, grant := range result.Me.LibraryPermissions {
			for _, permission := range grant.Permissions {
				if permission == "MANAGE_TITLES" {
					granted[grant.LibraryID] = true
				}
			}
		}
	}
	anyGranted := false
	for _, l := range result.Libraries {
		anyGranted = anyGranted || granted[l.ID]
	}
	byFacet := map[string][]scryerLibrary{}
	for _, l := range result.Libraries {
		if l.ID != "" && l.Name != "" && facetKind[l.Facet] != "" && (granted[l.ID] || !anyGranted) {
			byFacet[l.Facet] = append(byFacet[l.Facet], l)
		}
	}
	for _, list := range byFacet {
		sort.SliceStable(list, func(i, j int) bool { return strings.ToLower(list[i].Name) < strings.ToLower(list[j].Name) })
	}
	return byFacet, nil
}

var wordSplit = regexp.MustCompile(`[^\p{L}\p{N}]+`)

func words(s string) []string {
	out := []string{}
	for _, w := range wordSplit.Split(strings.ToLower(s), -1) {
		if w != "" {
			out = append(out, w)
		}
	}
	return out
}

func hasAllWords(l scryerLibrary, want []string) bool {
	have := map[string]bool{}
	for _, w := range append(words(l.Name), words(l.Slug)...) {
		have[w] = true
	}
	for _, w := range want {
		if !have[w] {
			return false
		}
	}
	return len(want) > 0
}

// ownLibrary is the one library of a facet named after the account ("Simon
// Movies" or slug simon-movies for the account simon). None or several: no answer.
func ownLibrary(list []scryerLibrary, username string) (scryerLibrary, bool) {
	var found []scryerLibrary
	for _, l := range list {
		if hasAllWords(l, words(username)) {
			found = append(found, l)
		}
	}
	if len(found) == 1 {
		return found[0], true
	}
	return scryerLibrary{}, false
}

// hintedLibrary is the one library whose name holds every word of the hint. Words
// that name the kind, not the owner ("movies", "series", "library"), are ignored.
func hintedLibrary(list []scryerLibrary, hint string) (scryerLibrary, bool) {
	generic := map[string]bool{"the": true, "library": true, "libraries": true, "movie": true, "movies": true, "film": true, "films": true, "series": true, "show": true, "shows": true, "tv": true, "anime": true}
	want := []string{}
	for _, w := range words(hint) {
		if !generic[w] {
			want = append(want, w)
		}
	}
	var found []scryerLibrary
	for _, l := range list {
		if hasAllWords(l, want) {
			found = append(found, l)
		}
	}
	if len(found) == 1 {
		return found[0], true
	}
	return scryerLibrary{}, false
}

// suggest picks the library a card proposes first: the one the request named,
// else the account's own, else Scryer's default for the kind, else the only one.
// It is a proposal; the person confirms it on the card.
func suggest(list []scryerLibrary, username, hint string) string {
	if l, ok := hintedLibrary(list, hint); ok {
		return l.ID
	}
	if l, ok := ownLibrary(list, username); ok {
		return l.ID
	}
	for _, l := range list {
		if l.IsDefault {
			return l.ID
		}
	}
	if len(list) == 1 {
		return list[0].ID
	}
	return ""
}

// libraryChoices is the view's list per kind, suggested first.
func libraryChoices(byFacet map[string][]scryerLibrary, username, hint string) (map[string]any, bool) {
	out := map[string]any{}
	hintMatched := false
	for facet, kind := range facetKind {
		list := byFacet[facet]
		pick := suggest(list, username, hint)
		if _, ok := hintedLibrary(list, hint); ok {
			hintMatched = true
		}
		choices := []any{}
		for _, first := range []bool{true, false} {
			for _, l := range list {
				if (l.ID == pick) == first {
					choices = append(choices, map[string]any{"id": l.ID, "name": l.Name, "suggested": l.ID == pick})
				}
			}
		}
		out[kind] = choices
	}
	return out, hintMatched
}

// addTarget is where an add goes. A named library must be one the account can
// manage for this kind. With none named, only an unambiguous answer is used: the
// single library, or the account's own. It never guesses a shared default.
func (a *scryerApp) addTarget(ctx context.Context, facet, libraryID string) (scryerLibrary, error) {
	byFacet, err := a.manageable(ctx)
	if err != nil {
		return scryerLibrary{}, err
	}
	list := byFacet[facet]
	if len(list) == 0 {
		return scryerLibrary{}, appError{"This Scryer account cannot add " + strings.ToLower(facet) + " titles to any library; nothing was added."}
	}
	if libraryID != "" {
		for _, l := range list {
			if l.ID == libraryID {
				return l, nil
			}
		}
		return scryerLibrary{}, appError{"This Scryer account cannot add to that library; nothing was added."}
	}
	if len(list) == 1 {
		return list[0], nil
	}
	if l, ok := ownLibrary(list, a.client.username); ok {
		return l, nil
	}
	names := []string{}
	for _, l := range list {
		names = append(names, l.Name)
	}
	return scryerLibrary{}, appError{"Choose a library: " + strings.Join(names, ", ") + ". Nothing was added."}
}

func (a *scryerApp) add(ctx context.Context, key, name string, year *int, monitorType, libraryID string) (map[string]any, error) {
	m := keyPattern.FindStringSubmatch(key)
	if m == nil || !allowedScopes[monitorType] || strings.TrimSpace(name) == "" {
		return nil, appError{"That result cannot be added from the card."}
	}
	kind, source, id := m[1], m[2], m[3]
	facet := kindFacet[kind]
	target, err := a.addTarget(ctx, facet, libraryID)
	if err != nil {
		return nil, err
	}
	// Never add a title twice: an existing title is shown as it is.
	var lib struct {
		Titles []libraryTitle `json:"titlesByExternalIds"`
	}
	if err := a.client.gql(ctx, libraryQuery, map[string]any{"s": source, "v": []string{id}}, &lib); err != nil {
		return nil, err
	}
	for _, t := range lib.Titles {
		match := false
		for _, x := range t.ExternalIDs {
			match = match || (x.Source == source && x.Value == id)
		}
		if t.Facet == facet && match {
			read, err := a.readTitle(ctx, t.ID)
			if err != nil {
				return nil, err
			}
			view := a.titleView(read, false)
			view["done"] = map[string]any{"action": "exists", "libraryName": read.LibraryName}
			return view, nil
		}
	}
	input := map[string]any{"name": name, "facet": facet, "libraryId": target.ID, "monitored": monitorType != "NONE", "tags": []string{}}
	if year != nil {
		input["year"] = *year
	}
	if source == "tvdb" {
		input["tvdbId"] = id
	} else {
		n, _ := strconv.Atoi(id)
		input["tmdbId"] = n
	}
	if kind != "movie" {
		input["options"] = map[string]any{"monitorType": monitorType}
	}
	var added struct {
		AddTitle struct {
			Title struct {
				ID string `json:"id"`
			} `json:"title"`
			MetadataHydrationState string `json:"metadataHydrationState"`
		} `json:"addTitle"`
	}
	if err := a.client.gql(ctx, `mutation($i:AddTitleInput!){addTitle(input:$i){title{id} metadataHydrationState}}`, map[string]any{"i": input}, &added); err != nil {
		return nil, err
	}
	read, err := a.readTitle(ctx, added.AddTitle.Title.ID)
	if err != nil {
		return nil, err
	}
	view := a.titleView(read, added.AddTitle.MetadataHydrationState == "PENDING")
	view["done"] = map[string]any{"action": "add", "libraryName": target.Name}
	return view, nil
}

type monitorArgs struct {
	TitleID      string   `json:"titleId"`
	MonitorType  *string  `json:"monitorType"`
	SeasonNumber *int     `json:"seasonNumber"`
	EpisodeIDs   []string `json:"episodeIds"`
	Monitored    *bool    `json:"monitored"`
}

func (a *scryerApp) monitor(ctx context.Context, args monitorArgs) (map[string]any, error) {
	scopes := 0
	for _, set := range []bool{args.MonitorType != nil, args.SeasonNumber != nil, len(args.EpisodeIDs) > 0} {
		if set {
			scopes++
		}
	}
	if scopes != 1 || (args.MonitorType == nil && args.Monitored == nil) || (args.MonitorType != nil && !allowedScopes[*args.MonitorType]) {
		return nil, appError{"Name exactly one scope: monitorType, seasonNumber or episodeIds (with monitored)."}
	}
	t, err := a.readTitle(ctx, args.TitleID)
	if err != nil {
		return nil, err
	}
	switch {
	case args.MonitorType != nil:
		on := *args.MonitorType != "NONE"
		if t.Facet != "MOVIE" {
			if err := a.client.gql(ctx, `mutation($i:UpdateTitleInput!){updateTitle(input:$i){id}}`, map[string]any{"i": map[string]any{"titleId": t.ID, "options": map[string]any{"monitorType": *args.MonitorType}}}, &struct{}{}); err != nil {
				return nil, err
			}
		}
		if err := a.client.gql(ctx, `mutation($i:SetTitleMonitoredInput!){setTitleMonitored(input:$i){id}}`, map[string]any{"i": map[string]any{"titleId": t.ID, "monitored": on}}, &struct{}{}); err != nil {
			return nil, err
		}
	case args.SeasonNumber != nil:
		collection := ""
		for _, c := range t.Collections {
			if n, ok := seasonOf(c.CollectionType, c.CollectionIndex); ok && n == *args.SeasonNumber {
				collection = c.ID
			}
		}
		if collection == "" {
			return nil, appError{"Scryer lists no such season for this title."}
		}
		if err := a.client.gql(ctx, `mutation($i:SetCollectionMonitoredInput!){setCollectionMonitored(input:$i){id}}`, map[string]any{"i": map[string]any{"collectionId": collection, "monitored": *args.Monitored}}, &struct{}{}); err != nil {
			return nil, err
		}
	default:
		// Only episodes of this title: the card cannot reach any other title's episodes.
		own := map[string]bool{}
		for _, c := range t.Collections {
			for _, e := range c.Episodes {
				own[e.ID] = true
			}
		}
		for _, id := range args.EpisodeIDs {
			if !own[id] {
				return nil, appError{"An episode does not belong to this title."}
			}
		}
		for _, id := range args.EpisodeIDs {
			if err := a.client.gql(ctx, `mutation($i:SetEpisodeMonitoredInput!){setEpisodeMonitored(input:$i){id}}`, map[string]any{"i": map[string]any{"episodeId": id, "monitored": *args.Monitored}}, &struct{}{}); err != nil {
				return nil, err
			}
		}
	}
	read, err := a.readTitle(ctx, t.ID)
	if err != nil {
		return nil, err
	}
	view := a.titleView(read, false)
	view["done"] = map[string]any{"action": "monitor"}
	return view, nil
}

// call runs one app tool. Arguments are decoded strictly; unknown fields fail.
func (a *scryerApp) call(ctx context.Context, name string, raw json.RawMessage) (map[string]any, error) {
	strict := func(v any) error {
		d := json.NewDecoder(strings.NewReader(string(raw)))
		d.DisallowUnknownFields()
		if d.Decode(v) != nil {
			return errInvalidArgs
		}
		return nil
	}
	switch name {
	case "scryer_search":
		var args struct {
			Query   string `json:"query"`
			Library string `json:"library"`
		}
		if strict(&args) != nil || strings.TrimSpace(args.Query) == "" || len(args.Query) > 200 || len(args.Library) > 100 {
			return nil, errInvalidArgs
		}
		return a.search(ctx, strings.TrimSpace(args.Query), args.Library)
	case "scryer_title":
		var args struct {
			TitleID string `json:"titleId"`
		}
		if strict(&args) != nil || args.TitleID == "" || len(args.TitleID) > 100 {
			return nil, errInvalidArgs
		}
		t, err := a.readTitle(ctx, args.TitleID)
		if err != nil {
			return nil, err
		}
		return a.titleView(t, false), nil
	case "scryer_add":
		var args struct {
			LibraryID   string `json:"libraryId"`
			Key         string `json:"key"`
			Name        string `json:"name"`
			Year        *int   `json:"year"`
			MonitorType string `json:"monitorType"`
		}
		if strict(&args) != nil || len(args.Name) > 300 || len(args.LibraryID) > 100 {
			return nil, errInvalidArgs
		}
		return a.add(ctx, args.Key, args.Name, args.Year, args.MonitorType, args.LibraryID)
	case "scryer_monitor":
		var args monitorArgs
		if strict(&args) != nil || args.TitleID == "" || len(args.EpisodeIDs) > 100 {
			return nil, errInvalidArgs
		}
		return a.monitor(ctx, args)
	}
	return nil, errUnknownTool
}

var (
	errInvalidArgs = errors.New("invalid arguments")
	errUnknownTool = errors.New("tool not allowed")
)

// originOf is the scheme and host of the Scryer GraphQL URL, where posters live.
func originOf(graphqlURL string) string {
	u, err := url.Parse(graphqlURL)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return ""
	}
	return u.Scheme + "://" + u.Host
}

// ---------- the model's copy ----------

// modelText is the short text the model reads. The card draws from the full
// structuredContent; a host may cut long text, so this stays a summary.
func modelText(view map[string]any) string {
	var b strings.Builder
	str := func(v any) string {
		switch x := v.(type) {
		case string:
			return x
		case *string:
			return deref(x)
		case *int:
			if x != nil {
				return strconv.Itoa(*x)
			}
		}
		return ""
	}
	switch view["view"] {
	case "search":
		results, _ := view["results"].([]any)
		fmt.Fprintf(&b, "Scryer search %q: %d results. The person sees them as a card with Add and Monitor buttons; you do not see what they press.\n", view["query"], len(results))
		if libs, ok := view["libraries"].(map[string]any); ok {
			b.WriteString("Libraries this account can add to (the card asks when there is more than one, and proposes the one marked suggested):\n")
			for _, kind := range []string{"movie", "series", "anime"} {
				names := []string{}
				list, _ := libs[kind].([]any)
				for _, item := range list {
					l, _ := item.(map[string]any)
					name := fmt.Sprint(l["name"])
					if l["suggested"] == true {
						name += " (suggested)"
					}
					names = append(names, name)
				}
				if len(names) == 0 {
					names = []string{"none"}
				}
				fmt.Fprintf(&b, "- %s: %s\n", kind, strings.Join(names, ", "))
			}
		}
		if hint, ok := view["libraryHintUnmatched"].(string); ok {
			fmt.Fprintf(&b, "The library hint %q matched no single library name above, so the card suggests the default. Search again with words from one of those names.\n", hint)
		}
		for i, item := range results {
			r, _ := item.(map[string]any)
			fmt.Fprintf(&b, "%d. %s (%s", i+1, r["name"], r["kind"])
			if y := str(r["year"]); y != "" {
				b.WriteString(", " + y)
			}
			b.WriteString(")")
			if lib, ok := r["library"].(map[string]any); ok {
				state := "not monitored"
				if lib["monitored"] == true {
					state = "monitored"
				}
				fmt.Fprintf(&b, ": in %s, titleId %s, %s", lib["libraryName"], lib["titleId"], state)
				if d, ok := lib["onDisk"].(map[string]int); ok {
					fmt.Fprintf(&b, ", %d of %d on disk", d["have"], d["total"])
				}
			} else {
				b.WriteString(": not in a library")
			}
			b.WriteString("\n")
		}
	case "title":
		t, _ := view["title"].(map[string]any)
		state := "not monitored"
		if t["monitored"] == true {
			state = "monitored"
		}
		fmt.Fprintf(&b, "Scryer title card: %s (%s", t["name"], t["kind"])
		if y := str(t["year"]); y != "" {
			b.WriteString(", " + y)
		}
		fmt.Fprintf(&b, "), titleId %s, library %s, %s", t["id"], t["libraryName"], state)
		if mt, ok := t["monitorType"].(string); ok {
			b.WriteString(", scope " + mt)
		}
		if t["hydration"] == "pending" {
			b.WriteString(". Scryer is still reading its episodes")
		}
		b.WriteString(".\n")
		if done, ok := view["done"].(map[string]any); ok {
			fmt.Fprintf(&b, "Done: %s", done["action"])
			if n, ok := done["libraryName"].(string); ok && n != "" {
				b.WriteString(" in " + n)
			}
			b.WriteString(".\n")
		}
		if movie, ok := view["movie"].(map[string]any); ok {
			if movie["onDisk"] == true {
				b.WriteString("On disk.\n")
			} else {
				b.WriteString("Not on disk.\n")
			}
		}
		seasons, _ := view["seasons"].([]any)
		for _, item := range seasons {
			s, _ := item.(map[string]any)
			episodes, _ := s["episodes"].([]any)
			disk, monitored := 0, 0
			for _, e := range episodes {
				ep, _ := e.(map[string]any)
				if ep["onDisk"] == true {
					disk++
				}
				if ep["monitored"] == true {
					monitored++
				}
			}
			name := fmt.Sprintf("Season %v", s["number"])
			if s["number"] == 0 {
				name = "Specials"
			}
			fmt.Fprintf(&b, "%s: %d episodes, %d on disk, %d monitored\n", name, len(episodes), disk, monitored)
		}
		b.WriteString("For single episodes, read the title with scryer_graphql.\n")
	}
	return b.String()
}
