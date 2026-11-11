package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"
)

// gqlFixture answers the operations the app tools send, from a tiny library:
// one series (two seasons, specials) and one movie. It records every mutation.
type gqlFixture struct {
	mu        sync.Mutex
	mutations []string
	inputs    []map[string]any
	failNext  string // a mutation name that returns a GraphQL error once
}

const fixtureTitle = `{"id":"t1","name":"Curb Your Enthusiasm","facet":"SERIES","monitored":true,"monitorType":null,"year":2000,"overview":"Larry.","posterUrl":"/images/media/abc/w250","network":"HBO","contentStatus":"Ended","metadataFetchedAt":"2026-11-10T00:00:00Z",
"mediaFiles":[{"episodeId":"e1","sizeBytes":3000000000,"qualityLabel":"1080p","role":"primary"}],
"collections":[
 {"id":"c0","collectionType":"SPECIALS","collectionIndex":"0","monitored":false,"episodes":[{"id":"e0","episodeNumber":"1","airDate":"1999-10-17","title":"Special","monitored":false,"sizeBytes":null,"mediaAvailability":{"state":"UNMONITORED","primaryQualityLabel":null}}]},
 {"id":"c1","collectionType":"SEASON","collectionIndex":"1","monitored":true,"episodes":[{"id":"e1","episodeNumber":"1","airDate":"2000-10-15","title":"The Pants Tent","monitored":true,"sizeBytes":3000000000,"mediaAvailability":{"state":"AVAILABLE","primaryQualityLabel":"1080p"}},{"id":"e2","episodeNumber":"2","airDate":"2000-10-22","title":"Ted and Mary","monitored":true,"sizeBytes":null,"mediaAvailability":{"state":"MISSING","primaryQualityLabel":null}}]},
 {"id":"c2","collectionType":"SEASON","collectionIndex":"2","monitored":false,"episodes":[{"id":"e3","episodeNumber":"1","airDate":"2001-09-23","title":"The Car Salesman","monitored":false,"sizeBytes":null,"mediaAvailability":{"state":"UNMONITORED","primaryQualityLabel":null}}]},
 {"id":"cx","collectionType":"ARC","collectionIndex":"x","monitored":false,"episodes":[]}]}`

const fixtureMovie = `{"id":"m1","name":"Frozen","facet":"MOVIE","monitored":true,"monitorType":null,"year":2013,"overview":null,"posterUrl":null,"network":null,"contentStatus":"Released","metadataFetchedAt":"2026-10-01T00:00:00Z",
"mediaFiles":[{"episodeId":null,"sizeBytes":7044446881,"qualityLabel":"1080p","role":"primary"}],"collections":[{"id":"cm","collectionType":"MOVIE","collectionIndex":"1","monitored":true,"episodes":[]}]}`

func (f *gqlFixture) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	var body struct {
		Query     string
		Variables map[string]any
	}
	json.NewDecoder(r.Body).Decode(&body)
	w.Header().Set("Content-Type", "application/json")
	q := body.Query
	switch {
	case strings.Contains(q, "login(input:"):
		fmt.Fprintf(w, `{"data":{"login":{"token":"tok","expiresAt":%q}}}`, time.Now().Add(time.Hour).Format(time.RFC3339Nano))
	case strings.Contains(q, "searchMetadataMulti"):
		fmt.Fprint(w, `{"data":{"searchMetadataMulti":{
		 "movies":[{"tvdbId":"","tmdbId":109445,"name":"Frozen","year":2013,"status":"Released","overview":"Sisters.","runtimeMinutes":102,"posterUrl":"/images/media/f/w250","popularity":9},
		           {"tvdbId":"","tmdbId":null,"name":"No ids","year":null,"status":null,"overview":null,"runtimeMinutes":null,"posterUrl":null,"popularity":null}],
		 "series":[{"tvdbId":"76203","tmdbId":4546,"name":"Curb Your Enthusiasm","year":2000,"status":"Ended","overview":"Larry.","runtimeMinutes":30,"posterUrl":"http://evil/x.jpg","popularity":5},
		           {"tvdbId":"999","tmdbId":null,"name":"Curb","year":2024,"status":"Continuing","overview":null,"runtimeMinutes":30,"posterUrl":null,"popularity":1}],
		 "anime":[]}}}`)
	case strings.Contains(q, "titlesByExternalIds"):
		values, _ := json.Marshal(body.Variables["v"])
		switch {
		case body.Variables["s"] == "tvdb" && strings.Contains(string(values), `"76203"`):
			fmt.Fprint(w, `{"data":{"titlesByExternalIds":[{"id":"t1","facet":"SERIES","monitored":true,"monitorType":null,"metadataFetchedAt":"2026-11-10T00:00:00Z","episodesOwned":1,"episodesTotal":4,"mediaFiles":[],"externalIds":[{"source":"tvdb","value":"76203"}]}]}}`)
		case body.Variables["s"] == "tmdb" && strings.Contains(string(values), `"109445"`):
			fmt.Fprint(w, `{"data":{"titlesByExternalIds":[{"id":"m1","facet":"MOVIE","monitored":true,"monitorType":null,"metadataFetchedAt":"x","episodesOwned":null,"episodesTotal":null,"mediaFiles":[{"role":"primary"}],"externalIds":[{"source":"tmdb","value":"109445"}]}]}}`)
		default:
			fmt.Fprint(w, `{"data":{"titlesByExternalIds":[]}}`)
		}
	case strings.HasPrefix(q, "query($id:ID!){title("):
		switch body.Variables["id"] {
		case "t1":
			fmt.Fprintf(w, `{"data":{"title":%s}}`, fixtureTitle)
		case "m1":
			fmt.Fprintf(w, `{"data":{"title":%s}}`, fixtureMovie)
		case "new":
			fmt.Fprint(w, `{"data":{"title":{"id":"new","name":"Curb","facet":"SERIES","monitored":true,"monitorType":"FUTURE_EPISODES","metadataFetchedAt":null,"mediaFiles":[],"collections":[]}}}`)
		default:
			fmt.Fprint(w, `{"data":{"title":null}}`)
		}
	case strings.HasPrefix(q, "mutation"):
		name := regexp.MustCompile(`\{(\w+)\(`).FindStringSubmatch(q)[1]
		f.mutations = append(f.mutations, name)
		input, _ := body.Variables["i"].(map[string]any)
		f.inputs = append(f.inputs, input)
		if f.failNext == name {
			f.failNext = ""
			fmt.Fprint(w, `{"data":null,"errors":[{"message":"Scryer refused the change"}]}`)
			return
		}
		if name == "addTitle" {
			fmt.Fprint(w, `{"data":{"addTitle":{"title":{"id":"new"},"metadataHydrationState":"PENDING"}}}`)
			return
		}
		fmt.Fprintf(w, `{"data":{"%s":{"id":"x"}}}`, name)
	default:
		w.WriteHeader(400)
	}
}

func appHandler(t *testing.T) (*gqlFixture, http.Handler) {
	t.Helper()
	f := &gqlFixture{}
	server := httptest.NewServer(f)
	t.Cleanup(server.Close)
	return f, scryerHandler(newScryerClient(server.URL, "pw-secret"), func(*http.Request) bool { return true })
}

type toolReply struct {
	Result struct {
		IsError           bool
		StructuredContent map[string]any
		Content           []struct{ Text string }
		Contents          []struct {
			URI, MimeType, Text string
			Meta                map[string]any `json:"_meta"`
		}
		Tools     []map[string]any
		Resources []map[string]any
	}
	Error *struct {
		Code    int
		Message string
	}
}

func rpc(t *testing.T, h http.Handler, method string, params any) toolReply {
	t.Helper()
	body, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": 7, "method": method, "params": params})
	w := callScryer(h, string(body))
	var reply toolReply
	if err := json.Unmarshal(w.Body.Bytes(), &reply); err != nil {
		t.Fatalf("%s: %s", method, w.Body.String())
	}
	return reply
}

func call(t *testing.T, h http.Handler, name string, args any) toolReply {
	return rpc(t, h, "tools/call", map[string]any{"name": name, "arguments": args})
}

func TestScryerAppListsToolsAndView(t *testing.T) {
	_, h := appHandler(t)
	tools := rpc(t, h, "tools/list", nil).Result.Tools
	visibility := map[string]string{}
	for _, tool := range tools {
		meta, _ := tool["_meta"].(map[string]any)
		ui, _ := meta["ui"].(map[string]any)
		vis, _ := json.Marshal(ui["visibility"])
		visibility[tool["name"].(string)] = string(vis)
		if tool["name"] != "scryer_graphql" && (ui["resourceUri"] != scryerViewURI || meta["ui/resourceUri"] != scryerViewURI) {
			t.Fatalf("%s does not point at the view", tool["name"])
		}
		hints, _ := tool["annotations"].(map[string]any)
		switch tool["name"] {
		case "scryer_graphql":
			if hints != nil {
				t.Fatal("full-admin GraphQL must carry no hints that could skip a host prompt")
			}
		case "scryer_search", "scryer_title":
			if hints["readOnlyHint"] != true {
				t.Fatalf("%s is read-only", tool["name"])
			}
		default:
			if hints["readOnlyHint"] != false || hints["destructiveHint"] != false {
				t.Fatalf("%s writes but never destroys", tool["name"])
			}
		}
	}
	want := map[string]string{"scryer_graphql": "null", "scryer_search": `["model","app"]`, "scryer_title": `["model","app"]`, "scryer_add": `["app"]`, "scryer_monitor": `["app"]`}
	if fmt.Sprint(visibility) != fmt.Sprint(want) {
		t.Fatalf("tools and visibility: %v", visibility)
	}
	read := rpc(t, h, "resources/read", map[string]any{"uri": scryerViewURI})
	if len(read.Result.Contents) != 1 || read.Result.Contents[0].MimeType != scryerViewMIME || !strings.Contains(read.Result.Contents[0].Text, "scryer-media-view source-sha256:") {
		t.Fatal("view not served")
	}
	if listed := rpc(t, h, "resources/list", nil).Result.Resources; len(listed) != 1 || listed[0]["uri"] != scryerViewURI {
		t.Fatal("resources/list")
	}
	for _, uri := range []string{"ui://scryer/other.html", "file:///etc/passwd", ""} {
		if rpc(t, h, "resources/read", map[string]any{"uri": uri}).Error == nil {
			t.Fatalf("resource %q served", uri)
		}
	}
}

func TestScryerSearchMarksLibraryAndKeepsOnlySafePosters(t *testing.T) {
	_, h := appHandler(t)
	r := call(t, h, "scryer_search", map[string]any{"query": "Curb"})
	if r.Result.IsError {
		t.Fatal(r.Result.Content)
	}
	results := r.Result.StructuredContent["results"].([]any)
	if len(results) != 3 {
		t.Fatalf("a result without ids must be dropped: %d", len(results))
	}
	first := results[0].(map[string]any)
	if first["key"] != "movie:tmdb:109445" || first["library"].(map[string]any)["titleId"] != "m1" {
		t.Fatalf("most popular first, with library state: %v", first)
	}
	if first["library"].(map[string]any)["onDisk"].(map[string]any)["have"] != 1.0 {
		t.Fatal("movie on disk")
	}
	curb := results[1].(map[string]any)
	if curb["key"] != "series:tvdb:76203" || curb["poster"] != nil {
		t.Fatalf("http poster must be dropped, relative poster needs an https origin: %v", curb["poster"])
	}
	if lib := curb["library"].(map[string]any); lib["monitorType"] != nil || lib["onDisk"].(map[string]any)["total"] != 4.0 {
		t.Fatalf("library state: %v", lib)
	}
	if other := results[2].(map[string]any); other["library"] != nil || other["ongoing"] != true {
		t.Fatalf("a different show with a similar name is not in the library: %v", other)
	}
	app := &scryerApp{origin: originOf("https://scryer.example.ts.net/graphql")}
	p := "/images/media/abc/w250"
	if app.poster(&p) != "https://scryer.example.ts.net/images/media/abc/w250" {
		t.Fatal("relative poster becomes absolute on the Scryer origin")
	}
	if meta := scryerResourceMeta(app.origin)["ui"].(map[string]any); fmt.Sprint(meta["csp"]) != "map[resourceDomains:[https://scryer.example.ts.net]]" {
		t.Fatalf("CSP declares the poster origin: %v", meta)
	}
}

func TestScryerTitleMapsSeasonsEpisodesAndMovies(t *testing.T) {
	_, h := appHandler(t)
	sc := call(t, h, "scryer_title", map[string]any{"titleId": "t1"}).Result.StructuredContent
	seasons := sc["seasons"].([]any)
	if len(seasons) != 3 {
		t.Fatalf("specials and two seasons; arcs dropped: %d", len(seasons))
	}
	s1 := seasons[1].(map[string]any)
	e1 := s1["episodes"].([]any)[0].(map[string]any)
	if s1["number"] != 1.0 || e1["onDisk"] != true || e1["file"].(map[string]any)["quality"] != "1080p" {
		t.Fatalf("episode on disk: %v", e1)
	}
	if title := sc["title"].(map[string]any); title["hydration"] != "ready" || title["monitorType"] != nil || title["network"] != "HBO" {
		t.Fatalf("title: %v", title)
	}
	movie := call(t, h, "scryer_title", map[string]any{"titleId": "m1"}).Result.StructuredContent["movie"].(map[string]any)
	if movie["onDisk"] != true {
		t.Fatal("movie on disk")
	}
	if r := call(t, h, "scryer_title", map[string]any{"titleId": "nope"}); !r.Result.IsError {
		t.Fatal("unknown title")
	}
}

func TestScryerMonitorKeepsExactScope(t *testing.T) {
	f, h := appHandler(t)
	r := call(t, h, "scryer_monitor", map[string]any{"titleId": "t1", "seasonNumber": 2, "monitored": true})
	if r.Result.IsError || r.Result.StructuredContent["done"].(map[string]any)["action"] != "monitor" {
		t.Fatal(r.Result.Content)
	}
	if fmt.Sprint(f.mutations) != "[setCollectionMonitored]" || f.inputs[0]["collectionId"] != "c2" || f.inputs[0]["monitored"] != true {
		t.Fatalf("season 2 only: %v %v", f.mutations, f.inputs)
	}
	f.mutations, f.inputs = nil, nil
	call(t, h, "scryer_monitor", map[string]any{"titleId": "t1", "seasonNumber": 0, "monitored": false})
	if f.inputs[0]["collectionId"] != "c0" {
		t.Fatal("season 0 is the specials")
	}
	f.mutations, f.inputs = nil, nil
	call(t, h, "scryer_monitor", map[string]any{"titleId": "t1", "episodeIds": []string{"e2"}, "monitored": false})
	if fmt.Sprint(f.mutations) != "[setEpisodeMonitored]" || f.inputs[0]["episodeId"] != "e2" {
		t.Fatalf("one episode: %v", f.mutations)
	}
	f.mutations, f.inputs = nil, nil
	call(t, h, "scryer_monitor", map[string]any{"titleId": "t1", "monitorType": "FUTURE_EPISODES"})
	if fmt.Sprint(f.mutations) != "[updateTitle setTitleMonitored]" || fmt.Sprint(f.inputs[0]["options"]) != "map[monitorType:FUTURE_EPISODES]" || f.inputs[1]["monitored"] != true {
		t.Fatalf("whole show scope: %v %v", f.mutations, f.inputs)
	}
	f.mutations, f.inputs = nil, nil
	call(t, h, "scryer_monitor", map[string]any{"titleId": "m1", "monitorType": "NONE"})
	if fmt.Sprint(f.mutations) != "[setTitleMonitored]" || f.inputs[0]["monitored"] != false {
		t.Fatalf("movie: %v", f.mutations)
	}
}

func TestScryerMonitorRefusesWhatTheCardMustNotDo(t *testing.T) {
	f, h := appHandler(t)
	for _, args := range []map[string]any{
		{"titleId": "t1", "episodeIds": []string{"e1", "elsewhere"}, "monitored": true}, // another title's episode
		{"titleId": "t1", "seasonNumber": 9, "monitored": true},                         // no such season
		{"titleId": "t1", "seasonNumber": 1},                                            // no direction
		{"titleId": "t1", "seasonNumber": 1, "episodeIds": []string{"e1"}, "monitored": true},
		{"titleId": "t1", "monitorType": "ADVANCED"},
	} {
		r := call(t, h, "scryer_monitor", args)
		if !r.Result.IsError && r.Error == nil {
			t.Fatalf("accepted %v", args)
		}
	}
	for _, bad := range []map[string]any{{"titleId": "t1", "delete": true}, {"query": "x", "extra": 1}} {
		if r := call(t, h, "scryer_monitor", bad); r.Error == nil || r.Error.Code != -32602 {
			t.Fatalf("unknown fields must fail: %v", bad)
		}
	}
	if r := call(t, h, "scryer_delete", map[string]any{"titleId": "t1"}); r.Error == nil || r.Error.Code != -32601 {
		t.Fatal("unknown tool")
	}
	if len(f.mutations) != 0 {
		t.Fatalf("refused calls reached Scryer: %v", f.mutations)
	}
	f.failNext = "setCollectionMonitored"
	r := call(t, h, "scryer_monitor", map[string]any{"titleId": "t1", "seasonNumber": 2, "monitored": true})
	if !r.Result.IsError || r.Result.StructuredContent != nil || !strings.Contains(r.Result.Content[0].Text, "Scryer refused the change") {
		t.Fatal("a refused write is an error with Scryer's words and no drawn state")
	}
}

func TestScryerAddNeverDuplicates(t *testing.T) {
	f, h := appHandler(t)
	r := call(t, h, "scryer_add", map[string]any{"key": "series:tvdb:76203", "name": "Curb Your Enthusiasm", "year": 2000, "monitorType": "ALL_EPISODES"})
	if r.Result.StructuredContent["done"].(map[string]any)["action"] != "exists" || len(f.mutations) != 0 {
		t.Fatalf("existing title must not be added again: %v", f.mutations)
	}
	r = call(t, h, "scryer_add", map[string]any{"key": "series:tvdb:999", "name": "Curb", "year": 2024, "monitorType": "FUTURE_EPISODES"})
	if fmt.Sprint(f.mutations) != "[addTitle]" {
		t.Fatalf("add: %v", f.mutations)
	}
	in := f.inputs[0]
	if in["tvdbId"] != "999" || in["facet"] != "SERIES" || in["monitored"] != true || fmt.Sprint(in["options"]) != "map[monitorType:FUTURE_EPISODES]" {
		t.Fatalf("add input: %v", in)
	}
	if title := r.Result.StructuredContent["title"].(map[string]any); title["hydration"] != "pending" || title["id"] != "new" {
		t.Fatalf("pending hydration: %v", title)
	}
	for _, bad := range []map[string]any{
		{"key": "series:imdb:tt1", "name": "x", "monitorType": "NONE"},
		{"key": "series:tvdb:1;drop", "name": "x", "monitorType": "NONE"},
		{"key": "series:tvdb:1", "name": "x", "monitorType": "ADVANCED"},
	} {
		if r := call(t, h, "scryer_add", bad); !r.Result.IsError && r.Error == nil {
			t.Fatalf("accepted %v", bad)
		}
	}
}

// The committed page names the SHA-256 of its sources (scryer-view/build.mjs). A
// source edit without a rebuild fails here, without npm.
func TestScryerViewMatchesItsSources(t *testing.T) {
	dir := "scryer-view"
	list, err := os.ReadFile(filepath.Join(dir, "sources.txt"))
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.New()
	for _, line := range strings.Split(string(list), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, line))
		if err != nil {
			t.Fatal(err)
		}
		fmt.Fprintf(hash, "%s\n%d\n", line, len(data))
		hash.Write(data)
	}
	want := "scryer-media-view source-sha256:" + hex.EncodeToString(hash.Sum(nil))
	if !strings.Contains(scryerViewHTML, want) {
		t.Fatal("dist/media.html is out of date; run node build.mjs in scryer-view")
	}
}
